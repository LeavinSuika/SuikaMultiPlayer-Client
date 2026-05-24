import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/music_provider.dart';
import 'package:suika_multi_player/providers/room_provider.dart';
import 'package:suika_multi_player/providers/sidebar_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/layout/toolbar.dart';
import 'package:suika_multi_player/layout/icon_sidebar.dart';
import 'package:suika_multi_player/layout/content_area.dart';
import 'package:suika_multi_player/layout/user_panel.dart';
import 'package:suika_multi_player/layout/mini_player.dart';
import 'package:suika_multi_player/utils/center_toast.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StreamSubscription? _roomWsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  Future<void> _init() async {
    await ref.read(authProvider.notifier).tryAutoLogin();
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    if (user != null) {
      _connectGlobalWs();
      ref.read(roomProvider.notifier).loadJoinedRooms(user.userUuid);
      _listenRoomWs();
    }
  }

  void _connectGlobalWs() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final globalWs = ref.read(globalWsProvider);
    if (!globalWs.isConnected) {
      globalWs.connect(user.userUuid);
    }
  }

  void _listenRoomWs() {
    final ws = ref.read(websocketProvider);
    _roomWsSub = ws.messages.listen((msg) {
      final room = ref.read(roomProvider.notifier);
      switch (msg.type) {
        case 'room_info':
          room.updateRoomInfo(msg.data);
          final rid = ref.read(roomProvider).currentRoom?.roomId;
          if (rid != null) room.refreshOnlineUsers(rid);
          break;
        case 'user_joined':
          room.addUser(msg.data['user_uuid'] as String);
          break;
        case 'user_left':
          room.removeUser(msg.data['user_uuid'] as String);
          break;
        case 'playlist_update':
          final newPlaylist = (msg.data['playlist'] as List<dynamic>?)
                  ?.map((e) => PlaylistEntry.fromJson(e))
                  .toList() ?? [];
          room.updatePlaylist(newPlaylist);
          break;
        case 'playback_state':
          _onPlaybackState(msg.data);
          break;
        case 'play_track':
          _onPlayTrack(msg.data);
          break;
        case 'pause':
          ref.read(playerProvider.notifier).pause();
          break;
        case 'resume':
          ref.read(playerProvider.notifier).play();
          break;
        case 'seek':
          final posMs = msg.data['pos'] as int? ?? 0;
          ref.read(playerProvider.notifier).seek(Duration(milliseconds: posMs));
          break;
        case 'pause_event':
          // 播放列表为空时服务端发送此消息，重置播放器为空闲状态
          ref.read(playerProvider.notifier).stop();
          break;
      }
    });
  }

  void _onPlayTrack(Map<String, dynamic> data) {
    final trackId = data['track_id'] as String? ?? '';
    final serverPos = data['pos'] as int? ?? 0;
    final isPlaying = data['is_playing'] as bool? ?? true;
    if (trackId.isEmpty) return;
    final cache = ref.read(trackCacheProvider.notifier);
    cache.fetchIfNeeded(trackId).then((_) {
      final track = ref.read(trackCacheProvider)[trackId] ??
          Track(id: trackId, name: trackId, artist: '');
      ref.read(playerProvider.notifier).playTrackFromServer(track, serverPos, isPlaying);
    });
  }

  void _onPlaybackState(Map<String, dynamic> data) {
    final trackId = data['track_id'] as String? ?? '';
    final isPlaying = (data['is_playing'] ?? data['is_played']) as bool? ?? false;
    final serverPos = data['pos'] as int? ?? 0;
    final playerState = ref.read(playerProvider);
    final player = ref.read(playerProvider.notifier);

    // 曲目不匹配或尚未加载完毕 → 跳过
    if (playerState.currentTrack?.id != trackId ||
        playerState.status == PlayerStatus.loading ||
        playerState.status == PlayerStatus.idle) {
      return;
    }

    // 播放器未就绪 → 只同步播放/暂停状态，不 seek
    if (!player.isReady) {
      if (isPlaying && !player.playing) {
        player.play();
      } else if (!isPlaying && player.playing) {
        player.pause();
      }
      return;
    }

    // 同步播放/暂停状态
    if (isPlaying && !player.playing) {
      player.play();
    } else if (!isPlaying && player.playing) {
      player.pause();
    }

    // 同步播放位置（带冷却期，避免频繁 seek 打断 Windows 音频管道）
    player.syncSeek(serverPos);
  }

  @override
  void dispose() {
    _roomWsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(sidebarTabProvider);
    final roomState = ref.watch(roomProvider);
    final isInRoom = roomState.enteredRoomId != null &&
        roomState.currentRoom?.roomId == roomState.enteredRoomId;

    // Stop player when entering a different room
    ref.listen<RoomState>(roomProvider, _onRoomStateChange);

    // 播放出错时居中提示
    ref.listen<String?>(playerProvider.select((s) => s.error), (_, error) {
      if (error != null && error.isNotEmpty) {
        showCenterToast(context,
          message: '播放失败',
          backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
          duration: const Duration(seconds: 4),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        children: [
          const Toolbar(),
          Expanded(
            child: Row(
              children: [
                const IconSidebar(),
                const Expanded(child: ContentArea()),
                if (tab == SidebarTab.player && isInRoom) const UserPanel(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  void _onRoomStateChange(RoomState? prev, RoomState next) {
    if (prev?.enteredRoomId != next.enteredRoomId) {
      ref.read(playerProvider.notifier).stop();
      if (next.enteredRoomId != null) {
        ref.read(exitedRoomIdProvider.notifier).state = null;
      }
    }
  }
}
