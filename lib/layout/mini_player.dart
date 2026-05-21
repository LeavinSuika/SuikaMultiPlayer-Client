import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/providers/sidebar_provider.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  void _playFirstInPlaylist() {
    final room = ref.read(roomProvider);
    if (room.playlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('歌单为空，请先搜索添加歌曲')),
      );
      return;
    }
    final cache = ref.read(trackCacheProvider.notifier);
    final firstId = room.playlist.first;
    cache.fetchIfNeeded(firstId).then((_) {
      final track = ref.read(trackCacheProvider)[firstId] ?? Track(id: firstId, name: firstId, artist: '');
      ref.read(playerProvider.notifier).playTrack(track);
    });
  }

  void _playNext() {
    ref.read(websocketProvider).sendSkip();
  }

  void _showPlaylist() {
    final room = ref.read(roomProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PlaylistSheet(playlist: room.playlist),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final isInRoom = room.currentRoom != null;

    if (!isInRoom) return const SizedBox.shrink();

    final track = player.status == PlayerStatus.idle ? null : player.currentTrack;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          _AlbumArt(track: track),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        track?.name ?? '未在播放',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Text(
                      track?.artist ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _ProgressBar(),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (track != null) {
                ref.read(playerProvider.notifier).togglePlayPause();
              } else {
                _playFirstInPlaylist();
              }
            },
            child: Container(
              width: 36, height: 36,
              child: Icon(
                player.status == PlayerStatus.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 24, color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          GestureDetector(
            onTap: _playNext,
            child: Container(
              width: 36, height: 36,
              child: Icon(Icons.skip_next_rounded, size: 24, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          GestureDetector(
            onTap: _showPlaylist,
            child: Container(
              width: 36, height: 36,
              child: Icon(Icons.queue_music_rounded, size: 22, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
          _VolumeButton(),
          _ExitButton(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AlbumArt extends ConsumerWidget {
  final Track? track;
  const _AlbumArt({this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF2A2A2A),
      ),
      child: track?.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                  track!.coverUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.3))))
          : Icon(Icons.music_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.3)),
    );
  }
}

class _ProgressBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<_ProgressBar> {
  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    final duration = player.duration > Duration.zero
        ? player.duration
        : (track?.durationMs != null ? Duration(milliseconds: track!.durationMs!) : Duration.zero);
    final pos = player.position;

    return SizedBox(
      height: 14,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _fmt(pos > duration && duration > Duration.zero ? duration : pos),
              style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: pos.inMilliseconds.toDouble().clamp(0, max(duration.inMilliseconds.toDouble(), 1)),
                max: max(duration.inMilliseconds.toDouble(), 1),
                onChanged: (v) => ref.read(playerProvider.notifier).seek(Duration(milliseconds: v.toInt())),
                onChangeEnd: (v) => ref.read(playerProvider.notifier).seekAndSync(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              _fmt(duration),
              style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _VolumeButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends ConsumerState<_VolumeButton> {
  OverlayEntry? _overlay;
  bool _hoveringButton = false;
  bool _hoveringSlider = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    if (_overlay != null) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (ctx) => Positioned(
        left: pos.dx + size.width / 2 - 22,
        top: pos.dy - 110,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveringSlider = true),
          onExit: (_) {
            setState(() => _hoveringSlider = false);
            _checkHide();
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 44,
              height: 110,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: _VolumeSlider(),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _checkHide() {
    if (!_hoveringButton && !_hoveringSlider) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_hoveringButton && !_hoveringSlider) {
          _removeOverlay();
          if (mounted) setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hoveringButton = true);
        _showOverlay();
      },
      onExit: (_) {
        setState(() => _hoveringButton = false);
        _checkHide();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          ref.watch(playerProvider).volume > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          size: 20,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _VolumeSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playerProvider).volume;
    final notifier = ref.read(playerProvider.notifier);
    return RotatedBox(
      quarterTurns: -1,
      child: SliderTheme(
        data: const SliderThemeData(
          trackHeight: 4,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
          activeTrackColor: Colors.white70,
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
        ),
        child: Slider(
          value: volume,
          onChanged: (v) => notifier.volume = v,
        ),
      ),
    );
  }
}

class _ExitButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final room = ref.read(roomProvider);
        final user = ref.read(authProvider).user;
        if (room.currentRoom == null || user == null) return;

        ref.read(playerProvider.notifier).stop();
        final msg = await ref.read(roomProvider.notifier).exitRoom(user.userUuid);
        ref.read(exitedRoomIdProvider.notifier).state = null;
        ref.read(sidebarTabProvider.notifier).state = SidebarTab.player;
        if (msg != null && context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('提示', style: TextStyle(color: Colors.white)),
              content: Text(msg, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      },
      child: Tooltip(
        message: '退出房间',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.logout_rounded,
            size: 20,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSheet extends ConsumerWidget {
  final List<String> playlist;
  const _PlaylistSheet({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text('歌单队列 (${playlist.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add, size: 18), label: const Text('添加歌曲'),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: playlist.isEmpty
                ? Center(child: Text('歌单为空', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
                : ListView.builder(
                    itemCount: playlist.length,
                    itemBuilder: (_, i) => _PlaylistTile(trackId: playlist[i], index: i),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final String trackId;
  final int index;
  const _PlaylistTile({required this.trackId, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(trackCacheProvider);
    final player = ref.watch(playerProvider);
    final track = cache[trackId];
    final isCurrent = player.currentTrack?.id == trackId;

    ref.read(trackCacheProvider.notifier).fetchIfNeeded(trackId);

    return ListTile(
      leading: CircleAvatar(
        radius: 16, backgroundColor: const Color(0xFF2A2A2A),
        child: track?.coverUrl != null
            ? ClipOval(child: Image.network(track!.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text('${index + 1}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))))
            : Text('${index + 1}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ),
      title: Text(
        track != null ? '${track.name} - ${track.artist}' : trackId,
        style: TextStyle(fontSize: 13, color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.6)),
      ),
      onTap: () {
        final t = track ?? Track(id: trackId, name: trackId, artist: '');
        ref.read(playerProvider.notifier).playTrack(t);
      },
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline, size: 18, color: Colors.white.withValues(alpha: 0.3)),
        onPressed: () => ref.read(websocketProvider).sendPlaylistRemove([trackId]),
      ),
    );
  }
}
