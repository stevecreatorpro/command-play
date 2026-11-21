import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../library/library_service.dart';

/// Thin wrapper over media_kit (libmpv). The rest of the app, including all
/// voice actions, talks only to this class.
///
/// Handles the things users expect from a good player: a real queue (so
/// next/previous and auto-advance work), resume-where-you-left-off, and
/// surfacing playback errors instead of failing silently.
class PlaybackService {
  PlaybackService({this.library}) {
    video = VideoController(player);
    player.stream.playlist.listen(_onPlaylist);
    player.stream.error.listen((e) {
      if (e.trim().isNotEmpty) lastError.value = e;
    });
    _saver = Timer.periodic(const Duration(seconds: 5), (_) => _savePosition());
  }

  final LibraryService? library;
  final Player player = Player();
  late final VideoController video;
  double _volumeBeforeMute = 100;
  late final Timer _saver;

  List<MediaItem> _queue = const [];

  /// What is loaded right now (null before anything is opened).
  final nowPlaying = ValueNotifier<MediaItem?>(null);

  /// Latest playback error (e.g. unsupported or corrupt file).
  final lastError = ValueNotifier<String?>(null);

  PlayerState get state => player.state;

  /// Plays [items] as a queue starting at [index]. Returns false if the file
  /// no longer exists.
  Future<bool> openQueue(List<MediaItem> items, int index) async {
    final item = items[index];
    if (!File(item.path).existsSync()) {
      lastError.value = 'File not found: ${item.displayTitle}';
      return false;
    }
    await _savePosition();
    _queue = List.unmodifiable(items);
    nowPlaying.value = item;
    await player.open(
      Playlist([for (final i in items) Media(i.path)], index: index),
      play: true,
    );
    unawaited(_resume(item));
    return true;
  }

  Future<bool> openItem(MediaItem item) => openQueue([item], 0);

  void _onPlaylist(Playlist pl) {
    if (_queue.isEmpty || pl.index < 0 || pl.index >= _queue.length) return;
    final item = _queue[pl.index];
    if (nowPlaying.value?.id == item.id) return;
    nowPlaying.value = item; // auto-advance / next / previous
    unawaited(_resume(item));
  }

  /// Seeks to the saved position (if meaningful) once the file is ready.
  Future<void> _resume(MediaItem item) async {
    final saved = library?.positionOf(item.id) ?? 0;
    if (saved < 10000) return;
    var dur = state.duration;
    if (dur == Duration.zero) {
      dur = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 6), onTimeout: () => Duration.zero);
    }
    if (nowPlaying.value?.id != item.id) return;
    if (dur == Duration.zero || saved > dur.inMilliseconds - 10000) return;
    await player.seek(Duration(milliseconds: saved));
  }

  Future<void> _savePosition() async {
    final item = nowPlaying.value;
    final lib = library;
    if (item == null || lib == null) return;
    final pos = state.position.inMilliseconds;
    final dur = state.duration.inMilliseconds;
    if (dur <= 0 || pos <= 0) return;
    // Finished (or nearly): start from the beginning next time.
    lib.setPosition(item.id, pos > dur - 15000 ? 0 : pos);
    if (item.durationMs == 0) lib.setDuration(item.id, dur);
  }

  Future<void> play() => player.play();
  Future<void> pause() async {
    await player.pause();
    await _savePosition();
  }

  Future<void> playOrPause() => player.playOrPause();
  Future<void> stop() async {
    await _savePosition();
    await player.stop();
  }

  Future<void> next() => player.next();
  Future<void> previous() => player.previous();

  Future<void> seekTo(Duration p) => player.seek(p);

  Future<void> seekRelative(Duration delta) {
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    final d = state.duration;
    if (d > Duration.zero && target > d) target = d;
    return player.seek(target);
  }

  Future<void> seekFraction(double f) =>
      player.seek(state.duration * f.clamp(0.0, 1.0));

  /// 0..100 (media_kit allows >100 for boost).
  Future<void> setVolume(double v) => player.setVolume(v.clamp(0, 130));

  Future<void> mute() async {
    if (state.volume > 0) _volumeBeforeMute = state.volume;
    await player.setVolume(0);
  }

  Future<void> unmute() => player.setVolume(_volumeBeforeMute);

  Future<void> setSpeed(double s) => player.setRate(s.clamp(0.25, 4.0));

  Future<void> dispose() async {
    _saver.cancel();
    await _savePosition();
    await player.dispose();
  }
}
