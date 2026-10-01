import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Service that monitors and enforces the highest possible display refresh rate
/// (e.g. 90Hz, 120Hz, 144Hz, 165Hz) on supported mobile devices.
/// It re-asserts the refresh rate whenever the app resumes from the background,
/// during route transitions, and via a periodic keep-alive guard.
class DisplayModeService with WidgetsBindingObserver {
  static final DisplayModeService _instance = DisplayModeService._internal();
  factory DisplayModeService() => _instance;
  DisplayModeService._internal();

  static const MethodChannel _nativeDisplayChannel = MethodChannel('com.groovy.music/display');

  bool _initialized = false;
  double _activeRefreshRate = 60.0;
  Timer? _keepAliveTimer;
  DateTime? _lastReassertTime;

  double get activeRefreshRate => _activeRefreshRate;

  /// Initializes the service and registers the lifecycle observer.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Initial enforcement
    await setHighestRefreshRate();

    // Start periodic guard to prevent OEM dynamic refresh throttling (e.g. Infinix XOS, MIUI, OneUI)
    _startKeepAliveGuard();
  }

  void _startKeepAliveGuard() {
    _keepAliveTimer?.cancel();
    if (kIsWeb || !Platform.isAndroid) return;

    // Periodically re-assert 120Hz every 25 seconds while the app is alive
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      reassertHighRefreshRate();
    });
  }

  /// Debounced re-assertion method safe to call on route changes, sheet dismissals, etc.
  void reassertHighRefreshRate() {
    final now = DateTime.now();
    if (_lastReassertTime != null &&
        now.difference(_lastReassertTime!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastReassertTime = now;
    setHighestRefreshRate().catchError((_) {});
  }

  /// Queries all available display modes and locks the screen to the highest rate.
  Future<void> setHighestRefreshRate() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      // 1. Android Native platform channel (pins preferredRefreshRate & Surface.setFrameRate)
      try {
        await _nativeDisplayChannel.invokeMethod('setHighRefreshRate');
      } catch (_) {}

      // 2. FlutterDisplayMode plugin (sets window.attributes.preferredDisplayModeId)
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
      _startKeepAliveGuard();
      setHighestRefreshRate();
    } else if (state == AppLifecycleState.paused) {
      _keepAliveTimer?.cancel();
    }
  }

  void dispose() {
    _keepAliveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// Navigator observer that ensures 120Hz is immediately re-asserted when navigating
/// between screens, sheets, or dialogs.
class DisplayModeRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    DisplayModeService().reassertHighRefreshRate();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    DisplayModeService().reassertHighRefreshRate();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    DisplayModeService().reassertHighRefreshRate();
  }
}
