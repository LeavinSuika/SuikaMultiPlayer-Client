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
  final List<String> playlist;
  final String? ownerUuid;

  const RoomState({
    this.isLoading = false,
    this.error,
    this.currentRoom,
    this.enteredRoomId,
    this.roomCache = const {},
    this.joinedRoomIds = const [],
    this.onlineUsers = const [],
    this.playlist = const [],
    this.ownerUuid,
  });

  RoomState copyWith({
    bool? isLoading,
    String? error,
    RoomDetail? currentRoom,
    int? enteredRoomId,
    Map<int, Room>? roomCache,
    List<int>? joinedRoomIds,
    List<String>? onlineUsers,
    List<String>? playlist,
    String? ownerUuid,
  }) =>
      RoomState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        currentRoom: currentRoom ?? this.currentRoom,
        enteredRoomId: enteredRoomId ?? this.enteredRoomId,
        roomCache: roomCache ?? this.roomCache,
        joinedRoomIds: joinedRoomIds ?? this.joinedRoomIds,
        onlineUsers: onlineUsers ?? this.onlineUsers,
        playlist: playlist ?? this.playlist,
        ownerUuid: ownerUuid ?? this.ownerUuid,
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
        if (state.currentRoom == null) {
          final detail = await _api.fetchRoom(id);
          state = state.copyWith(currentRoom: detail, enteredRoomId: id);
          _ws.connect(userUuid: userUuid, roomId: id.toString());
        }
      }
    } catch (_) {}
  }

  Future<void> createRoom(String name, String creatorUuid) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _api.createRoom(name: name, creatorUuid: creatorUuid);
      final detail = await _api.fetchRoom(room.roomId);
      final jids = [...state.joinedRoomIds];
      if (!jids.contains(room.roomId)) jids.add(room.roomId);
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
      if (!jids.contains(roomId)) jids.add(roomId);
      state = state.copyWith(
        isLoading: false,
        currentRoom: detail,
        enteredRoomId: roomId,
        joinedRoomIds: jids,
        playlist: detail.playlist,
      );
      _ws.disconnect();
      _ws.connect(userUuid: userUuid, roomId: roomId.toString());

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> leaveRoom(String userUuid) async {
    if (state.currentRoom == null) return null;
    final roomId = state.currentRoom!.roomId;
    _ws.disconnect();
    try {
      await _api.leaveRoom(roomId: roomId, userUuid: userUuid);
      // API succeeded — permanently remove from joined rooms
      final jids = state.joinedRoomIds.where((id) => id != roomId).toList();
      state = RoomState(roomCache: state.roomCache, joinedRoomIds: jids);
      return null;
    } catch (e) {
      // API failed (e.g. owner can't leave) — keep membership, just disconnect locally
      state = state.copyWith(
        currentRoom: null,
        enteredRoomId: null,
        onlineUsers: const [],
        playlist: const [],
      );
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
    final playlist = (data['playlist'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final owner = data['owner'] as String?;
    state = state.copyWith(playlist: playlist, ownerUuid: owner);
  }

  void updateOnlineUsers(List<String> users) => state = state.copyWith(onlineUsers: users);
  void updatePlaylist(List<String> playlist) => state = state.copyWith(playlist: playlist);
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
