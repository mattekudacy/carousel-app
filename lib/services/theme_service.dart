import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme-aware color helper for consistent colors across light/dark modes
class AppColors {
  final BuildContext context;
  
  AppColors.of(this.context);
  
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get colorScheme => Theme.of(context).colorScheme;
  
  // Status colors - semantic colors that work in both themes
  Color get success => isDark ? Colors.green.shade300 : Colors.green;
  Color get successLight => isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50;
  Color get successDark => isDark ? Colors.green.shade200 : Colors.green.shade800;
  
  Color get warning => isDark ? Colors.orange.shade300 : Colors.orange;
  Color get warningLight => isDark ? Colors.orange.shade900.withValues(alpha: 0.3) : Colors.orange.shade50;
  Color get warningDark => isDark ? Colors.orange.shade200 : Colors.orange.shade800;
  
  Color get error => isDark ? Colors.red.shade300 : Colors.red;
  Color get errorLight => isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50;
  Color get errorDark => isDark ? Colors.red.shade200 : Colors.red.shade800;
  
  Color get info => isDark ? Colors.blue.shade300 : Colors.blue;
  Color get infoLight => isDark ? Colors.blue.shade900.withValues(alpha: 0.3) : Colors.blue.shade50;
  Color get infoDark => isDark ? Colors.blue.shade200 : Colors.blue.shade800;
  
  Color get amber => isDark ? Colors.amber.shade300 : Colors.amber;
  Color get amberLight => isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50;
  Color get amberDark => isDark ? Colors.amber.shade200 : Colors.amber.shade700;
  
  // Neutral colors
  Color get neutral => isDark ? Colors.grey.shade400 : Colors.grey;
  Color get neutralLight => isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100;
  Color get neutralMedium => isDark ? Colors.grey.shade600 : Colors.grey.shade300;
  Color get neutralDark => isDark ? Colors.grey.shade300 : Colors.grey.shade600;
  Color get neutralDarker => isDark ? Colors.grey.shade200 : Colors.grey.shade700;
  
  // Card backgrounds
  Color get cardBackground => colorScheme.surface;
  Color get cardBackgroundElevated => isDark ? colorScheme.surfaceContainerHighest : Colors.white;
  
  // Text on status backgrounds
  Color get onSuccess => isDark ? Colors.green.shade100 : Colors.green.shade900;
  Color get onWarning => isDark ? Colors.orange.shade100 : Colors.orange.shade900;
  Color get onError => isDark ? Colors.red.shade100 : Colors.red.shade900;
  Color get onInfo => isDark ? Colors.blue.shade100 : Colors.blue.shade900;
  Color get onAmber => isDark ? Colors.amber.shade100 : Colors.amber.shade900;
  
  // Border colors
  Color get successBorder => isDark ? Colors.green.shade700 : Colors.green.shade300;
  Color get warningBorder => isDark ? Colors.orange.shade700 : Colors.orange.shade300;
  Color get errorBorder => isDark ? Colors.red.shade700 : Colors.red.shade300;
  Color get infoBorder => isDark ? Colors.blue.shade700 : Colors.blue.shade300;
  Color get amberBorder => isDark ? Colors.amber.shade700 : Colors.amber.shade300;
  
  // Special purpose colors
  Color get divider => isDark ? Colors.grey.shade700 : Colors.grey.shade300;
  Color get shadow => isDark ? Colors.black54 : Colors.black26;
  Color get overlay => isDark ? Colors.black54 : Colors.black38;
}

/// Theme mode options
enum AppThemeMode {
  system,
  light,
  dark,
}

extension AppThemeModeExtension on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

/// Theme configuration for the app
class AppTheme {
  static const Color _seedColor = Colors.deepPurple;

  /// Light theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.inversePrimary,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }
}

/// Theme state notifier
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const String _themeKey = 'app_theme_mode';

  ThemeNotifier() : super(AppThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    state = AppThemeMode.values[themeIndex.clamp(0, AppThemeMode.values.length - 1)];
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  void toggleTheme() {
    final nextIndex = (state.index + 1) % AppThemeMode.values.length;
    setTheme(AppThemeMode.values[nextIndex]);
  }

  /// Get the actual brightness based on current mode
  Brightness get effectiveBrightness {
    switch (state) {
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
      case AppThemeMode.system:
        return SchedulerBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  bool get isDark => effectiveBrightness == Brightness.dark;
}

// ============ PROVIDERS ============

/// Provider for theme state
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

/// Provider for checking if currently in dark mode
final isDarkModeProvider = Provider<bool>((ref) {
  final themeNotifier = ref.watch(themeProvider.notifier);
  return themeNotifier.isDark;
});
