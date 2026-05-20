import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:suika_multi_player/config/api_config.dart';

enum WsConnectionState { disconnected, connecting, connected }

class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;

  const WebSocketMessage({required this.type, required this.data});
}

/// 全局 WebSocket — 登录后保持连接，处理心跳和在线状态
class GlobalWebsocketService {
  WebSocketChannel? _channel;
  Timer? _pingTimer;

  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  Stream<WebSocketMessage> get messages => _messageController.stream;
  Stream<WsConnectionState> get connectionState =>
      _connectionStateController.stream;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;
  bool get isConnected => _state == WsConnectionState.connected;

  void connect(String userUuid) {
    _state = WsConnectionState.connecting;
    _connectionStateController.add(_state);

    final uri = Uri.parse('${ApiConfig.globalWsUrl}?user_uuid=$userUuid');

    try {
      _channel = WebSocketChannel.connect(uri);
      _state = WsConnectionState.connected;
      _connectionStateController.add(_state);
      _startPing();

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final type = json['type'] as String? ?? '';
            _messageController
                .add(WebSocketMessage(type: type, data: json));
          } catch (_) {}
        },
        onError: (_) => _onDisconnected(),
        onDone: () => _onDisconnected(),
      );
    } catch (_) {
      _onDisconnected();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null && _state == WsConnectionState.connected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (_) {}
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _state = WsConnectionState.disconnected;
    _connectionStateController.add(_state);
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _state = WsConnectionState.disconnected;
    _connectionStateController.add(_state);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}

class WebsocketService {
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  int _generation = 0;

  String? _roomId;
  String? _userUuid;

  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  Stream<WebSocketMessage> get messages => _messageController.stream;
  Stream<WsConnectionState> get connectionState =>
      _connectionStateController.stream;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  bool get isConnected => _state == WsConnectionState.connected;

  void connect({required String userUuid, required String roomId}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _userUuid = userUuid;
    _roomId = roomId;
    _doConnect();
  }

  void _doConnect() {
    if (_userUuid == null || _roomId == null) return;
    final gen = ++_generation;
    _setState(WsConnectionState.connecting);

    final uri = Uri.parse(
        '${ApiConfig.wsBaseUrl}/ws/room/$_roomId?user_uuid=$_userUuid');

    try {
      _channel = WebSocketChannel.connect(uri);
      _setState(WsConnectionState.connected);
      _reconnectAttempt = 0;
      _startPing();

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final type = json['type'] as String? ?? '';
            _messageController.add(WebSocketMessage(type: type, data: json));
          } catch (_) {}
        },
        onError: (_) => _handleDisconnect(gen),
        onDone: () => _handleDisconnect(gen),
      );
    } catch (_) {
      _handleDisconnect(gen);
    }
  }

  void _handleDisconnect([int? gen]) {
    // Ignore disconnect from stale connections
    if (gen != null && gen != _generation) return;
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(WsConnectionState.disconnected);
    _startReconnect();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      send({'type': 'ping'});
    });
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null && _state == WsConnectionState.connected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (_) {}
    }
  }

  void sendPlaylistAdd(List<Map<String, dynamic>> tracks) {
    send({
      'type': 'playlist_add',
      'tracks': tracks,
    });
  }

  void sendPlaylistRemove(List<String> trackIds) {
    send({
      'type': 'playlist_remove',
      'tracks': trackIds,
    });
  }

  void sendPause() {
    send({'type': 'pause'});
  }

  void sendResume() {
    send({'type': 'resume'});
  }

  void sendSeek(int positionMs) {
    send({'type': 'seek', 'pos': positionMs});
  }

  void sendSkip() {
    send({'type': 'skip'});
  }

  void _startReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempt >= 10) return;
    final delay = _reconnectAttempt < 3 ? 1000 : 5000;
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _reconnectAttempt++;
      if (_userUuid != null && _roomId != null) {
        _doConnect();
      }
    });
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(WsConnectionState.disconnected);
    _userUuid = null;
    _roomId = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
