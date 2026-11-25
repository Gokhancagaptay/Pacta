import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// main'de runApp'tan önce okunan tema (null: okunmadı, notifier okur).
final initialThemeProvider = Provider<ThemeMode?>((ref) => null);

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(initial: ref.watch(initialThemeProvider)),
);

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier({ThemeMode? initial}) : super(initial ?? ThemeMode.system) {
    if (initial == null) _loadTheme();
  }

  static const _themeKey = 'theme_mode';

  /// Kayıtlı tema; okunamazsa sistem teması.
  static Future<ThemeMode> readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_themeKey);
      if (index != null && index >= 0 && index < ThemeMode.values.length) {
        return ThemeMode.values[index];
      }
    } catch (_) {}
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final saved = await readSaved();
    if (mounted) state = saved;
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    state = themeMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, themeMode.index);
    } catch (_) {
      // Seçim bu oturumda geçerli kalır.
    }
  }
}
