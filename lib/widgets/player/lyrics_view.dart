import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/lyrics.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';

// ============================================================
// 常量
// ============================================================

const double _kBaseFontSize = 32.0;
const double _kLineHeight = 1.2;
const double _kLineSpacing = 38.4; // _kBaseFontSize * 1.2
const Duration _kScrollResumeTimeout = Duration(milliseconds: 2500);

// ============================================================
// 顶层容器
// ============================================================

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  bool _showTranslation = true;
  bool _useKaraoke = true;

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final isInRoom = room.currentRoom != null;

    if (!isInRoom) {
      return _buildJoinPrompt();
    }

    final currentTrack = ref.watch(playerProvider.select((s) => s.currentTrack));
    final hasTrack = currentTrack != null;

    ref.listen<String?>(
      playerProvider.select((s) => s.currentTrack?.id),
      (prevId, nextId) {
        if (nextId != null && nextId.isNotEmpty && nextId != prevId) {
          ref.read(lyricsProvider.notifier).fetchLyrics(nextId);
        }
      },
    );

    return Column(
      children: [
        _LyricsTopBar(
          roomName: room.currentRoom!.roomName,
          onlineCount: room.onlineUsers.length,
        ),
        const Divider(height: 1),
        Expanded(
          child: hasTrack
              ? _NowPlayingPage(
                  showTranslation: _showTranslation,
                  useKaraoke: _useKaraoke,
                  onToggleTranslation: () =>
                      setState(() => _showTranslation = !_showTranslation),
                  onToggleKaraoke: () =>
                      setState(() => _useKaraoke = !_useKaraoke),
                )
              : const _EmptyPlayer(),
        ),
      ],
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_rounded,
              size: 64, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('加入房间后开始播放',
              style:
                  TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showJoinDialog(context, ref),
            icon: const Icon(Icons.meeting_room_rounded, size: 18),
            label: const Text('加入房间'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref) {
    final roomIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入房间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '输入房间 ID'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: '或创建新房间（输入名称）'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final user = ref.read(authProvider).user;
              if (user == null) return;
              final id = int.tryParse(roomIdCtrl.text.trim());
              final name = nameCtrl.text.trim();
              if (id != null) {
                ref.read(roomProvider.notifier).joinRoom(id, user.userUuid);
              } else if (name.isNotEmpty) {
                ref.read(roomProvider.notifier).createRoom(name, user.userUuid);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 顶部信息栏
// ============================================================

class _LyricsTopBar extends StatelessWidget {
  final String roomName;
  final int onlineCount;
  const _LyricsTopBar({required this.roomName, required this.onlineCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.music_note_rounded,
              size: 18, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(roomName,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(width: 8),
          Container(width: 7, height: 7, decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Colors.greenAccent)),
          const SizedBox(width: 4),
          Text('在线 $onlineCount',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

// ============================================================
// 空播放器占位
// ============================================================

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_rounded,
              size: 80, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text('歌单为空',
              style: TextStyle(
                  fontSize: 16, color: Colors.white.withValues(alpha: 0.35))),
          const SizedBox(height: 6),
          Text('搜索歌曲添加到播放列表',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

// ============================================================
// Now Playing 主页面
// ============================================================

class _NowPlayingPage extends ConsumerStatefulWidget {
  final bool showTranslation;
  final bool useKaraoke;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleKaraoke;

  const _NowPlayingPage({
    required this.showTranslation,
    required this.useKaraoke,
    required this.onToggleTranslation,
    required this.onToggleKaraoke,
  });

  @override
  ConsumerState<_NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<_NowPlayingPage> {
  // ---- 手动滚动状态 ----
  bool _isManualScrolling = false;
  int _manualFocusIdx = 0;
  Timer? _manualScrollTimer;
  int _previousAutoLine = 0;

  // ---- 歌词容器尺寸 ----
  double _lyricsContainerHeight = 0;
  double _lyricsContainerWidth = 0;
  final GlobalKey _lyricsContainerKey = GlobalKey();

  // ---- 行高缓存 ----
  final Map<int, double> _lineHeights = {};

  @override
  void dispose() {
    _manualScrollTimer?.cancel();
    super.dispose();
  }

  void _enterManualScroll(int lineIdx) {
    _manualScrollTimer?.cancel();
    setState(() {
      _isManualScrolling = true;
      _manualFocusIdx = math.min(math.max(lineIdx, 0), 9999);
    });
    _manualScrollTimer = Timer(_kScrollResumeTimeout, () {
      if (mounted) setState(() => _isManualScrolling = false);
    });
  }

  void _onWheelScroll(double deltaY, int totalLines) {
    int target = _isManualScrolling ? _manualFocusIdx : _previousAutoLine;
    final limit = math.max(0, totalLines - 1);
    if (deltaY > 0) {
      target = math.min(target + 1, limit);
    } else if (deltaY < 0) {
      target = math.max(target - 1, 0);
    }
    _enterManualScroll(target);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider.select((s) => s));
    final position = player.position;
    final track = player.currentTrack;
    final isPlaying = player.status == PlayerStatus.playing;

    final lyricsAsync = ref.watch(lyricsProvider);
    final lyrics = lyricsAsync.valueOrNull;

    if (track == null) return const _EmptyPlayer();

    if (lyrics == null || lyrics.lines.isEmpty) {
      if (lyricsAsync.isLoading) {
        return const Center(
            child: SizedBox(
                width: 36, height: 36,
                child: CircularProgressIndicator(strokeWidth: 2)));
      }
      // 无歌词时仍然显示封面和歌曲信息
      return _buildNoLyrics(track);
    }

    final lines = lyrics.lines;
    final autoIdx = lyrics.findCurrentIndex(position);
    if (!_isManualScrolling) {
      _previousAutoLine = autoIdx;
    }
    final focusedIdx = _isManualScrolling ? _manualFocusIdx : autoIdx;

    final karaokeAvailable = lyrics.hasWordTiming;
    final translationAvailable = lyrics.hasTranslation;

    return Stack(
      children: [
        // ---- 背景层 ----
        _BackgroundLayer(coverUrl: track.coverUrl),

        // ---- 主内容区 ----
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: math.max(MediaQuery.of(context).size.width * 0.03, 20)),
              // ---- 左: 封面 + 歌曲信息 ----
              _CoverAndInfo(track: track),
              SizedBox(width: MediaQuery.of(context).size.width * 0.04),
              // ---- 右: 精美女歌词 (Expanded 占满剩余空间) ----
              Expanded(
                child: _LyricsPanel(
                  containerKey: _lyricsContainerKey,
                  lyrics: lyrics,
                  focusedIdx: focusedIdx,
                  position: position,
                  isPlaying: isPlaying,
                  isManualScrolling: _isManualScrolling,
                  showTranslation: widget.showTranslation,
                  useKaraoke: widget.useKaraoke,
                  hasKaraoke: lyrics.hasWordTiming,
                  hasTranslation: lyrics.hasTranslation,
                  containerHeight: _lyricsContainerHeight,
                  onContainerSize: (w, h) {
                    if (h != _lyricsContainerHeight ||
                        w != _lyricsContainerWidth) {
                      setState(() {
                        _lyricsContainerHeight = h;
                        _lyricsContainerWidth = w;
                      });
                    }
                  },
                  onTapLine: (line) {
                    ref.read(playerProvider.notifier).seek(line.time);
                  },
                  onWheel: (delta) =>
                      _onWheelScroll(delta, lines.length),
                  lineHeights: _lineHeights,
                ),
              ),
            ],
          ),
        ),
        // ---- 右下角切换按钮（有功能就始终显示） ----
        if (karaokeAvailable || translationAvailable)
          Positioned(
            right: 12,
            bottom: 12,
            child: _ToggleButtons(
              showTranslation: widget.showTranslation,
              useKaraoke: widget.useKaraoke,
              hasKaraoke: lyrics.hasWordTiming,
              hasTranslation: lyrics.hasTranslation,
              onToggleTranslation: widget.onToggleTranslation,
              onToggleKaraoke: widget.onToggleKaraoke,
            ),
          ),
      ],
    );
  }

  Widget _buildNoLyrics(Track track) {
    return Stack(
      children: [
        _BackgroundLayer(coverUrl: track.coverUrl),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track.coverUrl != null && track.coverUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _AlbumArt(coverUrl: track.coverUrl!, size: 220),
                ),
              _TrackInfo(track: track),
              const SizedBox(height: 24),
              Text('暂无歌词',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.35))),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 背景层 —— 模糊专辑封面 + 暗色遮罩
// ============================================================

class _BackgroundLayer extends StatelessWidget {
  final String? coverUrl;
  const _BackgroundLayer({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    if (coverUrl == null || coverUrl!.isEmpty) {
      return Container(color: const Color(0xFF0D0D0D));
    }
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 模糊的专辑封面
          Image.network(
            coverUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF0D0D0D)),
          ),
          // 模糊 + 暗色遮罩
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 左侧面板 —— 专辑封面 + 歌曲信息
// ============================================================

class _CoverAndInfo extends StatelessWidget {
  final Track track;
  const _CoverAndInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // 封面大小：屏幕高度的 28%~42%，clamp 在 180~380
    final coverSize =
        (screenHeight * 0.35).clamp(180.0, 380.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (track.coverUrl != null && track.coverUrl!.isNotEmpty)
          _AlbumArt(coverUrl: track.coverUrl!, size: coverSize),
        const SizedBox(height: 28),
        _TrackInfo(track: track),
      ],
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String coverUrl;
  final double size;
  const _AlbumArt({required this.coverUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 封面阴影层
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          // 封面图
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              coverUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    child,
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.8),
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF2A2A2A),
                ),
                child: Icon(Icons.music_note_rounded,
                    size: size * 0.4,
                    color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 歌曲信息
// ============================================================

class _TrackInfo extends StatelessWidget {
  final Track track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.of(context).size.width * 0.38;
    // 最大宽度限制：不能让标题在封面下方跑出范围
    final maxTitleWidth = (totalWidth - 40).clamp(160.0, 500.0);

    return SizedBox(
      width: maxTitleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 歌名
          _ScaledTitle(
            text: track.name,
            maxWidth: maxTitleWidth,
          ),
          const SizedBox(height: 14),
          // 歌手
          Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 17, color: Colors.white.withValues(alpha: 0.35)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          // 专辑
          if (track.album != null && track.album!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.album_rounded,
                    size: 17, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    track.album!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.35),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 动态缩放标题字号，确保不超出最大宽度
class _ScaledTitle extends StatefulWidget {
  final String text;
  final double maxWidth;
  const _ScaledTitle({required this.text, required this.maxWidth});

  @override
  State<_ScaledTitle> createState() => _ScaledTitleState();
}

class _ScaledTitleState extends State<_ScaledTitle> {
  double _fontSize = 45;

  @override
  void didUpdateWidget(_ScaledTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _fontSize = 45;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return Text(
        widget.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.15,
          letterSpacing: -0.5,
          shadows: [
            Shadow(
              blurRadius: 12,
              color: Colors.white.withValues(alpha: 0.15),
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    });
  }
}

// ============================================================
// 精美女歌词面板
// ============================================================

class _LyricsPanel extends StatefulWidget {
  final GlobalKey containerKey;
  final Lyrics lyrics;
  final int focusedIdx;
  final Duration position;
  final bool isPlaying;
  final bool isManualScrolling;
  final bool showTranslation;
  final bool useKaraoke;
  final bool hasKaraoke;
  final bool hasTranslation;
  final double containerHeight;
  final void Function(double w, double h) onContainerSize;
  final void Function(LyricLine line) onTapLine;
  final void Function(double deltaY) onWheel;
  final Map<int, double> lineHeights;

  const _LyricsPanel({
    required this.containerKey,
    required this.lyrics,
    required this.focusedIdx,
    required this.position,
    required this.isPlaying,
    required this.isManualScrolling,
    required this.showTranslation,
    required this.useKaraoke,
    required this.hasKaraoke,
    required this.hasTranslation,
    required this.containerHeight,
    required this.onContainerSize,
    required this.onTapLine,
    required this.onWheel,
    required this.lineHeights,
  });

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  final Map<int, double> _lineHeightsCache = {};
  double? _lastWidth;
  bool? _lastShowTranslation;
  Lyrics? _lastLyrics;

  @override
  Widget build(BuildContext context) {
    final lines = widget.lyrics.lines;
    final hasKaraoke = widget.hasKaraoke && widget.useKaraoke;

    return LayoutBuilder(builder: (ctx, constraints) {
      final cw = constraints.maxWidth;
      final ch = constraints.maxHeight;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onContainerSize(cw, ch);
      });

      final containerHeight = ch > 0 ? ch : widget.containerHeight;
      if (containerHeight <= 0) return const SizedBox.shrink();

      // 容器宽度、翻译开关或歌词数据变了 → 清除高度缓存
      final showTl = widget.showTranslation && widget.hasTranslation;
      if (_lastWidth != cw ||
          _lastShowTranslation != showTl ||
          _lastLyrics != widget.lyrics) {
        _lineHeightsCache.clear();
        _lastWidth = cw;
        _lastShowTranslation = showTl;
        _lastLyrics = widget.lyrics;
      }

      // 用 TextPainter 精确预计算每行高度
      final usableWidth = math.max(cw - 24.0, 100.0); // 减去 padding
      _precomputeHeights(lines, usableWidth, hasKaraoke, showTl);

      final maxIdx = math.max(0, lines.length - 1);
      final current = math.min(math.max(widget.focusedIdx, 0), maxIdx);

      final transforms = <_LineTransform>[];
      for (int i = 0; i < lines.length; i++) {
        transforms.add(_LineTransform());
      }

      final curHeight = _lineHeightsCache[current] ?? 40.0;
      transforms[current].top =
          containerHeight * 0.50 - curHeight / 2;
      transforms[current].scale = 1.0;
      transforms[current].opacity = 1.0;
      transforms[current].blur = 0.0;

      for (int i = current - 1; i >= 0; i--) {
        final offset = current - i;
        transforms[i].scale = _scaleByOffset(offset);
        transforms[i].opacity = _opacityByOffset(offset);
        transforms[i].blur = _blurByOffset(offset);
        final scaledH = (_lineHeightsCache[i] ?? 40.0) * transforms[i].scale;
        final sp = _kLineSpacing * transforms[i].scale;
        transforms[i].top = transforms[i + 1].top - scaledH - sp;
      }

      for (int i = current + 1; i < lines.length; i++) {
        final offset = i - current;
        transforms[i].scale = _scaleByOffset(offset);
        transforms[i].opacity = _opacityByOffset(offset);
        transforms[i].blur = _blurByOffset(offset);
        final prevScaledH =
            (_lineHeightsCache[i - 1] ?? 40.0) * transforms[i - 1].scale;
        final sp = _kLineSpacing * transforms[i - 1].scale;
        transforms[i].top = transforms[i - 1].top + prevScaledH + sp;
      }

      return ClipRect(
        child: ShaderMask(
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
              stops: [0.0, 0.03, 0.97, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              SizedBox(width: cw, height: containerHeight),
              for (int i = 0; i < lines.length; i++)
                if (widget.isManualScrolling &&
                    (i - widget.focusedIdx).abs() > 20)
                  const SizedBox.shrink()
                else
                  _LyricLineWidget(
                    line: lines[i],
                    lineIdx: i,
                    currentIdx: current,
                    position: widget.position,
                    isPlaying: widget.isPlaying,
                    showTranslation: widget.showTranslation,
                    useKaraoke: widget.useKaraoke,
                    hasKaraoke: widget.hasKaraoke,
                    lyrics: widget.lyrics,
                    transform: transforms[i],
                    onTap: () => widget.onTapLine(lines[i]),
                    onHeightMeasured: (_) {},
                  ),
            ],
          ),
        ),
      );
    });
  }

  void _precomputeHeights(
      List<LyricLine> lines, double maxWidth, bool karaoke, bool showTl) {
    for (int i = 0; i < lines.length; i++) {
      if (_lineHeightsCache.containsKey(i)) continue;
      final line = lines[i];
      double h = 0;

      if (line.text.isEmpty) {
        h = 32;
      } else {
        final hasWords = karaoke && line.words != null;
        final fontSize = _kBaseFontSize;
        final textStyle = TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: _kLineHeight,
        );
        if (hasWords) {
          // 逐字模式：用完整文本排版
          final displayText = line.words!.map((w) => w.text).join();
          h += _measureText(displayText, textStyle, maxWidth);
        } else {
          h += _measureText(line.text, textStyle, maxWidth);
        }

        if (showTl) {
          final tl = widget.lyrics.getTranslationForLine(line);
          if (tl != null && tl.isNotEmpty) {
            final tlStyle = TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.3,
            );
            h += 4 + _measureText(tl, tlStyle, maxWidth);
          }
        }
      }
      _lineHeightsCache[i] = h + 8; // padding
    }
  }

  double _measureText(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return tp.height;
  }

  static double _scaleByOffset(int offset) {
    final o = math.max(1 - offset.abs() * 0.2, 0.0);
    return o * o * o * 0.3 + 0.7;
  }

  static double _opacityByOffset(int offset) {
    final o = offset.abs();
    if (o <= 1) return 1.0;
    return math.max(1.0 - 0.4 * (o - 1), 0.0);
  }

  static double _blurByOffset(int offset) {
    final o = offset.abs();
    if (o == 0) return 0.0;
    return math.min(0.5 + 1.0 * o, 4.5);
  }
}

class _LineTransform {
  double top = 0;
  double scale = 1;
  double opacity = 1;
  double blur = 0;
}

// ============================================================
// 单行歌词 Widget
// ============================================================

class _LyricLineWidget extends StatefulWidget {
  final LyricLine line;
  final int lineIdx;
  final int currentIdx;
  final Duration position;
  final bool isPlaying;
  final bool showTranslation;
  final bool useKaraoke;
  final bool hasKaraoke;
  final Lyrics lyrics;
  final _LineTransform transform;
  final VoidCallback onTap;
  final void Function(double height) onHeightMeasured;

  const _LyricLineWidget({
    required this.line,
    required this.lineIdx,
    required this.currentIdx,
    required this.position,
    required this.isPlaying,
    required this.showTranslation,
    required this.useKaraoke,
    required this.hasKaraoke,
    required this.lyrics,
    required this.transform,
    required this.onTap,
    required this.onHeightMeasured,
  });

  @override
  State<_LyricLineWidget> createState() => _LyricLineWidgetState();
}

class _LyricLineWidgetState extends State<_LyricLineWidget> {
  bool _hovering = false;
  final GlobalKey _sizeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final ctx = _sizeKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    widget.onHeightMeasured(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.lineIdx == widget.currentIdx;
    final transform = widget.transform;
    final isInterlude = widget.line.text.isEmpty;
    final useKaraoke =
        widget.useKaraoke && widget.hasKaraoke && widget.line.words != null;

    final content = Opacity(
      opacity: transform.opacity,
      child: Transform.scale(
        scale: transform.scale,
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTap,
            child: Container(
              key: _sizeKey,
              decoration: BoxDecoration(
                color: _hovering
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isInterlude)
                    _InterludeDots(
                      isCurrent: isCurrent,
                      isPlaying: widget.isPlaying,
                      position: widget.position,
                      line: widget.line,
                    )
                  else if (useKaraoke)
                    _KaraokeWords(
                      words: widget.line.words!,
                      lineStart: widget.line.time,
                      lineIdx: widget.lineIdx,
                      currentIdx: widget.currentIdx,
                      position: widget.position,
                      isCurrent: isCurrent,
                    )
                  else
                    _buildPlainText(isCurrent),
                  if (widget.showTranslation &&
                      widget.lyrics.hasTranslation)
                    _buildTranslation(isCurrent),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (transform.blur > 0.01) {
      return Positioned(
        left: 0,
        right: 0,
        top: transform.top,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
              sigmaX: transform.blur, sigmaY: transform.blur),
          child: content,
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      top: transform.top,
      child: content,
    );
  }

  Widget _buildPlainText(bool isCurrent) {
    return Text(
      widget.line.text,
      style: TextStyle(
        fontSize: isCurrent ? _kBaseFontSize : 22,
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        color: Colors.white.withValues(
            alpha: isCurrent ? 1.0 : 0.4),
        height: _kLineHeight,
        shadows: isCurrent
            ? [
                Shadow(
                  blurRadius: 16,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                Shadow(
                  blurRadius: 32,
                  color: Colors.white.withValues(alpha: 0.1),
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildTranslation(bool isCurrent) {
    final translation = widget.lyrics.getTranslationForLine(widget.line);
    if (translation == null || translation.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        translation,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isCurrent ? 17 : 14,
          fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
          color: Colors.white.withValues(
              alpha: isCurrent ? 0.65 : 0.28),
          height: 1.3,
        ),
      ),
    );
  }
}

// ============================================================
// 逐字歌词（Karaoke）
// ============================================================

class _KaraokeWords extends StatelessWidget {
  final List<LyricWord> words;
  final Duration lineStart;
  final int lineIdx;
  final int currentIdx;
  final Duration position;
  final bool isCurrent;

  const _KaraokeWords({
    required this.words,
    required this.lineStart,
    required this.lineIdx,
    required this.currentIdx,
    required this.position,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: words.map((word) {
        return _KaraokeWord(
          word: word,
          lineStart: lineStart,
          isCurrentLine: isCurrent,
          position: position,
          trailingSpace: word.trailingSpace == true,
        );
      }).toList(),
    );
  }
}

class _KaraokeWord extends StatelessWidget {
  final LyricWord word;
  final Duration lineStart;
  final bool isCurrentLine;
  final Duration position;
  final bool trailingSpace;

  const _KaraokeWord({
    required this.word,
    required this.lineStart,
    required this.isCurrentLine,
    required this.position,
    this.trailingSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    final wordStart = lineStart + word.startTime;
    final wordEnd = wordStart + word.duration;

    double progress;
    if (!isCurrentLine) {
      progress = 1.0;
    } else if (word.duration == Duration.zero) {
      progress = position >= wordStart ? 1.0 : 0.0;
    } else if (position < wordStart) {
      progress = 0.0;
    } else if (position >= wordEnd) {
      progress = 1.0;
    } else {
      final elapsed = (position.inMicroseconds - wordStart.inMicroseconds) / 1000.0;
      final total = word.duration.inMicroseconds / 1000.0;
      progress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
    }

    // Float 动画：当前字的亮色部分上移 2px，非当前字下沉到原始位置
    final floatOffset = isCurrentLine ? -2.0 * progress : 0.0;

    // 与 _buildPlainText 保持样式一致
    final baseFontSize = isCurrentLine ? _kBaseFontSize : 22.0;
    final baseWeight = isCurrentLine ? FontWeight.w700 : FontWeight.w500;

    final dimStyle = TextStyle(
      fontSize: baseFontSize,
      fontWeight: baseWeight,
      color: Colors.white.withValues(alpha: 0.4),
      height: _kLineHeight,
    );
    final brightStyle = TextStyle(
      fontSize: baseFontSize,
      fontWeight: baseWeight,
      color: Colors.white,
      height: _kLineHeight,
      shadows: isCurrentLine
          ? [
              Shadow(
                blurRadius: 16,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              Shadow(
                blurRadius: 32,
                color: Colors.white.withValues(alpha: 0.1),
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );

    // 原 YRC 文本中词后有空格 → 渲染时补上间距
    final rightPad = trailingSpace == true ? 4.0 : 1.0;

    return Padding(
      padding: EdgeInsets.only(left: 1, right: rightPad),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Text(word.text, style: dimStyle),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, floatOffset),
                child: Text(word.text, style: brightStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 间奏动画点
// ============================================================

class _InterludeDots extends StatefulWidget {
  final bool isCurrent;
  final bool isPlaying;
  final Duration position;
  final LyricLine line;

  const _InterludeDots({
    required this.isCurrent,
    required this.isPlaying,
    required this.position,
    required this.line,
  });

  @override
  State<_InterludeDots> createState() => _InterludeDotsState();
}

class _InterludeDotsState extends State<_InterludeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_InterludeDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent) {
      if (widget.isPlaying && !_breathCtrl.isAnimating) {
        _breathCtrl.repeat(reverse: true);
      } else if (!widget.isPlaying && _breathCtrl.isAnimating) {
        _breathCtrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent) {
      return const SizedBox(height: 8);
    }

    final lineDur = widget.line.duration;
    const dotCount = 3;
    final perDotMs = lineDur > Duration.zero
        ? lineDur.inMilliseconds ~/ dotCount
        : 800;

    return AnimatedBuilder(
      animation: _breathCtrl,
      builder: (_, __) {
        final breathScale = 0.92 + _breathCtrl.value * 0.08;
        return SizedBox(
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(dotCount, (i) {
              final dotTime =
                  widget.line.time + Duration(milliseconds: perDotMs * i);
              double dotProgress = 0.0;
              if (widget.position >=
                  dotTime + Duration(milliseconds: perDotMs)) {
                dotProgress = 1.0;
              } else if (widget.position > dotTime) {
                final elapsed = (widget.position.inMilliseconds -
                        dotTime.inMilliseconds)
                    .toDouble();
                dotProgress = (elapsed / perDotMs).clamp(0.0, 1.0);
              }

              final dotOpacity =
                  widget.isCurrent ? 0.25 + dotProgress * 0.65 : 0.15;
              final dotScale =
                  breathScale * (0.7 + dotProgress * 0.3);

              return Container(
                width: 9 * dotScale,
                height: 9 * dotScale,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: dotOpacity),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ============================================================
// 切换按钮 (译 / 逐字)
// ============================================================

class _ToggleButtons extends StatelessWidget {
  final bool showTranslation;
  final bool useKaraoke;
  final bool hasKaraoke;
  final bool hasTranslation;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleKaraoke;

  const _ToggleButtons({
    required this.showTranslation,
    required this.useKaraoke,
    required this.hasKaraoke,
    required this.hasTranslation,
    required this.onToggleTranslation,
    required this.onToggleKaraoke,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasTranslation)
          _ToggleBtn(
            label: '译',
            active: showTranslation,
            onTap: onToggleTranslation,
          ),
        if (hasKaraoke)
          _ToggleBtn(
            label: '逐',
            active: useKaraoke,
            onTap: onToggleKaraoke,
          ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 30,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: Colors.white.withValues(
                alpha: active ? 0.9 : 0.25),
          ),
        ),
      ),
    );
  }
}
