import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ClientDeviceInfo {
  final String platform;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final String userAgent;

  ClientDeviceInfo({
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.userAgent,
  });

  Map<String, String> toHeaders() {
    return {
      'X-Client-Platform': platform,
      'X-Device-Model': deviceModel,
      'X-OS-Version': osVersion,
      'X-App-Version': appVersion,
      'User-Agent': userAgent,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'appVersion': appVersion,
    };
  }
}

class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  ClientDeviceInfo? _cachedInfo;

  Future<ClientDeviceInfo> getDeviceInfo() async {
    if (_cachedInfo != null) return _cachedInfo!;

    String platform = 'Unknown';
    String deviceModel = 'Groovy Device';
    String osVersion = 'Unknown OS';
    String appVersion = '1.1.5';

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (_) {
      // Fallback
    }

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        platform = 'Web';
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceModel = 'Web Browser (${webInfo.browserName.name})';
        osVersion = webInfo.platform ?? 'Web';
      } else if (Platform.isAndroid) {
        platform = 'Android';
        final android = await deviceInfo.androidInfo;
        final brand = android.brand.isNotEmpty ? _capitalize(android.brand) : _capitalize(android.manufacturer);
        final model = android.model.isNotEmpty ? android.model : 'Android Device';
        if (model.toLowerCase().startsWith(brand.toLowerCase())) {
          deviceModel = model;
        } else {
          deviceModel = '$brand $model'.trim();
        }
        osVersion = 'Android ${android.version.release} (API ${android.version.sdkInt})';
      } else if (Platform.isWindows) {
        platform = 'Windows';
        final windows = await deviceInfo.windowsInfo;
        final compName = windows.computerName.isNotEmpty ? windows.computerName : Platform.localHostname;
        deviceModel = compName.isNotEmpty ? compName : 'Windows PC';
        
        final prodName = windows.productName.isNotEmpty ? windows.productName : 'Windows';
        final dispVer = windows.displayVersion.isNotEmpty ? ' ${windows.displayVersion}' : '';
        final buildNum = windows.buildNumber > 0 ? ' (Build ${windows.buildNumber})' : '';
        osVersion = '$prodName$dispVer$buildNum'.trim();
      } else if (Platform.isIOS) {
        platform = 'iOS';
        final ios = await deviceInfo.iosInfo;
        deviceModel = ios.name.isNotEmpty ? ios.name : 'iPhone';
        osVersion = '${ios.systemName} ${ios.systemVersion}';
      } else if (Platform.isMacOS) {
        platform = 'macOS';
        final mac = await deviceInfo.macOsInfo;
        deviceModel = mac.model.isNotEmpty ? mac.model : 'Apple Mac';
        osVersion = 'macOS ${mac.majorVersion}.${mac.minorVersion}.${mac.patchVersion}';
      } else if (Platform.isLinux) {
        platform = 'Linux';
        final linux = await deviceInfo.linuxInfo;
        deviceModel = linux.prettyName.isNotEmpty ? linux.prettyName : 'Linux PC';
        osVersion = linux.versionId ?? 'Linux';
      }
    } catch (e) {
      debugPrint('[DeviceInfoService] Warning getting device info: $e');
      platform = defaultTargetPlatform.name;
      deviceModel = '$platform Device';
      osVersion = Platform.operatingSystemVersion;
    }

    final userAgent = 'GroovyNative/$appVersion ($platform; $deviceModel; $osVersion)';

    _cachedInfo = ClientDeviceInfo(
      platform: platform,
      deviceModel: deviceModel,
      osVersion: osVersion,
      appVersion: appVersion,
      userAgent: userAgent,
    );

    return _cachedInfo!;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
