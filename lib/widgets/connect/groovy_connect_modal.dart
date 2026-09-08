import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/cast_service.dart';
import '../../services/device_info_service.dart';
import '../../services/groovy_connect_service.dart';
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
        );
        if (ok) {
          await player.pause();
          if (mounted) {
            _showSnackBar(
              'Conectado a ${device.name}. Música transferida con Groovy Connect.',
              isSuccess: true,
            );
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
        // Just establish remote connection
        groovyConnect.transferPlayback(
          device: device,
          song: Song(id: 'dummy', title: 'Groovy Connect Session'),
          position: Duration.zero,
          isPlaying: false,
        );
        if (mounted) {
          _showSnackBar('Conectado a ${device.name}', isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al conectar: $e', isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _connectingDeviceId = null);
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
        backgroundColor: isSuccess ? const Color(0xFF1ED760) : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // --- MANUAL IP CONNECT DIALOG ---
  Future<void> _showManualIpDialog(BuildContext context, bool isDark) async {
    final controller = TextEditingController();
    final groovyConnect = Provider.of<GroovyConnectService>(context, listen: false);
    final player = Provider.of<PlayerProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF222225) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.wifi_find_rounded, color: Color(0xFF1ED760), size: 24),
            const SizedBox(width: 10),
            Text(
              'Conectar por IP Local',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Si tu router bloquea el descubrimiento automático (aislamiento de red), ingresa la IP local de tu otro dispositivo:',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Ej: 192.168.1.50',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1ED760), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1ED760),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final ip = controller.text.trim();
              if (ip.isEmpty) return;
              Navigator.of(ctx).pop();

              try {
                // Test connection
                final res = await http.get(
                  Uri.parse('http://$ip:42425/groovy/info'),
                ).timeout(const Duration(seconds: 3));

                if (res.statusCode == 200) {
                  final data = jsonDecode(res.body) as Map<String, dynamic>;
                  final device = GroovyRemoteDevice.fromJson(data, host: ip, port: 42425);
                  await _connectToGroovyDevice(device, groovyConnect, player);
                } else {
                  _showSnackBar('No se encontró Groovy en http://$ip:42425', isSuccess: false);
                }
              } catch (e) {
                _showSnackBar('No se pudo contactar $ip: $e', isSuccess: false);
              }
            },
            child: const Text('Conectar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        color: isDark ? const Color(0xFF161618) : Colors.white,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
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
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.2),
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
                  connectedColor: Color(0xFF1ED760),
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
                    Icons.wifi_find_rounded,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  tooltip: 'Conectar por IP Local',
                  onPressed: () => _showManualIpDialog(context, isDark),
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
                              color: Color(0xFF1ED760),
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

                // 3. GROOVY CONNECT INSTANCES (Windows, Android, Mac, Linux)
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
                      subtitle: '${dev.platform} • ${dev.isLocalLan ? "Red Wi-Fi Local" : "En línea"}',
                      badge: dev.isPlaying ? 'Reproduciendo' : 'Disponible',
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
      deviceSubtitle = 'Groovy Connect • Control Remoto en Vivo';
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

    final currentSong = player.currentSong;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1ED760).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1ED760).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Glowing Animated Active Device Icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ED760).withValues(
                        alpha: 0.18 + (_pulseController.value * 0.12),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        deviceIcon,
                        color: const Color(0xFF1ED760),
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
                        color: Color(0xFF1ED760),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deviceTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      deviceSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isRemoteConnected)
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF453A).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFFF453A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    if (groovyConnect.isConnected) groovyConnect.disconnect();
                    if (castService.isConnected) castService.disconnect();
                    if (upnpService.isConnected) upnpService.disconnect();
                  },
                  child: const Text(
                    'Desconectar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ED760).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1ED760),
                    ),
                  ),
                ),
            ],
          ),

          if (currentSong != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    player.isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_circle_filled_rounded,
                    size: 16,
                    color: const Color(0xFF1ED760),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${currentSong.title} • ${currentSong.artist ?? "Groovy"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (groovyConnect.isConnected) ...[
                    IconButton(
                      icon: Icon(
                        player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 18,
                        color: const Color(0xFF1ED760),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        groovyConnect.sendControl(player.isPlaying ? 'pause' : 'play');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 18, color: Colors.white70),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        groovyConnect.sendControl('skipNext');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Volume Slider
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                player.volume == 0
                    ? Icons.volume_off_rounded
                    : player.volume < 0.5
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                size: 18,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFF1ED760),
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: player.volume.clamp(0.0, 1.0),
                    onChanged: (v) {
                      player.setVolume(v);
                      if (groovyConnect.isConnected) {
                        groovyConnect.sendControl('volume', v);
                      }
                    },
                  ),
                ),
              ),
              Text(
                '${(player.volume * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
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
        color: isDark ? const Color(0xFF222225) : const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF1ED760)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: isLoading ? null : onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFF1ED760).withValues(alpha: 0.18)
                : (isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 21,
            color: isConnected
                ? const Color(0xFF1ED760)
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
                      ? const Color(0xFF1ED760)
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
                  color: const Color(0xFF1ED760).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1ED760),
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
                  color: Color(0xFF1ED760),
                ),
              )
            : isConnected
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1ED760), size: 20)
                : const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildNoDevicesCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1D) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.radar_rounded,
            size: 32,
            color: const Color(0xFF1ED760).withValues(alpha: 0.8),
          ),
          const SizedBox(height: 10),
          Text(
            'Buscando dispositivos en tu red Wi-Fi...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Abre Groovy en tu teléfono o computadora conectada a la misma red Wi-Fi para transferir la música al instante.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _startDeviceDiscovery,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Buscar de nuevo', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: () => _showManualIpDialog(context, isDark),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF1ED760).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF1ED760),
                ),
                icon: const Icon(Icons.link_rounded, size: 14),
                label: const Text('Ingresar IP', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F4F6),
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
                Icons.wifi_rounded,
                size: 16,
                color: Color(0xFF1ED760),
              ),
              const SizedBox(width: 8),
              Text(
                'CÓMO USAR GROOVY CONNECT',
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
          _instructionStep('1', 'Conecta tu teléfono y computadora a la misma red Wi-Fi.', isDark),
          const SizedBox(height: 6),
          _instructionStep('2', 'Abre Groovy en ambos dispositivos.', isDark),
          const SizedBox(height: 6),
          _instructionStep('3', 'Toca el dispositivo en la lista para transferir la reproducción al instante.', isDark),
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
            color: const Color(0xFF1ED760).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1ED760),
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
        backgroundColor: isDark ? const Color(0xFF222225) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            GroovyConnectIcon(size: 22, isConnected: true),
            SizedBox(width: 10),
            Text('Groovy Connect', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Groovy Connect te permite sincronizar y transferir la reproducción de música sin cortes entre tu teléfono móvil, tu computadora de escritorio, Google Cast y altavoces DLNA en tu red local.\n\nDisfruta de sonido continuo sin importar en qué pantalla o altavoz estés.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF1ED760))),
          ),
        ],
      ),
    );
  }

  void _showTroubleshootingDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF222225) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿No ves tu dispositivo?', style: TextStyle(fontSize: 17)),
        content: const Text(
          '1. Asegúrate de que ambos dispositivos estén conectados a la misma red Wi-Fi o banda del router.\n\n'
          '2. Verifica que Groovy esté abierto y activo en tu otro dispositivo.\n\n'
          '3. Si tu router tiene "Aislamiento de AP" activado, puedes usar el botón de arriba para ingresar la IP local directamente.\n\n'
          '4. En Windows, asegúrate de permitir a Groovy en redes privadas en el Firewall.',
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF1ED760))),
          ),
        ],
      ),
    );
  }
}
