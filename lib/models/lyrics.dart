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
  final bool? trailingSpace;

  const LyricWord({
    required this.startTime,
    required this.duration,
    required this.text,
    this.trailingSpace,
  });
}

class Lyrics {
  final List<LyricLine> lines;
  final List<LyricLine>? transLines;

  const Lyrics({required this.lines, this.transLines});

  bool get hasWordTiming => lines.any((l) => l.words != null && l.words!.isNotEmpty);
  bool get hasTranslation => transLines != null && transLines!.isNotEmpty;

  static List<LyricLine> _parseLrc(String text) {
    final lines = <LyricLine>[];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)');

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
        final rawText = wm.group(3) ?? '';
        final trailingSpace = rawText.endsWith(' ');
        final wText = rawText.trim();
        if (wText.isNotEmpty) {
          // YRC 格式中 word time 是绝对时间（相对歌曲开头），
          // LyricWord.startTime 需要是相对行首的时间
          words.add(LyricWord(
            startTime: Duration(milliseconds: wStart - startMs),
            duration: Duration(milliseconds: wDur),
            text: wText,
            trailingSpace: trailingSpace,
          ));
        }
      }

      // 用 displayText 做纯文本显示，词间按需要补空格
      String displayText;
      if (words.isNotEmpty) {
        final buf = StringBuffer();
        for (int j = 0; j < words.length; j++) {
          buf.write(words[j].text);
          if (words[j].trailingSpace == true && j < words.length - 1) {
            buf.write(' ');
          }
        }
        displayText = buf.toString();
      } else {
        displayText = content.replaceAll(RegExp(r'\(\d+,\d+,\d+\)'), '').trim();
      }

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

  /// 从嵌套结构提取歌词文本：支持直接字符串或 {version, lyric} 对象两种格式
  static String? _extractLyricText(dynamic field) {
    if (field == null) return null;
    if (field is String) return field;
    if (field is Map<String, dynamic>) return field['lyric'] as String?;
    return null;
  }

  factory Lyrics.fromServerResponse(Map<String, dynamic> json) {
    final lrcText = _extractLyricText(json['lrc']);
    final yrcText = _extractLyricText(json['yrc']);
    final tlyricText = _extractLyricText(json['tlyric']);

    final hasYrc = yrcText != null && yrcText.isNotEmpty;
    final lines = hasYrc ? _parseYrc(yrcText) : _parseLrc(lrcText ?? '');
    final transLines = tlyricText != null && tlyricText.isNotEmpty
        ? _parseLrc(tlyricText)
        : null;

    return Lyrics(lines: lines, transLines: transLines);
  }

  /// 为每个原始歌词行匹配翻译行：优先按行号匹配，兜底用时间就近匹配
  String? getTranslationForLine(LyricLine line) {
    if (transLines == null || transLines!.isEmpty) return null;

    // 首选：同序号匹配（绝大多数歌曲原文和译文一一对应）
    final idx = lines.indexOf(line);
    if (idx >= 0 && idx < transLines!.length) {
      final match = transLines![idx];
      if ((match.time - line.time).inMilliseconds.abs() < 8000) {
        return match.text;
      }
    }

    // 兜底：最近时间匹配
    LyricLine? best;
    var bestDiff = double.infinity;
    for (final tl in transLines!) {
      final diff = (tl.time - line.time).inMilliseconds.abs();
      if (diff < bestDiff) {
        bestDiff = diff.toDouble();
        best = tl;
      }
    }
    return bestDiff < 8000 ? best?.text : null;
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
