import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/services/api_service.dart';
import 'package:suika_multi_player/services/websocket_service.dart';

class RoomState {
  final bool isLoading;
  final String? error;
  final RoomDetail? currentRoom;
  final int? enteredRoomId; // 实际进入的房间（WS已连接），null表示未进入或仅预览
  final Map<int, Room> roomCache;
  final List<int> joinedRoomIds;
  final List<String> onlineUsers;
  final List<PlaylistEntry> playlist;
  final String? ownerUuid;

  const RoomState({
    this.isLoading = false,
    this.error,
    this.currentRoom,
    this.enteredRoomId,
    this.roomCache = const {},
    this.joinedRoomIds = const [],
    this.onlineUsers = const [],
    this.playlist = const <PlaylistEntry>[],
    this.ownerUuid,
  });

  static const _sentinel = Object();

  RoomState copyWith({
    bool? isLoading,
    Object? error = _sentinel,
    Object? currentRoom = _sentinel,
    Object? enteredRoomId = _sentinel,
    Map<int, Room>? roomCache,
    List<int>? joinedRoomIds,
    List<String>? onlineUsers,
    List<PlaylistEntry>? playlist,
    Object? ownerUuid = _sentinel,
  }) =>
      RoomState(
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _sentinel) ? this.error : error as String?,
        currentRoom: identical(currentRoom, _sentinel) ? this.currentRoom : currentRoom as RoomDetail?,
        enteredRoomId: identical(enteredRoomId, _sentinel) ? this.enteredRoomId : enteredRoomId as int?,
        roomCache: roomCache ?? this.roomCache,
        joinedRoomIds: joinedRoomIds ?? this.joinedRoomIds,
        onlineUsers: onlineUsers ?? this.onlineUsers,
        playlist: playlist ?? this.playlist,
        ownerUuid: identical(ownerUuid, _sentinel) ? this.ownerUuid : ownerUuid as String?,
      );
}

class RoomNotifier extends StateNotifier<RoomState> {
  final ApiService _api;
  final WebsocketService _ws;

  RoomNotifier(this._api, this._ws) : super(const RoomState());

  bool get isInRoom => state.currentRoom != null;

  Future<void> refreshOnlineUsers(int roomId) async {
    try {
      final users = await _api.getRoomOnlineUsers(roomId);
      state = state.copyWith(onlineUsers: users);
    } catch (_) {}
  }

  Future<void> loadJoinedRooms(String userUuid) async {
    try {
      final rooms = await _api.fetchUserRooms(userUuid);
      final roomIds = rooms.map((r) => r['room_id'] as int).toList();
      if (roomIds.isEmpty) return;

      state = state.copyWith(joinedRoomIds: roomIds);
      for (final r in rooms) {
        final id = r['room_id'] as int;
        state = state.copyWith(roomCache: {
          ...state.roomCache,
          id: Room(
            roomId: id,
            name: r['name'] as String? ?? '',
            creatorUuid: r['creator_uuid'] as String? ?? '',
            isPublic: r['is_public'] == true || r['is_public'] == 1,
            createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
          ),
        });
      }
    } catch (_) {}
  }

  Future<void> createRoom(String name, String creatorUuid) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _api.createRoom(name: name, creatorUuid: creatorUuid);
      final detail = await _api.fetchRoom(room.roomId);
      final jids = [...state.joinedRoomIds];
      if (!jids.contains(room.roomId)) jids.insert(0, room.roomId);
      state = state.copyWith(
        isLoading: false,
        currentRoom: detail,
        enteredRoomId: room.roomId,
        joinedRoomIds: jids,
        roomCache: {...state.roomCache, room.roomId: room},
        playlist: const [],
      );
      _ws.disconnect();
      _ws.connect(userUuid: creatorUuid, roomId: room.roomId.toString());

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> joinRoom(int roomId, String userUuid) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final detail = await _api.joinRoom(roomId: roomId, userUuid: userUuid);
      final jids = [...state.joinedRoomIds];
      if (!jids.contains(roomId)) jids.insert(0, roomId);
      state = state.copyWith(
        isLoading: false,
        currentRoom: detail,
        enteredRoomId: roomId,
        joinedRoomIds: jids,
        playlist: detail.playlist,
        roomCache: {
          ...state.roomCache,
          roomId: Room(
            roomId: detail.roomId,
            name: detail.roomName,
            creatorUuid: detail.creatorUuid,
            isPublic: detail.isPublic,
            createdAt: DateTime.now(),
          ),
        },
      );
      _ws.disconnect();
      _ws.connect(userUuid: userUuid, roomId: roomId.toString());

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// 退出房间同步（保留成员身份，仅断开实时连接）。
  /// Returns null on success, or an error message string on failure.
  Future<String?> exitRoom(String userUuid) async {
    if (state.currentRoom == null) return null;
    final roomId = state.currentRoom!.roomId;
    try {
      await _api.exitRoom(roomId: roomId, userUuid: userUuid);
    } catch (_) {}
    _ws.disconnect();
    state = state.copyWith(
      currentRoom: null,
      enteredRoomId: null,
      onlineUsers: const [],
      playlist: const [],
    );
    return null;
  }

  /// 离开房间（移除成员身份）。Returns null on success, or an error message string on failure.
  Future<String?> leaveRoom(String userUuid) async {
    if (state.currentRoom == null) return null;
    final roomId = state.currentRoom!.roomId;
    try {
      await _api.leaveRoom(roomId: roomId, userUuid: userUuid);
      // API succeeded — 断开连接并移除
      _ws.disconnect();
      final jids = state.joinedRoomIds.where((id) => id != roomId).toList();
      state = RoomState(roomCache: state.roomCache, joinedRoomIds: jids);
      return null;
    } catch (e) {
      // API 失败 — 保持房间连接和状态不变
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> previewRoom(int roomId) async {
    try {
      final detail = await _api.fetchRoom(roomId);
      state = state.copyWith(currentRoom: detail);
    } catch (_) {}
  }

  Future<void> switchRoom(Room room, String userUuid) async {
    state = state.copyWith(isLoading: true);
    try {
      final detail = await _api.fetchRoom(room.roomId);
      state = state.copyWith(
        isLoading: false,
        currentRoom: detail,
        enteredRoomId: room.roomId,
      );
    } catch (_) {
      final detail = RoomDetail(
        roomId: room.roomId, roomName: room.name, creatorUuid: room.creatorUuid,
        isPublic: room.isPublic, roomMembers: [], count: 0,
      );
      state = state.copyWith(
        isLoading: false,
        currentRoom: detail,
        enteredRoomId: room.roomId,
      );
    }
    _ws.disconnect();
    _ws.connect(userUuid: userUuid, roomId: room.roomId.toString());
  }

  void updateRoomInfo(Map<String, dynamic> data) {
    final playlist = (data['playlist'] as List<dynamic>?)
        ?.map((e) => PlaylistEntry.fromJson(e))
        .toList() ?? [];
    final owner = data['owner'] as String?;
    state = state.copyWith(playlist: playlist, ownerUuid: owner);
  }

  void updateOnlineUsers(List<String> users) => state = state.copyWith(onlineUsers: users);
  void updatePlaylist(List<PlaylistEntry> playlist) => state = state.copyWith(playlist: playlist);
  void addUser(String userUuid) {
    if (!state.onlineUsers.contains(userUuid)) {
      state = state.copyWith(onlineUsers: [...state.onlineUsers, userUuid]);
    }
  }
  void removeUser(String userUuid) {
    state = state.copyWith(onlineUsers: state.onlineUsers.where((u) => u != userUuid).toList());
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final ws = ref.watch(websocketProvider);
  return RoomNotifier(api, ws);
});
