import 'package:flutter/material.dart';

import '../domain/enums/enums.dart';

/// Material 3 themes for OpenCue.
///
/// The brief is a tool you glance at in public, so the palette is deliberately
/// understated: a desaturated deep teal seed, generous spacing, and no
/// saturated accent anywhere. Nothing here should read as a dating app if
/// someone glances over your shoulder.
class AppTheme {
  const AppTheme._();

  /// Seed colour. Muted enough to disappear, distinct enough to be a choice.
  static const Color seed = Color(0xFF2F5D62);

  /// Minimum comfortable window width before the layout switches to a
  /// bottom navigation bar.
  static const double railBreakpoint = 760;

  /// Maximum content width, so text does not stretch across a wide monitor.
  static const double contentMaxWidth = 900;

  /// Standard spacing unit.
  static const double gap = 12;

  static ThemeMode themeModeFor(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      // A visible focus ring on every focusable control, which matters more
      // than usual on a desktop app driven by Tab and arrow keys.
      focusColor: scheme.primary.withValues(alpha: 0.16),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 10,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      // Animations are kept short. A reference tool should feel instant, and
      // long transitions are the first thing that grates on repeat use.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Style for a Japanese opener shown as the main content of a card.
  ///
  /// Japanese needs more vertical room than Latin text at the same point size,
  /// hence the loosened line height.
  static TextStyle japaneseDisplay(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.headlineSmall ?? const TextStyle()).copyWith(
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Style for a Japanese opener in a list row.
  static TextStyle japaneseBody(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Style for the English meaning beneath a Japanese line.
  static TextStyle englishMeaning(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.35,
    );
  }
}
