import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/lyric_line.dart';
import 'lyrics_line.dart';
import 'interlude_dots_widget.dart';

enum ItemType { lyric, interlude }

class LyricsItem {
  final ItemType type;
  final LyricLine? line;
  final Duration startTime;
  final Duration endTime;
  final int? lyricIndex;

  LyricsItem({
    required this.type,
    this.line,
    required this.startTime,
    required this.endTime,
    this.lyricIndex,
  });
}

class LyricsListView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final Stream<Duration>? positionStream;
  final Duration? initialPosition;
  final Duration? currentTime;
  final Function(Duration) onSeek;
  final bool isActive;

  const LyricsListView({
    super.key,
    required this.lyrics,
    this.positionStream,
    this.initialPosition,
    this.currentTime,
    required this.onSeek,
    this.isActive = true,
  });

  @override
  State<LyricsListView> createState() => _LyricsListViewState();
}

class _LyricsListViewState extends State<LyricsListView> {
  late ScrollController _scrollController;
  late List<LyricsItem> _items;
  final Map<int, int> _lyricIndexToItemIndex = {};
  int _currentIndex = -1;
  int _currentLyricIndex = -1;
  bool _isManualScrolling = false;
  bool _isUnsynced = false;
  Timer? _resumeAutoScrollTimer;
  StreamSubscription<Duration>? _posSub;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentPosition = widget.initialPosition ?? widget.currentTime ?? Duration.zero;
    _buildItems();
    _updateIndexForPosition(_currentPosition, force: true);
    _subscribeToPosition();

    // Initial scroll to the current line after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLine(animate: false);
    });
  }

  void _subscribeToPosition() {
    _posSub?.cancel();
    if (widget.positionStream != null) {
      _posSub = widget.positionStream!.listen((pos) {
        _currentPosition = pos;
        _updateIndexForPosition(pos);
      });
    }
  }

  @override
  void didUpdateWidget(LyricsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.lyrics != widget.lyrics) {
      _buildItems();
      _updateIndexForPosition(_currentPosition, force: true);
    }
    
    if (oldWidget.positionStream != widget.positionStream) {
      _subscribeToPosition();
    }

    if (widget.currentTime != null && widget.currentTime != oldWidget.currentTime) {
      _currentPosition = widget.currentTime!;
      _updateIndexForPosition(_currentPosition);
    }

    if (widget.isActive && !oldWidget.isActive) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentLine();
      });
    }
  }

  void _buildItems() {
    _items = [];
    _lyricIndexToItemIndex.clear();
    if (widget.lyrics.isEmpty) {
      _isUnsynced = false;
      return;
    }

    // Principal Intro: only if vocals start after 5 seconds
    if (widget.lyrics[0].startTime >= const Duration(seconds: 5)) {
      _items.add(LyricsItem(
        type: ItemType.interlude,
        startTime: Duration.zero,
        endTime: widget.lyrics[0].startTime,
      ));
    }

    for (int i = 0; i < widget.lyrics.length; i++) {
      final line = widget.lyrics[i];
      final nextTime = i < widget.lyrics.length - 1 
          ? widget.lyrics[i + 1].startTime 
          : const Duration(hours: 24);

      // Only insert an interlude item if there is a true major instrumental break (>= 28.0 seconds).
      // Standard pauses of 5 seconds between lines do NOT show dots so lyrics remain clean and fluid.
      final bool hasMajorInstrumentalSolo = i < widget.lyrics.length - 1 && (nextTime - line.startTime) >= const Duration(seconds: 28);
      final estimatedLineEnd = line.endTime ?? (hasMajorInstrumentalSolo ? (line.startTime + const Duration(milliseconds: 4000)) : nextTime);

      _items.add(LyricsItem(
        type: ItemType.lyric,
        line: line,
        startTime: line.startTime,
        endTime: hasMajorInstrumentalSolo ? estimatedLineEnd : nextTime,
        lyricIndex: i,
      ));
      _lyricIndexToItemIndex[i] = _items.length - 1;

      // Major instrumental solo dots for genuine long musical breaks
      if (hasMajorInstrumentalSolo) {
        _items.add(LyricsItem(
          type: ItemType.interlude,
          startTime: estimatedLineEnd,
          endTime: nextTime,
        ));
      }
    }

    _isUnsynced = _items.length > 1 &&
        _items.every((item) => item.startTime == Duration.zero);
  }

  void _updateIndexForPosition(Duration pos, {bool force = false}) {
    if (!mounted) return; // guard: stream may fire after dispose
    if (_items.isEmpty) return;

    if (_isUnsynced) {
      if (_currentIndex != -1) {
        if (widget.isActive) {
          setState(() {
            _currentIndex = -1;
            _currentLyricIndex = -1;
          });
        } else {
          _currentIndex = -1;
          _currentLyricIndex = -1;
        }
      }
      return;
    }

    // Compensate for hardware/audio pipeline latency (~70ms) so lyrics highlight in real-time
    final effectivePos = pos + const Duration(milliseconds: 70);

    int low = 0;
    int high = _items.length - 1;
    int newIndex = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_items[mid].startTime <= effectivePos) {
        newIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // ONLY rebuild when the active line actually changes!
    if (newIndex != _currentIndex || force) {
      if (!widget.isActive) {
        // When screen is inactive, update state silently without rebuilds/animations
        _currentIndex = newIndex;
        if (newIndex >= 0 && newIndex < _items.length) {
          _currentLyricIndex = _items[newIndex].lyricIndex ?? -1;
        } else {
          _currentLyricIndex = -1;
        }
        return;
      }

      setState(() {
        _currentIndex = newIndex;
        if (newIndex >= 0 && newIndex < _items.length) {
          _currentLyricIndex = _items[newIndex].lyricIndex ?? -1;
        } else {
          _currentLyricIndex = -1;
        }
      });
      // Start scroll animation immediately in lockstep with the text highlight animation
      // on the exact same VSync tick, eliminating the 1-2 frame freeze/stutter
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions &&
          _scrollController.position.hasPixels) {
        _scrollToCurrentLine();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToCurrentLine();
          }
        });
      }
    }
  }

  static final List<String> _fontFallback = !kIsWeb && Platform.isAndroid
      ? const ['Roboto', 'sans-serif']
      : const [
          '-apple-system',
          'BlinkMacSystemFont',
          'SF Pro Display',
          'SF Pro Text',
          'Inter',
          'Segoe UI',
          'Roboto',
          'sans-serif',
        ];

  static final TextStyle _measureTextStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
    fontFamilyFallback: _fontFallback,
  );

  double _lastViewportWidth = 0;
  double _lastViewportHeight = 0;
  List<double> _itemOffsets = [];
  List<double> _itemHeights = [];
  double _computedForWidth = 0;

  /// Accurately compute prefix-sum offsets and item heights using Flutter's TextPainter engine.
  /// Reuses a single TextPainter instance and static TextStyle to eliminate GC pauses and memory spikes.
  void _recomputeItemHeights(double maxWidth) {
    if ((maxWidth - _computedForWidth).abs() < 2.0 &&
        _itemOffsets.length == _items.length &&
        _itemHeights.length == _items.length) {
      return;
    }

    _computedForWidth = maxWidth;
    _itemOffsets = List.filled(_items.length, 0.0);
    _itemHeights = List.filled(_items.length, 0.0);

    // 28.0 horizontal padding on left + 28.0 on right = 56.0
    final availableTextWidth = (maxWidth - 56.0).clamp(80.0, 3000.0);
    double accumulated = 0.0;

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 8,
    );

    for (int i = 0; i < _items.length; i++) {
      _itemOffsets[i] = accumulated;
      final item = _items[i];
      double h = 66.0;

      if (item.type == ItemType.interlude) {
        h = 51.0;
      } else if (item.line != null) {
        final text = item.line!.text;
        if (text.isEmpty) {
          h = 40.0;
        } else {
          tp.text = TextSpan(
            text: text,
            style: _measureTextStyle,
          );
          tp.layout(maxWidth: availableTextWidth);
          // 26.0 is vertical padding (13.0 top + 13.0 bottom)
          h = tp.height + 26.0;
        }
      }
      _itemHeights[i] = h;
      accumulated += h;
    }
    tp.dispose();
  }

  void _scrollToCurrentLine({Duration? duration, bool animate = true}) {
    if (!mounted ||
        !widget.isActive ||
        _isManualScrolling ||
        !_scrollController.hasClients ||
        _currentIndex < 0 ||
        _currentIndex >= _items.length) {
      return;
    }

    // Guard against unattached or unlaid-out scroll position to prevent assertion errors
    if (!_scrollController.position.hasContentDimensions ||
        !_scrollController.position.hasPixels) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToCurrentLine(duration: duration, animate: animate);
        }
      });
      return;
    }

    try {
      if (_itemOffsets.isEmpty && _lastViewportWidth > 0) {
        _recomputeItemHeights(_lastViewportWidth);
      }

      final itemOffset = (_currentIndex < _itemOffsets.length)
          ? _itemOffsets[_currentIndex]
          : 0.0;

      final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      // On mobile, initial lines start at the top; once past the threshold, center in viewport.
      // On Windows / Desktop, keep original centered placement.
      final double targetOffset;
      if (isMobile) {
        final focalPoint = _lastViewportHeight > 0 ? _lastViewportHeight * 0.38 : 220.0;
        const topPadding = 24.0;
        targetOffset = (itemOffset - (focalPoint - topPadding)).clamp(0.0, double.infinity);
      } else {
        targetOffset = itemOffset;
      }

      final clamped = targetOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      final scrollDelta = (_scrollController.offset - clamped).abs();

      if (scrollDelta > 1.0) {
        if (!animate) {
          _scrollController.jumpTo(clamped);
          return;
        }

        // Fluid Apple ProMotion quintic curve:
        // Glides seamlessly across stanzas at 120 FPS with zero initial jerk or hitch
        final effectiveDuration = duration ??
            (scrollDelta > 140
                ? const Duration(milliseconds: 420)
                : const Duration(milliseconds: 320));

        _scrollController.animateTo(
          clamped,
          duration: effectiveDuration,
          curve: const Cubic(0.22, 1.0, 0.36, 1.0),
        );
      }
    } catch (e) {
      debugPrint('[LyricsListView] _scrollToCurrentLine error: $e');
    }
  }

  void _onUserScroll() {
    _isManualScrolling = true;
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _isManualScrolling = false;
        _scrollToCurrentLine();
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _scrollController.dispose();
    _resumeAutoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noLyricsAvailable,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final isUnsynced = _isUnsynced;

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastViewportWidth = constraints.maxWidth;
        _lastViewportHeight = constraints.maxHeight;
        _recomputeItemHeights(constraints.maxWidth);

        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

        final double topPadding;
        final double bottomPadding;

        if (isMobile) {
          // On mobile: start cleanly from top (24px padding) with room at bottom for scrolling
          topPadding = 24.0;
          bottomPadding = constraints.maxHeight * 0.65;
        } else {
          // Centered lyrics on Windows / Desktop as requested
          final focalFraction = isLandscape ? 0.46 : 0.40;
          topPadding = constraints.maxHeight * focalFraction;
          bottomPadding = constraints.maxHeight * 0.55;
        }

        return RepaintBoundary(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is UserScrollNotification) {
                _onUserScroll();
              }
              return false;
            },
            // ListView.builder: cacheExtent pre-renders 1400px so subsequent stanzas/paragraphs
            // are already laid out and cached in GPU memory before scrolling to them,
            // preventing layout spikes and dropped frames at 120Hz.
            child: ListView.builder(
              controller: _scrollController,
              cacheExtent: 1400.0,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: bottomPadding,
              ),
              itemCount: _items.length,
              findChildIndexCallback: (Key key) {
                if (key is ValueKey<String>) {
                  final v = key.value;
                  if (v.startsWith('interlude_')) {
                    return int.tryParse(v.substring(10));
                  } else if (v.startsWith('lyric_')) {
                    final lIdx = int.tryParse(v.substring(6));
                    if (lIdx == null) return null;
                    return _lyricIndexToItemIndex[lIdx];
                  }
                }
                return null;
              },
              itemBuilder: (context, index) {
            final item = _items[index];
            
            if (item.type == ItemType.interlude) {
              final isCurrentInterlude = _currentIndex == index && widget.isActive;
              return Padding(
                key: ValueKey('interlude_$index'),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: InterludeDotsWidget(
                  isAnimating: isCurrentInterlude,
                ),
              );
            }

            final line = item.line!;
            final lyricIndex = item.lyricIndex!;
            
            LyricLineState state = LyricLineState.future;
            if (_currentLyricIndex != -1) {
              if (lyricIndex < _currentLyricIndex) {
                state = LyricLineState.past;
              } else if (lyricIndex == _currentLyricIndex) {
                state = LyricLineState.current;
              }
            } else {
              if (item.endTime <= _currentPosition) {
                state = LyricLineState.past;
              }
            }

            return LyricsLineWidget(
              key: ValueKey('lyric_$lyricIndex'),
              line: line,
              state: state,
              isUnsynced: isUnsynced,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSeek(line.startTime);
                
                setState(() {
                  _isManualScrolling = false;
                  _currentIndex = index;
                  _currentLyricIndex = lyricIndex;
                });
                _resumeAutoScrollTimer?.cancel();
                if (_scrollController.hasClients &&
                    _scrollController.position.hasContentDimensions &&
                    _scrollController.position.hasPixels) {
                  _scrollToCurrentLine();
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _scrollToCurrentLine();
                    }
                  });
                }
              },
            );
          },
        ),
      ),
    );
      },
    );
  }
}

