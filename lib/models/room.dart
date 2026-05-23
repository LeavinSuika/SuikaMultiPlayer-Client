class PlaylistEntry {
  final String trackId;
  final String? addedBy;

  const PlaylistEntry({required this.trackId, this.addedBy});

  factory PlaylistEntry.fromJson(dynamic data) {
    if (data is String) return PlaylistEntry(trackId: data);
    if (data is Map<String, dynamic>) {
      return PlaylistEntry(
        trackId: data['track_id'] as String? ?? '',
        addedBy: data['added_by'] as String?,
      );
    }
    return const PlaylistEntry(trackId: '');
  }

  @override
  bool operator ==(Object other) =>
      other is PlaylistEntry && other.trackId == trackId;

  @override
  int get hashCode => trackId.hashCode;
}

class Room {
  final int roomId;
  final String name;
  final String creatorUuid;
  final bool isPublic;
  final DateTime createdAt;

  const Room({
    required this.roomId,
    required this.name,
    required this.creatorUuid,
    required this.isPublic,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        roomId: json['room_id'] as int,
        name: json['name'] ?? json['room_name'] as String,
        creatorUuid: json['creator_uuid'] as String,
        isPublic: json['is_public'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'name': name,
        'creator_uuid': creatorUuid,
        'is_public': isPublic,
        'created_at': createdAt.toIso8601String(),
      };
}

class RoomMember {
  final String userUuid;
  final String role;

  const RoomMember({required this.userUuid, required this.role});

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        userUuid: json['user_uuid'] as String,
        role: json['role'] as String? ?? 'member',
      );

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
}

class RoomDetail {
  final int roomId;
  final String roomName;
  final String creatorUuid;
  final bool isPublic;
  final List<String> roomMembers;
  final List<RoomMember> roomMembersDetail;
  final int count;
  final List<PlaylistEntry> playlist;
  final Map<String, dynamic>? playstatus;

  const RoomDetail({
    required this.roomId,
    required this.roomName,
    required this.creatorUuid,
    required this.isPublic,
    required this.roomMembers,
    this.roomMembersDetail = const [],
    required this.count,
    this.playlist = const <PlaylistEntry>[],
    this.playstatus,
  });

  factory RoomDetail.fromJson(Map<String, dynamic> json) => RoomDetail(
        roomId: json['room_id'] as int,
        roomName: json['room_name'] as String? ?? '',
        creatorUuid: json['creator_uuid'] as String,
        isPublic: json['is_public'] == true || json['is_public'] == 1,
        roomMembers: (json['room_members'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        roomMembersDetail: (json['room_members_detail'] as List<dynamic>?)
                ?.map((e) => RoomMember.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        count: json['count'] as int? ?? 0,
        playlist: (json['playlist'] as List<dynamic>?)
                ?.map((e) => PlaylistEntry.fromJson(e))
                .toList() ??
            [],
        playstatus: json['playstatus'] as Map<String, dynamic>?,
      );

  RoomMember? getMember(String uuid) {
    try {
      return roomMembersDetail.firstWhere((m) => m.userUuid == uuid);
    } catch (_) {
      return null;
    }
  }
}
