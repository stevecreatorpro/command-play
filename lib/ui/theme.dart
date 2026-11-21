import 'package:flutter/material.dart';

/// Command Play palette: black, light purple and white, with gradients.
class CP {
  static const black = Color(0xFF07060B);
  static const surface = Color(0xFF12101A);
  static const surfaceHigh = Color(0xFF1C1828);
  static const stroke = Color(0x22FFFFFF);

  static const purpleDeep = Color(0xFF7C4DFF);
  static const purple = Color(0xFFB69CFF); // light purple accent
  static const lavender = Color(0xFFE6DCFF);
  static const white = Colors.white;
  static const textDim = Color(0xFFA9A3BC);

  /// Main accent gradient: deep purple -> light purple -> near white.
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purpleDeep, purple, lavender],
  );

  static const accentSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1F4D), Color(0xFF15111F)],
  );

  /// Fades used over video so controls stay readable.
  static const scrimTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xCC000000), Color(0x00000000)],
  );
  static const scrimBottom = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xEE000000), Color(0x00000000)],
  );

  /// Distinct-but-on-palette gradients for media thumbnails.
  static const thumbGradients = [
    [Color(0xFF7C4DFF), Color(0xFF2B1A5E)],
    [Color(0xFFB69CFF), Color(0xFF4B2C8F)],
    [Color(0xFF5B3FD1), Color(0xFF120E22)],
    [Color(0xFFE6DCFF), Color(0xFF7C4DFF)],
    [Color(0xFF9D7BFF), Color(0xFF1C1828)],
  ];

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: purpleDeep,
        brightness: Brightness.dark,
        primary: purple,
        surface: surface,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: black,
      sliderTheme: const SliderThemeData(
        activeTrackColor: purple,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: white,
        overlayColor: Color(0x33B69CFF),
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: white,
        displayColor: white,
      ),
      iconTheme: const IconThemeData(color: white),
    );
  }
}
