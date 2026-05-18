import 'package:flutter/material.dart';

const _seed = Color(0xFF4A6B6F);

/// Neutral dark, de-tinted from the teal seed. Shared by the Home writing
/// panel and the disabled (inert) button so the two surfaces match exactly.
/// Tuned for the app's dark theme (its only mode).
const kSurfacePanel = Color(0xFF1E2124);

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

  // Body text is 20px; the M3 default 14px button label is the cause of the
  // "strange / hard to read" button. Match the label to the body weight.
  final buttonLabelStyle = base.textTheme.bodyLarge?.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.5),
      bodyMedium:
          base.textTheme.bodyMedium?.copyWith(fontSize: 18, height: 1.5),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 16, height: 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: buttonLabelStyle,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        // Inert state: same neutral surface as the writing panel (de-tinted,
        // no green), with a clearly-present muted-neutral label — not the
        // near-invisible dark-on-dark M3 default.
        disabledBackgroundColor: kSurfacePanel,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
      ),
    ),
    // The writing panel's surface (fill, border, shadow, padding) is drawn by
    // a decorated container in home_screen.dart, so the field itself is
    // chrome-free: transparent, no border, no internal padding.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isCollapsed: true,
      contentPadding: EdgeInsets.zero,
      hintStyle: base.textTheme.bodyLarge?.copyWith(
        fontSize: 20,
        height: 1.5,
        color: scheme.onSurface.withValues(alpha: 0.72),
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),
    // Tap target only — no textStyle override, so the quiet "I need help
    // right now" header link and crisis "Return" stay understated.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: 0.30),
      selectionHandleColor: scheme.primary,
    ),
  );
}
