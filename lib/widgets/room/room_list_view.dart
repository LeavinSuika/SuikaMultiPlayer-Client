import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/sidebar_provider.dart';

class RoomListView extends ConsumerWidget {
  const RoomListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(roomProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的房间',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: roomState.currentRoom != null
                ? _CurrentRoomCard(room: roomState.currentRoom!)
                : _NoRoomPlaceholder(
                    onCreate: () {},
                  ),
          ),
        ],
      ),
    );
  }
}

class _CurrentRoomCard extends ConsumerWidget {
  final RoomDetail room;

  const _CurrentRoomCard({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    room.roomName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                  child: Text(
                    '房间 ID: ${room.roomId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.group_rounded,
                    size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  '${room.count} 位成员',
                  style: const TextStyle(fontSize: 13, color: Colors.white38),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.lock_open_rounded,
                    size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Text(
                  room.isPublic ? '公开' : '私密',
                  style: const TextStyle(fontSize: 13, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PlaybackStatus(room: room),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final user = ref.read(authProvider).user;
                  if (user == null) return;
                  ref.read(playerProvider.notifier).stop();
                  ref.read(roomProvider.notifier).switchRoom(
                    Room(
                      roomId: room.roomId,
                      name: room.roomName,
                      creatorUuid: room.creatorUuid,
                      isPublic: room.isPublic,
                      createdAt: DateTime.now(),
                    ),
                    user.userUuid,
                  );
                  ref.read(sidebarTabProvider.notifier).state = SidebarTab.player;
                },
                child: const Text('进入房间'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackStatus extends ConsumerWidget {
  final RoomDetail room;
  const _PlaybackStatus({required this.room});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pstate = room.playstatus;

    if (pstate == null || pstate.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.music_note_rounded, size: 16,
                color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 8),
            Text('暂无播放',
                style: TextStyle(fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.35))),
          ],
        ),
      );
    }

    final trackId = pstate['track_id'] as String? ?? '';
    final isPlaying = pstate['is_playing'] as bool? ?? false;
    final pos = pstate['pos'] as int? ?? 0;
    final duration = pstate['duration'] as int? ?? 0;

    final track = ref.watch(trackCacheProvider)[trackId];
    if (track == null && trackId.isNotEmpty) {
      ref.read(trackCacheProvider.notifier).fetchIfNeeded(trackId);
    }

    final trackName = track?.name ?? trackId;
    final progress = duration > 0 ? (pos / duration).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 16,
                color: isPlaying
                    ? Colors.greenAccent.withValues(alpha: 0.8)
                    : Colors.amberAccent.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPlaying
                          ? Colors.greenAccent.withValues(alpha: 0.6)
                          : Colors.amberAccent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_fmt(Duration(milliseconds: pos))} / ${_fmt(Duration(milliseconds: duration))}',
                style: TextStyle(fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoRoomPlaceholder extends StatelessWidget {
  final VoidCallback onCreate;

  const _NoRoomPlaceholder({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_rounded,
                size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              '你还未加入任何房间',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1E1E1E),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => const _CreateJoinBottomSheet(),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label:             const Text('创建或加入房间'),
            ),
          ],
        ),
    );
  }
}

class _CreateJoinBottomSheet extends StatelessWidget {
  const _CreateJoinBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('创建或加入房间',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white)),
          const SizedBox(height: 20),
          _JoinBtn(
            icon: Icons.add_circle_outline,
            label: '创建新房间',
            onTap: () {
              Navigator.pop(context);
              _showCreateDialog(context);
            },
          ),
          const SizedBox(height: 12),
          _JoinBtn(
            icon: Icons.login_rounded,
            label: '加入已有房间',
            onTap: () {
              Navigator.pop(context);
              _showJoinDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建房间'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '房间名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {'name': ctrl.text.trim()});
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入房间'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '输入房间 ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final id = int.tryParse(ctrl.text.trim());
              if (id != null) {
                Navigator.pop(ctx, {'room_id': id});
              }
            },
            child: const Text('加入'),
          ),
        ],
      ),
    );
  }
}

class _JoinBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _JoinBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }
}
