import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseAsset {
  final String name;
  final String browserDownloadUrl;

  const ReleaseAsset({required this.name, required this.browserDownloadUrl});

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String,
        browserDownloadUrl: json['browser_download_url'] as String,
      );
}

class ReleaseInfo {
  final String version;
  final String tagName;
  final String htmlUrl;

  final String body;
  final List<ReleaseAsset> assets;

  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    required this.assets,
  });

  String? get apkDownloadUrl {
    final apkAsset = assets.cast<ReleaseAsset?>().firstWhere(
          (a) => a?.name.toLowerCase().endsWith('.apk') ?? false,
          orElse: () => null,
        );
    return apkAsset?.browserDownloadUrl;
  }

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    return ReleaseInfo(
      version: tag.replaceFirst(RegExp(r'^v'), ''),
      tagName: tag,
      htmlUrl: json['html_url'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>?)
              ?.map((a) => ReleaseAsset.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class UpdateService {
  static String currentVersion = '1.0.43';
  static const MethodChannel _channel = MethodChannel('com.devid.musly/app_updater');

  static const String _apiUrl =
      'https://api.github.com/repos/Danx016/Groovy/releases/latest';

  // Global background download state notifiers
  static final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<double> downloadProgressNotifier = ValueNotifier<double>(0.0);
  static final ValueNotifier<String?> downloadErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<ReleaseInfo?> availableUpdateNotifier = ValueNotifier<ReleaseInfo?>(null);

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 180),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );

  static Future<void> initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (_) {}
  }

  static Future<ReleaseInfo?> checkForUpdate() async {
    try {
      await initVersion();
      final response = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final data = response.data;
      if (data == null) return null;

      final release = ReleaseInfo.fromJson(data);
      if (_isNewer(release.version, currentVersion)) {
        availableUpdateNotifier.value = release;
        return release;
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: check failed – $e');
      return null;
    }
  }

  static Future<void> startDownload(ReleaseInfo release) async {
    final apkUrl = release.apkDownloadUrl;
    if (apkUrl == null) return;
    if (isDownloadingNotifier.value) return;

    isDownloadingNotifier.value = true;
    downloadProgressNotifier.value = 0.0;
    downloadErrorNotifier.value = null;

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/app-update.apk';
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      await _dio.download(
        apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = (received / total).clamp(0.0, 1.0);
            downloadProgressNotifier.value = p;
          }
        },
      );

      isDownloadingNotifier.value = false;
      downloadProgressNotifier.value = 1.0;

      if (!kIsWeb && Platform.isAndroid) {
        await _channel.invokeMethod('installApk', {'filePath': filePath});
      }
    } catch (e) {
      isDownloadingNotifier.value = false;
      downloadErrorNotifier.value = e.toString();
      debugPrint('Update download error: $e');
    }
  }

  static Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required void Function(double progress) onProgress,
    required void Function(String error) onError,
  }) async {
    try {
      final release = availableUpdateNotifier.value ??
          ReleaseInfo(
            version: '',
            tagName: '',
            htmlUrl: '',
            body: '',
            assets: [ReleaseAsset(name: 'app-release.apk', browserDownloadUrl: downloadUrl)],
          );
      await startDownload(release);
    } catch (e) {
      onError(e.toString());
    }
  }

  static bool _isNewer(String remote, String current) {
    try {
      List<int> parse(String v) =>
          v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final r = parse(remote);
      final c = parse(current);
      final len = r.length > c.length ? r.length : c.length;
      while (r.length < len) {
        r.add(0);
      }
      while (c.length < len) {
        c.add(0);
      }

      for (int i = 0; i < len; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String stripMarkdown(String md) {
    var cleaned = md;

    // Filter out raw github comparison links and autogenerated bot lines
    cleaned = cleaned.replaceAll(RegExp(r'(?:Full Changelog|See full diff|Compare changes|Full diff).*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'https?:\/\/github\.com\S+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\* @[a-zA-Z0-9_-]+ in https:\/\/\S+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'@\w+ in #\d+'), '');

    // Format markdown
    cleaned = cleaned
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`{1,3}(.*?)`{1,3}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'^---+$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (cleaned.isEmpty) {
      return '• Mejoras en la reproducción y estabilidad\n• Sincronización precisa de letras multi-fuente\n• Interfaz renovada y optimizaciones de rendimiento a 120 Hz';
    }
    return cleaned;
  }
}
