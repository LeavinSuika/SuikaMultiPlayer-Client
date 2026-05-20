class LyricLine {
  final Duration time;
  final String text;
  final List<LyricWord>? words;
  final Duration duration;

  const LyricLine({
    required this.time,
    required this.text,
    this.words,
    this.duration = Duration.zero,
  });
}

class LyricWord {
  final Duration startTime;
  final Duration duration;
  final String text;

  const LyricWord({
    required this.startTime,
    required this.duration,
    required this.text,
  });
}

class Lyrics {
  final List<LyricLine> lines;
  final List<LyricLine>? transLines;

  const Lyrics({required this.lines, this.transLines});

  bool get hasWordTiming => lines.any((l) => l.words != null && l.words!.isNotEmpty);

  static List<LyricLine> _parseLrc(String text) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

    for (final line in text.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match == null) continue;
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      var msStr = match.group(3)!;
      if (msStr.length == 2) msStr = '${msStr}0';
      final ms = int.parse(msStr);
      final txt = match.group(4)?.trim() ?? '';

      lines.add(LyricLine(
        time: Duration(minutes: min, seconds: sec, milliseconds: ms),
        text: txt,
      ));
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  static List<LyricLine> _parseYrc(String text) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d+),(\d+)\](.*)');
    final wordRegExp = RegExp(r'\((\d+),(\d+),\d+\)([^(]+)');

    for (final line in text.split('\n')) {
      final match = regExp.firstMatch(line.trim());
      if (match == null) continue;

      final startMs = int.parse(match.group(1)!);
      final durationMs = int.parse(match.group(2)!);
      final content = match.group(3)?.trim() ?? '';

      final words = <LyricWord>[];
      for (final wm in wordRegExp.allMatches(content)) {
        final wStart = int.parse(wm.group(1)!);
        final wDur = int.parse(wm.group(2)!);
        final wText = wm.group(3)?.trim() ?? '';
        if (wText.isNotEmpty) {
          words.add(LyricWord(
            startTime: Duration(milliseconds: wStart),
            duration: Duration(milliseconds: wDur),
            text: wText,
          ));
        }
      }

      final plainText = content.replaceAll(wordRegExp, '').trim();
      final displayText = words.isNotEmpty
          ? words.map((w) => w.text).join()
          : plainText;

      lines.add(LyricLine(
        time: Duration(milliseconds: startMs),
        text: displayText,
        words: words.isNotEmpty ? words : null,
        duration: Duration(milliseconds: durationMs),
      ));
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  factory Lyrics.fromServerResponse(Map<String, dynamic> json) {
    final raw = json['lrc'] ?? json;
    final lrcText = raw['lrc'] as String?;
    final yrcText = raw['yrc'] as String?;
    final tlyricText = raw['tlyric'] as String?;

    final hasYrc = yrcText != null && yrcText.isNotEmpty;
    final lines = hasYrc ? _parseYrc(yrcText) : _parseLrc(lrcText ?? '');
    final transLines = tlyricText != null && tlyricText.isNotEmpty
        ? _parseLrc(tlyricText)
        : null;

    return Lyrics(lines: lines, transLines: transLines);
  }

  int findCurrentIndex(Duration position) {
    var idx = 0;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= position) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }
}
