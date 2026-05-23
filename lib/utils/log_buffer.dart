import 'dart:io';

class LogBuffer {
  static final LogBuffer _instance = LogBuffer._();
  static LogBuffer get instance => _instance;
  LogBuffer._();

  final List<String> _lines = [];
  static const int _maxLines = 2000;

  void add(String level, String source, String message) {
    final ts = DateTime.now().toIso8601String();
    _lines.add('[$ts] [$level] [$source] $message');
    while (_lines.length > _maxLines) {
      _lines.removeAt(0);
    }
  }

  void info(String source, String message) => add('INFO', source, message);
  void warn(String source, String message) => add('WARN', source, message);
  void error(String source, String message) => add('ERROR', source, message);

  String export() => _lines.join('\n');

  Future<String> saveToFile() async {
    final dir = Directory.current;
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${dir.path}${Platform.pathSeparator}suika_debug_$stamp.log');
    await file.writeAsString(export());
    return file.path;
  }
}
