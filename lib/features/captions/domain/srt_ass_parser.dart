import 'caption_cue.dart';
import 'srt_document.dart';

abstract final class SrtAssParser {
  static String toSrt(Iterable<CaptionCue> cues) => buildSrtDocument(
        cues.map(
          (cue) => SrtEntry(
            startMicroseconds: (cue.start * 1000000).round(),
            endMicroseconds: (cue.end * 1000000).round(),
            text: cue.text,
          ),
        ),
      );

  static List<CaptionCue> parseSrt(String source) {
    final blocks = source.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
    final cues = <CaptionCue>[];
    for (final block in blocks) {
      final lines =
          block.split('\n').where((line) => line.trim().isNotEmpty).toList();
      if (lines.length < 2) continue;
      final timingIndex = lines.indexWhere((line) => line.contains('-->'));
      if (timingIndex < 0) continue;
      final timing = lines[timingIndex].split('-->');
      if (timing.length != 2) continue;
      final start = _seconds(timing[0]);
      final end = _seconds(timing[1]);
      if (start == null || end == null || end <= start) continue;
      cues.add(
        CaptionCue(
          id: 'caption-${cues.length + 1}',
          start: start,
          end: end,
          text: lines.skip(timingIndex + 1).join('\n'),
        ),
      );
    }
    return cues;
  }

  static double? _seconds(String value) {
    final match =
        RegExp(r'^(\d+):(\d{2}):(\d{2})[,.](\d{3})$').firstMatch(value.trim());
    if (match == null) return null;
    return int.parse(match.group(1)!) * 3600 +
        int.parse(match.group(2)!) * 60 +
        int.parse(match.group(3)!) +
        int.parse(match.group(4)!) / 1000;
  }
}
