import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EqualizerPreset {
  final String name;
  final List<double> gains; // in dB (-12.0 to +12.0)

  const EqualizerPreset({required this.name, required this.gains});
}

class EqualizerService extends ChangeNotifier {
  static final EqualizerService _instance = EqualizerService._internal();
  factory EqualizerService() => _instance;
  EqualizerService._internal();

  static const String _keyEnabled = 'eq_enabled';
  static const String _keyPreset = 'eq_preset';
  static const String _keyCustomGains = 'eq_custom_gains';
  static const String _keyBassBoost = 'eq_bass_boost';
  static const String _keyVirtualizer = 'eq_virtualizer';

  static const List<int> frequencies = [60, 230, 910, 3600, 14000];

  static const List<EqualizerPreset> defaultPresets = [
    EqualizerPreset(name: 'Plano', gains: [0.0, 0.0, 0.0, 0.0, 0.0]),
    EqualizerPreset(name: 'Rock', gains: [4.5, 2.5, -1.0, 3.0, 4.5]),
    EqualizerPreset(name: 'Pop', gains: [2.0, 3.5, 4.0, 2.5, -1.0]),
    EqualizerPreset(name: 'Refuerzo de graves', gains: [6.5, 5.0, 1.5, 0.0, 0.0]),
    EqualizerPreset(name: 'Electrónica', gains: [5.0, 3.5, 0.0, 2.5, 4.5]),
    EqualizerPreset(name: 'Voces claras', gains: [-2.0, 1.0, 4.5, 3.0, 1.0]),
    EqualizerPreset(name: 'Acústico', gains: [3.0, 2.5, 1.5, 3.0, 3.5]),
    EqualizerPreset(name: 'Jazz', gains: [3.5, 2.0, -1.5, 2.0, 3.5]),
    EqualizerPreset(name: 'Hip Hop', gains: [5.5, 4.0, 0.5, 2.0, 3.0]),
  ];

  bool _enabled = false;
  String _currentPresetName = 'Plano';
  List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  double _bassBoost = 0.0; // 0.0 to 1.0
  double _virtualizer = 0.0; // 0.0 to 1.0

  bool _initialized = false;

  bool get isEnabled => _enabled;
  String get currentPresetName => _currentPresetName;
  List<double> get bandGains => List.unmodifiable(_bandGains);
  double get bassBoost => _bassBoost;
  double get virtualizer => _virtualizer;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? false;
      _currentPresetName = prefs.getString(_keyPreset) ?? 'Plano';
      _bassBoost = prefs.getDouble(_keyBassBoost) ?? 0.0;
      _virtualizer = prefs.getDouble(_keyVirtualizer) ?? 0.0;

      final savedGains = prefs.getString(_keyCustomGains);
      if (savedGains != null) {
        final decoded = (jsonDecode(savedGains) as List).cast<num>();
        _bandGains = decoded.map((n) => n.toDouble()).toList();
      } else {
        _applyPresetByName(_currentPresetName, notify: false);
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    notifyListeners();
  }

  Future<void> setPreset(String presetName) async {
    _currentPresetName = presetName;
    _applyPresetByName(presetName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreset, presetName);
    await prefs.setString(_keyCustomGains, jsonEncode(_bandGains));
    notifyListeners();
  }

  void _applyPresetByName(String name, {bool notify = true}) {
    for (final p in defaultPresets) {
      if (p.name == name) {
        _bandGains = List<double>.from(p.gains);
        if (notify) notifyListeners();
        return;
      }
    }
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    if (bandIndex < 0 || bandIndex >= _bandGains.length) return;
    _bandGains[bandIndex] = gain.clamp(-12.0, 12.0);
    _currentPresetName = 'Personalizado';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreset, _currentPresetName);
    await prefs.setString(_keyCustomGains, jsonEncode(_bandGains));
    notifyListeners();
  }

  Future<void> setBassBoost(double value) async {
    _bassBoost = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBassBoost, _bassBoost);
    notifyListeners();
  }

  Future<void> setVirtualizer(double value) async {
    _virtualizer = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVirtualizer, _virtualizer);
    notifyListeners();
  }

  /// Builds the mpv / lavfi filter string for audio engine filtering on Windows/Linux/macOS
  String buildMpvAudioFilter() {
    if (!_enabled) return '';
    final filters = <String>[];

    // Equalizer filters (5 peak eq filters)
    final eqParts = <String>[];
    for (int i = 0; i < frequencies.length; i++) {
      final f = frequencies[i];
      final g = _bandGains[i];
      if (g.abs() > 0.1) {
        eqParts.add('equalizer=f=$f:t=q:w=1:g=$g');
      }
    }
    if (eqParts.isNotEmpty) {
      filters.addAll(eqParts);
    }

    // Bass boost (low shelf boost)
    if (_bassBoost > 0.05) {
      final bassGain = (_bassBoost * 10.0).toStringAsFixed(1);
      filters.add('bass=g=$bassGain:f=110');
    }

    // Virtualizer / Spatial stereo widening
    if (_virtualizer > 0.05) {
      final width = (1.0 + _virtualizer * 1.5).toStringAsFixed(2);
      filters.add('extrastereo=m=$width');
    }

    return filters.join(',');
  }
}
