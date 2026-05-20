class ApiConfig {
  static String host = '127.0.0.1';
  static int port = 8001;

  static String get baseUrl => 'http://$host:$port';
  static String get wsBaseUrl => 'ws://$host:$port';
  static String get globalWsUrl => 'ws://$host:$port/ws';
}
