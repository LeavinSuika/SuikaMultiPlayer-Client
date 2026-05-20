import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
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
  final Player _player = Player();
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _errorSub;
  Completer<void>? _readyCompleter;
  DateTime _lastSeekTime = DateTime.now();

  PlayerNotifier(this._api, this._ws) : super(const PlayerState()) {
    _init();
  }

  bool _hasStartedPlaying = false;

  void _init() {
    _playingSub = _player.stream.playing.listen((playing) {
      if (playing) {
        _hasStartedPlaying = true;
        state = state.copyWith(status: PlayerStatus.playing);
        if (_readyCompleter != null) {
          _readyCompleter!.complete();
          _readyCompleter = null;
        }
      } else {
        if (state.status == PlayerStatus.playing ||
            state.status == PlayerStatus.paused) {
          state = state.copyWith(status: PlayerStatus.paused);
        }
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (buffering && !_hasStartedPlaying) {
        // 只在首次加载时设为 loading，播放中的重新缓冲不改变 UI 状态
        state = state.copyWith(status: PlayerStatus.loading);
      }
      if (!buffering && _player.state.duration > Duration.zero) {
        if (_readyCompleter != null) {
          _readyCompleter!.complete();
          _readyCompleter = null;
        }
      }
    });

    _durationSub = _player.stream.duration.listen((d) {
      if (d > Duration.zero) state = state.copyWith(duration: d);
    });

    _positionSub = _player.stream.position.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _completedSub = _player.stream.completed.listen((_) {
      state = state.copyWith(
          status: PlayerStatus.idle, position: Duration.zero);
    });

    _errorSub = _player.stream.error.listen((e) {
      state = state.copyWith(status: PlayerStatus.error, error: e.toString());
    });
  }

  /// 播放器是否已缓冲就绪（可安全 seek）
  bool get isReady =>
      !_player.state.buffering && _player.state.duration > Duration.zero;

  Duration get _timeSinceLastSeek =>
      DateTime.now().difference(_lastSeekTime);

  Future<void> playTrack(Track track) async {
    _hasStartedPlaying = false;
    state =
        state.copyWith(status: PlayerStatus.loading, currentTrack: track);
    try {
      final url = await _api.getMusicLink(track.id);
      _readyCompleter = Completer<void>();
      await _player.open(Media(url));
      await _player.play();
    } catch (e) {
      state =
          state.copyWith(status: PlayerStatus.error, error: e.toString());
    }
  }

  /// 由服务器 play_track 消息触发 — 不自动播放加载 → seek → 按需播放
  Future<void> playTrackFromServer(
      Track track, int serverPos, bool isPlaying) async {
    _hasStartedPlaying = false;
    state =
        state.copyWith(status: PlayerStatus.loading, currentTrack: track);
    try {
      final url = await _api.getMusicLink(track.id);

      // 1. 加载媒体但不自动播放（play: false），防止输出位置 0 的音频
      final openReady = Completer<void>();
      _readyCompleter = openReady;
      await _player.open(Media(url), play: false);
      // 等待缓冲就绪（listener 可能在 open 期间已完成 completer，所以用局部变量防 NPE）
      try {
        await openReady.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      } catch (_) {}

      // 2. 跳到同步位置
      if (serverPos > 0) {
        final seekReady = Completer<void>();
        _readyCompleter = seekReady;
        await _player.seek(Duration(milliseconds: serverPos));
        _lastSeekTime = DateTime.now();
        if (!_player.state.buffering) {
          seekReady.complete();
        }
        try {
          await seekReady.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () {},
          );
        } catch (_) {}
      }
      _readyCompleter = null;

      // 3. 按需播放
      if (isPlaying) {
        await _player.play();
      }
    } catch (e) {
      state =
          state.copyWith(status: PlayerStatus.error, error: e.toString());
    }
  }

  /// 由 playback_state 同步调用 — 只在必要时 seek，避免频繁打断播放
  Future<void> syncSeek(int targetMs) async {
    if (!isReady) return;
    if (_timeSinceLastSeek < const Duration(seconds: 2)) return;

    final localMs = _player.state.position.inMilliseconds;
    if ((targetMs - localMs).abs() > 1000) {
      await _player.seek(Duration(milliseconds: targetMs));
      _lastSeekTime = DateTime.now();
    }
  }

  Future<void> stop() async {
    _readyCompleter = null;
    try {
      await _player.stop();
      state = state.copyWith(
          status: PlayerStatus.idle,
          position: Duration.zero,
          currentTrack: null);
    } catch (_) {}
  }

  /// 仅供外部同步使用（main_shell pause/resume 消息）
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> togglePlayPause() async {
    if (state.currentTrack == null) return;
    if (_player.state.playing) {
      await _player.pause();
      _ws.sendPause();
    } else if (state.status == PlayerStatus.idle) {
      await playTrack(state.currentTrack!);
    } else {
      await _player.play();
      _ws.sendResume();
    }
  }

  void seek(Duration pos) {
    _player.seek(pos);
    state = state.copyWith(position: pos);
    _lastSeekTime = DateTime.now();
    _ws.sendSeek(pos.inMilliseconds);
  }

  // --- 公共 getter/setter（UI 通过 PlayerState 访问，不再暴露原生 Player）---
  // 音量内部存储为 0-1（匹配 Flutter Slider），调用 media_kit 时转换为 0-100
  Track? get currentTrack => state.currentTrack;
  Duration get position => _player.state.position;
  Duration? get duration => _player.state.duration;
  bool get playing => _player.state.playing;
  double get volume => state.volume;
  set volume(double v) {
    _player.setVolume(v * 100);
    state = state.copyWith(volume: v);
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref.watch(apiServiceProvider), ref.watch(websocketProvider));
});
