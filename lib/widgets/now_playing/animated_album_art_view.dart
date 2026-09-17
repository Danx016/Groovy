import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../services/player_ui_settings_service.dart';

/// Widget de carátula animada de altísimo rendimiento inspirado en Apple Music.
/// 
/// Características:
/// - Reproducción en bucle del video oficial Apple Music Motion Artwork (.m3u8) acelerado por GPU.
/// - Transición fluida (crossfade) de 350ms entre canciones para eliminar tirones.
/// - Escala elástica sincronizada con Play/Pause (1.0 en Play, 0.88 en Pausa).
/// - Micro-respiración orgánica cinematográfica durante reproducción.
/// - Sombra y halo de resplandor ambiental acelerados por hardware sin recalcular desenfoques.
/// - Aislamiento total en GPU mediante [RepaintBoundary].
class AnimatedAlbumArtView extends StatefulWidget {
  final ImageProvider image;
  final String tag;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final double borderRadius;
  final Color? dominantColor;
  final String? motionVideoUrl;

  const AnimatedAlbumArtView({
    super.key,
    required this.image,
    required this.tag,
    this.isPlaying = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.borderRadius = 22.0,
    this.dominantColor,
    this.motionVideoUrl,
  });

  @override
  State<AnimatedAlbumArtView> createState() => _AnimatedAlbumArtViewState();
}

class _AnimatedAlbumArtViewState extends State<AnimatedAlbumArtView>
    with TickerProviderStateMixin {
  late final AnimationController _playPauseController;
  late final Animation<double> _playPauseAnimation;

  late final AnimationController _motionController;
  late final AnimationController _shimmerController;

  final PlayerUiSettingsService _settingsService = PlayerUiSettingsService();
  bool _animationsEnabled = true;
  bool _motionVideoEnabled = true;

  Player? _videoPlayer;
  VideoController? _videoController;
  bool _isVideoReady = false;

  @override
  void initState() {
    super.initState();

    _animationsEnabled = _settingsService.getAnimatedArtwork();
    _motionVideoEnabled = _settingsService.getMotionArtworkVideo();
    _settingsService.animatedArtworkNotifier.addListener(_onSettingsChanged);
    _settingsService.motionArtworkVideoNotifier.addListener(_onSettingsChanged);

    // Animación de escala elástica Apple Music al pausar/reproducir
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.isPlaying ? 1.0 : 0.0,
    );

    _playPauseAnimation = CurvedAnimation(
      parent: _playPauseController,
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
      reverseCurve: Curves.easeInOutCubic,
    );

    // Animación de respiración orgánica ultra-suave (ciclo de 8 segundos)
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );

    // Animación de barrido de luz ambiental (ciclo de 12 segundos)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    );

    _syncAnimations();

    if (_motionVideoEnabled && widget.motionVideoUrl != null && widget.motionVideoUrl!.isNotEmpty) {
      _initVideoPlayer(widget.motionVideoUrl!);
    }
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _animationsEnabled = _settingsService.animatedArtworkNotifier.value;
      _motionVideoEnabled = _settingsService.motionArtworkVideoNotifier.value;
      if (!_motionVideoEnabled) {
        _disposeVideoPlayer();
      } else if (widget.motionVideoUrl != null && widget.motionVideoUrl!.isNotEmpty && _videoPlayer == null) {
        _initVideoPlayer(widget.motionVideoUrl!);
      }
      _syncAnimations();
    });
  }

  void _initVideoPlayer(String url) async {
    _disposeVideoPlayer();
    try {
      final p = Player();
      final c = VideoController(p);
      _videoPlayer = p;
      _videoController = c;

      // Keep silent - the track's audio is played by the main audio player
      await p.setVolume(0);
      await p.setPlaylistMode(PlaylistMode.loop);
      await p.open(Media(url), play: widget.isPlaying);

      if (mounted && _videoPlayer == p) {
        setState(() {
          _isVideoReady = true;
        });
      }
    } catch (e) {
      debugPrint('[MotionArtwork] Video init note: $e');
    }
  }

  void _disposeVideoPlayer() {
    _videoPlayer?.dispose();
    _videoPlayer = null;
    _videoController = null;
    _isVideoReady = false;
  }

  void _syncAnimations() {
    if (widget.isPlaying) {
      _playPauseController.animateTo(1.0);
      _videoPlayer?.play();
      if (_animationsEnabled) {
        if (!_motionController.isAnimating) {
          _motionController.repeat(reverse: true);
        }
        if (!_shimmerController.isAnimating) {
          _shimmerController.repeat();
        }
      } else {
        _motionController.stop();
        _shimmerController.stop();
      }
    } else {
      _playPauseController.animateTo(0.0);
      _videoPlayer?.pause();
      _motionController.stop();
      _shimmerController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAlbumArtView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncAnimations();
    }
    if (oldWidget.motionVideoUrl != widget.motionVideoUrl) {
      if (_motionVideoEnabled && widget.motionVideoUrl != null && widget.motionVideoUrl!.isNotEmpty) {
        _initVideoPlayer(widget.motionVideoUrl!);
      } else {
        _disposeVideoPlayer();
      }
    }
  }

  @override
  void dispose() {
    _settingsService.animatedArtworkNotifier.removeListener(_onSettingsChanged);
    _settingsService.motionArtworkVideoNotifier.removeListener(_onSettingsChanged);
    _disposeVideoPlayer();
    _playPauseController.dispose();
    _motionController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playPauseAnimation = _playPauseAnimation;
    final motionAnimation = _motionController;
    final shimmerAnimation = _shimmerController;

    // Artwork con AnimatedSwitcher para disolver suavemente una carátula en otra
    final artworkSwitcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          fit: StackFit.passthrough,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: RepaintBoundary(
        key: ValueKey('${widget.tag}_${widget.image.hashCode}'),
        child: Image(
          image: widget.image,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.white.withValues(alpha: 0.12),
            child: const Center(
              child: Icon(
                Icons.music_note_rounded,
                color: Colors.white70,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );

    return Hero(
      tag: widget.tag,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          playPauseAnimation,
          motionAnimation,
          shimmerAnimation,
        ]),
        builder: (context, _) {
          final playValue = playPauseAnimation.value;
          final motionValue = _animationsEnabled ? motionAnimation.value : 0.0;
          final shimmerValue = _animationsEnabled ? shimmerAnimation.value : 0.0;

          // Escala base Apple Music (0.88 en pausa -> 1.0 en play)
          // Respiración cinemática sutil de 1.2%
          final breathingScale = 1.0 + (0.012 * math.sin(motionValue * math.pi));
          final finalScale = (0.88 + (0.12 * playValue)) * (playValue > 0.5 ? breathingScale : 1.0);

          return Center(
            child: Transform.scale(
              scale: finalScale,
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 1. Halo ambiental (Glow) con opacidad compositada en GPU
                  if (widget.dominantColor != null && _animationsEnabled)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: Opacity(
                          opacity: ((0.30 + 0.12 * math.sin(motionValue * math.pi)) * playValue).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(widget.borderRadius * 1.4),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.dominantColor!,
                                  blurRadius: 32.0,
                                  spreadRadius: 1.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. Contenedor principal del artwork con sombra profunda
                  RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32 * playValue),
                            blurRadius: 24.0,
                            spreadRadius: 0.0,
                            offset: const Offset(0, 10.0),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            // Imagen con transición fluida (siempre de base)
                            artworkSwitcher,

                            // Video oficial de Apple Music Motion Artwork (en bucle silencioso)
                            if (_motionVideoEnabled && _videoController != null && _isVideoReady)
                              Positioned.fill(
                                child: AnimatedOpacity(
                                  opacity: _isVideoReady ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 400),
                                  child: Video(
                                    controller: _videoController!,
                                    fit: BoxFit.cover,
                                    controls: NoVideoControls,
                                  ),
                                ),
                              ),

                            // 3. Sutil reflejo de luz ambiental Apple Music Sheen
                            if (_animationsEnabled && playValue > 0.1)
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: 0.16 * playValue,
                                      child: Transform.rotate(
                                        angle: -math.pi / 4,
                                        child: Transform.translate(
                                          offset: Offset(
                                            (shimmerValue * 600) - 300,
                                            0,
                                          ),
                                          child: Container(
                                            width: 140,
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white,
                                                  Colors.transparent,
                                                ],
                                                stops: [0.0, 0.5, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Borde fino de cristal estilo Apple
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(widget.borderRadius),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 0.75,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
