class ApiConfig {
  static String host = '0.0.0.0';
  static int port = 8001;
  static bool useSSL = true;

  static String get _scheme => useSSL ? 'https' : 'http';
  static String get _wsScheme => useSSL ? 'wss' : 'ws';

  static String get baseUrl => '$_scheme://$host:$port';
  static String get wsBaseUrl => '$_wsScheme://$host:$port';
  static String get globalWsUrl => '$_wsScheme://$host:$port/ws';
}
