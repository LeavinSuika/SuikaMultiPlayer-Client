import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/models/playback_state.dart';
import 'package:suika_multi_player/services/websocket_service.dart';

final globalWsProvider = Provider<GlobalWebsocketService>((ref) {
  final ws = GlobalWebsocketService();
  ref.onDispose(() => ws.dispose());
  return ws;
});

final websocketProvider = Provider<WebsocketService>((ref) {
  final ws = WebsocketService();
  ref.onDispose(() => ws.dispose());
  return ws;
});

class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final WebsocketService _ws;
  StreamSubscription? _sub;

  PlaybackNotifier(this._ws)
      : super(PlaybackState(
          trackId: '',
          isPlaying: false,
          positionMs: 0,
          serverTimestamp: DateTime.now(),
        )) {
    _sub = _ws.messages.listen((msg) {
      if (msg.type == 'playback_state') {
        state = PlaybackState.fromJson(msg.data);
      } else if (msg.type == 'pause_event') {
        final isPaused = msg.data['is_paused'] as bool? ?? false;
        state = state.copyWith(isPlaying: !isPaused);
      }
    });
  }

  void onLocalPositionChanged(Duration position) {
    state = state.copyWith(positionMs: position.inMilliseconds);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final playbackProvider =
    StateNotifierProvider.autoDispose<PlaybackNotifier, PlaybackState?>((ref) {
  final ws = ref.watch(websocketProvider);
  return PlaybackNotifier(ws);
});
