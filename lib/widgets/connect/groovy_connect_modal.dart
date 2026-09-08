import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../screens/login_screen.dart';
import '../../services/cast_service.dart';
import '../../services/device_info_service.dart';
import '../../services/groovy_connect_service.dart';
import '../../services/theme_service.dart';
import '../../services/upnp_service.dart';
import 'groovy_connect_icon.dart';

/// Modal dialog (desktop) or bottom sheet (mobile) to pick and control playback devices,
/// matching Spotify Connect and Apple Music sleek dark design aesthetics.
class GroovyConnectModal extends StatefulWidget {
  const GroovyConnectModal({super.key});

  /// Opens the connect modal either as a BottomSheet on mobile or a Dialog on desktop.
  static Future<void> show(BuildContext context) async {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      await showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
            child: const GroovyConnectModal(),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const FractionallySizedBox(
          heightFactor: 0.88,
          child: GroovyConnectModal(),
        ),
      );
    }
  }

  @override
  State<GroovyConnectModal> createState() => _GroovyConnectModalState();
}

class _GroovyConnectModalState extends State<GroovyConnectModal> {
  ClientDeviceInfo? _deviceInfo;
  List<UpnpDevice> _upnpDevices = [];
  Timer? _pollTimer;
  bool _isSearching = false;
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _loadLocalDeviceInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDeviceDiscovery();
    });
  }

  Future<void> _loadLocalDeviceInfo() async {
    final info = await DeviceInfoService().getDeviceInfo();
    if (mounted) {
      setState(() => _deviceInfo = info);
    }
  }

  void _startDeviceDiscovery() {
    if (!mounted) return;
    setState(() => _isSearching = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final groovyConnect = Provider.of<GroovyConnectService>(context, listen: false);

    // 1. Groovy Connect P2P Discovery (LAN & Cloud)
    try {
      groovyConnect.discover(authToken: auth.token);
    } catch (e) {
      debugPrint('[GroovyConnect] Discovery error: $e');
    }

    // 2. UPnP / DLNA discovery on local network
    try {
      final upnp = Provider.of<UpnpService>(context, listen: false);
      upnp.discover();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (mounted) {
          final currentList = upnp.devices;
          if (currentList.length != _upnpDevices.length) {
            setState(() => _upnpDevices = List.of(currentList));
          }
        }
      });
    } catch (e) {
      debugPrint('[GroovyConnect] UPnP error: $e');
    }

    // 3. Google Cast discovery on supported platforms
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        GoogleCastDiscoveryManager.instance.startDiscovery();
      } catch (e) {
        debugPrint('[GroovyConnect] GoogleCast discovery error: $e');
      }
    }

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isSearching = false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        GoogleCastDiscoveryManager.instance.stopDiscovery();
      } catch (_) {}
    }
    super.dispose();
  }

  // --- CONNECT HANDLERS WITH ACTUAL PLAYBACK TRANSFER ---

  Future<void> _connectToGroovyDevice(
    GroovyRemoteDevice device,
    GroovyConnectService groovyConnect,
    PlayerProvider player,
  ) async {
    setState(() => _connectingDeviceId = device.id);
    try {
      final song = player.currentSong;
      final position = player.position;
      final isPlaying = player.isPlaying;

      // If controller has a song, and either controller is playing or target device is not actively playing: transfer
      final shouldTransfer = song != null && (isPlaying || !device.isPlaying);

      if (shouldTransfer) {
        final ok = await groovyConnect.transferPlayback(
          device: device,
          song: song,
          position: position,
          isPlaying: isPlaying,
          queue: player.queue,
          queueIndex: player.currentIndex,
        );
        if (ok) {
          player.enableGroovyConnectRemote(
            device,
            transferredSong: song,
            isPlaying: isPlaying,
            position: position,
          );
          if (mounted) {
            _showSnackBar(
              'Conectado a ${device.name}. Reproduciendo con Groovy Connect.',
              isSuccess: true,
            );
            Navigator.of(context).pop();
          }
        } else {
          if (mounted) {
            _showSnackBar(
              'No se pudo transferir a ${device.name}. Verifica que Groovy esté abierto.',
              isSuccess: false,
            );
          }
        }
      } else {
        // Connect to remote device without transferring current song (adopt remote playback)
        final ok = await groovyConnect.connectToDevice(device);
        if (ok) {
          player.enableGroovyConnectRemote(device);
          if (mounted) {
            _showSnackBar('Conectado a ${device.name}', isSuccess: true);
            Navigator.of(context).pop();
          }
        } else {
          if (mounted) {
            _showSnackBar(
              'No se pudo conectar a ${device.name}. Verifica que Groovy esté abierto.',
              isSuccess: false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al conectar: $e', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  /// Switches playback back to this local device (Spotify style), stopping the remote device.
  Future<void> _switchToThisDevice(
    GroovyConnectService groovyConnect,
    PlayerProvider player,
    CastService castService,
    UpnpService upnpService,
  ) async {
    setState(() => _connectingDeviceId = 'local');
    try {
      final song = player.currentSong;
      final position = player.position;
      final isPlaying = player.isPlaying;
      final queue = player.queue;
      final queueIndex = player.currentIndex;

      if (groovyConnect.isConnected) {
        await groovyConnect.sendControl('pause');
        groovyConnect.disconnect();
        player.disableGroovyConnectRemote();
      }
      if (castService.isConnected) castService.disconnect();
      if (upnpService.isConnected) upnpService.disconnect();

      if (song != null) {
        await player.playSong(
          song,
          playlist: queue,
          startIndex: queueIndex,
          initialPosition: position,
        );
        if (!isPlaying) {
          await player.pause();
        }
      }

      if (mounted) {
        _showSnackBar('Reproduciendo en este dispositivo.', isSuccess: true);
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('[GroovyConnect] Error switching to this device: $e');
    } finally {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  Future<void> _connectToUpnpDevice(
    UpnpDevice device,
    UpnpService upnpService,
    PlayerProvider player,
  ) async {
    setState(() => _connectingDeviceId = device.friendlyName);
    try {
      final ok = await upnpService.connect(device);
      if (ok) {
        if (player.currentSong != null) {
          final song = player.currentSong!;
          await player.playSong(song);
        }
        if (mounted) {
          _showSnackBar(
            'Conectado a ${device.friendlyName}. Reproduciendo en alta fidelidad.',
            isSuccess: true,
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'No se pudo conectar a ${device.friendlyName}. Verifica el altavoz.',
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error de conexión DLNA: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceId = null);
    }
  }

  Future<void> _connectToCastDevice(
    GoogleCastDevice device,
    CastService castService,
    PlayerProvider player,
  ) async {
    setState(() => _connectingDeviceId = device.friendlyName);
    try {
      final ok = await castService.connectToDevice(device);
      if (ok) {
        if (player.currentSong != null) {
          final song = player.currentSong!;
          await player.playSong(song);
        }
        if (mounted) {
          _showSnackBar(
            'Conectado a ${device.friendlyName}. Reproduciendo con Google Cast.',
            isSuccess: true,
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'No se pudo conectar a ${device.friendlyName}',
            isSuccess: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error de conexión Cast: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceId = null);
    }
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final accentColor = themeService.accentColor.color;
    final platformDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isDark = themeService.themeMode == ThemeMode.dark ||
        (themeService.themeMode == ThemeMode.system && platformDark);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: isSuccess ? accentColor : const Color(0xFFEF5350),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    final themeService = Provider.of<ThemeService>(context);
    final platformDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isDark = themeService.themeMode == ThemeMode.dark ||
        (themeService.themeMode == ThemeMode.system && platformDark);
    final accentColor = themeService.accentColor.color;

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final tertiaryTextColor = isDark ? Colors.white38 : Colors.black45;
    final dividerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    final castService = Provider.of<CastService>(context);
    final upnpService = Provider.of<UpnpService>(context);
    final groovyConnect = Provider.of<GroovyConnectService>(context);
    final player = Provider.of<PlayerProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final isCastConnected = castService.isConnected;
    final isUpnpConnected = upnpService.isConnected;
    final isGroovyConnected = groovyConnect.isConnected;
    final isRemoteConnected = isCastConnected || isUpnpConnected || isGroovyConnected;

    // Filter and deduplicate devices by physical identity (name + platform)
    final Map<String, GroovyRemoteDevice> uniqueDevices = {};
    for (final dev in groovyConnect.discoveredDevices) {
      final isThisDeviceConnected = isGroovyConnected &&
          (groovyConnect.connectedDevice?.id == dev.id ||
           (groovyConnect.connectedDevice?.name.trim().toLowerCase() == dev.name.trim().toLowerCase() &&
            groovyConnect.connectedDevice?.platform.trim().toLowerCase() == dev.platform.trim().toLowerCase()));

      final key = '${dev.platform.trim().toLowerCase()}_${dev.name.trim().toLowerCase()}';

      if (!uniqueDevices.containsKey(key)) {
        uniqueDevices[key] = dev;
      } else if (isThisDeviceConnected) {
        uniqueDevices[key] = dev;
      }
    }
    final groovyDevices = uniqueDevices.values.toList();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Drag Handle (Mobile)
          if (!isDesktop)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                GroovyConnectIcon(
                  size: 22,
                  isConnected: true,
                  connectedColor: accentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dispositivos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: secondaryTextColor,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 0.8, color: dividerColor),

          // Scrollable Devices Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                // 1. ACTIVE PLAYBACK DEVICE CARD
                _buildCurrentDeviceCard(
                  context,
                  isDark: isDark,
                  accentColor: accentColor,
                  cardBgColor: cardBgColor,
                  cardBorderColor: cardBorderColor,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  isRemoteConnected: isRemoteConnected,
                  castService: castService,
                  upnpService: upnpService,
                  groovyConnect: groovyConnect,
                  player: player,
                ),

                const SizedBox(height: 20),

                // 2. OTHER AVAILABLE DEVICES HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DISPOSITIVOS DISPONIBLES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: tertiaryTextColor,
                      ),
                    ),
                    if (_isSearching || groovyConnect.isDiscovering)
                      Row(
                        children: [
                          Text(
                            'Buscando... ',
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryTextColor,
                            ),
                          ),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          ),
                        ],
                      )
                    else
                      GestureDetector(
                        onTap: _startDeviceDiscovery,
                        child: Row(
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Actualizar',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. THIS LOCAL DEVICE (Only shown if currently connected to a REMOTE device, to allow switching back)
                if (isRemoteConnected)
                  _buildDeviceTile(
                    icon: isMobile ? Icons.smartphone_rounded : Icons.laptop_windows_rounded,
                    title: isMobile ? 'Este teléfono' : 'Esta computadora',
                    subtitle: _deviceInfo?.deviceModel ?? (isMobile ? 'Dispositivo móvil' : 'Windows PC'),
                    badge: 'Cambiar aquí',
                    isConnected: false,
                    isLoading: _connectingDeviceId == 'local',
                    isDark: isDark,
                    accentColor: accentColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    onTap: () => _switchToThisDevice(groovyConnect, player, castService, upnpService),
                  ),

                // 4. GROOVY CONNECT CLOUD INSTANCES (External devices)
                if (groovyDevices.isNotEmpty) ...[
                  ...groovyDevices.map((dev) {
                    final isThisConnected = isGroovyConnected &&
                        groovyConnect.connectedDevice?.id == dev.id;
                    final isConnecting = _connectingDeviceId == dev.id;

                    final isLaptop = dev.platform.toLowerCase().contains('windows') ||
                        dev.platform.toLowerCase().contains('mac') ||
                        dev.platform.toLowerCase().contains('linux');

                    return _buildDeviceTile(
                      icon: isLaptop ? Icons.laptop_windows_rounded : Icons.smartphone_rounded,
                      title: dev.name,
                      subtitle: '${dev.platform} • En la nube',
                      badge: isThisConnected
                          ? (player.isPlaying ? 'Reproduciendo' : 'En remoto')
                          : (dev.isPlaying ? 'En uso' : 'En línea'),
                      isConnected: isThisConnected,
                      isLoading: isConnecting,
                      isDark: isDark,
                      accentColor: accentColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      onTap: isThisConnected
                          ? null
                          : () => _connectToGroovyDevice(dev, groovyConnect, player),
                    );
                  }),
                ],

                // 5. GOOGLE CAST DEVICES (Android / iOS)
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                  StreamBuilder<List<GoogleCastDevice>>(
                    stream: GoogleCastDiscoveryManager.instance.devicesStream,
                    builder: (context, snapshot) {
                      final castDevices = snapshot.data ?? [];
                      if (castDevices.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: castDevices.map((d) {
                          final isThisConnected = isCastConnected &&
                              castService.deviceName == d.friendlyName;
                          final isConnecting = _connectingDeviceId == d.friendlyName;

                          return _buildDeviceTile(
                            icon: Icons.cast_rounded,
                            title: d.friendlyName,
                            subtitle: d.modelName ?? 'Google Cast',
                            badge: 'Google Cast',
                            isConnected: isThisConnected,
                            isLoading: isConnecting,
                            isDark: isDark,
                            accentColor: accentColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            onTap: isThisConnected
                                ? null
                                : () => _connectToCastDevice(d, castService, player),
                          );
                        }).toList(),
                      );
                    },
                  ),

                // 6. DLNA / UPNP WIRELESS SPEAKERS & TVS
                ..._upnpDevices.map((d) {
                  final isThisConnected = isUpnpConnected &&
                       upnpService.connectedDevice?.friendlyName == d.friendlyName;
                  final isConnecting = _connectingDeviceId == d.friendlyName;

                  return _buildDeviceTile(
                    icon: Icons.speaker_group_rounded,
                    title: d.friendlyName,
                    subtitle: [d.manufacturer, d.modelName]
                        .where((s) => s.isNotEmpty)
                        .join(' • '),
                    badge: 'DLNA',
                    isConnected: isThisConnected,
                    isLoading: isConnecting,
                    isDark: isDark,
                    accentColor: accentColor,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    onTap: isThisConnected
                        ? null
                        : () => _connectToUpnpDevice(d, upnpService, player),
                  );
                }),

                // 7. IF NO OTHER DEVICES DETECTED: Elegant minimalist text
                if (groovyDevices.isEmpty && _upnpDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _isSearching || groovyConnect.isDiscovering
                            ? 'Buscando dispositivos en la nube...'
                            : 'No se encontraron otros dispositivos',
                        style: TextStyle(
                          fontSize: 13,
                          color: tertiaryTextColor,
                        ),
                      ),
                    ),
                  ),

                // 8. Minimal auth note if not logged in
                if (!auth.isAuthenticated)
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: secondaryTextColor,
                        ),
                        child: const Text(
                          'Inicia sesión para conectar dispositivos en la nube',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDeviceCard(
    BuildContext context, {
    required bool isDark,
    required Color accentColor,
    required Color cardBgColor,
    required Color cardBorderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isRemoteConnected,
    required CastService castService,
    required UpnpService upnpService,
    required GroovyConnectService groovyConnect,
    required PlayerProvider player,
  }) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    String deviceTitle;
    String deviceSubtitle;
    IconData deviceIcon;

    if (groovyConnect.isConnected) {
      deviceTitle = groovyConnect.connectedDevice?.name ?? 'Dispositivo Groovy';
      deviceSubtitle = 'Groovy Connect • Controlando de forma remota';
      deviceIcon = Icons.speaker_phone_rounded;
    } else if (castService.isConnected) {
      deviceTitle = castService.deviceName ?? 'Dispositivo Google Cast';
      deviceSubtitle = 'Altavoz Cast • Red Wi-Fi';
      deviceIcon = Icons.cast_connected_rounded;
    } else if (upnpService.isConnected) {
      deviceTitle = upnpService.connectedDevice?.friendlyName ?? 'Altavoz DLNA';
      deviceSubtitle = 'Reproductor DLNA • Alta fidelidad';
      deviceIcon = Icons.speaker_rounded;
    } else {
      deviceTitle = isMobile ? 'Este teléfono' : 'Esta computadora';
      deviceSubtitle = _deviceInfo?.deviceModel ??
          (isMobile ? 'Dispositivo móvil' : 'Windows PC');
      deviceIcon = isMobile ? Icons.smartphone_rounded : Icons.laptop_mac_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                deviceIcon,
                color: accentColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTÁS ESCUCHANDO EN',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deviceTitle,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  deviceSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EqualizerBars(
                  isPlaying: player.isPlaying,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isRemoteConnected ? 'En remoto' : 'Activo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required bool isConnected,
    bool isLoading = false,
    required bool isDark,
    required Color accentColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    VoidCallback? onTap,
  }) {
    final tileBg = isConnected
        ? accentColor.withValues(alpha: isDark ? 0.12 : 0.08)
        : (isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFF2F2F7));

    final tileBorder = isConnected
        ? Border.all(color: accentColor.withValues(alpha: 0.28), width: 1)
        : Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: tileBorder,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: isLoading ? null : onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isConnected
                ? accentColor.withValues(alpha: isDark ? 0.20 : 0.14)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 21,
            color: isConnected
                ? accentColor
                : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isConnected ? accentColor : primaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null && !isConnected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: secondaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              )
            : isConnected
                ? Icon(Icons.check_circle_rounded, color: accentColor, size: 20)
                : Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
      ),
    );
  }

}

/// Dynamic animated equalizer soundwave bars (Spotify / Apple Music style)
class _EqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  const _EqualizerBars({required this.isPlaying, required this.color});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(8),
          const SizedBox(width: 2.5),
          _bar(5),
          const SizedBox(width: 2.5),
          _bar(12),
          const SizedBox(width: 2.5),
          _bar(7),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _bar(5 + 11 * ((t * 1.3) % 1.0)),
            const SizedBox(width: 2.5),
            _bar(14 - 9 * ((t * 0.9) % 1.0)),
            const SizedBox(width: 2.5),
            _bar(7 + 13 * ((t * 1.5) % 1.0)),
            const SizedBox(width: 2.5),
            _bar(13 - 7 * ((t * 1.1) % 1.0)),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height.clamp(4.0, 18.0),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
