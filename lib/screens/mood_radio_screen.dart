import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/player_provider.dart';
import '../services/recommendation_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

class MoodVibe {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final List<Color> gradient;
  final List<String> searchKeywords;

  const MoodVibe({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.gradient,
    required this.searchKeywords,
  });
}

class MoodRadioScreen extends StatefulWidget {
  const MoodRadioScreen({super.key});

  @override
  State<MoodRadioScreen> createState() => _MoodRadioScreenState();
}

class _MoodRadioScreenState extends State<MoodRadioScreen> {
  final _customPromptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatingVibeTitle;

  static const List<MoodVibe> predefinedVibes = [
    MoodVibe(
      id: 'gym',
      title: 'Gym & Potencia',
      description: 'Phonk, Bass Boosted, Hard Trap y energía para entrenar',
      emoji: '🏋️‍♂️',
      gradient: [Color(0xFFFF2D55), Color(0xFFFF5E3A)],
      searchKeywords: ['gym workout phonk trap hype motivation', 'hard workout mix phonk beats'],
    ),
    MoodVibe(
      id: 'rainy',
      title: 'Noche de Lluvia',
      description: 'Lo-Fi Chill, Bedroom Pop y melodías tranquilas para relajarse',
      emoji: '🌧️',
      gradient: [Color(0xFF2C3E50), Color(0xFF3498DB)],
      searchKeywords: ['lofi hip hop chill beats rain night', 'bedroom pop chill acoustic relaxing'],
    ),
    MoodVibe(
      id: 'focus',
      title: 'Enfoque & Estudio',
      description: 'Ambient, Synthwave instrumental y concentración máxima',
      emoji: '📚',
      gradient: [Color(0xFF5856D6), Color(0xFFAF52DE)],
      searchKeywords: ['study ambient music focus deep work', 'synthwave chill instrumental beats'],
    ),
    MoodVibe(
      id: 'roadtrip',
      title: 'Carretera al Atardecer',
      description: 'Indie Rock, Clásicos 80s y canciones para cantar al volante',
      emoji: '🚗',
      gradient: [Color(0xFFFF9500), Color(0xFFFF2D55)],
      searchKeywords: ['road trip classic rock 80s hits sunset', 'feel good indie roadtrip playlist'],
    ),
    MoodVibe(
      id: 'party',
      title: 'Fiesta & Descontrol',
      description: 'Reggaeton 2010s, Hits latinos de discoteca y perreo',
      emoji: '🎉',
      gradient: [Color(0xFFFA2D48), Color(0xFFFFCC00)],
      searchKeywords: ['reggaeton viejito clasicos perreo fiesta', 'latin dance party club hits'],
    ),
    MoodVibe(
      id: 'despecho',
      title: 'Despecho & Sentimiento',
      description: 'Baladas, canciones desgarradoras y nostalgia',
      emoji: '💔',
      gradient: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
      searchKeywords: ['baladas románticas despecho regional canciones tristes', 'pop latino desamor nostalgia'],
    ),
    MoodVibe(
      id: 'coffee',
      title: 'Café de Domingo',
      description: 'Bossa Nova suave, Acústico íntimo y vibras de cafetería',
      emoji: '☕',
      gradient: [Color(0xFFB06AB3), Color(0xFF4568DC)],
      searchKeywords: ['coffee shop acoustic guitar bossa nova relaxing morning', 'sunday morning acoustic warm'],
    ),
    MoodVibe(
      id: 'gaming',
      title: 'Cyberpunk & Gaming',
      description: 'Electro Darkwave, Cyberpunk 2077 vibes y ritmo futurista',
      emoji: '👾',
      gradient: [Color(0xFF00F260), Color(0xFF0575E6)],
      searchKeywords: ['cyberpunk dark synthwave gaming music', 'midtempo bass dark electro'],
    ),
  ];

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  Future<void> _generateMix(String vibeTitle, List<String> keywords) async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _generatingVibeTitle = vibeTitle;
    });

    final player = Provider.of<PlayerProvider>(context, listen: false);
    final ytService = Provider.of<YoutubeService>(context, listen: false);
    final rec = Provider.of<RecommendationService>(context, listen: false);

    try {
      final aggregatedSongs = <Song>[];
      final seenIds = <String>{};

      // 1. Search based on the vibe keywords
      for (final kw in keywords) {
        final results = await ytService.search(kw);
        final found = [
          ...results.songs,
          if (results.youtubeVideos != null) ...results.youtubeVideos!,
        ];
        for (final song in found) {
          if (!seenIds.contains(song.id)) {
            seenIds.add(song.id);
            aggregatedSongs.add(song);
          }
        }
        if (aggregatedSongs.length >= 15) break;
      }

      // 2. Personalize with user top artists if matching vibe
      final topArtists = rec.getTopArtists(3);
      if (topArtists.isNotEmpty) {
        final artistQuery = '${topArtists.first} ${keywords.first.split(' ').first}';
        final artistHits = await ytService.search(artistQuery);
        final hits = [
          ...artistHits.songs,
          if (artistHits.youtubeVideos != null) ...artistHits.youtubeVideos!,
        ];
        for (final song in hits) {
          if (!seenIds.contains(song.id)) {
            seenIds.add(song.id);
            aggregatedSongs.insert(1, song); // place high in queue
          }
        }
      }

      if (aggregatedSongs.isNotEmpty) {
        // Play the generated mix
        await player.playSong(aggregatedSongs.first, playlist: aggregatedSongs, startIndex: 0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Radio "$vibeTitle" iniciada con ${aggregatedSongs.length} temas!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFFA2D48),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('No se encontraron canciones para este estado de ánimo.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar mix: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generatingVibeTitle = null;
        });
      }
    }
  }

  void _onCustomPromptSubmit() {
    final prompt = _customPromptController.text.trim();
    if (prompt.isEmpty) return;
    _generateMix(prompt, [prompt, '$prompt playlist mix']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0D0B12) : const Color(0xFFF7F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFA2D48), Color(0xFFAF52DE)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AI RADIO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Mood Mixes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              Text(
                '¿Cómo te quieres sentir hoy?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige un estado de ánimo o escribe tu propia situación para generar una estación infinita adaptada a tu vibra.',
                style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.35),
              ),
              const SizedBox(height: 20),

              // Custom prompt box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191722) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.sparkles, color: AppTheme.appleMusicRed, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _customPromptController,
                        onSubmitted: (_) => _onCustomPromptSubmit(),
                        decoration: InputDecoration(
                          hintText: 'Ej. "Cena romántica", "Gaming espacial"...',
                          hintStyle: TextStyle(color: subtitleColor, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.arrow_right_circle_fill, color: AppTheme.appleMusicRed, size: 28),
                      onPressed: _onCustomPromptSubmit,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              Text(
                'ESTACIONES DE ESTADO DE ÁNIMO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 14),

              // Grid of vibes
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: predefinedVibes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, idx) {
                  final vibe = predefinedVibes[idx];
                  return InkWell(
                    onTap: _isGenerating ? null : () => _generateMix(vibe.title, vibe.searchKeywords),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: vibe.gradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: vibe.gradient.first.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vibe.emoji, style: const TextStyle(fontSize: 28)),
                          const Spacer(),
                          Text(
                            vibe.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            vibe.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          // Loading overlay during generation
          if (_isGenerating)
            Container(
              color: Colors.black.withValues(alpha: 0.65),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.appleMusicRed),
                      const SizedBox(height: 18),
                      Text(
                        'Generando estación...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      if (_generatingVibeTitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _generatingVibeTitle!,
                          style: TextStyle(fontSize: 14, color: AppTheme.appleMusicRed, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
