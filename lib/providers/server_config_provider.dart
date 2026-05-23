import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/utils/storage.dart';

class ServerConfig {
  final String host;
  final int port;

  const ServerConfig({required this.host, required this.port});

  String get address => '$host:$port';
  String get baseUrl => 'http://$host:$port';
  String get wsBaseUrl => 'ws://$host:$port';
}

class ServerConfigNotifier extends StateNotifier<ServerConfig> {
  final StorageService _storage;

  ServerConfigNotifier(this._storage, ServerConfig initial)
      : super(initial);

  Future<void> update(String host, int port) async {
    ApiConfig.host = host;
    ApiConfig.port = port;
    state = ServerConfig(host: host, port: port);
    await _storage.setString('server_host', host);
    await _storage.setString('server_port', port.toString());
  }
}

final serverConfigProvider =
    StateNotifierProvider<ServerConfigNotifier, ServerConfig>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final savedHost = storage.getString('server_host');
  final savedPortStr = storage.getString('server_port');
  final host = (savedHost != null && savedHost.isNotEmpty)
      ? savedHost
      : ApiConfig.host;
  final port = int.tryParse(savedPortStr ?? '') ?? ApiConfig.port;
  ApiConfig.host = host;
  ApiConfig.port = port;
  return ServerConfigNotifier(storage, ServerConfig(host: host, port: port));
});
