import 'package:flutter/material.dart';

const _seed = Color(0xFF4A6B6F);

ThemeData get lightTheme => _buildTheme(Brightness.light);
ThemeData get darkTheme => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 18, height: 1.5),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 16, height: 1.5),
    ),
  );
}
