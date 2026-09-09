import 'dart:async';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  late List<GlobalKey> _keys;
  late List<LyricsItem> _items;
  int _currentIndex = -1;
  int _currentLyricIndex = -1;
  bool _isManualScrolling = false;
  Timer? _resumeAutoScrollTimer;
  StreamSubscription<Duration>? _posSub;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentPosition = widget.initialPosition ?? widget.currentTime ?? Duration.zero;
    _buildItems();
    _updateIndexForPosition(_currentPosition);
    _subscribeToPosition();
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
      _updateIndexForPosition(_currentPosition);
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
        _scrollToCurrentLine(duration: const Duration(milliseconds: 300));
      });
    }
  }

  void _buildItems() {
    _items = [];
    if (widget.lyrics.isEmpty) {
      _keys = [];
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

    _keys = List.generate(_items.length, (_) => GlobalKey());
  }

  void _updateIndexForPosition(Duration pos) {
    if (_items.isEmpty) return;

    final isUnsynced = _items.length > 1 && 
        _items.every((item) => item.startTime == Duration.zero);

    if (isUnsynced) {
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

    int low = 0;
    int high = _items.length - 1;
    int newIndex = -1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_items[mid].startTime <= pos) {
        newIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // ONLY rebuild when the active line actually changes!
    if (newIndex != _currentIndex) {
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

  void _scrollToCurrentLine({Duration duration = const Duration(milliseconds: 360)}) {
    if (!mounted || !widget.isActive || _isManualScrolling || !_scrollController.hasClients || _currentIndex < 0 || _currentIndex >= _keys.length) return;

    try {
      final key = _keys[_currentIndex];
      final keyContext = key.currentContext;
      if (keyContext != null) {
        final renderObject = keyContext.findRenderObject();
        if (renderObject is RenderBox && _scrollController.hasClients && renderObject.attached) {
          final viewport = RenderAbstractViewport.maybeOf(renderObject);
          if (viewport == null) return;
          final size = MediaQuery.of(context).size;
          final isLandscape = size.width > size.height;
          // Align active line at ~34% on desktop/landscape (vertically level with album art), ~28% on portrait
          final focalAlignment = isLandscape ? 0.34 : 0.28;
          final targetOffset = viewport.getOffsetToReveal(renderObject, focalAlignment).offset;
          final clamped = targetOffset.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          if ((_scrollController.offset - clamped).abs() > 2.0) {
            _scrollController.animateTo(
              clamped,
              duration: duration,
              curve: Curves.easeOutCubic,
            );
          }
        }
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

    final isUnsynced = _items.length > 1 && 
        _items.every((item) => item.startTime == Duration.zero);

    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    final topPadding = isLandscape ? (size.height * 0.20) : 32.0;
    final bottomPadding = isLandscape ? (size.height * 0.55) : (size.height * 0.50);

    return RepaintBoundary(
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is UserScrollNotification) {
            _onUserScroll();
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              
              if (item.type == ItemType.interlude) {
                return Container(
                  key: _keys[index],
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: const InterludeDotsWidget(),
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

              return Container(
                key: _keys[index],
                child: LyricsLineWidget(
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
                    _scrollToCurrentLine(duration: const Duration(milliseconds: 450));
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
