import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/cast_service.dart';
import '../../services/device_info_service.dart';
import '../../services/groovy_connect_service.dart';
import '../../services/upnp_service.dart';
import '../../theme/app_theme.dart';
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

class _GroovyConnectModalState extends State<GroovyConnectModal>
    with SingleTickerProviderStateMixin {
  ClientDeviceInfo? _deviceInfo;
  List<UpnpDevice> _upnpDevices = [];
  Timer? _pollTimer;
  bool _isSearching = false;
  String? _connectingDeviceId;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

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
    _pulseController.dispose();
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

      if (song != null) {
        final ok = await groovyConnect.transferPlayback(
          device: device,
          song: song,
          position: position,
          isPlaying: isPlaying,
          queue: player.queue,
          queueIndex: player.currentIndex,
        );
        if (ok) {
          player.enableGroovyConnectRemote(device);
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
        // Connect to remote device without requiring an active song
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppTheme.appleMusicRed : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final castService = Provider.of<CastService>(context);
    final upnpService = Provider.of<UpnpService>(context);
    final groovyConnect = Provider.of<GroovyConnectService>(context);
    final player = Provider.of<PlayerProvider>(context);

    final isCastConnected = castService.isConnected;
    final isUpnpConnected = upnpService.isConnected;
    final isGroovyConnected = groovyConnect.isConnected;
    final isRemoteConnected = isCastConnected || isUpnpConnected || isGroovyConnected;

    final groovyDevices = groovyConnect.discoveredDevices;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 10),
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
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
            child: Row(
              children: [
                const GroovyConnectIcon(
                  size: 24,
                  isConnected: true,
                  connectedColor: AppTheme.appleMusicRed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conectarse a un dispositivo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Groovy Connect',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  tooltip: 'Acerca de Groovy Connect',
                  onPressed: () => _showAboutConnectDialog(context, isDark),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0x1FFFFFFF)),

          // Scrollable Devices Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                // 1. ACTIVE PLAYBACK DEVICE CARD
                _buildCurrentDeviceCard(
                  context,
                  isDark: isDark,
                  isRemoteConnected: isRemoteConnected,
                  castService: castService,
                  upnpService: upnpService,
                  groovyConnect: groovyConnect,
                  player: player,
                ),

                const SizedBox(height: 22),

                // 2. OTHER AVAILABLE DEVICES HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SELECCIONA UN DISPOSITIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isDark
                            ? const Color(0xFFA0A0A0)
                            : const Color(0xFF666666),
                      ),
                    ),
                    if (_isSearching || groovyConnect.isDiscovering)
                      Row(
                        children: [
                          Text(
                            'Buscando... ',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.appleMusicRed,
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
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Actualizar',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. THIS LOCAL DEVICE (Tap to switch playback back here, just like Spotify)
                _buildDeviceTile(
                  icon: isMobile ? Icons.smartphone_rounded : Icons.laptop_windows_rounded,
                  title: isMobile ? 'Este teléfono' : 'Esta computadora',
                  subtitle: _deviceInfo?.deviceModel ?? (isMobile ? 'Dispositivo móvil' : 'Windows PC'),
                  badge: !isRemoteConnected ? (player.isPlaying ? 'Reproduciendo' : 'Activo') : null,
                  isConnected: !isRemoteConnected,
                  isLoading: _connectingDeviceId == 'local',
                  isDark: isDark,
                  onTap: !isRemoteConnected
                      ? null
                      : () => _switchToThisDevice(groovyConnect, player, castService, upnpService),
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
                      onTap: isThisConnected
                          ? null
                          : () => _connectToGroovyDevice(dev, groovyConnect, player),
                    );
                  }),
                ],

                // 4. GOOGLE CAST DEVICES (Android / iOS)
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
                            subtitle: d.modelName ?? 'Google Cast / Nest Audio',
                            badge: 'Google Cast',
                            isConnected: isThisConnected,
                            isLoading: isConnecting,
                            isDark: isDark,
                            onTap: isThisConnected
                                ? null
                                : () => _connectToCastDevice(d, castService, player),
                          );
                        }).toList(),
                      );
                    },
                  ),

                // 5. DLNA / UPNP WIRELESS SPEAKERS & TVS
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
                    onTap: isThisConnected
                        ? null
                        : () => _connectToUpnpDevice(d, upnpService, player),
                  );
                }),

                // 6. IF NO OTHER DEVICES DETECTED YET: SHOW INTERACTIVE RADAR SCAN CARD
                if (groovyDevices.isEmpty && _upnpDevices.isEmpty)
                  _buildNoDevicesCard(context, isDark),

                const SizedBox(height: 18),

                // 7. GROOVY CONNECT HOW-TO GUIDE
                _buildInstructionsCard(isDark),

                const SizedBox(height: 16),

                // 8. TROUBLESHOOTING HELP BUTTON
                Center(
                  child: TextButton.icon(
                    onPressed: () => _showTroubleshootingDialog(context, isDark),
                    icon: Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFFB3B3B3) : Colors.black54,
                    ),
                    label: Text(
                      '¿NO PUEDO VER MI DISPOSITIVO?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFFB3B3B3) : Colors.black54,
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
        color: AppTheme.appleMusicRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.appleMusicRed.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Glowing Animated Active Device Icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.appleMusicRed.withValues(
                    alpha: 0.18 + (_pulseController.value * 0.12),
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    deviceIcon,
                    color: AppTheme.appleMusicRed,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTÁS ESCUCHANDO EN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.appleMusicRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deviceTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  deviceSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
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
              color: AppTheme.appleMusicRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EqualizerBars(
                  isPlaying: player.isPlaying,
                  color: AppTheme.appleMusicRed,
                ),
                const SizedBox(width: 6),
                Text(
                  isRemoteConnected ? 'En remoto' : 'Activo',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.appleMusicRed,
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
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isConnected
            ? AppTheme.appleMusicRed.withValues(alpha: 0.10)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? AppTheme.appleMusicRed.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: isLoading ? null : onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isConnected
                ? AppTheme.appleMusicRed.withValues(alpha: 0.18)
                : (isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 21,
            color: isConnected
                ? AppTheme.appleMusicRed
                : (isDark ? Colors.white : Colors.black87),
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
                  color: isConnected
                      ? AppTheme.appleMusicRed
                      : (isDark ? Colors.white : Colors.black),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null && !isConnected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.appleMusicRed,
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
            color: isDark ? Colors.white60 : Colors.black54,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.appleMusicRed,
                ),
              )
            : isConnected
                ? const Icon(Icons.check_circle_rounded, color: AppTheme.appleMusicRed, size: 20)
                : const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildNoDevicesCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_sync_rounded,
            size: 34,
            color: AppTheme.appleMusicRed.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 10),
          Text(
            'Buscando tus dispositivos en la nube...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Abre Groovy con tu cuenta en tu teléfono, PC o laptop en cualquier lugar (Wi-Fi o datos móviles 4G/5G) para reproducir tu música a distancia.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _startDeviceDiscovery,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppTheme.appleMusicRed,
              side: BorderSide(
                color: AppTheme.appleMusicRed.withValues(alpha: 0.4),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Actualizar dispositivos', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_done_rounded,
                size: 16,
                color: AppTheme.appleMusicRed,
              ),
              const SizedBox(width: 8),
              Text(
                'CÓMO USAR GROOVY CONNECT GLOBAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _instructionStep('1', 'Inicia sesión con tu cuenta de Groovy en tus dispositivos.', isDark),
          const SizedBox(height: 6),
          _instructionStep('2', 'Abre Groovy en tu teléfono o PC desde cualquier red (Wi-Fi o datos móviles).', isDark),
          const SizedBox(height: 6),
          _instructionStep('3', 'Toca el dispositivo en la lista para reproducir y controlar tu música al instante.', isDark),
        ],
      ),
    );
  }

  Widget _instructionStep(String num, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.appleMusicRed.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.appleMusicRed,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  void _showAboutConnectDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            GroovyConnectIcon(size: 22, isConnected: true),
            SizedBox(width: 10),
            Text('Groovy Connect', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Groovy Connect te permite sincronizar y transferir la reproducción de música sin cortes entre tu teléfono móvil, tu computadora de escritorio y otros dispositivos en cualquier lugar a través de la nube.\n\nDisfruta de sonido continuo estés donde estés, con Wi-Fi o datos móviles.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: AppTheme.appleMusicRed)),
          ),
        ],
      ),
    );
  }

  void _showTroubleshootingDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿No ves tu dispositivo?', style: TextStyle(fontSize: 17)),
        content: const Text(
          '1. Asegúrate de tener iniciada sesión con la misma cuenta en ambos dispositivos.\n\n'
          '2. Verifica que Groovy esté abierto y activo en tu otro dispositivo.\n\n'
          '3. Verifica que ambos dispositivos tengan conexión a internet (Wi-Fi o datos móviles).\n\n'
          '4. Toca el botón de actualizar para refrescar los dispositivos activos en la nube.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(color: AppTheme.appleMusicRed)),
          ),
        ],
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
