import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:suika_multi_player/models/lyrics.dart';
import 'package:suika_multi_player/models/track.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/providers/websocket_provider.dart';
import 'package:suika_multi_player/services/api_service.dart';
import 'package:suika_multi_player/services/netease_service.dart';
import 'package:suika_multi_player/services/websocket_service.dart';

final neteaseServiceProvider = Provider<NeteaseService>((ref) => NeteaseService());

class SearchNotifier extends StateNotifier<AsyncValue<List<Track>>> {
  final NeteaseService _netease;
  SearchNotifier(this._netease) : super(const AsyncValue.data([]));

  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) { state = const AsyncValue.data([]); return; }
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _netease.search(keyword));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  void clear() => state = const AsyncValue.data([]);
}

final searchProvider = StateNotifierProvider.autoDispose<SearchNotifier, AsyncValue<List<Track>>>((ref) {
  return SearchNotifier(ref.watch(neteaseServiceProvider));
});

class TrackCache extends StateNotifier<Map<String, Track>> {
  final NeteaseService _netease;
  TrackCache(this._netease) : super({});

  void cache(Track track) {
    if (!state.containsKey(track.id)) state = {...state, track.id: track};
  }

  void cacheAll(List<Track> tracks) {
    final m = Map<String, Track>.from(state);
    for (final t in tracks) {
      if (!m.containsKey(t.id)) m[t.id] = t;
    }
    state = m;
  }

  Future<void> fetchIfNeeded(String trackId) async {
    if (state.containsKey(trackId)) return;
    try {
      final detail = await _netease.getTrackDetail(trackId);
      if (detail != null) state = {...state, trackId: detail};
    } catch (_) {}
  }

  Track? getTrack(String trackId) => state[trackId];
}

final trackCacheProvider = StateNotifierProvider<TrackCache, Map<String, Track>>((ref) {
  return TrackCache(ref.watch(neteaseServiceProvider));
});

class LyricsNotifier extends StateNotifier<AsyncValue<Lyrics?>> {
  final ApiService _api;
  LyricsNotifier(this._api) : super(const AsyncValue.data(null));
  String? _currentTrackId;

  Future<void> fetchLyrics(String trackId) async {
    if (trackId == _currentTrackId) return;
    _currentTrackId = trackId;
    if (trackId.isEmpty) { state = const AsyncValue.data(null); return; }
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(Lyrics.fromServerResponse(await _api.getLyrics(trackId)));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<String?> getMusicUrl(String trackId) async {
    try { return await _api.getMusicLink(trackId); } catch (_) { return null; }
  }
}

final lyricsProvider = StateNotifierProvider.autoDispose<LyricsNotifier, AsyncValue<Lyrics?>>((ref) {
  return LyricsNotifier(ref.watch(apiServiceProvider));
});

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerState {
  final PlayerStatus status;
  final Track? currentTrack;
  final String? error;
  final Duration position;
  final Duration duration;
  final double volume;
  const PlayerState({
    this.status = PlayerStatus.idle,
    this.currentTrack,
    this.error,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
  });
  PlayerState copyWith({
    PlayerStatus? status,
    Track? currentTrack,
    String? error,
    Duration? position,
    Duration? duration,
    double? volume,
  }) =>
      PlayerState(
        status: status ?? this.status,
        currentTrack: currentTrack ?? this.currentTrack,
        error: error ?? this.error,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
      );
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final ApiService _api;
  final WebsocketService _ws;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _errorSub;
  Timer? _posTimer;
  Completer<void>? _readyCompleter;
  DateTime _lastSeekTime = DateTime.now();

  PlayerNotifier(this._api, this._ws) : super(const PlayerState()) {
    _init();
  }

  void _init() {
    _playerStateSub = _audioPlayer.playerStateStream.listen((ps) {
      // 先处理 ready completer（独立判断，不影响 playing 状态更新）
      if (ps.processingState == ProcessingState.ready) {
        _readyCompleter?.complete();
        _readyCompleter = null;
      }
      // 再处理 playing 状态
      if (ps.processingState == ProcessingState.completed) {
        state = state.copyWith(status: PlayerStatus.idle, position: Duration.zero);
      } else if (ps.playing) {
        state = state.copyWith(status: PlayerStatus.playing);
      } else if (ps.processingState == ProcessingState.loading) {
        state = state.copyWith(status: PlayerStatus.loading);
      } else {
        if (state.status == PlayerStatus.playing || state.status == PlayerStatus.paused) {
          state = state.copyWith(status: PlayerStatus.paused);
        }
      }
    });

    _durationSub = _audioPlayer.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });

    _errorSub = _audioPlayer.playbackEventStream.listen((event) {
      // just_audio_windows 的 BufferingProgress 错误可安全忽略
    }, onError: (Object e) {
      state = state.copyWith(status: PlayerStatus.error, error: e.toString());
    });

    _posTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_audioPlayer.playing) {
        state = state.copyWith(position: _audioPlayer.position);
      }
    });
  }

  /// 播放器是否已缓冲就绪（可安全 seek）
  bool get isReady =>
      _audioPlayer.playerState.processingState == ProcessingState.ready ||
      _audioPlayer.playing;

  /// 距离上次 seek 的时间，用于防止频繁 seek 打断 Windows 音频管道
  Duration get _timeSinceLastSeek => DateTime.now().difference(_lastSeekTime);

  Future<void> playTrack(Track track) async {
    state = state.copyWith(status: PlayerStatus.loading, currentTrack: track);
    try {
      final url = await _api.getMusicLink(track.id);
      _readyCompleter = Completer<void>();
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      state = state.copyWith(status: PlayerStatus.error, error: e.toString());
    }
  }

  /// 由服务器 play_track 消息触发 — 加载音频，seek 到服务器位置，再按需播放
  Future<void> playTrackFromServer(Track track, int serverPos, bool isPlaying) async {
    state = state.copyWith(status: PlayerStatus.loading, currentTrack: track);
    try {
      final url = await _api.getMusicLink(track.id);
      _readyCompleter = Completer<void>();
      await _audioPlayer.setUrl(url);

      // 等待播放器进入 ready 状态再 seek，避免打断 Windows 音频初始化
      await _readyCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
      _readyCompleter = null;

      if (serverPos > 0) {
        await _audioPlayer.seek(Duration(milliseconds: serverPos));
        _lastSeekTime = DateTime.now();
      }
      if (isPlaying) {
        await _audioPlayer.play();
      }
    } catch (e) {
      state = state.copyWith(status: PlayerStatus.error, error: e.toString());
    }
  }

  /// 由 playback_state 同步调用 — 只在必要时 seek，避免频繁打断播放
  Future<void> syncSeek(int targetMs) async {
    if (!isReady) return;
    // 冷却期 2 秒，避免连续 seek 打断 Windows Media Foundation 管道
    if (_timeSinceLastSeek < const Duration(seconds: 2)) return;

    final localMs = _audioPlayer.position.inMilliseconds;
    if ((targetMs - localMs).abs() > 1000) {
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
      _lastSeekTime = DateTime.now();
    }
  }

  Future<void> stop() async {
    _readyCompleter = null;
    try {
      await _audioPlayer.stop();
      state = state.copyWith(status: PlayerStatus.idle, position: Duration.zero, currentTrack: null);
    } catch (_) {}
  }

  Future<void> togglePlayPause() async {
    if (state.currentTrack == null) return;
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      _ws.sendPause();
    } else if (state.status == PlayerStatus.idle) {
      await playTrack(state.currentTrack!);
    } else {
      await _audioPlayer.play();
      _ws.sendResume();
    }
  }

  void seek(Duration pos) {
    _audioPlayer.seek(pos);
    state = state.copyWith(position: pos);
    _lastSeekTime = DateTime.now();
    _ws.sendSeek(pos.inMilliseconds);
  }

  AudioPlayer get audioPlayer => _audioPlayer;
  Track? get currentTrack => state.currentTrack;
  Duration get position => _audioPlayer.position;
  Duration? get duration => _audioPlayer.duration;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  bool get playing => _audioPlayer.playing;
  double get volume => state.volume;
  set volume(double v) {
    _audioPlayer.setVolume(v);
    state = state.copyWith(volume: v);
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _errorSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref.watch(apiServiceProvider), ref.watch(websocketProvider));
});
