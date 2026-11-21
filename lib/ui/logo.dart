import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Command Play logo: a bold white "C" whose open mouth points right,
/// cradling a rounded deep-to-light purple play triangle -
/// "C" for Command, the triangle for Play.
class CPlayLogo extends StatelessWidget {
  const CPlayLogo({super.key, this.size = 40, this.background = false});

  final double size;

  /// Draw on the black rounded-square tile (used for app icons).
  final bool background;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: CPlayLogoPainter(background: background)),
      );
}

class CPlayLogoPainter extends CustomPainter {
  CPlayLogoPainter({this.background = false});
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);

    if (background) {
      final tile = RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(s * 0.23));
      canvas.drawRRect(
        tile,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 1.2,
            colors: [Color(0xFF2A1F4D), CP.black],
          ).createShader(Offset.zero & size),
      );
    }

    final scale = background ? 0.78 : 1.0;
    final r = s * 0.36 * scale; // ring radius
    final stroke = s * 0.15 * scale;

    // Soft purple glow behind the C.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = CP.purpleDeep.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
    );

    // The "C": a solid white ring segment with a mouth facing right. Its ends
    // are cut on a slant: the outer edge reaches further into the mouth than
    // the inner edge, giving crisp angled "/" terminals instead of round caps.
    const gap = 84 * math.pi / 180;
    const slant = 6 * math.pi / 180;
    final outer = Rect.fromCircle(center: c, radius: r + stroke / 2);
    final inner = Rect.fromCircle(center: c, radius: r - stroke / 2);
    const outerStart = gap / 2 - slant;
    const outerEnd = 2 * math.pi - gap / 2 + slant;
    const innerStart = gap / 2;
    const innerEnd = 2 * math.pi - gap / 2;
    final cShape = Path()
      ..arcTo(outer, outerStart, outerEnd - outerStart, true)
      ..arcTo(inner, innerEnd, -(innerEnd - innerStart), false)
      ..close();
    canvas.drawPath(cShape, Paint()..color = CP.white);

    // Play triangle: centred slightly right so its tip breaks out of the C.
    final t = r * 0.95;
    final tc = c.translate(r * 0.22, 0);
    final p1 = tc.translate(-t * 0.45, -t * 0.55);
    final p2 = tc.translate(-t * 0.45, t * 0.55);
    final p3 = tc.translate(t * 0.62, 0);
    final tri = _roundedTriangle(p1, p2, p3, s * 0.035 * scale);
    canvas.drawPath(
      tri,
      Paint()
        // Play icon: deep purple -> light purple gradient.
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [CP.purpleDeep, CP.purple],
        ).createShader(tri.getBounds()),
    );
  }

  Path _roundedTriangle(Offset a, Offset b, Offset c, double radius) {
    Offset towards(Offset from, Offset to, double d) {
      final v = to - from;
      return from + v / v.distance * d;
    }

    final pts = [a, b, c];
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final cur = pts[i];
      final prev = pts[(i + 2) % 3];
      final next = pts[(i + 1) % 3];
      final start = towards(cur, prev, radius);
      final end = towards(cur, next, radius);
      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, end.dx, end.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant CPlayLogoPainter old) =>
      old.background != background;
}
