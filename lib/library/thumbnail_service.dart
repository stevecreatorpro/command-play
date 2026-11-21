import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import 'library_service.dart';

/// Builds a JPEG thumbnail + duration for every library item, offline, using
/// a hidden muted player. Each file is processed once; results are cached in
/// [LibraryService.thumbDir] and `thumb_state` (1 = ok, 2 = no image).
class ThumbnailService {
  ThumbnailService(this.library);

  final LibraryService library;

  /// Bumped whenever a thumbnail/duration is ready, so the UI can refresh.
  final version = ValueNotifier<int>(0);

  bool _running = false;
  bool _again = false;

  File fileFor(MediaItem item) =>
      File(p.join(library.thumbDir, '${item.id}.jpg'));

  /// Returns the cached thumbnail file if one exists.
  File? thumbFor(MediaItem item) {
    final f = fileFor(item);
    return f.existsSync() ? f : null;
  }

  /// Processes all pending items. Safe to call repeatedly (e.g. after a scan).
  Future<void> run() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    Player? player;
    try {
      do {
        _again = false;
        final pending = library.pendingThumbs();
        if (pending.isEmpty) break;
        if (player == null) {
          player = Player();
          // A VideoController makes libmpv decode frames so screenshots work.
          VideoController(player);
          await player.setVolume(0);
        }
        // The hidden player's video surface can take a moment to come up,
        // so the first file(s) may fail: retry failures once at the end.
        final failed = <MediaItem>[];
        for (final item in pending) {
          final state = await _process(player, item);
          if (state == 1) {
            library.setThumbState(item.id, 1);
          } else {
            failed.add(item);
          }
          version.value++;
        }
        for (final item in failed) {
          library.setThumbState(item.id, await _process(player, item));
          version.value++;
        }
      } while (_again);
    } finally {
      await player?.dispose();
      _running = false;
    }
  }

  Future<int> _process(Player player, MediaItem item) async {
    try {
      if (!File(item.path).existsSync()) return 2;
      await player.open(Media(item.path), play: false);
      var dur = player.state.duration;
      if (dur == Duration.zero) {
        dur = await player.stream.duration
            .firstWhere((d) => d > Duration.zero)
            .timeout(const Duration(seconds: 8), onTimeout: () => Duration.zero);
      }
      if (dur > Duration.zero) library.setDuration(item.id, dur.inMilliseconds);

      // Grab a frame ~12% in (skips black intros/logos); if that fails, try
      // again near the start. Long recordings can take seconds to seek, so
      // wait for the position to actually arrive instead of a fixed delay.
      final targets = dur > Duration.zero
          ? [dur * 0.12, dur * 0.03]
          : [const Duration(seconds: 5), const Duration(seconds: 1)];
      for (final target in targets) {
        await player.seek(target);
        await player.stream.position
            .firstWhere((p) => (p - target).abs() < const Duration(seconds: 3))
            .timeout(const Duration(seconds: 5),
                onTimeout: () => Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final bytes = await player.screenshot(format: 'image/jpeg');
        if (bytes != null && bytes.length > 2000) {
          await fileFor(item).writeAsBytes(bytes, flush: true);
          return 1;
        }
      }
    } catch (_) {
      // Unsupported/corrupt file: fall back to gradient artwork.
    }
    return 2;
  }
}
