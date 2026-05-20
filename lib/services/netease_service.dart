import 'dart:async';
import 'package:dio/dio.dart';
import 'package:suika_multi_player/models/track.dart';

class NeteaseService {
  final Dio _dio;

  NeteaseService() : _dio = Dio(BaseOptions(
    baseUrl: 'https://netease-cloud-music-api-five-roan-88.vercel.app',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<List<Track>> search(String keyword, {int limit = 30}) async {
    try {
      final resp = await _dio.get('/cloudsearch', queryParameters: {
        'keywords': keyword,
        'limit': limit,
        'type': 1,
      });
      final data = resp.data as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>;
      final songs = result['songs'] as List<dynamic>? ?? [];
      return songs.map((s) => _parseTrack(s as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Track _parseTrack(Map<String, dynamic> json) {
    final al = json['al'] as Map<String, dynamic>? ?? {};
    final ar = json['ar'] as List<dynamic>? ?? [];
    final artist = ar.isNotEmpty
        ? (ar.first as Map<String, dynamic>)['name']?.toString() ?? ''
        : '';

    // Build cover URL via server proxy to bypass CDN issues on desktop
    String? coverUrl;
    final picUrl = al['picUrl']?.toString();
    if (picUrl != null && picUrl.isNotEmpty) {
      final encoded = Uri.encodeComponent('${picUrl.split('?').first}?param=200y200');
      coverUrl = 'http://127.0.0.1:8001/api/img_proxy?url=$encoded';
    }

    return Track(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artist: artist,
      album: al['name']?.toString(),
      coverUrl: coverUrl,
      durationMs: (json['dt'] as int?) ?? 0,
      source: 'netease',
    );
  }

  Future<Track?> getTrackDetail(String trackId) async {
    try {
      final resp = await _dio.get('/song/detail', queryParameters: {
        'ids': trackId,
      });
      final data = resp.data as Map<String, dynamic>;
      final songs = data['songs'] as List<dynamic>? ?? [];
      if (songs.isEmpty) return null;
      return _parseTrack(songs.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
