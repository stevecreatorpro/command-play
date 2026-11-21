/// Source of recognised speech. Implementations: Vosk (offline, mic),
/// later sherpa-onnx / whisper.cpp. Typed commands bypass this entirely.
abstract class VoiceInput {
  /// Final transcripts (one per spoken utterance).
  Stream<String> get transcripts;
  Future<void> start();
  Future<void> stop();
  bool get isSupported;
}
