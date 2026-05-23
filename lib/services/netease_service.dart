import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/utils/log_buffer.dart';

class NeteaseService {
  final Dio _dio;

  NeteaseService() : _dio = Dio(BaseOptions(
    baseUrl: 'https://music.163.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Referer': 'https://music.163.com/',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  )) {
    final lb = LogBuffer.instance;
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => lb.info('NETEASE', obj.toString()),
    ));
  }

  /// music.163.com 返回 content-type: text/plain，需手动解析 JSON
  Map<String, dynamic> _parseResp(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw FormatException('Unexpected response type: ${data.runtimeType}');
  }

  Future<List<Track>> search(String keyword, {int limit = 30}) async {
    LogBuffer.instance.info('NETEASE', 'Search: "$keyword"');
    try {
      final resp = await _dio.get('/api/search/get/web', queryParameters: {
        'csrf_token': 'hlpretag=',
        'hlposttag': '',
        's': keyword,
        'type': 1,
        'offset': 0,
        'total': true,
        'limit': limit,
      });
      final data = _parseResp(resp.data);
      final result = data['result'] as Map<String, dynamic>?;
      final songs = result?['songs'] as List<dynamic>? ?? [];
      final tracks = songs
          .map((s) => _parseTrack(s as Map<String, dynamic>))
          .toList();
      LogBuffer.instance.info('NETEASE', 'Search result: ${tracks.length} tracks');

      // 搜索接口不含 picUrl，批量查一次详情补封面
      final missingCoverIds = tracks
          .where((t) => t.coverUrl == null)
          .map((t) => t.id)
          .toList();
      if (missingCoverIds.isNotEmpty) {
        final details = await _batchDetail(missingCoverIds);
        for (int i = 0; i < tracks.length; i++) {
          final cover = details[tracks[i].id];
          if (cover != null) {
            tracks[i] = Track(
              id: tracks[i].id,
              name: tracks[i].name,
              artist: tracks[i].artist,
              album: tracks[i].album,
              coverUrl: cover,
              durationMs: tracks[i].durationMs,
              source: tracks[i].source,
            );
          }
        }
      }

      return tracks;
    } catch (e) {
      LogBuffer.instance.error('NETEASE', 'Search failed: $e');
      return [];
    }
  }

  /// 批量查询歌曲详情，返回 id → coverUrl 映射
  Future<Map<String, String>> _batchDetail(List<String> trackIds) async {
    final result = <String, String>{};
    try {
      final idsJson = '[${trackIds.join(',')}]';
      final resp = await _dio.get('/api/song/detail', queryParameters: {
        'ids': idsJson,
      });
      final data = _parseResp(resp.data);
      final songs = data['songs'] as List<dynamic>? ?? [];
      for (final s in songs) {
        final json = s as Map<String, dynamic>;
        final al = (json['al'] as Map<String, dynamic>?) ??
                   (json['album'] as Map<String, dynamic>?) ??
                   <String, dynamic>{};
        final picUrl = (al['picUrl'] ?? json['picUrl'])?.toString();
        if (picUrl != null && picUrl.isNotEmpty) {
          final encoded =
              Uri.encodeComponent('${picUrl.split('?').first}?param=200y200');
          result[json['id'].toString()] =
              '${ApiConfig.baseUrl}/api/img_proxy?url=$encoded';
        }
      }
      LogBuffer.instance.info('NETEASE', 'Batch detail: ${result.length}/${trackIds.length} covers');
    } catch (e) {
      LogBuffer.instance.error('NETEASE', 'Batch detail failed: $e');
    }
    return result;
  }

  Track _parseTrack(Map<String, dynamic> json) {
    // 适配 music.163.com 响应格式
    final al = json['al'] as Map<String, dynamic>? ??
              json['album'] as Map<String, dynamic>? ??
              <String, dynamic>{};
    final arList = (json['ar'] as List<dynamic>?) ??
                   (json['artists'] as List<dynamic>?) ??
                   [];
    final artist = arList.isNotEmpty
        ? (arList.first as Map<String, dynamic>)['name']?.toString() ?? ''
        : '';

    // 封面：优先 album.picUrl，其次 al.picUrl
    String? coverUrl;
    final picUrl = (al['picUrl'] ?? json['picUrl'])?.toString();
    if (picUrl != null && picUrl.isNotEmpty) {
      final encoded =
          Uri.encodeComponent('${picUrl.split('?').first}?param=200y200');
      coverUrl = '${ApiConfig.baseUrl}/api/img_proxy?url=$encoded';
      LogBuffer.instance.info('IMG', 'Cover proxy: $picUrl');
    }

    return Track(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artist: artist,
      album: al['name']?.toString(),
      coverUrl: coverUrl,
      durationMs: (json['dt'] as int?) ?? (json['duration'] as int?) ?? 0,
      source: 'netease',
    );
  }

  Future<Track?> getTrackDetail(String trackId) async {
    try {
      final resp = await _dio.get('/api/song/detail', queryParameters: {
        'ids': '[$trackId]',
      });
      final data = _parseResp(resp.data);
      final songs = data['songs'] as List<dynamic>? ?? [];
      if (songs.isEmpty) return null;
      return _parseTrack(songs.first as Map<String, dynamic>);
    } catch (e) {
      LogBuffer.instance.error('NETEASE', 'Detail failed: $e');
      return null;
    }
  }
}
