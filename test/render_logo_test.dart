// Renders the in-app logo painter to PNG files used for app icons, so the
// icon and the in-app logo are always the same artwork.
// Run with:  RENDER_LOGO=1 flutter test test/render_logo_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:command_play/ui/logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(String path, int px, {required bool background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CPlayLogoPainter(background: background)
      .paint(canvas, Size(px.toDouble(), px.toDouble()));
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render logo PNGs', () async {
    await _render('assets/icon/app_icon.png', 1024, background: true);
    await _render('assets/icon/app_icon_foreground.png', 1024,
        background: false);
  },
      skip: Platform.environment['RENDER_LOGO'] == null
          ? 'Set RENDER_LOGO=1 to regenerate icon PNGs'
          : null);
}
