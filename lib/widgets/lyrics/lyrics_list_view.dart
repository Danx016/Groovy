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
  final Duration currentTime;
  final Function(Duration) onSeek;

  const LyricsListView({
    super.key,
    required this.lyrics,
    required this.currentTime,
    required this.onSeek,
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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _buildItems();
    _updateCurrentIndex();
  }

  @override
  void didUpdateWidget(LyricsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.lyrics != widget.lyrics) {
      _buildItems();
    }
    
    if (oldWidget.currentTime != widget.currentTime) {
      _updateCurrentIndex();
    }
  }

  void _buildItems() {
    _items = [];
    if (widget.lyrics.isEmpty) {
      _keys = [];
      return;
    }

    // Optional intro interlude if music starts after 6 seconds
    if (widget.lyrics[0].startTime > const Duration(seconds: 6)) {
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

      // Line remains active from its startTime until the next line starts
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

  void _updateCurrentIndex() {
    if (_items.isEmpty) return;

    // Check if unsynced (all lines have startTime == 0)
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

    // Find the current active line: the last item whose startTime <= currentTime
    int newIndex = -1;
    for (int i = 0; i < _items.length; i++) {
      if (widget.currentTime >= _items[i].startTime) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
        if (newIndex >= 0 && newIndex < _items.length) {
          _currentLyricIndex = _items[newIndex].lyricIndex ?? -1;
        } else {
          _currentLyricIndex = -1;
        }
      });
      _scrollToCurrentLine();
    }
  }

  void _scrollToCurrentLine() {
    if (_isManualScrolling || !_scrollController.hasClients || _currentIndex < 0 || _currentIndex >= _keys.length) return;

    final key = _keys[_currentIndex];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
      );
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

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.07, 0.85, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
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
            bottom: MediaQuery.of(context).size.height * 0.38,
            left: 0,
            right: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              
              if (item.type == ItemType.interlude) {
                return Container(
                  key: _keys[index],
                  padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 14.0),
                  child: InterludeDotsWidget(
                    currentTime: widget.currentTime,
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
                if (item.endTime <= widget.currentTime) {
                  state = LyricLineState.past;
                }
              }

              final distance = _currentLyricIndex != -1 
                  ? (lyricIndex - _currentLyricIndex).abs() 
                  : 3;

              return Container(
                key: _keys[index],
                child: RepaintBoundary(
                  child: LyricsLineWidget(
                    line: line,
                    state: state,
                    currentTime: widget.currentTime,
                    distance: distance,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSeek(line.startTime);
                      
                      setState(() => _isManualScrolling = false);
                      _resumeAutoScrollTimer?.cancel();
                    },
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

