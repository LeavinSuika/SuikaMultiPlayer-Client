import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suika_multi_player/config/api_config.dart';
import 'package:suika_multi_player/providers/auth_provider.dart';
import 'package:suika_multi_player/utils/storage.dart';

class ServerConfig {
  final String host;
  final int port;
  final bool useSSL;

  const ServerConfig({required this.host, required this.port, required this.useSSL});

  String get address => '$host:$port';
  String get baseUrl => '${useSSL ? "https" : "http"}://$host:$port';
  String get wsBaseUrl => '${useSSL ? "wss" : "ws"}://$host:$port';
}

class ServerConfigNotifier extends StateNotifier<ServerConfig> {
  final StorageService _storage;

  ServerConfigNotifier(this._storage, ServerConfig initial)
      : super(initial);

  Future<void> update(String host, int port) async {
    ApiConfig.host = host;
    ApiConfig.port = port;
    state = ServerConfig(host: host, port: port, useSSL: state.useSSL);
    await _storage.setString('server_host', host);
    await _storage.setString('server_port', port.toString());
  }

  Future<void> setUseSSL(bool value) async {
    ApiConfig.useSSL = value;
    state = ServerConfig(host: state.host, port: state.port, useSSL: value);
    await _storage.setString('server_use_ssl', value.toString());
  }
}

final serverConfigProvider =
    StateNotifierProvider<ServerConfigNotifier, ServerConfig>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final savedHost = storage.getString('server_host');
  final savedPortStr = storage.getString('server_port');
  final savedUseSSL = storage.getString('server_use_ssl');
  final host = (savedHost != null && savedHost.isNotEmpty)
      ? savedHost
      : ApiConfig.host;
  final port = int.tryParse(savedPortStr ?? '') ?? ApiConfig.port;
  final useSSL = (savedUseSSL != null)
      ? (savedUseSSL == 'true')
      : ApiConfig.useSSL;
  ApiConfig.host = host;
  ApiConfig.port = port;
  ApiConfig.useSSL = useSSL;
  return ServerConfigNotifier(storage, ServerConfig(host: host, port: port, useSSL: useSSL));
});
