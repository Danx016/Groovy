import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_theme.dart';
import '../album_artwork.dart';

class GroovyJamSession {
  static final GroovyJamSession _instance = GroovyJamSession._internal();
  factory GroovyJamSession() => _instance;
  GroovyJamSession._internal();

  bool isHosting = false;
  bool isGuest = false;
  String? roomCode;
  bool allowGuestControl = false;
  final List<String> participants = [];

  void startJam() {
    isHosting = true;
    isGuest = false;
    final rng = Random();
    final num = 1000 + rng.nextInt(9000);
    roomCode = 'JAM-$num';
    participants.clear();
    participants.add('Tú (Anfitrión)');
  }

  void joinJam(String code) {
    isHosting = false;
    isGuest = true;
    roomCode = code.toUpperCase().trim();
  }

  void leaveJam() {
    isHosting = false;
    isGuest = false;
    roomCode = null;
    participants.clear();
  }
}

class GroovyJamSheet extends StatefulWidget {
  const GroovyJamSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GroovyJamSheet(),
    );
  }

  @override
  State<GroovyJamSheet> createState() => _GroovyJamSheetState();
}

class _GroovyJamSheetState extends State<GroovyJamSheet> {
  final _jam = GroovyJamSession();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _shareJamCode() {
    if (_jam.roomCode == null) return;
    SharePlus.instance.share(
      ShareParams(
        text: '🎉 ¡Únete a mi sesión Groovy Jam para escuchar música juntos y añadir canciones a la cola!\n'
            'Código de sala: ${_jam.roomCode}\n'
            'Enlace: https://groovyapi.duckdns.org/jam/${_jam.roomCode}',
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

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
              const SizedBox(height: 18),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA2D48), Color(0xFFAF52DE)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.person_3_fill, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Groovy Jam',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Sesión compartida en tiempo real',
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ACTIVE JAM VIEW
              if (_jam.isHosting || _jam.isGuest) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26262A) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.appleMusicRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'SESIÓN ACTIVA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(CupertinoIcons.share, size: 20, color: AppTheme.appleMusicRed),
                            onPressed: _shareJamCode,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _jam.roomCode ?? '',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: AppTheme.appleMusicRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comparte este código para que otros agreguen canciones a la cola',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: subtitleColor),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Now playing preview
                if (player.currentSong != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1F23) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AlbumArtwork(
                            coverArt: player.currentSong!.coverArt,
                            size: 44,
                            borderRadius: 8,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                player.currentSong!.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                player.currentSong!.artist ?? 'Groovy',
                                style: TextStyle(color: subtitleColor, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Leave / End Jam button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(CupertinoIcons.xmark_circle),
                    label: Text(_jam.isHosting ? 'Finalizar sesión Jam' : 'Salir del Jam'),
                    onPressed: () {
                      setState(() {
                        _jam.leaveJam();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Has salido del Jam'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                ),
              ] else ...[
                // INACTIVE JAM: HOST OR JOIN
                Text(
                  'Escucha música en sincronía con tus amigos y construye una cola colaborativa en tiempo real.',
                  style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Start Jam Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.appleMusicRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(CupertinoIcons.play_arrow_solid, color: Colors.white),
                    label: const Text(
                      'Iniciar una sesión Jam',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: () {
                      setState(() {
                        _jam.startJam();
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),
                const Center(child: Text('O ÚNETE A UNA SALA EXISTENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(height: 16),

                // Join with code input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Ej. JAM-4921',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5856D6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      onPressed: () {
                        final code = _codeController.text.trim();
                        if (code.isNotEmpty) {
                          setState(() {
                            _jam.joinJam(code);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Conectado a $code')),
                          );
                        }
                      },
                      child: const Text('Unirse', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
