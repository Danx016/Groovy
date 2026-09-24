import 'dart:async';
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
  int _currentIndex = -1;
  int _currentLyricIndex = -1;
  bool _isManualScrolling = false;
  bool _isUnsynced = false;
  Timer? _resumeAutoScrollTimer;
  StreamSubscription<Duration>? _posSub;
  Duration _currentPosition = Duration.zero;

  // Estimated item height for scroll offset calculation (avoids GlobalKey).
  // Lyric lines: ~32px font * 1.25 height + 26px vertical padding = ~66px
  // Interlude dots: ~11px dot + 24px vertical padding = ~35px
  static const double _estimatedLyricHeight = 66.0;
  static const double _estimatedInterludeHeight = 55.0;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentLine();
      });
    }
  }

  double _lastViewportWidth = 0;

  /// Estimate the scroll offset for a given item index using pre-computed heights,
  /// dynamically adjusting for multi-line wrapped lyrics based on available viewport width.
  double _estimateOffsetForIndex(int index, double maxWidth) {
    // 28.0 horizontal padding on left and right = 56.0
    final availableWidth = (maxWidth - 56.0).clamp(180.0, 3000.0);
    // Average 32px bold character takes ~17.5px width in typography
    final charsPerLine = (availableWidth / 17.5).floor().clamp(14, 120);

    double offset = 0;
    for (int i = 0; i < index && i < _items.length; i++) {
      final item = _items[i];
      if (item.type == ItemType.interlude) {
        offset += _estimatedInterludeHeight;
      } else {
        final textLen = item.line?.text.length ?? 0;
        final linesCount = (textLen / charsPerLine).ceil().clamp(1, 4);
        // Base line height is 66px (40px font line-height + 26px vertical padding).
        // Each wrapped line adds 40px (font size 32 * line height 1.25).
        offset += _estimatedLyricHeight + (linesCount - 1) * 40.0;
      }
    }
    return offset;
  }

  void _scrollToCurrentLine({Duration? duration, bool animate = true}) {
    if (!mounted || !widget.isActive || _isManualScrolling || !_scrollController.hasClients || _currentIndex < 0 || _currentIndex >= _items.length) return;

    try {
      final size = MediaQuery.of(context).size;
      final isLandscape = size.width > size.height;
      // Align active line at ~34% on desktop/landscape, ~28% on portrait
      final focalFraction = isLandscape ? 0.34 : 0.28;
      final viewportHeight = _scrollController.position.viewportDimension;
      final topPadding = isLandscape ? (viewportHeight * 0.20) : 32.0;

      // Calculate target offset using estimated item heights and account for topPadding
      final width = _lastViewportWidth > 0 ? _lastViewportWidth : size.width;
      final itemOffset = _estimateOffsetForIndex(_currentIndex, width);
      final targetOffset = topPadding + itemOffset - (viewportHeight * focalFraction);

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

        // Adaptive duration & smooth Apple-style ease-in-out curve:
        // Stanza transitions glide gracefully without abrupt jerky snaps
        final effectiveDuration = duration ?? (scrollDelta > 140
            ? const Duration(milliseconds: 520)
            : const Duration(milliseconds: 380));

        _scrollController.animateTo(
          clamped,
          duration: effectiveDuration,
          curve: Curves.easeInOutCubic,
        );
      }
    } catch (_) {}
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

        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final topPadding = isLandscape ? (constraints.maxHeight * 0.20) : 32.0;
        final bottomPadding = isLandscape ? (constraints.maxHeight * 0.55) : (constraints.maxHeight * 0.50);

        return RepaintBoundary(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is UserScrollNotification) {
                _onUserScroll();
              }
              return false;
            },
            // ListView.builder: only builds visible items + a small buffer.
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: bottomPadding,
              ),
              itemCount: _items.length,
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

            // Clamping distance to 0, 1, or 2 stops rebuilds and animation tweens on the other 90+ lines
            final distance = _currentLyricIndex != -1 
                ? (lyricIndex - _currentLyricIndex).abs().clamp(0, 2) 
                : 2;

            return LyricsLineWidget(
              key: ValueKey('lyric_$lyricIndex'),
              line: line,
              state: state,
              distance: distance,
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
                _scrollToCurrentLine();
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

