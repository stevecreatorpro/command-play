import '../library/library_service.dart';
import '../playback/playback_service.dart';
import '../voice/voice_controller.dart';
import 'action_registry.dart';
import 'intent.dart';

/// Binds every [kActionSpecs] id to real behaviour.
ActionRegistry buildRegistry({
  required PlaybackService playback,
  required LibraryService library,
  required ChoiceSession session,
}) {
  ActionResult ok(bool success, String message) =>
      ActionResult(success, message);
  final r = ActionRegistry();

  r.register('play', (_) async {
    await playback.play();
    return ok(true, 'Playing');
  });
  r.register('pause', (_) async {
    await playback.pause();
    return ok(true, 'Paused');
  });
  r.register('stop', (_) async {
    await playback.stop();
    return ok(true, 'Stopped');
  });
  r.register('next', (_) async {
    await playback.next();
    return ok(true, 'Next');
  });
  r.register('previous', (_) async {
    await playback.previous();
    return ok(true, 'Previous');
  });

  r.register('seekRelative', (a) async {
    final s = a['seconds'] as int;
    await playback.seekRelative(Duration(seconds: s));
    return ok(true, s >= 0 ? 'Forward $s seconds' : 'Back ${-s} seconds');
  });
  r.register('seekAbsolute', (a) async {
    if (a['fraction'] != null) {
      await playback.seekFraction((a['fraction'] as num).toDouble());
    } else {
      await playback.seekTo(Duration(milliseconds: a['ms'] as int));
    }
    return ok(true, 'Done');
  });

  r.register('volumeSet', (a) async {
    final v = (a['percent'] as num).toDouble();
    await playback.setVolume(v);
    return ok(true, 'Volume ${v.round()}');
  });
  r.register('volumeDelta', (a) async {
    final v = playback.state.volume + (a['delta'] as num);
    await playback.setVolume(v);
    return ok(true, 'Volume ${v.clamp(0, 130).round()}');
  });
  r.register('mute', (_) async {
    await playback.mute();
    return ok(true, 'Muted');
  });
  r.register('unmute', (_) async {
    await playback.unmute();
    return ok(true, 'Unmuted');
  });

  r.register('speedSet', (a) async {
    final s = (a['speed'] as num).toDouble();
    await playback.setSpeed(s);
    return ok(true, 'Speed $s times');
  });
  r.register('speedDelta', (a) async {
    final s = playback.state.rate + (a['delta'] as num);
    await playback.setSpeed(s);
    return ok(true, 'Speed ${s.clamp(0.25, 4.0)} times');
  });

  r.register('search', (a) async {
    final q = a['query'] as String;
    final shouldPlay = a['play'] as bool;
    final hits = library.search(q);
    if (hits.isEmpty) {
      return ok(false, 'I could not find $q');
    }
    final clearWinner = hits.first.score >= 0.95 &&
        (hits.length == 1 || hits[1].score < 0.8);
    if (shouldPlay && (hits.length == 1 || clearWinner)) {
      session.clear();
      final item = hits.first.item;
      if (!await playback.openItem(item)) {
        return ok(false, '${item.displayTitle} is missing from this device');
      }
      return ok(true, 'Playing ${item.displayTitle}');
    }
    session.set([for (final h in hits) h.item]);
    final spoken = [
      for (var i = 0; i < hits.length && i < 3; i++)
        '${i + 1}, ${hits[i].item.displayTitle}'
    ].join('. ');
    return ok(true, 'I found ${hits.length}. $spoken. Which one?');
  });
  r.register('choose', (a) async {
    final i = (a['index'] as int) - 1;
    if (i < 0 || i >= session.candidates.length) {
      return ok(false, 'There is no such option.');
    }
    final item = session.candidates[i];
    session.clear();
    if (!await playback.openItem(item)) {
      return ok(false, '${item.displayTitle} is missing from this device');
    }
    return ok(true, 'Playing ${item.displayTitle}');
  });
  r.register('cancel', (_) async {
    session.clear();
    return ok(true, 'Okay');
  });

  assert(r.missingHandlers.isEmpty,
      'Actions without handlers: ${r.missingHandlers}');
  return r;
}
