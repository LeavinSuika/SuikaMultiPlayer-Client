import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/models/lyrics.dart';

class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key});

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final playback = ref.watch(playbackProvider);
    final lyrics = ref.watch(lyricsProvider);
    final isInRoom = room.currentRoom != null;

    if (!isInRoom) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones_rounded,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              '加入房间后开始播放',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
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

    return Column(
      children: [
        _LyricsTopBar(
          roomName: room.currentRoom!.roomName,
          onlineCount: room.onlineUsers.length,
        ),
        const Divider(height: 1),
        Expanded(
          child: playback == null || playback.trackId.isEmpty
              ? _EmptyPlayer(
                  isOwner: false,
                  onAddSong: () {},
                )
              : _ScrollingLyrics(lyrics: lyrics),
        ),
      ],
    );
  }
}

class _LyricsTopBar extends StatelessWidget {
  final String roomName;
  final int onlineCount;

  const _LyricsTopBar({
    required this.roomName,
    required this.onlineCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.music_note_rounded,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            roomName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '在线 $onlineCount',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onAddSong;

  const _EmptyPlayer({required this.isOwner, required this.onAddSong});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music_rounded,
              size: 80, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            '歌单为空',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '搜索歌曲添加到播放列表',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddSong,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('搜索歌曲'),
          ),
        ],
      ),
    );
  }
}

class _ScrollingLyrics extends ConsumerWidget {
  final AsyncValue<Lyrics?> lyrics;

  const _ScrollingLyrics({required this.lyrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);

    final lines = lyrics.valueOrNull?.lines ?? [];
    if (lines.isEmpty) {
      return Center(
        child: Text('暂无歌词',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 15)),
      );
    }

    final currentIdx = lyrics.valueOrNull?.findCurrentIndex(
          Duration(milliseconds: playback?.positionMs ?? 0),
        ) ??
        0;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.35),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isCurrent = i == currentIdx;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: isCurrent ? 22 : 15,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
            child: Text(
              line.text.isEmpty ? '...' : line.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

class _WordLyrics extends ConsumerWidget {
  final AsyncValue<Lyrics?> lyrics;

  const _WordLyrics({required this.lyrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final position = Duration(milliseconds: playback?.positionMs ?? 0);
    final lines = lyrics.valueOrNull?.lines ?? [];
    final hasWords = lyrics.valueOrNull?.hasWordTiming ?? false;

    if (lines.isEmpty) {
      return Center(
        child: Text('暂无逐字歌词',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3), fontSize: 15)),
      );
    }

    if (!hasWords) {
      return Center(
        child: Text('当前歌词不支持逐字模式',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 15)),
      );
    }

    final currentIdx =
        lyrics.valueOrNull?.findCurrentIndex(position) ?? 0;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.3),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final line = lines[i];
        final isCurrent = i == currentIdx;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          alignment: Alignment.center,
          child: Opacity(
            opacity: isCurrent ? 1.0 : 0.35,
            child: line.words != null && line.words!.isNotEmpty
                ? Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: line.words!.map((w) {
                      final wordStart = w.startTime;
                      final wordEnd = wordStart + w.duration;
                      final isActive = isCurrent &&
                          position >= wordStart &&
                          position < wordEnd;
                      return Text(
                        w.text,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive ? Colors.white : Colors.white70,
                        ),
                      );
                    }).toList(),
                  )
                : Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.white : Colors.white70,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
