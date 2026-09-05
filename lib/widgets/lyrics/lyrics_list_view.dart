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

    // Optional intro interlude if music starts after 4 seconds
    if (widget.lyrics[0].startTime > const Duration(seconds: 4)) {
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

      _items.add(LyricsItem(
        type: ItemType.lyric,
        line: line,
        startTime: line.startTime,
        endTime: nextTime,
        lyricIndex: i,
      ));
    }

    _keys = List.generate(_items.length, (_) => GlobalKey());
  }

  void _updateIndexForPosition(Duration pos) {
    if (_items.isEmpty) return;

    final isUnsynced = _items.length > 1 && 
        _items.every((item) => item.startTime == Duration.zero);

    if (isUnsynced) {
      if (_currentIndex != -1) {
        setState(() {
          _currentIndex = -1;
          _currentLyricIndex = -1;
        });
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
    // This saves 50 unnecessary rebuilds per second.
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
        if (newIndex >= 0 && newIndex < _items.length) {
          _currentLyricIndex = _items[newIndex].lyricIndex ?? -1;
        } else {
          _currentLyricIndex = -1;
        }
      });
      if (widget.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentLine();
        });
      }
    }
  }

  void _scrollToCurrentLine({Duration duration = const Duration(milliseconds: 400)}) {
    if (!widget.isActive || _isManualScrolling || !_scrollController.hasClients || _currentIndex < 0 || _currentIndex >= _keys.length) return;

    final key = _keys[_currentIndex];
    final keyContext = key.currentContext;
    if (keyContext != null) {
      final renderObject = keyContext.findRenderObject();
      if (renderObject is RenderBox && _scrollController.hasClients) {
        final viewport = RenderAbstractViewport.of(renderObject);
        final targetOffset = viewport.getOffsetToReveal(renderObject, 0.24).offset;
        final clamped = targetOffset.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          clamped,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _onUserScroll() {
    if (!_isManualScrolling) {
      setState(() {
        _isManualScrolling = true;
      });
    }

    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isManualScrolling = false;
        });
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
            top: 20,
            bottom: MediaQuery.of(context).size.height * 0.42,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              
              if (item.type == ItemType.interlude) {
                return Container(
                  key: _keys[index],
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: InterludeDotsWidget(
                    currentTime: _currentPosition,
                    targetTime: item.endTime,
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

              final distance = _currentLyricIndex != -1 
                  ? (lyricIndex - _currentLyricIndex).abs() 
                  : 3;

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
                    _scrollToCurrentLine(duration: const Duration(milliseconds: 400));
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
