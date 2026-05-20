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

class RoomDetail {
  final int roomId;
  final String roomName;
  final String creatorUuid;
  final bool isPublic;
  final List<String> roomMembers;
  final int count;
  final List<String> playlist;
  final Map<String, dynamic>? playstatus;

  const RoomDetail({
    required this.roomId,
    required this.roomName,
    required this.creatorUuid,
    required this.isPublic,
    required this.roomMembers,
    required this.count,
    this.playlist = const [],
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
        count: json['count'] as int? ?? 0,
        playlist: (json['playlist'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        playstatus: json['playstatus'] as Map<String, dynamic>?,
      );
}
