import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'voice_input.dart';

/// Offline speech recognition with Vosk. The model zip is bundled in
/// assets/models, so no network is ever needed.
///
/// - Android: Vosk's own SpeechService captures the mic.
/// - Windows/Linux: the `record` package streams raw 16 kHz mono PCM, which is
///   fed straight into the Vosk recognizer via FFI (libvosk.dll / .so).
class VoskVoiceInput implements VoiceInput {
  VoskVoiceInput(
      {this.modelAsset = 'assets/models/vosk-model-small-en-us-0.15.zip'});

  static const _sampleRate = 16000;

  final String modelAsset;
  final _finals = StreamController<String>.broadcast();
  final _partials = StreamController<String>.broadcast();

  Recognizer? _recognizer;

  // Android
  SpeechService? _service;
  StreamSubscription<String>? _serviceSub;

  // Desktop
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSub;
  Future<void> _queue = Future.value(); // keeps audio chunks in order

  bool get _isDesktop => Platform.isWindows || Platform.isLinux;

  @override
  bool get isSupported => Platform.isAndroid || _isDesktop;

  @override
  Stream<String> get transcripts => _finals.stream;

  /// Live, in-progress text while the user is still speaking.
  Stream<String> get partialTranscripts => _partials.stream;

  bool get isModelLoaded => _recognizer != null;

  /// Unzips (first run only) and loads the model, then creates a recognizer.
  Future<void> _ensureRecognizer() async {
    if (_recognizer != null) return;
    final vosk = VoskFlutterPlugin.instance();
    final modelPath = await ModelLoader().loadFromAssets(modelAsset);
    final model = await vosk.createModel(modelPath);
    // TODO: pass `grammar:` built from command words + library titles to bias
    // recognition toward what the user can actually say.
    _recognizer =
        await vosk.createRecognizer(model: model, sampleRate: _sampleRate);
  }

  @override
  Future<void> start() async {
    if (!isSupported) return;
    if (Platform.isAndroid) {
      await _startAndroid();
    } else {
      await _startDesktop();
    }
  }

  Future<void> _startAndroid() async {
    if (!(await Permission.microphone.request()).isGranted) {
      throw StateError('Microphone permission denied');
    }
    await _ensureRecognizer();
    if (_service == null) {
      _service =
          await VoskFlutterPlugin.instance().initSpeechService(_recognizer!);
      _serviceSub = _service!.onResult().listen(_emitFinalJson);
      _service!.onPartial().listen((json) => _emitPartialJson(json));
    }
    await _service!.start();
  }

  Future<void> _startDesktop() async {
    _recorder ??= AudioRecorder();
    if (!await _recorder!.hasPermission()) {
      throw StateError('Microphone permission denied. Check Windows '
          'Settings > Privacy > Microphone.');
    }
    await _ensureRecognizer();
    final stream = await _recorder!.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));
    _micSub = stream.listen((chunk) {
      _queue = _queue.then((_) => _process(chunk));
    });
  }

  Future<void> _process(Uint8List chunk) async {
    final r = _recognizer;
    if (r == null) return;
    final sentenceDone = await r.acceptWaveformBytes(chunk);
    if (sentenceDone) {
      _emitFinalJson(await r.getResult());
    } else {
      _emitPartialJson(await r.getPartialResult());
    }
  }

  void _emitFinalJson(String json) {
    final text = (jsonDecode(json) as Map)['text'] as String? ?? '';
    _partials.add('');
    if (text.trim().isNotEmpty) _finals.add(text.trim());
  }

  void _emitPartialJson(String json) {
    final text = (jsonDecode(json) as Map)['partial'] as String? ?? '';
    _partials.add(text);
  }

  @override
  Future<void> stop() async {
    if (Platform.isAndroid) {
      await _service?.stop();
      return;
    }
    await _micSub?.cancel();
    _micSub = null;
    await _recorder?.stop();
    await _queue;
    // Flush whatever was said right before the user pressed stop.
    final r = _recognizer;
    if (r != null) _emitFinalJson(await r.getFinalResult());
  }

  Future<void> dispose() async {
    await stop();
    await _serviceSub?.cancel();
    await _service?.dispose();
    await _recorder?.dispose();
    await _recognizer?.dispose();
    await _finals.close();
    await _partials.close();
  }
}
