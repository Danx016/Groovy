import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
  static const String currentVersion = '1.0.15';
  static const MethodChannel _channel = MethodChannel('com.devid.musly/app_updater');

  static const String _apiUrl =
      'https://api.github.com/repos/Danx016/Groovy/releases/latest';

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );

  static Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final data = response.data;
      if (data == null) return null;

      final release = ReleaseInfo.fromJson(data);
      if (_isNewer(release.version, currentVersion)) {
        return release;
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: check failed – $e');
      return null;
    }
  }

  static Future<void> downloadAndInstallApk({
    required String downloadUrl,
    required void Function(double progress) onProgress,
    required void Function(String error) onError,
  }) async {
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
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      if (!kIsWeb && Platform.isAndroid) {
        await _channel.invokeMethod('installApk', {'filePath': filePath});
      }
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
    return md
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'`{1,3}(.*?)`{1,3}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'^---+$', multiLine: true), '─────────────')
        .trim();
  }
}
