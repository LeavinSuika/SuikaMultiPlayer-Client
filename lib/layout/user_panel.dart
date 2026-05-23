import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/user_cache_provider.dart';
import 'package:suika_multi_player/widgets/user_avatar.dart';

class UserPanel extends ConsumerWidget {
  const UserPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    final members = room.currentRoom?.roomMembers ?? [];
    final onlineUsers = room.onlineUsers;

    if (members.isEmpty) {
      return Container(
        width: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.95),
          border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '未加入房间',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
        ),
      );
    }

    final offlineUsers = members.where((u) => !onlineUsers.contains(u)).toList();

    for (final uuid in members) {
      ref.read(userCacheProvider.notifier).fetchUser(uuid);
    }

    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onlineUsers.isNotEmpty ? Colors.greenAccent : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text('在线 — ${onlineUsers.length}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...onlineUsers.map((uuid) => _UserTile(
                      uuid: uuid,
                      isOnline: true,
                      isOwner: uuid == room.ownerUuid,
                      currentUserUuid: auth.user?.userUuid,
                    )),
                if (offlineUsers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('离线 — ${offlineUsers.length}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.35))),
                  ),
                  ...offlineUsers.map((uuid) => _UserTile(
                        uuid: uuid,
                        isOnline: false,
                        isOwner: uuid == room.ownerUuid,
                        currentUserUuid: auth.user?.userUuid,
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final String uuid;
  final bool isOnline;
  final bool isOwner;
  final String? currentUserUuid;

  const _UserTile({
    required this.uuid,
    required this.isOnline,
    required this.isOwner,
    this.currentUserUuid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMe = uuid == currentUserUuid;
    final userCache = ref.watch(userCacheProvider);
    final user = userCache[uuid];
    final displayName = user?.nickname ?? user?.userName ?? uuid.substring(0, 8);
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isMe ? theme.colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  avatarUrl: user?.avatarUrl,
                  fallback: firstLetter,
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.greenAccent : Colors.grey,
                      border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  if (isOwner) Padding(padding: const EdgeInsets.only(right: 4), child: Text('👑', style: const TextStyle(fontSize: 11))),
                  Flexible(
                    child: Text(displayName, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: isOnline ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.35)))),
                  if (isMe) Padding(padding: const EdgeInsets.only(left: 4), child: Text('(你)', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary.withValues(alpha: 0.7)))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
