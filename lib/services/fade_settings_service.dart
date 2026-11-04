import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class FadeSettingsService {
  static const String _keyFadeEnabled = 'fade_enabled';
  static const String _keyFadeDurationMs = 'fade_duration_ms';
  static const String _keyDjTransitionEnabled = 'dj_transition_bpm_enabled';

  static final FadeSettingsService _instance = FadeSettingsService._internal();
  factory FadeSettingsService() => _instance;
  FadeSettingsService._internal();

  SharedPreferences? _prefs;

  final ValueNotifier<bool> fadeEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<int> fadeDurationMsNotifier = ValueNotifier(300);
  final ValueNotifier<bool> djTransitionEnabledNotifier = ValueNotifier(false);

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    fadeEnabledNotifier.value = getFadeEnabled();
    fadeDurationMsNotifier.value = getFadeDurationMs();
    djTransitionEnabledNotifier.value = getDjTransitionEnabled();
  }

  Future<void> setFadeEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_keyFadeEnabled, enabled);
    fadeEnabledNotifier.value = enabled;
  }

  bool getFadeEnabled() {
    return _prefs?.getBool(_keyFadeEnabled) ?? false;
  }

  Future<void> setFadeDurationMs(int durationMs) async {
    await initialize();
    await _prefs!.setInt(_keyFadeDurationMs, durationMs);
    fadeDurationMsNotifier.value = durationMs;
  }

  int getFadeDurationMs() {
    return _prefs?.getInt(_keyFadeDurationMs) ?? 300;
  }

  Future<void> setDjTransitionEnabled(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_keyDjTransitionEnabled, enabled);
    djTransitionEnabledNotifier.value = enabled;
  }

  bool getDjTransitionEnabled() {
    return _prefs?.getBool(_keyDjTransitionEnabled) ?? false;
  }

  void dispose() {
    fadeEnabledNotifier.dispose();
    fadeDurationMsNotifier.dispose();
    djTransitionEnabledNotifier.dispose();
  }
}
