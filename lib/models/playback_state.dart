class PlaybackState {
  final String trackId;
  final bool isPlaying;
  final int positionMs;
  final DateTime serverTimestamp;

  const PlaybackState({
    required this.trackId,
    required this.isPlaying,
    required this.positionMs,
    required this.serverTimestamp,
  });

  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    int pos = 0;
    final rawPos = json['pos'];
    if (rawPos is int) {
      pos = rawPos;
    } else if (rawPos is double) {
      pos = rawPos.toInt();
    }

    return PlaybackState(
      trackId: json['track_id'] as String? ?? '',
      isPlaying: (json['is_playing'] ?? json['is_played']) as bool? ?? false,
      positionMs: pos,
      serverTimestamp: now,
    );
  }

  Duration get position => Duration(milliseconds: positionMs);

  PlaybackState copyWith({
    String? trackId,
    bool? isPlaying,
    int? positionMs,
    DateTime? serverTimestamp,
  }) =>
      PlaybackState(
        trackId: trackId ?? this.trackId,
        isPlaying: isPlaying ?? this.isPlaying,
        positionMs: positionMs ?? this.positionMs,
        serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      );
}
