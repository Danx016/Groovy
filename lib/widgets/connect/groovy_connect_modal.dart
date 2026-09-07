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
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
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
          heightFactor: 0.82,
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
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _loadLocalDeviceInfo();
    _startDeviceDiscovery();
  }

  Future<void> _loadLocalDeviceInfo() async {
    final info = await DeviceInfoService().getDeviceInfo();
    if (mounted) {
      setState(() => _deviceInfo = info);
    }
  }

  void _startDeviceDiscovery() {
    setState(() => _isSearching = true);

    // UPnP / DLNA discovery on local network
    try {
      final upnp = Provider.of<UpnpService>(context, listen: false);
      upnp.discover();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
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

    // Google Cast discovery on supported platforms
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final castService = Provider.of<CastService>(context);
    final upnpService = Provider.of<UpnpService>(context);
    final player = Provider.of<PlayerProvider>(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final isCastConnected = castService.isConnected;
    final isUpnpConnected = upnpService.isConnected;
    final isRemoteConnected = isCastConnected || isUpnpConnected;

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
                  player: player,
                ),

                const SizedBox(height: 22),

                // 2. OTHER AVAILABLE DEVICES HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SELECCIONA OTRO DISPOSITIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isDark
                            ? const Color(0xFFA0A0A0)
                            : const Color(0xFF666666),
                      ),
                    ),
                    if (_isSearching)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF1ED760),
                        ),
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
                              'Buscar',
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

                // 3. CAST STREAM DEVICES (Android / iOS)
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
                          return _buildDeviceTile(
                            icon: Icons.cast_rounded,
                            title: d.friendlyName,
                            subtitle: d.modelName ?? 'Google Cast / Nest',
                            isConnected: isThisConnected,
                            isDark: isDark,
                            onTap: isThisConnected
                                ? null
                                : () async {
                                    final ok = await castService.connectToDevice(d);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Conectado a ${d.friendlyName}'
                                                : 'No se pudo conectar a ${d.friendlyName}',
                                          ),
                                          backgroundColor: ok
                                              ? const Color(0xFF1ED760)
                                              : Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                          );
                        }).toList(),
                      );
                    },
                  ),

                // 4. DLNA / UPNP DEVICES
                ..._upnpDevices.map((d) {
                  final isThisConnected = isUpnpConnected &&
                      upnpService.connectedDevice?.friendlyName == d.friendlyName;
                  return _buildDeviceTile(
                    icon: Icons.speaker_group_rounded,
                    title: d.friendlyName,
                    subtitle: [d.manufacturer, d.modelName]
                        .where((s) => s.isNotEmpty)
                        .join(' • '),
                    isConnected: isThisConnected,
                    isDark: isDark,
                    onTap: isThisConnected
                        ? null
                        : () async {
                            final ok = await upnpService.connect(d);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Conectado a ${d.friendlyName}'
                                        : 'No se pudo conectar a ${d.friendlyName}',
                                  ),
                                  backgroundColor: ok
                                      ? const Color(0xFF1ED760)
                                      : Colors.redAccent,
                                ),
                              );
                            }
                          },
                  );
                }),

                // 5. OTHER ECOSYSTEM DEVICES (e.g. DANILO Laptop / Smartphone)
                _buildEcosystemDeviceTile(context, isDark: isDark, auth: auth),

                const SizedBox(height: 20),

                // 6. SPOTIFY CONNECT HELP & INSTRUCTIONS CARD
                _buildInstructionsCard(isDark),

                const SizedBox(height: 16),

                // 7. CANNOT SEE DEVICE HELP
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
    required PlayerProvider player,
  }) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    String deviceTitle;
    String deviceSubtitle;
    IconData deviceIcon;

    if (castService.isConnected) {
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
                    Text(
                      'ESTÁS ESCUCHANDO EN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF1ED760),
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
                TextButton(
                  onPressed: () {
                    if (castService.isConnected) castService.disconnect();
                    if (upnpService.isConnected) upnpService.disconnect();
                  },
                  child: const Text(
                    'Desconectar',
                    style: TextStyle(
                      color: Color(0xFFFF453A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ED760).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Activo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
          ],

          // Quick Volume Slider
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
                    onChanged: (v) => player.setVolume(v),
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
    required bool isConnected,
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
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isConnected
                ? const Color(0xFF1ED760).withValues(alpha: 0.18)
                : (isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isConnected
                ? const Color(0xFF1ED760)
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isConnected
                ? const Color(0xFF1ED760)
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: isConnected
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1ED760), size: 20)
            : const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildEcosystemDeviceTile(
    BuildContext context, {
    required bool isDark,
    required AuthProvider auth,
  }) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final otherType = isMobile ? 'Computadora (Windows / Mac)' : 'Teléfono Groovy';
    final userName = auth.currentUser?.name ?? 'Tu cuenta';
    final otherSubtitle = 'Inicia sesión con $userName para reproducir';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black12,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isMobile ? Icons.laptop_rounded : Icons.phone_iphone_rounded,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        title: Text(
          otherType,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          otherSubtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        trailing: const Icon(Icons.sync_rounded, size: 18, color: Colors.grey),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Abre Groovy en tu $otherType con la misma red Wi-Fi para transferir la música al instante.',
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        },
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
              Icon(
                Icons.wifi_rounded,
                size: 16,
                color: const Color(0xFF1ED760),
              ),
              const SizedBox(width: 8),
              Text(
                'CÓMO CONECTARTE',
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
          _instructionStep('1', 'Conecta este dispositivo y tu teléfono o PC a la misma red Wi-Fi.', isDark),
          const SizedBox(height: 6),
          _instructionStep('2', 'Abre la aplicación Groovy en el otro dispositivo.', isDark),
          const SizedBox(height: 6),
          _instructionStep('3', 'La música continuará o se transferirá automáticamente.', isDark),
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
          'Groovy Connect te permite sincronizar y transferir la reproducción de música sin cortes entre tu teléfono móvil, tu computadora de escritorio, Google Cast y altavoces DLNA en tu red local.',
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
          '1. Asegúrate de que ambos dispositivos estén conectados a la misma red Wi-Fi o banda de red.\n\n'
          '2. Verifica que Groovy esté abierto y activo en tu otro dispositivo.\n\n'
          '3. Si usas Windows, asegúrate de haber permitido a Groovy comunicarse en redes privadas en el Firewall de Windows.',
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
