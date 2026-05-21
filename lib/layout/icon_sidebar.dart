import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/sidebar_provider.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';

class IconSidebar extends ConsumerWidget {
  const IconSidebar({super.key});

  void _showCreateJoinSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateJoinSheet(ref: ref),
    );
  }

  void _showSearchOverlay(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _SearchOverlay(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedTab = ref.watch(sidebarTabProvider);
    final roomState = ref.watch(roomProvider);
    final currentRoom = roomState.currentRoom;
    final exitedRoomId = ref.watch(exitedRoomIdProvider);
    final isInRoom = roomState.enteredRoomId != null;
    final canSearch = isInRoom && selectedTab == SidebarTab.player;

    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Top: joined rooms
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final roomId in roomState.joinedRoomIds)
                  Builder(builder: (context) {
                    final room = roomState.roomCache[roomId];
                    if (room == null) return const SizedBox.shrink();
                    final isEntered = roomState.enteredRoomId == roomId;
                    final isPreviewed = !isEntered && currentRoom?.roomId == roomId;
                    final user = ref.watch(authProvider).user;
                    return _RoomIcon(
                      name: room.name,
                      roomId: room.roomId,
                      isEntered: isEntered,
                      isPreviewed: isPreviewed,
                      exitedRoomId: exitedRoomId,
                      onTap: () {
                        ref.read(roomProvider.notifier).previewRoom(room.roomId);
                        ref.read(sidebarTabProvider.notifier).state = SidebarTab.player;
                      },
                      onDoubleTap: () {
                        ref.read(playerProvider.notifier).stop();
                        ref.read(roomProvider.notifier).switchRoom(room, user?.userUuid ?? '');
                        ref.read(sidebarTabProvider.notifier).state = SidebarTab.player;
                      },
                    );
                  }),
              ],
            ),
          ),
          // Bottom: menu buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _SidebarIcon(
                  icon: Icons.search_rounded,
                  label: '搜索',
                  isSelected: false,
                  enabled: canSearch,
                  onTap: canSearch
                      ? () => _showSearchOverlay(context, ref)
                      : null,
                ),
                const SizedBox(height: 4),
                _SidebarIcon(
                  icon: Icons.person_rounded,
                  label: '我的',
                  isSelected: selectedTab == SidebarTab.profile,
                  onTap: () => ref.read(sidebarTabProvider.notifier).state =
                      SidebarTab.profile,
                ),
                const SizedBox(height: 4),
                _SidebarIcon(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  isSelected: selectedTab == SidebarTab.settings,
                  onTap: () => ref.read(sidebarTabProvider.notifier).state =
                      SidebarTab.settings,
                ),
                const SizedBox(height: 12),
                _SidebarIcon(
                  icon: Icons.add_rounded,
                  label: '加入',
                  isSelected: false,
                  isJoin: true,
                  onTap: () => _showCreateJoinSheet(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RoomIcon extends StatefulWidget {
  final String name;
  final int roomId;
  final bool isEntered;
  final bool isPreviewed;
  final int? exitedRoomId;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _RoomIcon({
    required this.name,
    required this.roomId,
    required this.isEntered,
    required this.isPreviewed,
    required this.exitedRoomId,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  State<_RoomIcon> createState() => _RoomIconState();
}

class _RoomIconState extends State<_RoomIcon> with TickerProviderStateMixin {
  AnimationController? _pulseCtrl;
  bool _wasPreviewed = false;
  bool _wasExited = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPreviewed) _startPreviewPulse();
  }

  @override
  void didUpdateWidget(covariant _RoomIcon old) {
    super.didUpdateWidget(old);
    if (widget.isPreviewed && !old.isPreviewed) _startPreviewPulse();
    if (!widget.isPreviewed && old.isPreviewed) _stopPulse();
  }

  void _startPreviewPulse() {
    _pulseCtrl?.dispose();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _wasPreviewed = true;
    setState(() {});
  }

  void _startExitPulse() {
    _pulseCtrl?.dispose();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _wasExited = true;
    setState(() {});
  }

  void _stopPulse() {
    _pulseCtrl?.dispose();
    _pulseCtrl = null;
    _wasPreviewed = false;
    _wasExited = false;
    setState(() {});
  }

  @override
  void dispose() {
    _pulseCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '#';
    final isExited = !widget.isEntered && widget.exitedRoomId == widget.roomId;

    // Start exit pulse when this room is the one exited
    if (isExited && !_wasExited) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startExitPulse());
    }
    if (!isExited && _wasExited) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopPulse());
    }

    final isActive = widget.isEntered || _wasPreviewed || _wasExited;
    final isSolid = widget.isEntered;
    final hasPulse = _pulseCtrl != null && !isSolid;

    final borderOpacity = isSolid ? 0.5 : (hasPulse ? (_pulseCtrl!.value * 0.5).clamp(0.1, 0.5) : 0.0);
    final bgColor = isSolid ? const Color(0xFF5A5A5A) : (isActive ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A));
    final textColor = isSolid ? Colors.white : (isActive ? Colors.white.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.7));

    Widget icon = Container(
      width: 48, height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: bgColor,
        border: isActive ? Border.all(color: Colors.white.withValues(alpha: borderOpacity), width: 2) : null,
      ),
      child: Center(child: Text(letter, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor))),
    );

    if (hasPulse) {
      icon = AnimatedBuilder(animation: _pulseCtrl!, builder: (_, child) {
        final op = (_pulseCtrl!.value * 0.5).clamp(0.1, 0.5);
        return Container(
          width: 48, height: 48,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bgColor,
            border: Border.all(color: Colors.white.withValues(alpha: op), width: 2),
          ),
          child: Center(child: Text(letter, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor))),
        );
      });
    }

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      child: Tooltip(message: widget.name, child: icon),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isJoin;
  final bool enabled;
  final VoidCallback? onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isJoin = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isSelected ? Colors.white : Colors.white.withValues(alpha: 0.45);
    final color = enabled ? baseColor : Colors.white.withValues(alpha: 0.15);

    return Padding(
      padding: EdgeInsets.only(top: isJoin ? 12 : 0),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Tooltip(
          message: enabled ? label : label,
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? const Color(0xFF3A3A3A)
                  : (isJoin ? const Color(0xFF2A2A2A) : Colors.transparent),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchOverlay extends ConsumerStatefulWidget {
  const _SearchOverlay();

  @override
  ConsumerState<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<_SearchOverlay> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addTrack(Track track) {
    final room = ref.read(roomProvider);
    if (room.currentRoom == null) return;
    ref.read(trackCacheProvider.notifier).cache(track);
    ref.read(websocketProvider).sendPlaylistAdd([
      {'track_id': track.id, 'duration': track.durationMs ?? 0}
    ]);
    final newList = [...room.playlist, track.id];
    ref.read(roomProvider.notifier).updatePlaylist(newList);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加: ${track.name}'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider);

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：搜索框 + 关闭按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜索歌曲...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.white.withValues(alpha: 0.4)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(searchProvider.notifier).clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        ref.read(searchProvider.notifier).search(v.trim());
                      }
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.white.withValues(alpha: 0.5),
                  tooltip: '关闭',
                ),
              ],
            ),
          ),
          // 结果列表
          Flexible(
            child: results.when(
              data: (tracks) => tracks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        _searchCtrl.text.isNotEmpty ? '无搜索结果' : '输入关键词搜索歌曲',
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.35)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: tracks.length,
                      itemBuilder: (_, i) => _TrackTile(
                        track: tracks[i],
                        onAdd: () => _addTrack(tracks[i]),
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text('搜索出错', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7)))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onAdd;

  const _TrackTile({required this.track, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
        child: track.coverUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  track.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                ),
              )
            : Icon(Icons.music_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.5)),
      ),
      title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
      subtitle: Text('${track.artist}${track.album != null ? ' · ${track.album}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
      trailing: IconButton(
        icon: Icon(Icons.add_circle_outline_rounded, size: 22, color: theme.colorScheme.primary),
        onPressed: onAdd,
        tooltip: '添加到歌单',
      ),
    );
  }
}

class _CreateJoinSheet extends ConsumerWidget {
  final WidgetRef ref;

  const _CreateJoinSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef unused) {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '创建或加入房间',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '房间名称（创建新房间）',
              prefixIcon: Icon(Icons.add_circle_outline_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  final user = ref.read(authProvider).user;
                  if (user != null) {
                    ref.read(roomProvider.notifier).createRoom(name, user.userUuid);
                    ref.read(sidebarTabProvider.notifier).state = SidebarTab.player;
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('创建房间'),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          TextField(
            controller: idCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '房间 ID（加入已有房间）',
              prefixIcon: Icon(Icons.login_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final id = int.tryParse(idCtrl.text.trim());
                if (id != null) {
                  final user = ref.read(authProvider).user;
                  if (user != null) {
                    ref.read(roomProvider.notifier).joinRoom(id, user.userUuid);
                    ref.read(sidebarTabProvider.notifier).state = SidebarTab.player;
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('加入房间'),
            ),
          ),
        ],
      ),
    );
  }
}
