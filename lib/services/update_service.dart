import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? get windowsSetupDownloadUrl {
    final exeAsset = assets.cast<ReleaseAsset?>().firstWhere(
          (a) => a?.name.toLowerCase().endsWith('.exe') ?? false,
          orElse: () => null,
        );
    return exeAsset?.browserDownloadUrl;
  }

  String? get debDownloadUrl {
    final debAsset = assets.cast<ReleaseAsset?>().firstWhere(
          (a) => a?.name.toLowerCase().endsWith('.deb') ?? false,
          orElse: () => null,
        );
    return debAsset?.browserDownloadUrl;
  }

  String? get appImageDownloadUrl {
    final imgAsset = assets.cast<ReleaseAsset?>().firstWhere(
          (a) =>
              a?.name.toLowerCase().contains('linux') == true &&
              a?.name.toLowerCase().endsWith('.appimage') == true,
          orElse: () => null,
        );
    return imgAsset?.browserDownloadUrl;
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
  static String currentVersion = '1.4.8';
  static const MethodChannel _channel = MethodChannel('com.groovy.music/app_updater');

  static const String _apiUrl =
      'https://api.github.com/repos/Danx016/Groovy/releases/latest';

  static const String _prefKeyDismissedVersion = 'dismissed_update_version';
  static const String _prefKeyDismissedTime = 'dismissed_update_time';

  // Global background download state notifiers
  static final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<double> downloadProgressNotifier = ValueNotifier<double>(0.0);
  static final ValueNotifier<String?> downloadErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<ReleaseInfo?> availableUpdateNotifier = ValueNotifier<ReleaseInfo?>(null);
  static final ValueNotifier<bool> isInstallerReadyNotifier = ValueNotifier<bool>(false);

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

  static String cleanVersion(String v) {
    return v.split('+')[0].trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
  }

  static String get currentVersionDisplay => cleanVersion(currentVersion);

  static Future<void> initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        currentVersion = info.version;
      }
      await cleanupOldInstallers();
    } catch (_) {}
  }

  /// Returns the standardized installer filename for this platform and version
  static String getInstallerFileName(ReleaseInfo release) {
    final v = cleanVersion(release.version);
    if (!kIsWeb && Platform.isWindows) {
      return 'Groovy-Update-v$v-Setup.exe';
    } else if (!kIsWeb && Platform.isLinux) {
      if (release.debDownloadUrl != null) {
        return 'Groovy-Update-v$v.deb';
      } else {
        return 'Groovy-Update-v$v.AppImage';
      }
    } else {
      return 'app-update-v$v.apk';
    }
  }

  /// Returns the local destination file path for this release's installer
  static Future<String> getInstallerFilePath(ReleaseInfo release) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/${getInstallerFileName(release)}';
  }

  /// Checks if the installer for this release has already been completely downloaded
  static Future<bool> isInstallerDownloaded(ReleaseInfo release) async {
    try {
      final path = await getInstallerFilePath(release);
      final file = File(path);
      if (await file.exists()) {
        final len = await file.length();
        // A complete installer binary must be at least 1MB
        if (len > 1024 * 1024) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the local installer for this release if the user explicitly wants to re-download
  static Future<void> deleteDownloadedInstaller(ReleaseInfo release) async {
    try {
      final path = await getInstallerFilePath(release);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      final partFile = File('$path.part');
      if (await partFile.exists()) {
        await partFile.delete();
      }
    } catch (_) {}
    isInstallerReadyNotifier.value = false;
    downloadProgressNotifier.value = 0.0;
  }

  /// Cleans up obsolete installers and stale partial downloads
  static Future<void> cleanupOldInstallers({String? currentAppVersion}) async {
    try {
      final dir = await getTemporaryDirectory();
      final currentClean = cleanVersion(currentAppVersion ?? currentVersion);
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.startsWith('Groovy-Update-') || name.startsWith('app-update-')) {
            if (name.endsWith('.part') || name.endsWith('.downloading')) {
              try {
                await entity.delete();
              } catch (_) {}
            } else {
              final regExp = RegExp(r'[-_]v?([0-9]+(?:\.[0-9]+)+(?:\+[0-9]+)?)');
              final match = regExp.firstMatch(name);
              if (match != null) {
                final fileVersion = match.group(1);
                if (fileVersion != null && !isNewer(fileVersion, currentClean)) {
                  try {
                    await entity.delete();
                  } catch (_) {}
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('UpdateService: cleanupOldInstallers error: $e');
    }
  }

  /// Snooze an update version for 24 hours so it won't prompt repeatedly on launch
  static Future<void> snoozeUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyDismissedVersion, cleanVersion(version));
      await prefs.setInt(_prefKeyDismissedTime, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('UpdateService: failed to save snoozed update: $e');
    }
  }

  /// Clears snoozed update state so the update dialog can be shown again immediately
  static Future<void> clearSnooze([String? version]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (version != null) {
        final dismissedVersion = prefs.getString(_prefKeyDismissedVersion);
        if (dismissedVersion == cleanVersion(version)) {
          await prefs.remove(_prefKeyDismissedVersion);
          await prefs.remove(_prefKeyDismissedTime);
        }
      } else {
        await prefs.remove(_prefKeyDismissedVersion);
        await prefs.remove(_prefKeyDismissedTime);
      }
    } catch (e) {
      debugPrint('UpdateService: failed to clear snooze: $e');
    }
  }

  /// Converts raw technical exceptions (Dio, sockets, timeouts) into clear, friendly messages
  static String formatDownloadError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Tiempo de espera agotado. Tu conexión a internet es lenta o inestable.';
        case DioExceptionType.connectionError:
          return 'Se perdió la conexión a internet durante la descarga. Comprueba tu conexión.';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          return 'El servidor de descarga respondió con error ($code). Intenta más tarde o descarga desde la web.';
        case DioExceptionType.cancel:
          return 'Descarga cancelada.';
        default:
          final msg = (error.message ?? '').toLowerCase();
          if (msg.contains('socket') || msg.contains('network') || msg.contains('failed host lookup')) {
            return 'Se perdió la conexión a internet durante la descarga. Comprueba tu conexión.';
          }
          return 'Error de red al descargar la actualización. Verifica tu conexión.';
      }
    }
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') || str.contains('failed host lookup') || str.contains('network')) {
      return 'Se perdió la conexión a internet durante la descarga. Comprueba tu conexión.';
    }
    if (str.contains('space') || str.contains('storage') || str.contains('enospc')) {
      return 'Espacio insuficiente en el almacenamiento del dispositivo.';
    }
    if (str.contains('permission')) {
      return 'Permiso denegado para guardar la actualización.';
    }
    return 'No se pudo completar la descarga. Verifica tu conexión e inténtalo de nuevo.';
  }

  /// Checks whether a specific update version has been snoozed within the last 24 hours
  static Future<bool> isUpdateSnoozed(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString(_prefKeyDismissedVersion);
      final dismissedTime = prefs.getInt(_prefKeyDismissedTime) ?? 0;

      if (dismissedVersion == cleanVersion(version)) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - dismissedTime;
        if (elapsed < const Duration(hours: 24).inMilliseconds) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<ReleaseInfo?> checkForUpdate({bool force = false}) async {
    try {
      await initVersion();
      final response = await _dio.get<Map<String, dynamic>>(_apiUrl);
      final data = response.data;
      if (data == null) return null;

      final release = ReleaseInfo.fromJson(data);
      if (isNewer(release.version, currentVersion)) {
        final isDownloaded = await isInstallerDownloaded(release);
        isInstallerReadyNotifier.value = isDownloaded;

        if (!force) {
          final snoozed = await isUpdateSnoozed(release.version);
          if (snoozed) {
            debugPrint('UpdateService: update ${release.version} is currently snoozed');
            return null;
          }
        }
        availableUpdateNotifier.value = release;
        return release;
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: check failed – $e');
      return null;
    }
  }

  /// Installs an already downloaded update file
  static Future<void> installDownloadedUpdate(ReleaseInfo release) async {
    final filePath = await getInstallerFilePath(release);
    final file = File(filePath);
    if (!await file.exists()) {
      isInstallerReadyNotifier.value = false;
      downloadErrorNotifier.value = 'El instalador ya no se encuentra en el dispositivo. Vuelve a descargarlo.';
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('installApk', {'filePath': filePath});
      } on PlatformException catch (pe) {
        if (pe.code == 'NEED_PERMISSION') {
          downloadErrorNotifier.value =
              'Activa el permiso "Instalar apps desconocidas" en Ajustes y pulsa Instalar de nuevo.';
        } else {
          downloadErrorNotifier.value =
              'Error al iniciar instalación: ${pe.message ?? pe.code}';
        }
      }
    } else if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.start(
          filePath,
          ['/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
          mode: ProcessStartMode.detached,
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        exit(0);
      } catch (_) {
        try {
          await Process.start(
            'cmd.exe',
            ['/c', 'start', '""', filePath],
            mode: ProcessStartMode.detached,
          );
          await Future.delayed(const Duration(milliseconds: 1500));
          exit(0);
        } catch (err) {
          debugPrint('Failed to launch Windows update installer: $err');
          downloadErrorNotifier.value =
              'No se pudo ejecutar el instalador. Ábrelo manualmente desde tu carpeta temporal o descarga de GitHub.';
        }
      }
    } else if (!kIsWeb && Platform.isLinux) {
      if (filePath.endsWith('.deb')) {
        try {
          await Process.start('xdg-open', [filePath], mode: ProcessStartMode.detached);
          await Future.delayed(const Duration(milliseconds: 1500));
          exit(0);
        } catch (err) {
          debugPrint('Failed to open deb installer with xdg-open: $err');
          await Process.start('xdg-open', [release.htmlUrl], mode: ProcessStartMode.detached);
        }
        return;
      }

      final appImageEnv = Platform.environment['APPIMAGE'];
      if (appImageEnv != null && appImageEnv.isNotEmpty) {
        try {
          await Process.run('chmod', ['+x', filePath]);
          await File(filePath).copy(appImageEnv);
          await Process.start(
            appImageEnv,
            [],
            mode: ProcessStartMode.detached,
          );
          await Future.delayed(const Duration(milliseconds: 500));
          exit(0);
        } catch (e) {
          debugPrint('Linux AppImage self-update failed: $e');
          await Process.start('xdg-open', [release.htmlUrl], mode: ProcessStartMode.detached);
        }
      } else {
        await Process.start('xdg-open', [release.htmlUrl], mode: ProcessStartMode.detached);
      }
    }
  }

  /// Downloads the release installer. If autoInstall is true and download completes, proceeds to install.
  static Future<void> startDownload(ReleaseInfo release, {bool autoInstall = false}) async {
    // If the installer is already downloaded, don't download again!
    if (await isInstallerDownloaded(release)) {
      isInstallerReadyNotifier.value = true;
      if (autoInstall) {
        await installDownloadedUpdate(release);
      }
      return;
    }

    final String? downloadUrl;
    if (!kIsWeb && Platform.isWindows) {
      downloadUrl = release.windowsSetupDownloadUrl ?? release.htmlUrl;
    } else if (!kIsWeb && Platform.isLinux) {
      if (release.debDownloadUrl != null) {
        downloadUrl = release.debDownloadUrl;
      } else {
        downloadUrl = release.appImageDownloadUrl ?? release.htmlUrl;
      }
    } else {
      downloadUrl = release.apkDownloadUrl;
    }

    if (downloadUrl == null || downloadUrl.isEmpty) {
      downloadErrorNotifier.value = 'No se encontró un archivo instalador para tu plataforma.';
      return;
    }
    if (isDownloadingNotifier.value) return;

    isDownloadingNotifier.value = true;
    downloadProgressNotifier.value = 0.0;
    downloadErrorNotifier.value = null;
    isInstallerReadyNotifier.value = false;

    final targetPath = await getInstallerFilePath(release);
    final partPath = '$targetPath.part';

    try {
      final partFile = File(partPath);
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }

      await _dio.download(
        downloadUrl,
        partPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = (received / total).clamp(0.0, 1.0);
            downloadProgressNotifier.value = p;
          }
        },
      );

      // Once download finishes completely, atomically rename .part to the final installer file
      final completedPartFile = File(partPath);
      if (await completedPartFile.exists()) {
        final finalFile = File(targetPath);
        if (await finalFile.exists()) {
          try {
            await finalFile.delete();
          } catch (_) {}
        }
        await completedPartFile.rename(targetPath);
      }

      isDownloadingNotifier.value = false;
      downloadProgressNotifier.value = 1.0;
      isInstallerReadyNotifier.value = true;

      if (autoInstall) {
        await installDownloadedUpdate(release);
      }
    } catch (e) {
      isDownloadingNotifier.value = false;
      downloadErrorNotifier.value = formatDownloadError(e);
      // Delete any broken or incomplete temporary partial file
      try {
        final file = File(partPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      // Clear snooze so the update remains available next time app starts
      await clearSnooze(release.version);
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
      await startDownload(release, autoInstall: true);
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Robust semantic version comparator that supports build metadata (+63) and pre-releases (-beta)
  static bool isNewer(String remote, String current) {
    try {
      final (rParts, rBuild) = _parseVersion(remote);
      final (cParts, cBuild) = _parseVersion(current);

      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      final r = List<int>.from(rParts);
      final c = List<int>.from(cParts);
      while (r.length < maxLen) {
        r.add(0);
      }
      while (c.length < maxLen) {
        c.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }

      // If major.minor.patch are equal (e.g. 1.0.72 vs 1.0.72),
      // only consider newer if BOTH specify a build number and remote build is strictly greater.
      if (rBuild > 0 && cBuild > 0 && rBuild > cBuild) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static (List<int>, int) _parseVersion(String v) {
    var clean = v.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    int buildNumber = 0;
    if (clean.contains('+')) {
      final parts = clean.split('+');
      clean = parts[0];
      if (parts.length > 1) {
        buildNumber = int.tryParse(parts[1].replaceAll(RegExp(r'\D'), '')) ?? 0;
      }
    }
    if (clean.contains('-')) {
      clean = clean.split('-')[0];
    }
    final components = clean
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
    return (components, buildNumber);
  }

  static String stripMarkdown(String md) {
    var cleaned = md;

    // Filter out raw github comparison links and autogenerated bot lines
    cleaned = cleaned.replaceAll(RegExp(r'(?:Full Changelog|See full diff|Compare changes|Full diff).*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'https?:\/\/github\.com\S+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\* @[a-zA-Z0-9_-]+ in https:\/\/\S+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'@\w+ in #\d+'), '');

    // Filter out downloads and footer sections so in-app update banner only shows actual changelog
    final downloadsIndex = cleaned.indexOf(RegExp(r'#{1,4}\s*📦?\s*Descargas Disponibles', caseSensitive: false));
    if (downloadsIndex != -1) {
      cleaned = cleaned.substring(0, downloadsIndex).trim();
    }
    final footerIndex = cleaned.indexOf(RegExp(r'#{1,4}\s*📝?\s*Registro.*Cambios', caseSensitive: false));
    if (footerIndex != -1) {
      cleaned = cleaned.substring(0, footerIndex).trim();
    }

    // Filter out top title and introductory headings
    cleaned = cleaned.replaceAll(RegExp(r'^[#\s]*🎵\s*Groovy[^\n]*\n*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^[#\s]*✨\s*Novedades[^\n]*\n*', multiLine: true), '');

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
      return '• Mejoras de estabilidad, rendimiento y correcciones de errores en esta versión.';
    }
    return cleaned;
  }
}
