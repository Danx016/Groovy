import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';

typedef _DwmSetWindowAttributeC = Int32 Function(
  IntPtr hwnd,
  Uint32 dwAttribute,
  Pointer<Void> pvAttribute,
  Uint32 cbAttribute,
);
typedef _DwmSetWindowAttributeDart = int Function(
  int hwnd,
  int dwAttribute,
  Pointer<Void> pvAttribute,
  int cbAttribute,
);

typedef _FindWindowC = IntPtr Function(
  Pointer<Utf16> lpClassName,
  Pointer<Utf16> lpWindowName,
);
typedef _FindWindowDart = int Function(
  Pointer<Utf16> lpClassName,
  Pointer<Utf16> lpWindowName,
);

typedef _GetActiveWindowC = IntPtr Function();
typedef _GetActiveWindowDart = int Function();

typedef _GetForegroundWindowC = IntPtr Function();
typedef _GetForegroundWindowDart = int Function();

class WindowsTitleBarService {
  static final WindowsTitleBarService _instance =
      WindowsTitleBarService._internal();
  factory WindowsTitleBarService() => _instance;
  WindowsTitleBarService._internal();

  int? _hwnd;
  _DwmSetWindowAttributeDart? _dwmSetWindowAttribute;
  _FindWindowDart? _findWindow;
  _GetActiveWindowDart? _getActiveWindow;
  _GetForegroundWindowDart? _getForegroundWindow;
  bool _initialized = false;

  void initialize() {
    if (kIsWeb || !Platform.isWindows) return;
    if (_initialized) return;

    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final dwmapi = DynamicLibrary.open('dwmapi.dll');

      _dwmSetWindowAttribute = dwmapi.lookupFunction<_DwmSetWindowAttributeC,
          _DwmSetWindowAttributeDart>('DwmSetWindowAttribute');
      _findWindow =
          user32.lookupFunction<_FindWindowC, _FindWindowDart>('FindWindowW');
      _getActiveWindow = user32.lookupFunction<_GetActiveWindowC,
          _GetActiveWindowDart>('GetActiveWindow');
      _getForegroundWindow = user32.lookupFunction<_GetForegroundWindowC,
          _GetForegroundWindowDart>('GetForegroundWindow');

      _initialized = true;
    } catch (e) {
      debugPrint('WindowsTitleBarService initialize error: $e');
    }
  }

  int _getHwnd() {
    if (_hwnd != null && _hwnd != 0) return _hwnd!;
    if (!_initialized) initialize();

    try {
      if (_findWindow != null) {
        final titlePtr = 'Groovy'.toNativeUtf16();
        final hwnd = _findWindow!(nullptr, titlePtr);
        calloc.free(titlePtr);
        if (hwnd != 0) {
          _hwnd = hwnd;
          return hwnd;
        }
      }
      if (_getActiveWindow != null) {
        final hwnd = _getActiveWindow!();
        if (hwnd != 0) {
          _hwnd = hwnd;
          return hwnd;
        }
      }
      if (_getForegroundWindow != null) {
        final hwnd = _getForegroundWindow!();
        if (hwnd != 0) {
          _hwnd = hwnd;
          return hwnd;
        }
      }
    } catch (e) {
      debugPrint('Error retrieving HWND: $e');
    }
    return _hwnd ?? 0;
  }

  /// Sets the title bar color to match the theme:
  /// isDark = true -> Title bar is pure black (#000000), text is white
  /// isDark = false -> Title bar is pure white (#FFFFFF), text is dark
  void updateTheme({required bool isDark, Color? customBackgroundColor}) {
    if (kIsWeb || !Platform.isWindows) return;

    final hwnd = _getHwnd();
    if (hwnd == 0 || _dwmSetWindowAttribute == null) return;

    try {
      // 1. DWMWA_USE_IMMERSIVE_DARK_MODE (20, and 19 on older Windows 10)
      final darkModePtr = calloc<Int32>();
      darkModePtr.value = isDark ? 1 : 0;
      _dwmSetWindowAttribute!(hwnd, 20, darkModePtr.cast(), sizeOf<Int32>());
      _dwmSetWindowAttribute!(hwnd, 19, darkModePtr.cast(), sizeOf<Int32>());
      calloc.free(darkModePtr);

      // 2. DWMWA_CAPTION_COLOR (35) - supported on Windows 11+
      // COLORREF format: 0x00BBGGRR
      final Color bg =
          customBackgroundColor ?? (isDark ? Colors.black : Colors.white);
      final int r = (bg.r * 255.0).round().clamp(0, 255);
      final int g = (bg.g * 255.0).round().clamp(0, 255);
      final int b = (bg.b * 255.0).round().clamp(0, 255);
      final int colorRef = r | (g << 8) | (b << 16);

      final captionColorPtr = calloc<Uint32>();
      captionColorPtr.value = colorRef;
      _dwmSetWindowAttribute!(
          hwnd, 35, captionColorPtr.cast(), sizeOf<Uint32>());
      calloc.free(captionColorPtr);

      // 3. DWMWA_TEXT_COLOR (36) - supported on Windows 11+
      final textIsDark = !isDark;
      final int textR = textIsDark ? 0 : 255;
      final int textG = textIsDark ? 0 : 255;
      final int textB = textIsDark ? 0 : 255;
      final int textColorRef = textR | (textG << 8) | (textB << 16);

      final textColorPtr = calloc<Uint32>();
      textColorPtr.value = textColorRef;
      _dwmSetWindowAttribute!(
          hwnd, 36, textColorPtr.cast(), sizeOf<Uint32>());
      calloc.free(textColorPtr);

      // 4. DWMWA_BORDER_COLOR (34) - supported on Windows 11+
      final borderColorPtr = calloc<Uint32>();
      borderColorPtr.value = colorRef;
      _dwmSetWindowAttribute!(
          hwnd, 34, borderColorPtr.cast(), sizeOf<Uint32>());
      calloc.free(borderColorPtr);
    } catch (e) {
      debugPrint('Error updating Windows title bar theme: $e');
    }
  }
}
