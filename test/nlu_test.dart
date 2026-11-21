import 'package:command_play/core/action_specs.dart';
import 'package:command_play/voice/nlu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nlu = Nlu();

  test('every spec example parses to its own action (voice parity)', () {
    for (final spec in kActionSpecs) {
      expect(spec.examples.length, greaterThanOrEqualTo(3),
          reason: '${spec.id} needs >= 3 example phrases');
      for (final phrase in spec.examples) {
        final intent = nlu.parse(phrase, hasCandidates: true);
        expect(intent?.actionId, spec.id, reason: '"$phrase"');
      }
    }
  });

  test('arguments', () {
    expect(nlu.parse('skip forward 30 seconds')!.args['seconds'], 30);
    expect(nlu.parse('go back 10 seconds')!.args['seconds'], -10);
    expect(nlu.parse('rewind')!.args['seconds'], -10);
    expect(nlu.parse('go to one hour five minutes')!.args['ms'], 3900000);
    expect(nlu.parse('go to 50 percent')!.args['fraction'], 0.5);
    expect(nlu.parse('volume to fifty')!.args['percent'], 50);
    expect(nlu.parse('play at 1.5x')!.args['speed'], 1.5);
    expect(nlu.parse('Hey Play, pause')!.actionId, 'pause');
    final s = nlu.parse('play the song thriller')!;
    expect(s.args['query'], 'thriller');
    expect(s.args['play'], true);
  });

  test('choose only when results are pending', () {
    expect(nlu.parse('the second one')?.actionId, isNull);
    expect(nlu.parse('the second one', hasCandidates: true)!.args['index'], 2);
  });
}
