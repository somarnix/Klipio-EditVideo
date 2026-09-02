import 'dart:math' as math;
import '../domain/editable_caption.dart';
import '../domain/ass_text.dart';
import '../../export/domain/export_models.dart';
import '../../timeline/domain/timeline_models.dart';
import '../../text/domain/caption_visual_state.dart';

/// Production timeline caption adapter, extracted from the active editor.
/// Source-word clocks survive trimming; cue visibility remains half-open.
abstract final class CaptionProjectExport {
  static List<CaptionCueSettings> resolve(
    TimelineModel requestedTimeline, {
    required Map<String, List<EditableCaptionCue>> captions,
    required double timelineEnd,
    String textCase = 'none',
    bool sharedWordClock = true,
    TimelineModel? outputTimeline,
    Map<String, double> playbackSpeedsByMediaPath = const {},
  }) {
    final result = <CaptionCueSettings>[];
    final timeline = requestedTimeline;
    final renderedTimeline = outputTimeline ?? requestedTimeline;
    final outputClips = <String, ClipModel>{
      for (final track in renderedTimeline.videoTracks)
        for (final clip in track.clips) clip.id: clip,
    };
    for (final track in timeline.videoTracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        if (clip.isMuted) continue;
        final outputClip = outputClips[clip.id] ?? clip;
        final speed = clip
            .resolvedPlaybackSpeed(
                playbackSpeedsByMediaPath[clip.mediaPath] ?? 1)
            .clamp(0.25, 4.0)
            .toDouble();
        final cues = captions[clip.mediaPath] ?? const <EditableCaptionCue>[];
        for (final cue in cues) {
          final sourceStart = math.max(cue.start, clip.sourceStart);
          final sourceEnd = math.min(cue.end, clip.sourceEnd);
          if (sourceEnd - sourceStart <= 0.01) continue;
          final start = outputClip.timelineStart +
              (sourceStart - clip.sourceStart) / speed;
          final end =
              outputClip.timelineStart + (sourceEnd - clip.sourceStart) / speed;
          if (start >= timelineEnd || end <= 0) continue;
          final text = normalizeAssDisplayText(cue.text).trim();
          if (text.isEmpty) continue;
          // Bind the full cue before trimming timed words. Otherwise repeated
          // tokens preceding the trim can redirect the surviving word's range.
          final ranges = CaptionTimelineResolver(
              cueId: cue.id,
              text: text,
              start: cue.start,
              end: cue.end,
              textCase: textCase,
              words: cue.words.map((w) => CaptionTimedWord(
                  id: w.id,
                  text: w.text,
                  start: w.start,
                  end: w.end))).wordRangesById;
          result.add(
            CaptionCueSettings(
              id: '${cue.id}/clip/${clip.id}',
              start: start.clamp(0.0, timelineEnd).toDouble(),
              end: end.clamp(0.0, timelineEnd).toDouble(),
              text: text,
              x: cue.x,
              y: cue.y,
              words: List.unmodifiable([
                for (final word in cue.words)
                  if (word.end > sourceStart && word.start < sourceEnd)
                    CaptionWordSettings(
                      id: word.id,
                      // Explicit invalid ranges remain invalid after a trim;
                      // null would re-enable token matching in the adapter.
                      rangeStart: ranges[word.id]?.start ?? -1,
                      rangeEnd: ranges[word.id]?.end ?? -1,
                      // The cue clips visibility, not the animation clock.
                      start: sharedWordClock
                          ? outputClip.timelineStart +
                              (word.start - clip.sourceStart) / speed
                          : (outputClip.timelineStart +
                                  (math.max(word.start, sourceStart) -
                                          clip.sourceStart) /
                                      speed)
                              .clamp(0.0, timelineEnd)
                              .toDouble(),
                      end: sharedWordClock
                          ? outputClip.timelineStart +
                              (word.end - clip.sourceStart) / speed
                          : (outputClip.timelineStart +
                                  (math.min(word.end, sourceEnd) -
                                          clip.sourceStart) /
                                      speed)
                              .clamp(0.0, timelineEnd)
                              .toDouble(),
                      text: normalizeAssDisplayText(word.text),
                    ),
              ]),
            ),
          );
        }
      }
    }
    result.sort((left, right) => left.start.compareTo(right.start));
    return List.unmodifiable(result);
  }
}
