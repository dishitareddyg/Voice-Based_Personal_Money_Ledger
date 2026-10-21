import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.hideBalances = false,
    this.showVoiceExamples = true,
    this.hapticsEnabled = true,
    this.repaymentReminders = true,
  });

  final ThemeMode themeMode;
  final bool hideBalances;
  final bool showVoiceExamples;
  final bool hapticsEnabled;
  final bool repaymentReminders;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? hideBalances,
    bool? showVoiceExamples,
    bool? hapticsEnabled,
    bool? repaymentReminders,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      hideBalances: hideBalances ?? this.hideBalances,
      showVoiceExamples: showVoiceExamples ?? this.showVoiceExamples,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      repaymentReminders: repaymentReminders ?? this.repaymentReminders,
    );
  }

  String get themeModeStorageValue {
    switch (themeMode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  static ThemeMode parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
