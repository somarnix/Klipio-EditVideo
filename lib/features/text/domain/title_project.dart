import '../../export/domain/export_models.dart';
import '../../timeline/domain/timeline_models.dart';
import 'title_visual_state.dart';

/// Adapter for the existing editable project schema. Typography remains in
/// textOverlays; timing/keyframes remain in the identified timeline instance.
abstract final class TitleProject {
  static List<TextOverlaySettings> decode(Object? value) {
    final rows = value is List ? value : const [];
    return List.unmodifiable([
      for (final entry in rows.indexed)
        if (entry.$2 case final Map row) _decode(row, entry.$1),
    ]);
  }

  static TextOverlaySettings _decode(Map row, int index) {
    double number(String key, double fallback) {
      final value = double.tryParse('${row[key] ?? ''}');
      return value != null && value.isFinite ? value : fallback;
    }

    final start = number('timelineStart', 0), duration = number('duration', 0);
    return TextOverlaySettings(
        id: '${row['id'] ?? 'text-legacy-${index + 1}'}',
        text: '${row['text'] ?? ''}',
        font: '${row['font'] ?? 'Arial'}',
        size: number('size', 44),
        x: number('x', .5),
        y: number('y', .75),
        startX: number('startX', .5),
        startY: number('startY', 1),
        color: '${row['color'] ?? '#FFFFFF'}',
        opacity: number('opacity', 1),
        stroke: number('stroke', 3),
        strokeColor: '${row['strokeColor'] ?? '#000000'}',
        strokeOpacity: number('strokeOpacity', .9),
        shadow: row['shadow'] != false,
        shadowColor: '${row['shadowColor'] ?? '#000000'}',
        shadowOpacity: number('shadowOpacity', .65),
        animation: '${row['animation'] ?? 'none'}',
        animationDuration: number('animationDuration', 1),
        timelineStart: start,
        timelineEnd: duration > 0 ? start + duration : 0,
        visible: row['isVisible'] != false,
        tracking: number('tracking', 0),
        curve: number('curve', 0));
  }

  static List<TextOverlaySettings> resolve(
          Object? value, TimelineModel outputTimeline) =>
      List.unmodifiable([
        for (final title in decode(value))
          if (outputTimeline.clipById(title.id)?.track.isMuted != true)
            TitleTimelineResolver.bind(title, outputTimeline)
      ]);
}
