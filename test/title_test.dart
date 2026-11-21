import 'package:command_play/library/library_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release-style file names become readable titles', () {
    expect(prettyTitle('Reacher.S01E08.480p.AMZN.WEBRip.x265.[9jaRocks.Com]'),
        'Reacher S01E08');
    expect(prettyTitle('Reacher.S02E01.480p.HEVC.x265'), 'Reacher S02E01');
    expect(prettyTitle('Oppenheimer.2023.1080p.BluRay.x264.YIFY'),
        'Oppenheimer 2023');
    expect(prettyTitle('SEN301LL_Y3_01_03'), 'SEN301LL Y3 01 03');
    // Seen in the user's library:
    expect(prettyTitle('SEN301LL_Y3_01_03.mp4'), 'SEN301LL Y3 01 03');
    expect(prettyTitle('Reacher.S02E01.480p.HEVC.x265-MeGusta[eztv.re]'),
        'Reacher S02E01');
  });

  test('normal titles are left alone', () {
    const t = 'SEN 322- Recorded Live Lesson (16th September, 2026) - Miva';
    expect(prettyTitle(t), t);
    expect(prettyTitle('Wonder Park'), 'Wonder Park');
    expect(prettyTitle('Meg 2: The Trench'), 'Meg 2: The Trench');
  });
}
