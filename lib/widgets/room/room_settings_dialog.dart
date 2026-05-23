import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/user_cache_provider.dart';
import 'package:suika_multi_player/utils/center_toast.dart';
import 'package:suika_multi_player/widgets/user_avatar.dart';

class RoomSettingsDialog extends ConsumerStatefulWidget {
  final int roomId;
  final String roomName;
  final String ownerUuid;

  const RoomSettingsDialog({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.ownerUuid,
  });

  @override
  ConsumerState<RoomSettingsDialog> createState() =>
      _RoomSettingsDialogState();
}

class _RoomSettingsDialogState extends ConsumerState<RoomSettingsDialog> {
  List<RoomMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiServiceProvider);
      final detail = await api.fetchRoom(widget.roomId);
      setState(() {
        _members = detail.roomMembersDetail;
        _loading = false;
      });
      // 预加载用户缓存
      for (final m in _members) {
        ref.read(userCacheProvider.notifier).fetchUser(m.userUuid);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setRole(String uuid, String role) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      await ref.read(apiServiceProvider).setRoomMemberRole(
            operatorUuid: user.userUuid,
            roomId: widget.roomId,
            userUuid: uuid,
            role: role,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        showCenterToast(context,
            message: '操作失败: $e',
            backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
      }
    }
  }

  Future<void> _kick(String uuid) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      await ref.read(apiServiceProvider).kickRoomMember(
            operatorUuid: user.userUuid,
            roomId: widget.roomId,
            userUuid: uuid,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        showCenterToast(context,
            message: '操作失败: $e',
            backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
      }
    }
  }

  Future<void> _deleteRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解散房间'),
        content: Text('确定要解散「${widget.roomName}」吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            child: const Text('确认解散'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      await ref.read(apiServiceProvider).deleteRoom(
            operatorUuid: user.userUuid,
            roomId: widget.roomId,
          );
      // 刷新侧边栏房间列表
      ref.read(roomProvider.notifier).loadJoinedRooms(user.userUuid);
      if (mounted) {
        showCenterToast(context, message: '房间已解散');
        Navigator.pop(context); // 关闭设置弹窗
      }
    } catch (e) {
      if (mounted) {
        showCenterToast(context,
            message: '解散失败: $e',
            backgroundColor: Colors.redAccent.withValues(alpha: 0.85));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('房间设置 — ${widget.roomName}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9))),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 成员列表
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('加载失败: $_error',
                    style: TextStyle(
                        color: Colors.redAccent.withValues(alpha: 0.8))),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _members.length,
                  itemBuilder: (_, i) => _MemberTile(
                    member: _members[i],
                    isSelf: _members[i].userUuid ==
                        ref.read(authProvider).user?.userUuid,
                    isOwner: _members[i].isOwner,
                    onSetRole: (role) => _setRole(_members[i].userUuid, role),
                    onKick: () => _kick(_members[i].userUuid),
                  ),
                ),
              ),
            const Divider(),
            // 底部操作
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleteRoom,
                  icon: const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('解散房间'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent.withValues(alpha: 0.8),
                    side: BorderSide(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final RoomMember member;
  final bool isSelf;
  final bool isOwner;
  final void Function(String role) onSetRole;
  final VoidCallback onKick;

  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.isOwner,
    required this.onSetRole,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleLabel = isOwner ? '房主' : (member.isAdmin ? '管理员' : '成员');

    // 从缓存取用户昵称
    final userCache = ref.watch(userCacheProvider);
    final user = userCache[member.userUuid];
    final displayName = user?.nickname ?? user?.userName ?? member.userUuid.substring(0, 8);
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelf ? Colors.white.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            UserAvatar(
              avatarUrl: user?.avatarUrl,
              fallback: firstLetter,
              radius: 16,
            ),
            const SizedBox(width: 10),
            // 名称 + 角色
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                      if (isSelf)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text('(你)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.4))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(roleLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: isOwner
                              ? Colors.amber.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.35))),
                ],
              ),
            ),
            // 操作按钮（房主不能被操作，自己不能操作自己）
            if (!isOwner && !isSelf)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz_rounded,
                    size: 18, color: Colors.white.withValues(alpha: 0.4)),
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                itemBuilder: (_) => [
                  if (!member.isAdmin)
                    const PopupMenuItem(
                        value: 'admin', child: Text('设为管理员'))
                  else
                    const PopupMenuItem(value: 'member', child: Text('取消管理员')),
                  const PopupMenuItem(
                      value: 'kick',
                      child: Text('踢出房间',
                          style: TextStyle(color: Colors.redAccent))),
                ],
                onSelected: (v) {
                  if (v == 'kick') {
                    onKick();
                  } else {
                    onSetRole(v);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
