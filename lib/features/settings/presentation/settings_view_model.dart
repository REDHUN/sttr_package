import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { system, light, dark }

class SettingsViewModel extends ChangeNotifier {
  static const _themeKey = 'theme_preference';
  static const _localeKey = 'preferred_locale';

  ThemePreference _theme = ThemePreference.system;
  String? _preferredLocaleId;
  bool _isLoading = true;
  String? _errorMessage;

  ThemePreference get theme => _theme;
  ThemeMode get themeMode => switch (_theme) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
  String? get preferredLocaleId => _preferredLocaleId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final themeValue = preferences.getString(_themeKey);
      _theme = ThemePreference.values.firstWhere(
        (value) => value.name == themeValue,
        orElse: () => ThemePreference.system,
      );
      _preferredLocaleId = preferences.getString(_localeKey);
      _errorMessage = null;
    } on Exception catch (error) {
      _errorMessage = 'Settings could not be loaded: $error';
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> setTheme(ThemePreference value) async {
    if (_theme == value) return;
    _theme = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeKey, value.name);
  }

  Future<void> setPreferredLocale(String? localeId) async {
    if (_preferredLocaleId == localeId) return;
    _preferredLocaleId = localeId;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    if (localeId == null || localeId.isEmpty) {
      await preferences.remove(_localeKey);
    } else {
      await preferences.setString(_localeKey, localeId);
    }
  }
}
