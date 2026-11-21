import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/action_registry.dart';
import '../library/library_service.dart';
import 'nlu.dart';

/// Pending search results the user can pick from ("the second one").
class ChoiceSession extends ChangeNotifier {
  List<MediaItem> candidates = const [];

  void set(List<MediaItem> items) {
    candidates = items;
    notifyListeners();
  }

  void clear() => set(const []);
}

/// Single-word noises the recogniser emits for coughs, breaths or the
/// player's own audio. Ignored instead of answered.
const _fillers = {
  'huh', 'uh', 'um', 'umm', 'hmm', 'hm', 'ah', 'oh', 'eh', 'er', 'mm', 'the',
  'a', 'an', 'and', 'i', 'it', 'is', 'that', 'yeah', 'yes', 'no', 'so', 'but',
};

/// transcript (voice or typed) -> NLU -> action registry -> spoken feedback.
class VoiceController extends ChangeNotifier {
  VoiceController({
    required this.nlu,
    required this.registry,
    required this.session,
    FlutterTts? tts,
  }) : _tts = tts {
    _tts?.awaitSpeakCompletion(true);
  }

  final Nlu nlu;
  final ActionRegistry registry;
  final ChoiceSession session;
  final FlutterTts? _tts;

  String heard = '';
  String feedback = '';
  bool listening = false;
  bool speakFeedback = true;

  bool _speaking = false;
  DateTime _quietUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// True while the app's own voice is playing (plus a short tail), so the
  /// microphone does not treat the app's reply as a new command.
  bool get isSpeaking => _speaking || DateTime.now().isBefore(_quietUntil);

  void setListening(bool v) {
    listening = v;
    notifyListeners();
  }

  /// Text from the microphone: filtered for noise and self-echo.
  Future<void> handleSpeech(String text) async {
    final t = text.trim().toLowerCase();
    if (t.isEmpty || isSpeaking) return;
    final words = t.split(RegExp(r'\s+'));
    if (words.every(_fillers.contains)) return; // "huh", "the", ...
    final intent =
        nlu.parse(text, hasCandidates: session.candidates.isNotEmpty);
    if (intent == null) {
      // Show, but do not speak: avoids talk-back loops on background noise.
      heard = text;
      feedback = "I didn't catch that. Try \"play\" followed by a name.";
      notifyListeners();
      return;
    }
    await _run(text, speak: true);
  }

  /// Text typed by the user (or from a tapped result).
  Future<void> handleText(String text) => _run(text, speak: true);

  Future<void> _run(String text, {required bool speak}) async {
    heard = text;
    final intent =
        nlu.parse(text, hasCandidates: session.candidates.isNotEmpty);
    if (intent == null) {
      feedback = "I didn't catch that. Try \"play\" followed by a name.";
    } else {
      final result = await registry.execute(intent);
      feedback = result.message;
    }
    notifyListeners();
    if (speak && speakFeedback && _tts != null) {
      _speaking = true;
      try {
        await _tts.speak(feedback);
      } finally {
        _speaking = false;
        _quietUntil = DateTime.now().add(const Duration(milliseconds: 700));
      }
    }
  }
}
