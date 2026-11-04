import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_theme.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  Timer? _ticker;
  bool _fadeOut = true;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration? d) {
    if (d == null || d.isNegative) return '00:00';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectTimer(PlayerProvider player, Duration duration, {bool endOfSong = false}) {
    player.setSleepTimer(
      duration,
      endCurrentSong: endOfSong,
      fadeOut: _fadeOut,
      fadeDurationSeconds: 30,
    );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          endOfSong
              ? 'La música se apagará al terminar esta canción'
              : 'Temporizador configurado para ${duration.inMinutes} minutos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final player = Provider.of<PlayerProvider>(context);

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    final remaining = player.sleepTimerRemaining;
    final hasTimer = player.hasSleepTimer;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.appleMusicRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.timer,
                      color: AppTheme.appleMusicRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temporizador de apagado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (hasTimer && remaining != null)
                        Text(
                          'Apagando en ${_formatDuration(remaining)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.appleMusicRed,
                          ),
                        )
                      else if (player.sleepTimerEndCurrentSong)
                        Text(
                          'Se apagará al terminar la canción actual',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.appleMusicRed,
                          ),
                        )
                      else
                        Text(
                          'Detiene la reproducción suavemente',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Presets
              _buildOption(
                title: '15 minutos',
                icon: CupertinoIcons.clock,
                onTap: () => _selectTimer(player, const Duration(minutes: 15)),
                isDark: isDark,
              ),
              _buildOption(
                title: '30 minutos',
                icon: CupertinoIcons.clock,
                onTap: () => _selectTimer(player, const Duration(minutes: 30)),
                isDark: isDark,
              ),
              _buildOption(
                title: '45 minutos',
                icon: CupertinoIcons.clock,
                onTap: () => _selectTimer(player, const Duration(minutes: 45)),
                isDark: isDark,
              ),
              _buildOption(
                title: '1 hora',
                icon: CupertinoIcons.clock,
                onTap: () => _selectTimer(player, const Duration(hours: 1)),
                isDark: isDark,
              ),
              _buildOption(
                title: 'Al terminar esta canción',
                icon: CupertinoIcons.forward_end_fill,
                onTap: () => _selectTimer(player, Duration.zero, endOfSong: true),
                isDark: isDark,
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Fade out toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.appleMusicRed,
                title: Text(
                  'Desvanecer audio gradualmente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'Baja el volumen suavemente durante los últimos 30 segundos',
                  style: TextStyle(fontSize: 12, color: subtitleColor),
                ),
                value: _fadeOut,
                onChanged: (val) => setState(() => _fadeOut = val),
              ),

              if (hasTimer || player.sleepTimerEndCurrentSong) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.xmark_circle),
                    label: const Text(
                      'Cancelar temporizador activo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      player.cancelSleepTimer();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Temporizador cancelado'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
