import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Service that monitors and enforces the highest possible display refresh rate
/// (e.g. 90Hz, 120Hz, 144Hz, 165Hz) on supported mobile devices.
/// It also re-asserts the refresh rate whenever the app resumes from the background.
class DisplayModeService with WidgetsBindingObserver {
  static final DisplayModeService _instance = DisplayModeService._internal();
  factory DisplayModeService() => _instance;
  DisplayModeService._internal();

  bool _initialized = false;
  double _activeRefreshRate = 60.0;

  double get activeRefreshRate => _activeRefreshRate;

  /// Initializes the service and registers the lifecycle observer.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    await setHighestRefreshRate();
  }

  /// Queries all available display modes and locks the screen to the highest rate.
  Future<void> setHighestRefreshRate() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final modes = await FlutterDisplayMode.supported;
      if (modes.isEmpty) {
        await FlutterDisplayMode.setHighRefreshRate();
        return;
      }

      DisplayMode? highestMode;
      for (final mode in modes) {
        if (highestMode == null || mode.refreshRate > highestMode.refreshRate) {
          highestMode = mode;
        }
      }

      if (highestMode != null) {
        await FlutterDisplayMode.setPreferredMode(highestMode);
        _activeRefreshRate = highestMode.refreshRate;
        debugPrint(
          '[DisplayModeService] Set highest display mode: '
          '${highestMode.width}x${highestMode.height} @ ${_activeRefreshRate.round()}Hz',
        );
      } else {
        await FlutterDisplayMode.setHighRefreshRate();
      }
    } catch (e) {
      debugPrint('[DisplayModeService] Error setting high refresh rate: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from background, many Android skins drop back to 60Hz.
    // Re-assert the high refresh rate immediately.
    if (state == AppLifecycleState.resumed) {
      setHighestRefreshRate();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
