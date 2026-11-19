import 'package:material_ui/material_ui.dart';

/// Dark "studio at night" look with neon accents.
class AppColors {
  static const background = Color(0xFF0B0C16);
  static const surface = Color(0xFF161828);
  static const surfaceHigh = Color(0xFF20233A);
  static const text = Color(0xFFECEEFF);
  static const textDim = Color(0xFF8D91B3);
  static const record = Color(0xFFFF3B5C);
  static const accent = Color(0xFF7C5CFF);

  /// Per-track colours, cycled.
  static const tracks = [
    Color(0xFF7C5CFF),
    Color(0xFF00D1C1),
    Color(0xFFFFB238),
    Color(0xFFFF5CA8),
    Color(0xFF4DA3FF),
    Color(0xFF8BE04E),
  ];

  static Color track(int i) => tracks[i % tracks.length];

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF151033), background, Color(0xFF07131A)],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(surface: AppColors.surface, primary: AppColors.accent);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
    ),
  );
}

String formatTime(double seconds) {
  final neg = seconds < 0;
  final s = seconds.abs();
  final m = s ~/ 60;
  final sec = (s % 60).floor();
  final tenth = ((s * 10) % 10).floor();
  return '${neg ? '-' : ''}$m:${sec.toString().padLeft(2, '0')}.$tenth';
}
