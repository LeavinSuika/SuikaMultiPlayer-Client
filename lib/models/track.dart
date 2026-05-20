class Track {
  final String id;
  final String name;
  final String artist;
  final String? album;
  final String? coverUrl;
  final int? durationMs;
  final String? source;

  const Track({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.coverUrl,
    this.durationMs,
    this.source,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? json['title'] as String? ?? '',
        artist: json['artist'] as String? ??
            (json['artists'] is List
                ? (json['artists'] as List)
                    .map((a) => a is Map ? a['name']?.toString() ?? '' : a.toString())
                    .join(', ')
                : '') ??
            '',
        album: json['album'] is Map
            ? json['album']['name']?.toString()
            : json['album']?.toString(),
        coverUrl: json['cover_url']?.toString() ??
            (json['album'] is Map
                ? json['album']['picUrl']?.toString()
                : null) ??
            json['picUrl']?.toString(),
        durationMs: json['duration_ms'] as int? ??
            json['duration'] as int?,
        source: json['source']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'artist': artist,
        'album': album,
        'cover_url': coverUrl,
        'duration_ms': durationMs,
        'source': source,
      };

  String get durationFormatted {
    if (durationMs == null) return '--:--';
    final totalSec = durationMs! ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
