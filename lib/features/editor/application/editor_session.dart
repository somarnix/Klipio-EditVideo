import 'dart:convert';
import 'effect_edit.dart';
import 'transition_edit.dart';

import '../../captions/domain/editable_caption.dart';
import '../../export/domain/export_models.dart';
import '../../projects/services/editor_project_repository.dart';
import '../../text/domain/caption_visual_state.dart';
import '../../timeline/domain/timeline_models.dart';
import '../../text/domain/title_project.dart';
import '../../composition/domain/program_render_snapshot.dart';

Object? _freeze(Object? value) => value is Map
    ? Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry('$k', _freeze(v))))
    : value is List
        ? List<Object?>.unmodifiable(value.map(_freeze))
        : value;

/// Detached durable revision, never a view of a live widget or its collections.
class EditorProjectRevision {
  EditorProjectRevision(Map<String, Object?> data)
      : data = _freeze(jsonDecode(jsonEncode(data))) as Map<String, dynamic>;
  final Map<String, dynamic> data;
}

class EditorProjectLoad {
  const EditorProjectLoad(this.revision, this.recovered);
  final EditorProjectRevision revision;
  final bool recovered;
}

/// Application owner used by the active editor and headless lifecycle tests.
/// Existing operations temporarily access the owned maps through widget
/// delegates; players, selection, history UI and preferences stay outside here.
class EditorSession {
  EditorSession({this.repository = const EditorProjectRepository()});
  final EditorProjectRepository repository;
  final Map<String, List<EditableCaptionCue>> captions = {};
  final Map<String, TimelineModel> timelines = {};
  TimelineModel timeline = TimelineModel.empty();
  Map<String, Object?> _envelope = {'version': 6, 'videos': <Object?>[]};
  bool _disposed = false;

  void _checkOpen() {
    if (_disposed) throw StateError('Editor session is closed');
  }

  bool commitEffect(EffectEdit? edit, {required void Function() beforeChange}) {
    _checkOpen();
    if (edit == null || !identical(edit.before, timeline)) return false;
    beforeChange();
    timeline = edit.after;
    return true;
  }

  bool commitTransition(TransitionEdit? edit,
      {required void Function() beforeChange}) {
    _checkOpen();
    if (edit == null || !identical(edit.before, timeline)) return false;
    beforeChange();
    timeline = edit.after;
    return true;
  }

  List<TextOverlaySettings> titleExport({EditorProjectRevision? revision}) {
    final captured = revision ?? capture();
    final source = TimelineModel.fromJson(captured.data['timeline']);
    return TitleProject.resolve(
        captured.data['textOverlays'],
        ProgramRenderSnapshot.build(
            sourceTimeline: source,
            playbackSpeedsByMediaPath: const {}).outputTimeline);
  }

  /// Legacy migration identity is asset key + original cue index, before sort.
  /// Equal visible cues are distinct instances; explicit saved IDs always win.
  static Map<String, List<EditableCaptionCue>> decodeCaptions(Object? value) {
    final result = <String, List<EditableCaptionCue>>{};
    final source = value is Map ? value : const {};
    for (final entry in source.entries) {
      final cues = <EditableCaptionCue>[];
      final items = entry.value is List ? entry.value as List : const [];
      for (final indexed in items.indexed) {
        final item = indexed.$2;
        if (item is! Map) continue;
        final start = double.tryParse('${item['start'] ?? ''}');
        final end = double.tryParse('${item['end'] ?? ''}');
        final text = '${item['text'] ?? ''}';
        if (start == null ||
            end == null ||
            !start.isFinite ||
            !end.isFinite ||
            end <= start ||
            text.isEmpty) continue;
        cues.add(EditableCaptionCue.fromJson(
            {...item, 'start': start, 'end': end},
            migrationKey: '${entry.key}/cue/${indexed.$1}'));
      }
      cues.sort((a, b) => a.start.compareTo(b.start));
      if (cues.isNotEmpty) result['${entry.key}'] = cues;
    }
    return result;
  }

  /// Identity-targeted atomic replacement. History is recorded by the existing
  /// editor command boundary before calling this operation, not during save.
  void putCaption(String asset, EditableCaptionCue cue) {
    _checkOpen();
    if (!cue.start.isFinite ||
        !cue.end.isFinite ||
        cue.end <= cue.start ||
        cue.text.isEmpty) {
      throw ArgumentError('Invalid caption interval/text');
    }
    final next = [...?captions[asset]];
    final index = next.indexWhere((existing) => existing.id == cue.id);
    if (index < 0) {
      next.add(cue);
    } else {
      next[index] = cue;
    }
    next.sort((a, b) => a.start.compareTo(b.start));
    captions[asset] = next;
  }

  /// UI bridges supply still-unextracted durable settings at the capture
  /// boundary. Owned captions/timelines cannot be overwritten by stale JSON.
  EditorProjectRevision capture({Map<String, Object?>? envelope}) {
    _checkOpen();
    if (envelope != null) _envelope = EditorProjectRevision(envelope).data;
    return EditorProjectRevision({
      ..._envelope,
      'captionCues': {
        for (final e in captions.entries)
          e.key: e.value.map((c) => c.toJson()).toList()
      },
      'timeline': timeline.toJson(),
      'timelines': {for (final e in timelines.entries) e.key: e.value.toJson()},
    });
  }

  /// Read/validate/migrate without probing media or installing player state.
  /// Recovery consent belongs to the caller; merely reading never writes files.
  Future<EditorProjectLoad> read(String path) async {
    _checkOpen();
    final loaded = await repository.read(path);
    return EditorProjectLoad(
        EditorProjectRevision(loaded.data), loaded.recovered);
  }

  void restore(EditorProjectRevision revision) {
    _checkOpen();
    final detached = EditorProjectRevision(revision.data).data;
    final nextCaptions = decodeCaptions(detached['captionCues']);
    final nextTimeline = detached['timeline'] == null
        ? TimelineModel.empty()
        : TimelineModel.fromJson(detached['timeline']);
    final savedTimelines = detached['timelines'];
    final nextTimelines = <String, TimelineModel>{
      if (savedTimelines is Map)
        for (final e in savedTimelines.entries)
          '${e.key}': TimelineModel.fromJson(e.value),
    };
    // Parse completely before replacing an existing valid session.
    _envelope = detached;
    captions
      ..clear()
      ..addAll(nextCaptions);
    timelines
      ..clear()
      ..addAll(nextTimelines);
    timeline = nextTimeline;
  }

  Future<void> save(String path, {EditorProjectRevision? revision}) {
    // Capture synchronously, before any queued I/O or widget disposal.
    // An already captured request may finish after its session is closed.
    final captured = revision ?? capture();
    return repository.write(path, captured.data);
  }

  List<CaptionCueSettings> captionExport(String asset) {
    _checkOpen();
    return List.unmodifiable([
      for (final cue in captions[asset] ?? const <EditableCaptionCue>[])
        CaptionCueSettings(
            id: cue.id,
            start: cue.start,
            end: cue.end,
            text: cue.text,
            x: cue.x,
            y: cue.y,
            words: List.unmodifiable([
              for (final word in cue.words)
                CaptionWordSettings(
                    id: word.id,
                    start: word.start,
                    end: word.end,
                    text: word.text),
            ])),
    ]);
  }

  static CaptionTimelineResolver captionResolver(EditableCaptionCue cue,
          {String motion = 'highlight', String textCase = 'none'}) =>
      CaptionTimelineResolver(
          cueId: cue.id,
          text: cue.text,
          start: cue.start,
          end: cue.end,
          motion: motion,
          textCase: textCase,
          words: cue.words.map((w) => CaptionTimedWord(
              id: w.id, text: w.text, start: w.start, end: w.end)));

  void dispose() {
    _disposed = true;
    captions.clear();
    timelines.clear();
    timeline = TimelineModel.empty();
    _envelope = {};
  }
}
