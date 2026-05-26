import 'package:dio/dio.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/models/room.dart';
import 'package:suika_multi_player/models/user.dart';
import 'package:suika_multi_player/utils/http_client.dart';

class ApiService {
  final Dio _dio = createDioClient();

  Dio get _client {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    return _dio;
  }

  Map<String, dynamic> _parse(Response resp) {
    return resp.data as Map<String, dynamic>;
  }

  Future<User> register({
    required String userName,
    required String pwd,
    required String nickname,
  }) async {
    final data = _parse(await _client.post('/api/register', data: {
      'user_name': userName,
      'pwd': pwd,
      'nickname': nickname,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '注册失败');
    }
    return User(
      userUuid: data['user_uuid'] as String,
      userName: userName,
      nickname: nickname,
      role: 'user',
      status: 'online',
    );
  }

  Future<User> login({
    required String userName,
    required String pwd,
  }) async {
    final data = _parse(await _client.post('/api/login', data: {
      'user_name': userName,
      'pwd': pwd,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '登录失败');
    }
    return User(
      userUuid: data['user_uuid'] as String,
      userName: userName,
      nickname: '',
      role: 'user',
      status: 'online',
    );
  }

  Future<User> fetchUser(String userUuid) async {
    final data = _parse(await _client.post('/api/fetch_user', data: {
      'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '获取用户失败');
    }
    return User.fromJson(data['user_info'] as Map<String, dynamic>);
  }

  Future<void> resetPwd({
    required String userUuid,
    required String oldPwd,
    required String newPwd,
  }) async {
    final data = _parse(await _client.post('/api/reset_pwd', data: {
      'user_uuid': userUuid,
      'old_pwd': oldPwd,
      'new_pwd': newPwd,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '修改密码失败');
    }
  }

  Future<void> updateNickname({
    required String userUuid,
    required String nickname,
  }) async {
    final data = _parse(await _client.post('/api/update_nickname', data: {
      'user_uuid': userUuid,
      'nickname': nickname,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '修改昵称失败');
    }
  }

  /// 上传图片到图床，返回 {image_id, url}
  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final filename = filePath.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final resp = await _client.post('/api/upload_image', data: formData);
    final data = _parse(resp);
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '上传图片失败');
    }
    return data;
  }

  Future<void> updateAvatar({
    required String userUuid,
    required String avatarUrl,
    required String avatarKey,
  }) async {
    final data = _parse(await _client.post('/api/update_avatar', data: {
      'user_uuid': userUuid,
      'avatar_url': avatarUrl,
      'avatar_key': avatarKey,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '修改头像失败');
    }
  }

  Future<Room> createRoom({
    required String name,
    required String creatorUuid,
    bool isPublic = true,
  }) async {
    final data = _parse(await _client.post('/api/create_room', data: {
      'name': name,
      'creator_uuid': creatorUuid,
      'is_public': isPublic,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '创建房间失败');
    }
    return Room(
      roomId: data['room_id'] as int,
      name: name,
      creatorUuid: creatorUuid,
      isPublic: isPublic,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteRoom({
    required String operatorUuid,
    required int roomId,
  }) async {
    final data = _parse(await _client.post('/api/delete_room', data: {
      'operator_uuid': operatorUuid,
      'room_id': roomId,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '删除房间失败');
    }
  }

  Future<RoomDetail> joinRoom({
    required int roomId,
    required String userUuid,
  }) async {
    final data = _parse(await _client.post('/api/join_room', data: {
      'room_id': roomId,
      'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '加入房间失败');
    }
    return RoomDetail.fromJson(data['details'] as Map<String, dynamic>);
  }

  Future<void> leaveRoom({
    required int roomId,
    required String userUuid,
  }) async {
    final data = _parse(await _client.post('/api/leave_room', data: {
      'room_id': roomId,
      'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '离开房间失败');
    }
  }

  Future<void> exitRoom({
    required int roomId,
    required String userUuid,
  }) async {
    final data = _parse(await _client.post('/api/exit_room', data: {
      'room_id': roomId,
      'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '退出房间失败');
    }
  }

  Future<RoomDetail> fetchRoom(int roomId, {String? userUuid}) async {
    final data = _parse(await _client.post('/api/fetch_room', data: {
      'room_id': roomId,
      if (userUuid != null) 'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '获取房间信息失败');
    }
    return RoomDetail.fromJson(data);
  }

  Future<List<String>> getRoomOnlineUsers(int roomId) async {
    final resp = await _client.get('/api/room/$roomId/online');
    final data = resp.data as Map<String, dynamic>;
    return (data['online'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
  }

  Future<String> getMusicLink(String trackId) async {
    final data = _parse(await _client.get('/api/music_link_get', data: {
      'track_id': trackId,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '获取音乐链接失败');
    }
    return data['url'] as String;
  }

  Future<Map<String, dynamic>> getLyrics(String trackId) async {
    final data = _parse(await _client.get('/api/lrc_link_get', data: {
      'track_id': trackId,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '获取歌词失败');
    }
    return data['lrc'] as Map<String, dynamic>;
  }

  Future<List<Room>> fetchRooms() async {
    final data = _parse(await _client.get('/api/rooms'));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '获取房间列表失败');
    }
    final list = data['rooms'] as List<dynamic>;
    return list.map((r) => Room.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> logout(String userUuid) async {
    await _client.post('/api/logout', data: {'user_uuid': userUuid});
  }

  Future<void> transferRoom({
    required String operatorUuid,
    required int roomId,
    required String toUuid,
  }) async {
    final data = _parse(await _client.post('/api/transfer_room', data: {
      'operator_uuid': operatorUuid,
      'room_id': roomId,
      'to_uuid': toUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '转让失败');
    }
  }

  Future<void> setRoomMemberRole({
    required String operatorUuid,
    required int roomId,
    required String userUuid,
    required String role,
  }) async {
    final data = _parse(await _client.post('/api/set_room_members_role', data: {
      'operator_uuid': operatorUuid,
      'room_id': roomId,
      'user_uuid': userUuid,
      'role': role,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '设置角色失败');
    }
  }

  Future<void> setRoomIsPublic({
    required String operatorUuid,
    required int roomId,
    required bool isPublic,
  }) async {
    final data = _parse(await _client.post('/api/set_room_is_public', data: {
      'operator_uuid': operatorUuid,
      'room_id': roomId,
      'is_public': isPublic,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '切换失败');
    }
  }

  Future<void> kickRoomMember({
    required String operatorUuid,
    required int roomId,
    required String userUuid,
  }) async {
    final data = _parse(await _client.post('/api/kick_room_member', data: {
      'operator_uuid': operatorUuid,
      'room_id': roomId,
      'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '踢出成员失败');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserRooms(String userUuid) async {
    final data = _parse(await _client.get('/api/user/$userUuid/rooms'));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '获取用户房间失败');
    }
    return (data['rooms'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<void> banUser({
    required String operatorUuid,
    required String userUuid,
    String? banReason,
    String? pardonTime,
  }) async {
    final data = _parse(await _client.post('/api/ban_user', data: {
      'operator_uuid': operatorUuid,
      'user_uuid': userUuid,
      if (banReason != null) 'ban_reason': banReason,
      if (pardonTime != null) 'pardon_time': pardonTime,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '封禁失败');
    }
  }

  Future<void> unbanUser({
    required String operatorUuid,
    required String userUuid,
  }) async {
    final data = _parse(await _client.post('/api/unban_user', data: {
      'operator_uuid': operatorUuid,
      'user_uuid': userUuid,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '解封失败');
    }
  }

  Future<void> banIp({
    required String operatorUuid,
    required String ip,
    String? banReason,
    String? pardonTime,
  }) async {
    final data = _parse(await _client.post('/api/ban_ip', data: {
      'operator_uuid': operatorUuid,
      'ip': ip,
      if (banReason != null) 'ban_reason': banReason,
      if (pardonTime != null) 'pardon_time': pardonTime,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '封禁IP失败');
    }
  }

  Future<void> unbanIp({
    required String operatorUuid,
    required String ip,
  }) async {
    final data = _parse(await _client.post('/api/unban_ip', data: {
      'operator_uuid': operatorUuid,
      'ip': ip,
    }));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '解封IP失败');
    }
  }

  Future<List<Map<String, dynamic>>> adminListUsers(
      String operatorUuid) async {
    final data = _parse(await _client.get(
        '/api/admin/users?operator_uuid=$operatorUuid'));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return (data['users'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> adminListBannedUsers(
      String operatorUuid) async {
    final data = _parse(await _client.get(
        '/api/admin/banned_users?operator_uuid=$operatorUuid'));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return (data['users'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> adminListBannedIps(
      String operatorUuid) async {
    final data = _parse(await _client.get(
        '/api/admin/banned_ips?operator_uuid=$operatorUuid'));
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '查询失败');
    }
    return (data['ips'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
