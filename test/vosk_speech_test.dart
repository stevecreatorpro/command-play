// Real-speech test: WAV files -> Vosk (via libvosk FFI) -> NLU -> action.
//
// Skipped unless these env vars are set (needs the unzipped model + WAVs):
//   VOSK_MODEL_DIR  folder of the unzipped vosk model
//   VOSK_WAV_DIR    folder with pause.wav, skip.wav, volume.wav, play.wav,
//                   back.wav (16 kHz mono 16-bit PCM)
// and libvosk.dll on PATH (e.g. the vosk_flutter windows/libs folder).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:command_play/voice/nlu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

Uint8List _pcmFromWav(File f) {
  final b = f.readAsBytesSync();
  final d = ByteData.sublistView(b);
  var i = 12; // skip "RIFF" size "WAVE"
  while (i + 8 <= b.length) {
    final id = ascii.decode(b.sublist(i, i + 4));
    final size = d.getUint32(i + 4, Endian.little);
    if (id == 'data') return b.sublist(i + 8, i + 8 + size);
    i += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('No data chunk in ${f.path}');
}

Future<String> _recognize(Recognizer r, Uint8List pcm) async {
  final texts = <String>[];
  const chunk = 8000; // 0.25 s of 16 kHz 16-bit mono, like a mic stream
  for (var o = 0; o < pcm.length; o += chunk) {
    final end = o + chunk < pcm.length ? o + chunk : pcm.length;
    if (await r.acceptWaveformBytes(pcm.sublist(o, end))) {
      texts.add((jsonDecode(await r.getResult()) as Map)['text'] as String);
    }
  }
  texts.add((jsonDecode(await r.getFinalResult()) as Map)['text'] as String);
  return texts.where((t) => t.trim().isNotEmpty).join(' ').trim();
}

void main() {
  final modelDir = Platform.environment['VOSK_MODEL_DIR'];
  final wavDir = Platform.environment['VOSK_WAV_DIR'];
  final skip = modelDir == null || wavDir == null
      ? 'Set VOSK_MODEL_DIR and VOSK_WAV_DIR to run real-speech tests'
      : null;

  test('spoken commands become the right actions', () async {
    final vosk = VoskFlutterPlugin.instance();
    final model = await vosk.createModel(modelDir!);
    final nlu = Nlu();
    const expected = {
      'pause': 'pause',
      'skip': 'seekRelative',
      'volume': 'volumeSet',
      'play': 'search',
      'back': 'seekRelative',
    };
    for (final e in expected.entries) {
      final r = await vosk.createRecognizer(model: model, sampleRate: 16000);
      final heard = await _recognize(r, _pcmFromWav(File('$wavDir/${e.key}.wav')));
      final intent = nlu.parse(heard);
      // ignore: avoid_print
      print('${e.key.padRight(7)} heard "$heard" -> $intent');
      expect(intent?.actionId, e.value, reason: 'heard "$heard"');
      await r.dispose();
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
