import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import 'infrastructure_providers.dart';

class SettingsController extends Notifier<AppSettings> {
  static const _themeKey = 'voice_ledger.settings.theme';
  static const _hideBalancesKey = 'voice_ledger.settings.hide_balances';
  static const _examplesKey = 'voice_ledger.settings.voice_examples';
  static const _hapticsKey = 'voice_ledger.settings.haptics';
  static const _remindersKey = 'voice_ledger.settings.reminders';

  @override
  AppSettings build() {
    unawaited(_load());
    return const AppSettings();
  }

  Future<void> _load() async {
    final storage = ref.read(tokenStorageProvider);
    try {
      final theme = await storage.readSetting(_themeKey);
      final hide = await storage.readSetting(_hideBalancesKey);
      final examples = await storage.readSetting(_examplesKey);
      final haptics = await storage.readSetting(_hapticsKey);
      final reminders = await storage.readSetting(_remindersKey);
      state = AppSettings(
        themeMode: AppSettings.parseThemeMode(theme),
        hideBalances: hide == 'true',
        showVoiceExamples: examples != 'false',
        hapticsEnabled: haptics != 'false',
        repaymentReminders: reminders != 'false',
      );
    } catch (_) {
      // Defaults are safe if secure storage is temporarily unavailable.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _write(_themeKey, state.themeModeStorageValue);
  }

  Future<void> setHideBalances(bool value) async {
    state = state.copyWith(hideBalances: value);
    await _write(_hideBalancesKey, value.toString());
  }

  Future<void> setShowVoiceExamples(bool value) async {
    state = state.copyWith(showVoiceExamples: value);
    await _write(_examplesKey, value.toString());
  }

  Future<void> setHapticsEnabled(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    await _write(_hapticsKey, value.toString());
  }

  Future<void> setRepaymentReminders(bool value) async {
    state = state.copyWith(repaymentReminders: value);
    await _write(_remindersKey, value.toString());
  }

  Future<void> _write(String key, String value) async {
    try {
      await ref.read(tokenStorageProvider).writeSetting(key, value);
    } catch (_) {
      // Settings remain applied for this session even if persistence fails.
    }
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
