class User {
  final String userUuid;
  final String userName;
  final String nickname;
  final String? avatarUrl;
  final String role;
  final String status;

  const User({
    required this.userUuid,
    required this.userName,
    required this.nickname,
    this.avatarUrl,
    required this.role,
    required this.status,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        userUuid: json['user_uuid'] as String,
        userName: json['user_name'] as String,
        nickname: json['nickname'] as String,
        avatarUrl: json['avatar_url'] as String?,
        role: json['role'] as String? ?? 'user',
        status: json['status'] as String? ?? 'offline',
      );

  Map<String, dynamic> toJson() => {
        'user_uuid': userUuid,
        'user_name': userName,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'role': role,
        'status': status,
      };

  User copyWith({
    String? userUuid,
    String? userName,
    String? nickname,
    String? avatarUrl,
    String? role,
    String? status,
  }) =>
      User(
        userUuid: userUuid ?? this.userUuid,
        userName: userName ?? this.userName,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        status: status ?? this.status,
      );

  bool get isAdmin => role == 'admin';
  bool get isOnline => status == 'online';
}
