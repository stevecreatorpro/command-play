import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class MediaItem {
  const MediaItem(
    this.id,
    this.path,
    this.title,
    this.folder, {
    this.durationMs = 0,
    this.positionMs = 0,
  });

  final int id;
  final String path;
  final String title;
  final String folder;
  final int durationMs;
  final int positionMs;

  bool get isVideo => _videoExt.contains(p.extension(path).toLowerCase());

  Duration get duration => Duration(milliseconds: durationMs);

  /// Human-friendly title: "Reacher.S01E08.480p.AMZN.WEBRip.x265.[site]"
  /// becomes "Reacher S01E08".
  String get displayTitle => prettyTitle(title);
}

final _junkTokens = RegExp(
  r'\b(480p|576p|720p|1080p|1440p|2160p|4k|uhd|hdr|x264|x265|h264|h265|hevc|'
  r'avc|webrip|web-dl|webdl|web|bluray|blu-ray|brrip|bdrip|dvdrip|hdtv|hdrip|'
  r'amzn|nf|dsnp|hmax|aac|ac3|dts|ddp5|ddp|5\.1|10bit|8bit|yify|yts|rarbg|'
  r'psa|galaxyrg|tgx|proper|repack|extended|unrated)\b',
  caseSensitive: false,
);

String prettyTitle(String raw) {
  var t = raw.replaceAll(RegExp(r'\[[^\]]*\]'), ''); // [site] tags
  final looksLikeRelease = RegExp(r'[._]').hasMatch(t) && !t.trim().contains(' ');
  t = t.replaceAll(RegExp(r'[._]+'), ' ');
  if (looksLikeRelease) {
    // Cut at the first quality/source token: everything after is noise.
    final m = _junkTokens.firstMatch(t);
    if (m != null && m.start > 0) t = t.substring(0, m.start);
  }
  t = t.replaceAll(_junkTokens, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // Leftover extensions from names like 'lesson.mp4.mp4'.
  t = t.replaceAll(
      RegExp(r'(\s(mp4|mkv|avi|mov|webm|wmv|m4v|mp3|m4a|flac|wav))+$',
          caseSensitive: false),
      '');
  t = t.replaceAll(RegExp(r'[\s\-\u2013]+$'), '');
  return t.isEmpty ? raw : t;
}

class SearchHit {
  const SearchHit(this.item, this.score);
  final MediaItem item;
  final double score; // 0..1
}

const _videoExt = {
  '.mp4', '.mkv', '.avi', '.mov', '.webm', '.flv', '.ts', '.3gp', '.wmv',
  '.m4v',
};

const _mediaExt = {
  ..._videoExt,
  '.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg', '.opus', '.wma', '.alac',
};

const _cols =
    'm.id,m.path,m.title,m.folder,m.duration_ms,m.position_ms';

/// Local media index: SQLite + FTS5, with fuzzy fallback for mis-heard names.
class LibraryService {
  LibraryService._(this._db, this.thumbDir);
  final Database _db;

  /// Folder holding cached thumbnail JPEGs (`<id>.jpg`).
  final String thumbDir;

  static Future<LibraryService> open({String? dbPath}) async {
    final path = dbPath ??
        p.join((await getApplicationSupportDirectory()).path, 'library.db');
    final db = sqlite3.open(path);
    db.execute('''
      CREATE TABLE IF NOT EXISTS media(
        id INTEGER PRIMARY KEY,
        path TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        folder TEXT NOT NULL,
        added_at INTEGER NOT NULL
      );
      CREATE VIRTUAL TABLE IF NOT EXISTS media_fts USING fts5(title, folder);
    ''');
    // Migrations for databases created by earlier versions.
    final cols = {
      for (final r in db.select('PRAGMA table_info(media)')) r['name'] as String
    };
    for (final c in ['duration_ms', 'position_ms', 'thumb_state']) {
      if (!cols.contains(c)) {
        db.execute('ALTER TABLE media ADD COLUMN $c INTEGER NOT NULL DEFAULT 0');
      }
    }
    // v2: thumbnail grabbing became more patient; retry earlier failures once.
    final version = db.select('PRAGMA user_version').first.values.first as int;
    // v3: failed thumbnails are retried at the end of a run.
    if (version < 3) {
      db.execute('UPDATE media SET thumb_state=0 WHERE thumb_state=2');
      db.execute('PRAGMA user_version = 3');
    }
    final thumbs = p.join(p.dirname(path), 'thumbs');
    Directory(thumbs).createSync(recursive: true);
    return LibraryService._(db, thumbs);
  }

  /// Recursively indexes a folder. Works offline; no network involved.
  Future<int> scan(String dir) async {
    var added = 0;
    final insert = _db.prepare(
        'INSERT OR IGNORE INTO media(path,title,folder,added_at) VALUES(?,?,?,?)');
    final fts =
        _db.prepare('INSERT INTO media_fts(rowid,title,folder) VALUES(?,?,?)');
    _db.execute('BEGIN');
    try {
      await for (final e
          in Directory(dir).list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        if (!_mediaExt.contains(p.extension(e.path).toLowerCase())) continue;
        final title = p.basenameWithoutExtension(e.path);
        final folder = p.basename(p.dirname(e.path));
        insert.execute([
          e.path,
          title,
          folder,
          DateTime.now().millisecondsSinceEpoch,
        ]);
        if (_db.updatedRows > 0) {
          // Index both the raw and the pretty title so voice search matches
          // "reacher s01e08" as well as the file name.
          fts.execute([
            _db.lastInsertRowId,
            '${_clean(title)} ${_clean(prettyTitle(title))}',
            _clean(folder),
          ]);
          added++;
        }
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    } finally {
      insert.dispose();
      fts.dispose();
    }
    return added;
  }

  /// Removes entries whose files were deleted or moved. Returns count removed.
  int pruneMissing() {
    final gone = [
      for (final r in _db.select('SELECT id,path FROM media'))
        if (!File(r['path'] as String).existsSync()) r['id'] as int
    ];
    for (final id in gone) {
      _db.execute('DELETE FROM media WHERE id=?', [id]);
      _db.execute('DELETE FROM media_fts WHERE rowid=?', [id]);
      final thumb = File(p.join(thumbDir, '$id.jpg'));
      if (thumb.existsSync()) thumb.deleteSync();
    }
    return gone.length;
  }

  /// Everything in the library, newest first.
  List<MediaItem> all({int limit = 5000}) => [
        for (final r in _db.select(
            'SELECT $_cols FROM media m ORDER BY m.added_at DESC, m.title '
            'LIMIT ?',
            [limit]))
          _item(r),
      ];

  /// Items whose thumbnail has not been attempted yet.
  List<MediaItem> pendingThumbs() => [
        for (final r in _db.select(
            'SELECT $_cols FROM media m WHERE m.thumb_state=0 '
            'ORDER BY m.added_at DESC'))
          _item(r),
      ];

  void setThumbState(int id, int state) =>
      _db.execute('UPDATE media SET thumb_state=? WHERE id=?', [state, id]);

  void setDuration(int id, int ms) =>
      _db.execute('UPDATE media SET duration_ms=? WHERE id=?', [ms, id]);

  void setPosition(int id, int ms) =>
      _db.execute('UPDATE media SET position_ms=? WHERE id=?', [ms, id]);

  int positionOf(int id) {
    final r = _db.select('SELECT position_ms FROM media WHERE id=?', [id]);
    return r.isEmpty ? 0 : r.first['position_ms'] as int;
  }

  int get count =>
      _db.select('SELECT COUNT(*) c FROM media').first['c'] as int;

  /// Exact/prefix match via FTS5 first, then fuzzy edit-distance fallback.
  List<SearchHit> search(String query, {int limit = 5}) {
    final q = _clean(query);
    final tokens = q.split(' ').where((w) => w.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];

    final match = tokens.map((w) => '"$w"*').join(' ');
    final rows = _db.select(
      'SELECT $_cols FROM media_fts f '
      'JOIN media m ON m.id=f.rowid WHERE media_fts MATCH ? '
      'ORDER BY rank LIMIT 50',
      [match],
    );
    var hits = [
      for (final r in rows) SearchHit(_item(r), _bestScore(r, q).clamp(0.7, 1.0)),
    ];

    if (hits.isEmpty) {
      // Speech engines mis-hear names ("la mar" vs "lamar"): fuzzy fallback.
      final all = _db.select('SELECT $_cols FROM media m');
      hits = [
        for (final r in all) SearchHit(_item(r), _bestScore(r, q)),
      ].where((h) => h.score >= 0.55).toList();
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  double _bestScore(Row r, String q) {
    final raw = r['title'] as String;
    final a = _similarity(_clean(raw), q);
    final b = _similarity(_clean(prettyTitle(raw)), q);
    return a > b ? a : b;
  }

  MediaItem _item(Row r) => MediaItem(
        r['id'] as int,
        r['path'] as String,
        r['title'] as String,
        r['folder'] as String,
        durationMs: r['duration_ms'] as int? ?? 0,
        positionMs: r['position_ms'] as int? ?? 0,
      );

  static String _clean(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// 1 - normalized Levenshtein distance.
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var diag = prev[0];
      prev[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final tmp = prev[j];
        prev[j] = [
          prev[j] + 1,
          prev[j - 1] + 1,
          diag + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
        diag = tmp;
      }
    }
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1 - prev[b.length] / maxLen;
  }

  void dispose() => _db.dispose();
}
