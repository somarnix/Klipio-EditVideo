import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/timeline_editor.dart';
import '../domain/timeline_models.dart';

typedef TimelineClipContextMenu = void Function(
  String clipId,
  Offset globalPosition,
);

typedef TimelineItemSelection = void Function(
  String id,
  bool toggle,
  bool range,
);

typedef TimelineMarqueeSelection = void Function(
  Set<String> itemIds,
  bool additive,
);

class TimelineMarqueeController extends ValueNotifier<Rect?> {
  TimelineMarqueeController() : super(null);

  Offset? _origin;
  int? _pointer;
  bool _additive = false;

  void begin(int pointer, Offset origin, {required bool additive}) {
    _pointer = pointer;
    _origin = origin;
    _additive = additive;
    value = Rect.fromPoints(origin, origin);
  }

  void update(int pointer, Offset position) {
    if (_pointer != pointer || _origin == null) return;
    value = Rect.fromPoints(_origin!, position);
  }

  ({Rect rect, bool additive})? finish(int pointer) {
    if (_pointer != pointer || value == null) return null;
    final result = (rect: value!, additive: _additive);
    cancel();
    return result;
  }

  void cancel() {
    _pointer = null;
    _origin = null;
    _additive = false;
    value = null;
  }
}

class TimelineClipDragData {
  TimelineClipDragData({required this.clipId, required this.trackId});

  final String clipId;
  final String trackId;
  double grabOffsetSeconds = 0;
}

class TimelineMediaDragData {
  const TimelineMediaDragData({
    required this.mediaPath,
    required this.duration,
  });

  final String mediaPath;
  final double duration;
}

class TimelineCaptionCueData {
  const TimelineCaptionCueData({
    required this.id,
    required this.timelineStart,
    required this.duration,
    required this.text,
  });

  final String id;
  final double timelineStart;
  final double duration;
  final String text;
}

class DynamicTimelineView extends StatelessWidget {
  const DynamicTimelineView({
    super.key,
    required this.model,
    required this.pixelsPerSecond,
    required this.playheadSeconds,
    required this.onModelChanged,
    required this.onSeek,
    required this.onClipSelected,
    this.selectedClipId,
    this.selectedClipIds = const {},
    this.markers = const [],
    this.thumbnailPaths = const {},
    this.audioWaveformPeaks = const {},
    this.waveformPeaksPerSecond = 50,
    this.mediaWithSourceAudio = const {},
    this.clipLabels = const {},
    this.trackHeights = const {},
    this.onTrackHeightChanged,
    this.onClipContextMenu,
    this.onMediaDropped,
    this.skimmerSeconds,
    this.playheadOverride,
    this.captionCues = const [],
    this.selectedCaptionId,
    this.onCaptionSelected,
    this.selectedCaptionIds = const {},
    this.onClipSelectionChanged,
    this.marqueeController,
    this.onMarqueeSelection,
    this.onCaptionSelectionChanged,
    this.captionHidden = false,
    this.captionLocked = false,
    this.onCaptionVisibilityChanged,
    this.onCaptionLockChanged,
    this.onCaptionDeleteRequested,
    this.onTrackDeleteRequested,
    this.musicPath,
    this.musicMuted = false,
    this.musicLocked = false,
    this.onMusicMuteChanged,
    this.onMusicLockChanged,
    this.onMusicDeleteRequested,
    this.musicSelected = false,
    this.onMusicSelected,
    this.compact = false,
    this.visibleStartSeconds = 0,
    this.visibleEndSeconds = double.infinity,
    this.onModelPreviewChanged,
    this.onModelPreviewCommitted,
  });

  final TimelineModel model;
  final double pixelsPerSecond;
  final double playheadSeconds;
  final ValueChanged<TimelineModel> onModelChanged;
  final ValueChanged<double> onSeek;
  final ValueChanged<String> onClipSelected;
  final String? selectedClipId;
  final Set<String> selectedClipIds;
  final TimelineItemSelection? onClipSelectionChanged;
  final TimelineMarqueeController? marqueeController;
  final TimelineMarqueeSelection? onMarqueeSelection;
  final List<double> markers;
  final Map<String, List<String>> thumbnailPaths;
  final Map<String, List<double>> audioWaveformPeaks;
  final double waveformPeaksPerSecond;
  final Set<String> mediaWithSourceAudio;
  final Map<String, String> clipLabels;
  final Map<String, double> trackHeights;
  final void Function(String trackId, double height)? onTrackHeightChanged;
  final TimelineClipContextMenu? onClipContextMenu;
  final void Function(
    TimelineMediaDragData media,
    String trackId,
    double timelineStart,
  )? onMediaDropped;
  final ValueNotifier<double?>? skimmerSeconds;
  final ValueListenable<double?>? playheadOverride;
  final List<TimelineCaptionCueData> captionCues;
  final String? selectedCaptionId;
  final ValueChanged<String>? onCaptionSelected;
  final Set<String> selectedCaptionIds;
  final TimelineItemSelection? onCaptionSelectionChanged;
  final bool captionHidden;
  final bool captionLocked;
  final VoidCallback? onCaptionVisibilityChanged;
  final VoidCallback? onCaptionLockChanged;
  final VoidCallback? onCaptionDeleteRequested;
  final ValueChanged<String>? onTrackDeleteRequested;
  final String? musicPath;
  final bool musicMuted;
  final bool musicLocked;
  final VoidCallback? onMusicMuteChanged;
  final VoidCallback? onMusicLockChanged;
  final VoidCallback? onMusicDeleteRequested;
  final bool musicSelected;
  final TimelineItemSelection? onMusicSelected;
  final bool compact;
  final double visibleStartSeconds;
  final double visibleEndSeconds;
  final ValueChanged<TimelineModel>? onModelPreviewChanged;
  final VoidCallback? onModelPreviewCommitted;

  static const _editor = TimelineEditor();
  bool _isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  Color _timelineBackground(BuildContext context) =>
      _isLight(context) ? const Color(0xffeef1f5) : const Color(0xff10141a);

  Color _trackBackground(BuildContext context) =>
      _isLight(context) ? const Color(0xffe7ebf1) : const Color(0xff141a21);

  Color _trackHeaderBackground(BuildContext context) =>
      _isLight(context) ? const Color(0xfff3f5f8) : const Color(0xff171d25);

  Color _trackDivider(BuildContext context) =>
      _isLight(context) ? const Color(0xffc7d0dc) : const Color(0xff28313d);

  Color _trackControlColor(BuildContext context) =>
      _isLight(context) ? const Color(0xff334155) : const Color(0xffd7dee8);

  Color _selectedTrackHeaderBackground(BuildContext context) =>
      _isLight(context) ? const Color(0xffdbeafe) : const Color(0xff1b2731);

  (bool, bool) get _selectionModifiers {
    final keyboard = HardwareKeyboard.instance;
    return (
      keyboard.isControlPressed || keyboard.isMetaPressed,
      keyboard.isShiftPressed,
    );
  }

  void _selectClip(String id) {
    final modifiers = _selectionModifiers;
    if (onClipSelectionChanged != null) {
      onClipSelectionChanged!(id, modifiers.$1, modifiers.$2);
    } else {
      onClipSelected(id);
    }
  }

  void _selectCaption(String id) {
    final modifiers = _selectionModifiers;
    if (onCaptionSelectionChanged != null) {
      onCaptionSelectionChanged!(id, modifiers.$1, modifiers.$2);
    } else {
      onCaptionSelected?.call(id);
    }
  }

  double _secondsForContentX(double x) {
    return (x / pixelsPerSecond)
        .clamp(0.0, math.max(model.duration, 0.0))
        .toDouble();
  }

  double _secondsForLocalPosition(Offset position, double labelWidth) {
    return _secondsForContentX(position.dx - labelWidth);
  }

  bool _intersectsVisibleRange(double start, double end) {
    final viewportDuration =
        math.max(0, visibleEndSeconds - visibleStartSeconds);
    final buffer = math.max(2.0, viewportDuration * 0.08);
    return end >= visibleStartSeconds - buffer &&
        start <= visibleEndSeconds + buffer;
  }

  double _defaultRowHeightFor(TrackType type) => switch (type) {
        TrackType.video => compact ? 58.0 : 66.0,
        TrackType.audio => compact ? 42.0 : 48.0,
        TrackType.text => compact ? 32.0 : 36.0,
      };

  double _rowHeightFor(TrackModel track) {
    final stored = trackHeights[track.id];
    if (stored != null) return stored;
    return _defaultRowHeightFor(track.type);
  }

  ({double startFraction, double endFraction}) _visibleClipFractions(
    ClipModel clip,
  ) {
    if (!visibleStartSeconds.isFinite || !visibleEndSeconds.isFinite) {
      return (startFraction: 0, endFraction: 1);
    }
    final viewportDuration = math.max(
      0.0,
      visibleEndSeconds - visibleStartSeconds,
    );
    final buffer = math.max(2.0, viewportDuration * 0.08);
    final start = math.max(
      clip.timelineStart,
      visibleStartSeconds - buffer,
    );
    final end = math.min(
      clip.timelineEnd,
      visibleEndSeconds + buffer,
    );
    if (clip.duration <= 0 || end <= start) {
      return (startFraction: 0, endFraction: 0);
    }
    return (
      startFraction:
          ((start - clip.timelineStart) / clip.duration).clamp(0.0, 1.0),
      endFraction: ((end - clip.timelineStart) / clip.duration).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelWidth = compact ? 124.0 : 132.0;
    final rulerHeight = compact ? 24.0 : 30.0;
    final defaultRowHeight = compact ? 54.0 : 66.0;
    final contentWidth = math.max(
      520.0,
      (math.max(model.duration, 10) + 2) * pixelsPerSecond,
    );
    final totalWidth = labelWidth + contentWidth;
    final trackRows = model.displayTracks;
    final captionRowHeight =
        captionCues.isEmpty ? 0.0 : (compact ? 30.0 : 34.0);
    final musicRowHeight =
        musicPath == null || musicPath!.isEmpty ? 0.0 : (compact ? 42.0 : 48.0);
    final totalHeight = rulerHeight +
        captionRowHeight +
        musicRowHeight +
        trackRows.fold<double>(
          0,
          (sum, track) => sum + _rowHeightFor(track),
        );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final position = event.localPosition;
        if ((event.buttons & kPrimaryMouseButton) == 0 ||
            position.dx < labelWidth) {
          return;
        }
        if (position.dy < rulerHeight) {
          onSeek(_secondsForLocalPosition(position, labelWidth));
          return;
        }
        if (_clipAtPosition(
              position,
              labelWidth: labelWidth,
              rulerHeight: rulerHeight,
              captionRowHeight: captionRowHeight,
              musicRowHeight: musicRowHeight,
              defaultRowHeight: defaultRowHeight,
              trackRows: trackRows,
            ) !=
            null) {
          onSeek(_secondsForLocalPosition(position, labelWidth));
          return;
        }
        if (marqueeController == null || onMarqueeSelection == null) {
          onSeek(_secondsForLocalPosition(position, labelWidth));
          return;
        }
        final keyboard = HardwareKeyboard.instance;
        marqueeController!.begin(
          event.pointer,
          position,
          additive: keyboard.isControlPressed || keyboard.isMetaPressed,
        );
      },
      onPointerMove: (event) =>
          marqueeController?.update(event.pointer, event.localPosition),
      onPointerUp: (event) {
        final completed = marqueeController?.finish(event.pointer);
        if (completed == null) return;
        // A click on empty timeline space is a seek, not a zero-size marquee.
        // Without this branch the marquee callback only cleared selection and
        // the green hover/skimmer line appeared to ignore the click.
        if (completed.rect.width.abs() < 3 && completed.rect.height.abs() < 3) {
          onSeek(_secondsForLocalPosition(completed.rect.center, labelWidth));
          onMarqueeSelection?.call(<String>{}, completed.additive);
          return;
        }
        onMarqueeSelection?.call(
          _clipsIntersectingMarquee(
            completed.rect,
            labelWidth: labelWidth,
            rulerHeight: rulerHeight,
            captionRowHeight: captionRowHeight,
            musicRowHeight: musicRowHeight,
            defaultRowHeight: defaultRowHeight,
            trackRows: trackRows,
          ),
          completed.additive,
        );
      },
      onPointerCancel: (_) => marqueeController?.cancel(),
      child: MouseRegion(
        onHover: (event) {
          if (skimmerSeconds == null) return;
          if (event.localPosition.dx < labelWidth) {
            skimmerSeconds!.value = null;
            return;
          }
          skimmerSeconds!.value =
              _secondsForLocalPosition(event.localPosition, labelWidth);
        },
        onExit: (_) {
          if (skimmerSeconds != null) skimmerSeconds!.value = null;
        },
        child: RepaintBoundary(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              height: totalHeight,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: totalWidth,
                maxWidth: totalWidth,
                child: SizedBox(
                  width: totalWidth,
                  height: totalHeight,
                  child: ColoredBox(
                    color: _timelineBackground(context),
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: rulerHeight,
                              child: Row(
                                children: [
                                  SizedBox(width: labelWidth),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (details) => onSeek(
                                        _secondsForContentX(
                                          details.localPosition.dx,
                                        ),
                                      ),
                                      onPanDown: (details) => onSeek(
                                        _secondsForContentX(
                                          details.localPosition.dx,
                                        ),
                                      ),
                                      onPanUpdate: (details) => onSeek(
                                        _secondsForContentX(
                                          details.localPosition.dx,
                                        ),
                                      ),
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _DynamicRulerPainter(
                                            pixelsPerSecond: pixelsPerSecond,
                                            duration: model.duration,
                                            markers: markers,
                                            visibleStartSeconds:
                                                visibleStartSeconds,
                                            visibleEndSeconds:
                                                visibleEndSeconds,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (captionCues.isNotEmpty)
                              _captionTrackRow(
                                context,
                                labelWidth: labelWidth,
                                rowHeight: captionRowHeight,
                                contentWidth: contentWidth,
                              ),
                            for (final track in trackRows)
                              _trackRow(
                                context,
                                track,
                                labelWidth: labelWidth,
                                rowHeight: _rowHeightFor(track),
                                contentWidth: contentWidth,
                              ),
                            if (musicRowHeight > 0)
                              _musicTrackRow(
                                context,
                                labelWidth: labelWidth,
                                rowHeight: musicRowHeight,
                                contentWidth: contentWidth,
                              ),
                          ],
                        ),
                        if (skimmerSeconds != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ValueListenableBuilder<double?>(
                                valueListenable: skimmerSeconds!,
                                builder: (context, value, child) {
                                  if (value == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Stack(
                                    children: [
                                      Positioned(
                                        left: labelWidth +
                                            value * pixelsPerSecond,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 1.5,
                                          color: const Color(0xff22c55e),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        if (playheadOverride == null)
                          _bluePlayhead(context, labelWidth, playheadSeconds)
                        else
                          Positioned.fill(
                            child: ValueListenableBuilder<double?>(
                              valueListenable: playheadOverride!,
                              builder: (context, requested, child) => Stack(
                                children: [
                                  _bluePlayhead(
                                    context,
                                    labelWidth,
                                    requested ?? playheadSeconds,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (marqueeController != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ValueListenableBuilder<Rect?>(
                                valueListenable: marqueeController!,
                                builder: (context, rect, child) {
                                  if (rect == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Stack(
                                    children: [
                                      Positioned.fromRect(
                                        rect: rect,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: const Color(0x3322d3ee),
                                            border: Border.all(
                                              color: const Color(0xff22d3ee),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _clipAtPosition(
    Offset position, {
    required double labelWidth,
    required double rulerHeight,
    required double captionRowHeight,
    required double musicRowHeight,
    required double defaultRowHeight,
    required List<TrackModel> trackRows,
  }) {
    if (captionRowHeight > 0 &&
        position.dy >= rulerHeight &&
        position.dy <= rulerHeight + captionRowHeight) {
      final timelineX = position.dx - labelWidth;
      for (final cue in captionCues) {
        final left = cue.timelineStart * pixelsPerSecond;
        final right = left + math.max(2, cue.duration * pixelsPerSecond);
        if (timelineX >= left && timelineX <= right) return cue.id;
      }
      return null;
    }
    var top = rulerHeight + captionRowHeight;
    for (final track in trackRows) {
      final height = _rowHeightFor(track);
      if (position.dy >= top && position.dy <= top + height) {
        final timelineX = position.dx - labelWidth;
        for (final clip in track.clips) {
          final left = clip.timelineStart * pixelsPerSecond;
          final right = left + math.max(4, clip.duration * pixelsPerSecond);
          if (timelineX >= left && timelineX <= right) return clip.id;
        }
        return null;
      }
      top += height;
    }
    if (musicRowHeight > 0 &&
        position.dy >= top &&
        position.dy <= top + musicRowHeight) {
      final timelineX = position.dx - labelWidth;
      if (timelineX >= 0 &&
          timelineX <= math.max(6, model.duration * pixelsPerSecond)) {
        return 'music-track';
      }
    }
    return null;
  }

  Set<String> _clipsIntersectingMarquee(
    Rect marquee, {
    required double labelWidth,
    required double rulerHeight,
    required double captionRowHeight,
    required double musicRowHeight,
    required double defaultRowHeight,
    required List<TrackModel> trackRows,
  }) {
    final selected = <String>{};
    if (captionRowHeight > 0) {
      for (final cue in captionCues) {
        final cueRect = Rect.fromLTWH(
          labelWidth + cue.timelineStart * pixelsPerSecond,
          rulerHeight + 3,
          math.max(2, cue.duration * pixelsPerSecond),
          math.max(1, captionRowHeight - 6),
        );
        if (marquee.overlaps(cueRect) || marquee.contains(cueRect.center)) {
          selected.add(cue.id);
        }
      }
    }
    var top = rulerHeight + captionRowHeight;
    for (final track in trackRows) {
      final height = _rowHeightFor(track);
      for (final clip in track.clips) {
        final clipRect = Rect.fromLTWH(
          labelWidth + clip.timelineStart * pixelsPerSecond,
          top + 4,
          math.max(4, clip.duration * pixelsPerSecond),
          math.max(1, height - 8),
        );
        if (marquee.overlaps(clipRect) || marquee.contains(clipRect.center)) {
          selected.add(clip.id);
        }
      }
      top += height;
    }
    if (musicRowHeight > 0) {
      final musicRect = Rect.fromLTWH(
        labelWidth,
        top + 4,
        math.max(6, model.duration * pixelsPerSecond),
        math.max(1, musicRowHeight - 8),
      );
      if (marquee.overlaps(musicRect) || marquee.contains(musicRect.center)) {
        selected.add('music-track');
      }
    }
    return selected;
  }

  Widget _bluePlayhead(
    BuildContext context,
    double labelWidth,
    double seconds,
  ) {
    return Positioned(
      left: labelWidth + seconds * pixelsPerSecond - 8,
      top: 0,
      bottom: 0,
      width: 16,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.globalPosition);
            onSeek(_secondsForLocalPosition(local, labelWidth));
          },
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: const Color(0xff1f6bff),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Color(0xff1f6bff),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _captionTrackRow(
    BuildContext context, {
    required double labelWidth,
    required double rowHeight,
    required double contentWidth,
  }) {
    const accent = Color(0xffd97757);
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          Container(
            width: labelWidth,
            decoration: BoxDecoration(
              color: _trackHeaderBackground(context),
              border: Border(
                right: BorderSide(color: _trackDivider(context)),
                bottom: BorderSide(color: _trackDivider(context)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 9),
                Container(
                  width: 28,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.17),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: accent.withOpacity(0.55)),
                  ),
                  child: const Text(
                    'T1',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                _trackHeaderButton(
                  context,
                  tooltip: captionHidden ? 'Show captions' : 'Hide captions',
                  icon: captionHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  muted: captionHidden,
                  onPressed: onCaptionVisibilityChanged,
                ),
                _trackHeaderButton(
                  context,
                  tooltip: captionLocked ? 'Unlock captions' : 'Lock captions',
                  icon: captionLocked ? Icons.lock : Icons.lock_open,
                  warning: captionLocked,
                  onPressed: onCaptionLockChanged,
                ),
                _trackHeaderButton(
                  context,
                  tooltip: 'Delete caption track',
                  icon: Icons.delete_outline,
                  danger: true,
                  onPressed: onCaptionDeleteRequested,
                ),
                const SizedBox(width: 3),
              ],
            ),
          ),
          SizedBox(
            width: contentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: _trackBackground(context),
                border: Border(
                  bottom: BorderSide(color: _trackDivider(context)),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final cue in captionCues.where(
                    (cue) => _intersectsVisibleRange(
                      cue.timelineStart,
                      cue.timelineStart + cue.duration,
                    ),
                  ))
                    Positioned(
                      left: cue.timelineStart * pixelsPerSecond,
                      top: 3,
                      bottom: 3,
                      width: math.max(2, cue.duration * pixelsPerSecond),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _selectCaption(cue.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: const Color(0xff7f3f35)
                                  .withOpacity(captionHidden ? 0.28 : 1),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: (selectedCaptionId == cue.id ||
                                        selectedCaptionIds.contains(cue.id))
                                    ? const Color(0xfff59e7a)
                                    : accent.withOpacity(0.58),
                                width: (selectedCaptionId == cue.id ||
                                        selectedCaptionIds.contains(cue.id))
                                    ? 1.5
                                    : 0.8,
                              ),
                            ),
                            child: cue.duration * pixelsPerSecond < 52
                                ? null
                                : Text(
                                    cue.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackRow(
    BuildContext context,
    TrackModel track, {
    required double labelWidth,
    required double rowHeight,
    required double contentWidth,
  }) {
    final accent = _trackAccent(track.type);
    final selectedOnTrack = selectedClipId != null &&
            track.clips.any((clip) => clip.id == selectedClipId) ||
        track.clips.any((clip) => selectedClipIds.contains(clip.id));
    final linkedAudio = track.type == TrackType.video
        ? track.clips
            .map((clip) => model.linkedAudioForVideo(clip.id))
            .whereType<ClipModel>()
            .toList()
        : const <ClipModel>[];
    final sourceAudioMuted = linkedAudio.isNotEmpty &&
        linkedAudio.every((clip) {
          final result = model.clipById(clip.id);
          return clip.isMuted || result?.track.isMuted == true;
        });
    final trackBackground = _trackBackground(context);
    return SizedBox(
      width: labelWidth + contentWidth,
      height: rowHeight,
      child: Stack(
        children: [
          Row(
            children: [
              Container(
                width: labelWidth,
                decoration: BoxDecoration(
                  color: selectedOnTrack
                      ? _selectedTrackHeaderBackground(context)
                      : _trackHeaderBackground(context),
                  border: Border(
                    right: BorderSide(color: _trackDivider(context)),
                    bottom: BorderSide(color: _trackDivider(context)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selectedOnTrack
                          ? accent.withOpacity(0.75)
                          : accent.withOpacity(0.28),
                      offset: const Offset(2, 0),
                      blurRadius: 0,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 9),
                    Container(
                      width: 28,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.17),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent.withOpacity(0.55)),
                      ),
                      child: Text(
                        track.label,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        minimumSize: Size.zero,
                        maximumSize: const Size(20, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: track.type == TrackType.audio
                          ? (track.isMuted ? 'Unmute track' : 'Mute track')
                          : (track.isMuted ? 'Show track' : 'Hide track'),
                      onPressed: () => onModelChanged(
                        _editor.updateTrack(
                          model,
                          track.id,
                          (item) => item.copyWith(isMuted: !item.isMuted),
                        ),
                      ),
                      icon: Icon(
                        track.type == TrackType.audio
                            ? (track.isMuted
                                ? Icons.volume_off
                                : Icons.volume_up)
                            : (track.isMuted
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                        size: 15,
                        color: track.isMuted
                            ? const Color(0xff64748b)
                            : _trackControlColor(context),
                      ),
                    ),
                    if (track.type == TrackType.video)
                      _trackHeaderButton(
                        context,
                        tooltip: sourceAudioMuted
                            ? 'Unmute source audio'
                            : 'Mute source audio',
                        icon: sourceAudioMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                        muted: sourceAudioMuted,
                        onPressed: linkedAudio.isEmpty
                            ? null
                            : () {
                                final linkedIds =
                                    linkedAudio.map((clip) => clip.id).toSet();
                                onModelChanged(
                                  model.copyWith(
                                    tracks: [
                                      for (final item in model.tracks)
                                        item.type == TrackType.audio
                                            ? item.copyWith(
                                                isMuted: sourceAudioMuted &&
                                                        item.clips.any((clip) =>
                                                            linkedIds.contains(
                                                                clip.id))
                                                    ? false
                                                    : item.isMuted,
                                                clips: [
                                                  for (final clip in item.clips)
                                                    linkedIds.contains(clip.id)
                                                        ? clip.copyWith(
                                                            isMuted:
                                                                !sourceAudioMuted,
                                                          )
                                                        : clip,
                                                ],
                                              )
                                            : item,
                                    ],
                                  ),
                                );
                              },
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        minimumSize: Size.zero,
                        maximumSize: const Size(24, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: track.isLocked ? 'Unlock track' : 'Lock track',
                      onPressed: () => onModelChanged(
                        _editor.updateTrack(
                          model,
                          track.id,
                          (item) => item.copyWith(isLocked: !item.isLocked),
                        ),
                      ),
                      icon: Icon(
                        track.isLocked ? Icons.lock : Icons.lock_open,
                        size: 15,
                        color: track.isLocked
                            ? const Color(0xfff59e0b)
                            : _trackControlColor(context),
                      ),
                    ),
                    _trackHeaderButton(
                      context,
                      tooltip: 'Delete ${track.label} track',
                      icon: Icons.delete_outline,
                      danger: true,
                      onPressed: track.isLocked
                          ? null
                          : () => onTrackDeleteRequested?.call(track.id),
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
              ),
              SizedBox(
                width: contentWidth,
                child: Builder(
                  builder: (rowContext) {
                    return DragTarget<Object>(
                      onWillAcceptWithDetails: (details) {
                        final data = details.data;
                        if (track.isLocked) return false;
                        if (data is TimelineMediaDragData) {
                          return track.type == TrackType.video &&
                              onMediaDropped != null;
                        }
                        if (data is TimelineClipDragData) {
                          final source = model.clipById(data.clipId);
                          return source?.track.type == track.type;
                        }
                        return false;
                      },
                      onAcceptWithDetails: (details) {
                        final box = rowContext.findRenderObject() as RenderBox?;
                        if (box == null) return;
                        final local = box.globalToLocal(details.offset);
                        final data = details.data;
                        if (data is TimelineMediaDragData) {
                          final proposed = math
                              .max(
                                0,
                                local.dx / pixelsPerSecond - data.duration / 2,
                              )
                              .toDouble();
                          onMediaDropped?.call(data, track.id, proposed);
                          return;
                        }
                        if (data is! TimelineClipDragData) return;
                        final source = model.clipById(data.clipId)?.clip;
                        if (source == null) return;
                        final proposed = math
                            .max(
                              0,
                              local.dx / pixelsPerSecond -
                                  data.grabOffsetSeconds,
                            )
                            .toDouble();
                        final movingIds = selectedClipIds.contains(source.id)
                            ? selectedClipIds
                            : {source.id};
                        final earliestSelectedStart = movingIds
                            .map((id) => model.clipById(id)?.clip.timelineStart)
                            .whereType<double>()
                            .fold<double>(source.timelineStart, math.min);
                        final requestedDelta = proposed - source.timelineStart;
                        final groupDelta = math.max(
                          -earliestSelectedStart,
                          requestedDelta,
                        );
                        var next = _editor.moveClip(
                          model,
                          clipId: source.id,
                          targetTrackId: track.id,
                          timelineStart: source.timelineStart + groupDelta,
                          playhead: playheadSeconds,
                          markers: markers,
                        );
                        final movedSource = next.clipById(source.id)?.clip;
                        if (movedSource == null) return;
                        final delta =
                            movedSource.timelineStart - source.timelineStart;
                        for (final movingId
                            in movingIds.where((id) => id != source.id)) {
                          final moving = next.clipById(movingId);
                          if (moving == null || moving.track.isLocked) {
                            continue;
                          }
                          next = _editor.moveClip(
                            next,
                            clipId: movingId,
                            targetTrackId: moving.track.id,
                            timelineStart:
                                math.max(0, moving.clip.timelineStart + delta),
                            snap: false,
                          );
                        }
                        onModelChanged(next);
                      },
                      builder: (context, candidates, rejected) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => onSeek(
                            _secondsForContentX(details.localPosition.dx),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: candidates.isEmpty
                                  ? trackBackground
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.15),
                              border: Border(
                                bottom:
                                    BorderSide(color: _trackDivider(context)),
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                for (final clip in track.clips.where(
                                  (clip) => _intersectsVisibleRange(
                                    clip.timelineStart,
                                    clip.timelineEnd,
                                  ),
                                ))
                                  _clipWidget(context, track, clip, rowHeight),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (onTrackHeightChanged != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 7,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => onTrackHeightChanged!(
                    track.id,
                    _defaultRowHeightFor(track.type),
                  ),
                  onVerticalDragUpdate: (details) => onTrackHeightChanged!(
                    track.id,
                    (rowHeight + details.delta.dy)
                        .clamp(compact ? 34.0 : 40.0, 150.0)
                        .toDouble(),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xff64748b),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _musicTrackRow(
    BuildContext context, {
    required double labelWidth,
    required double rowHeight,
    required double contentWidth,
  }) {
    const accent = Color(0xff34d399);
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          Container(
            width: labelWidth,
            decoration: BoxDecoration(
              color: musicSelected
                  ? _selectedTrackHeaderBackground(context)
                  : _trackHeaderBackground(context),
              border: Border(
                right: BorderSide(color: _trackDivider(context)),
                bottom: BorderSide(color: _trackDivider(context)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 9),
                Container(
                  width: 28,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.17),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: accent.withOpacity(0.55)),
                  ),
                  child: const Text(
                    'M1',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                _trackHeaderButton(
                  context,
                  tooltip: musicMuted ? 'Unmute music' : 'Mute music',
                  icon: musicMuted ? Icons.volume_off : Icons.volume_up,
                  muted: musicMuted,
                  onPressed: onMusicMuteChanged,
                ),
                _trackHeaderButton(
                  context,
                  tooltip: musicLocked ? 'Unlock music' : 'Lock music',
                  icon: musicLocked ? Icons.lock : Icons.lock_open,
                  warning: musicLocked,
                  onPressed: onMusicLockChanged,
                ),
                _trackHeaderButton(
                  context,
                  tooltip: 'Delete music track',
                  icon: Icons.delete_outline,
                  danger: true,
                  onPressed: musicLocked ? null : onMusicDeleteRequested,
                ),
                const SizedBox(width: 3),
              ],
            ),
          ),
          SizedBox(
            width: contentWidth,
            child: Container(
              decoration: BoxDecoration(
                color: _trackBackground(context),
                border: Border(
                  bottom: BorderSide(color: _trackDivider(context)),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final modifiers = _selectionModifiers;
                      onMusicSelected?.call(
                        'music-track',
                        modifiers.$1,
                        modifiers.$2,
                      );
                    },
                    child: Container(
                      width: math.max(6, model.duration * pixelsPerSecond),
                      height: rowHeight - 8,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xff047857)
                            .withOpacity(musicMuted ? 0.28 : 0.82),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: musicSelected ? Colors.white : accent,
                          width: musicSelected ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: _DynamicWaveformPainter(
                                color: Colors.white.withOpacity(0.68),
                                peaks:
                                    audioWaveformPeaks[musicPath!] ?? const [],
                                peaksPerSecond: waveformPeaksPerSecond,
                                sourceStart: 0,
                                duration: model.duration,
                                visibleStartFraction: model.duration <= 0 ||
                                        !visibleStartSeconds.isFinite
                                    ? 0
                                    : (visibleStartSeconds / model.duration)
                                        .clamp(0.0, 1.0),
                                visibleEndFraction: model.duration <= 0 ||
                                        !visibleEndSeconds.isFinite
                                    ? 1
                                    : (visibleEndSeconds / model.duration)
                                        .clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                          Container(
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.topLeft,
                            child: Text(
                              _basename(musicPath!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 3)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackHeaderButton(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    VoidCallback? onPressed,
    bool muted = false,
    bool warning = false,
    bool danger = false,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: Size.zero,
        maximumSize: const Size(20, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 15,
        color: onPressed == null
            ? const Color(0xff4b5563)
            : danger
                ? const Color(0xffef4444)
                : warning
                    ? const Color(0xfff59e0b)
                    : muted
                        ? const Color(0xff64748b)
                        : _trackControlColor(context),
      ),
    );
  }

  Widget _clipWidget(
    BuildContext context,
    TrackModel track,
    ClipModel clip,
    double rowHeight,
  ) {
    final width = math.max(4.0, clip.duration * pixelsPerSecond);
    final dragData = TimelineClipDragData(
      clipId: clip.id,
      trackId: track.id,
    );
    final visibleFractions = _visibleClipFractions(clip);
    final selected =
        selectedClipId == clip.id || selectedClipIds.contains(clip.id);
    final hasIndependentAudio = model.audioTracks.any(
      (audioTrack) => audioTrack.clips.any(
        (audioClip) =>
            !audioClip.isLinkedAudio && audioClip.mediaPath == clip.mediaPath,
      ),
    );
    final hasLinkedAudio = track.type == TrackType.video &&
        (model.linkedAudioForVideo(clip.id) != null ||
            (mediaWithSourceAudio.contains(clip.mediaPath) &&
                !hasIndependentAudio));
    final controllableAudio = track.type == TrackType.audio
        ? clip
        : model.linkedAudioForVideo(clip.id);
    final color = switch (track.type) {
      TrackType.video => const Color(0xff0f5963),
      TrackType.audio => const Color(0xff176b64),
      TrackType.text => const Color(0xff8b4938),
    };
    final content = RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectClip(clip.id),
          onSecondaryTapDown: (details) {
            if (!selectedClipIds.contains(clip.id) &&
                selectedClipId != clip.id) {
              onClipSelected(clip.id);
            }
            onClipContextMenu?.call(clip.id, details.globalPosition);
          },
          child: Container(
            width: width,
            height: rowHeight - 8,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(track.isMuted ? 0.28 : 0.88),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? const Color(0xffcbd5e1).withOpacity(0.78)
                    : const Color(0xff2c7780),
                width: selected ? 1.0 : 0.8,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (track.type == TrackType.video)
                  _filmstrip(clip, width)
                else if (track.type == TrackType.audio)
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _DynamicWaveformPainter(
                        color: Colors.white.withOpacity(0.65),
                        peaks: audioWaveformPeaks[clip.mediaPath] ?? const [],
                        peaksPerSecond: waveformPeaksPerSecond,
                        sourceStart: clip.sourceStart,
                        duration: clip.duration,
                        visibleStartFraction: visibleFractions.startFraction,
                        visibleEndFraction: visibleFractions.endFraction,
                      ),
                    ),
                  ),
                if (hasLinkedAudio)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      key: ValueKey('linked-audio-waveform-${clip.id}'),
                      height: (rowHeight * 0.36).clamp(20.0, 42.0),
                      decoration: const BoxDecoration(
                        color: Color(0xee075985),
                        border: Border(
                          top: BorderSide(color: Color(0xff22d3ee), width: 1),
                        ),
                      ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _DynamicWaveformPainter(
                            color: const Color(0xff67e8f9),
                            peaks:
                                audioWaveformPeaks[clip.mediaPath] ?? const [],
                            peaksPerSecond: waveformPeaksPerSecond,
                            sourceStart: clip.sourceStart,
                            duration: clip.duration,
                            visibleStartFraction:
                                visibleFractions.startFraction,
                            visibleEndFraction: visibleFractions.endFraction,
                          ),
                        ),
                      ),
                    ),
                  ),
                Container(color: Colors.black.withOpacity(0.12)),
                if (clip.transitionIn != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: math.min(
                        width,
                        clip.transitionIn!.duration * pixelsPerSecond,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xcc22d3ee), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                if (width >= 52)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 20,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.centerLeft,
                      decoration: const BoxDecoration(
                        color: Color(0xd9044f59),
                        border: Border(
                          bottom: BorderSide(color: Color(0xff0891b2)),
                        ),
                      ),
                      child: Text(
                        _visualClipLabel(clip),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                if (controllableAudio != null && width >= 78)
                  Positioned(
                    right: 2,
                    top: 2,
                    width: 18,
                    height: 18,
                    child: Tooltip(
                      message: controllableAudio.isMuted
                          ? 'Unmute clip audio'
                          : 'Mute clip audio',
                      child: Material(
                        color: Colors.black.withOpacity(0.62),
                        borderRadius: BorderRadius.circular(3),
                        child: InkWell(
                          key: ValueKey('clip-audio-${clip.id}'),
                          onTap: track.isLocked
                              ? null
                              : () => _setClipAudioMuted(
                                    controllableAudio,
                                    !controllableAudio.isMuted,
                                  ),
                          child: Icon(
                            controllableAudio.isMuted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (track.isLocked)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.lock, size: 12, color: Colors.white),
                    ),
                  ),
                if (clip.effects.any((effect) => effect.enabled) ||
                    clip.keyframes.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (clip.effects.any((effect) => effect.enabled))
                            const Icon(
                              Icons.auto_awesome,
                              size: 10,
                              color: Color(0xfffacc15),
                            ),
                          if (clip.keyframes.isNotEmpty) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.diamond_outlined,
                              size: 10,
                              color: Color(0xff67e8f9),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Positioned(
      left: clip.timelineStart * pixelsPerSecond,
      width: width,
      top: 0,
      bottom: 0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          track.isLocked
              ? content
              : Draggable<TimelineClipDragData>(
                  data: dragData,
                  dragAnchorStrategy: (draggable, context, globalPosition) {
                    final box = context.findRenderObject() as RenderBox?;
                    final local = box?.globalToLocal(globalPosition) ??
                        Offset(width / 2, 0);
                    dragData.grabOffsetSeconds = (local.dx / pixelsPerSecond)
                        .clamp(0.0, clip.duration)
                        .toDouble();
                    return local;
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    elevation: 8,
                    child: Container(
                      width: width,
                      height: math.max(28, rowHeight - 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        _visualClipLabel(clip),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.25, child: content),
                  child: content,
                ),
          if (selected && !track.isLocked)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _resizeHandle(clip, startEdge: true),
            ),
          if (selected && !track.isLocked)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: _resizeHandle(clip, startEdge: false),
            ),
        ],
      ),
    );
  }

  Widget _resizeHandle(ClipModel clip, {required bool startEdge}) {
    return _TimelineClipTrimHandle(
      key: ValueKey(
        'clip-trim-${clip.id}-${startEdge ? 'start' : 'end'}',
      ),
      model: model,
      editor: _editor,
      clipId: clip.id,
      startEdge: startEdge,
      pixelsPerSecond: pixelsPerSecond,
      onPreview: onModelPreviewChanged ?? onModelChanged,
      onCommit: onModelPreviewCommitted,
    );
  }

  void _setClipAudioMuted(ClipModel audioClip, bool muted) {
    final result = model.clipById(audioClip.id);
    if (result == null || result.track.isLocked) return;
    onModelChanged(
      _editor.updateTrack(
        model,
        result.track.id,
        (track) => track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (clip.id == audioClip.id)
                clip.copyWith(isMuted: muted)
              else
                clip,
          ],
        ),
      ),
    );
  }

  Widget _filmstrip(ClipModel clip, double width) {
    final paths = thumbnailPaths[clip.mediaPath] ?? const [];
    if (paths.isEmpty) return const SizedBox.shrink();
    final visible = _visibleClipFractions(clip);
    final left = width * visible.startFraction;
    final visibleWidth = math.max(
      1.0,
      width * (visible.endFraction - visible.startFraction),
    );
    final count = (visibleWidth / 84).ceil().clamp(1, 18);
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: left,
            top: 0,
            bottom: 0,
            width: visibleWidth,
            child: Row(
              children: [
                for (var index = 0; index < count; index++)
                  Expanded(
                    child: Image.file(
                      File(
                        paths[((visible.startFraction +
                                    (visible.endFraction -
                                            visible.startFraction) *
                                        (index + 0.5) /
                                        count) *
                                (paths.length - 1))
                            .round()
                            .clamp(0, paths.length - 1)],
                      ),
                      height: double.infinity,
                      cacheWidth: 112,
                      filterQuality: FilterQuality.low,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

  String _visualClipLabel(ClipModel clip) {
    final raw = clipLabels[clip.id] ?? _basename(clip.mediaPath);
    return raw.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }

  Color _trackAccent(TrackType type) => switch (type) {
        TrackType.video => const Color(0xff22d3ee),
        TrackType.audio => const Color(0xff34d399),
        TrackType.text => const Color(0xfffb923c),
      };
}

class _DynamicRulerPainter extends CustomPainter {
  const _DynamicRulerPainter({
    required this.pixelsPerSecond,
    required this.duration,
    required this.markers,
    required this.visibleStartSeconds,
    required this.visibleEndSeconds,
  });

  final double pixelsPerSecond;
  final double duration;
  final List<double> markers;
  final double visibleStartSeconds;
  final double visibleEndSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = const Color(0xff64748b);
    final markerPaint = Paint()..color = const Color(0xfff59e0b);
    final step = pixelsPerSecond >= 80
        ? 0.5
        : pixelsPerSecond >= 40
            ? 1.0
            : pixelsPerSecond >= 20
                ? 2.0
                : pixelsPerSecond >= 8
                    ? 5.0
                    : pixelsPerSecond >= 4
                        ? 10.0
                        : pixelsPerSecond >= 2
                            ? 30.0
                            : 60.0;
    final minorStep = step / 5;
    final buffer =
        math.max(2.0, (visibleEndSeconds - visibleStartSeconds) * 0.08);
    final paintStart = math.max(0.0, visibleStartSeconds - buffer);
    final paintEnd = math.min(
      math.max(duration + 2, size.width / pixelsPerSecond),
      visibleEndSeconds + buffer,
    );
    if (minorStep * pixelsPerSecond >= 4) {
      for (var second = (paintStart / minorStep).floor() * minorStep;
          second <= paintEnd;
          second += minorStep) {
        final x = second * pixelsPerSecond;
        canvas.drawLine(
          Offset(x, size.height - 4),
          Offset(x, size.height),
          line,
        );
      }
    }
    for (var second = (paintStart / step).floor() * step;
        second <= paintEnd;
        second += step) {
      final x = second * pixelsPerSecond;
      canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height), line);
      final painter = TextPainter(
        text: TextSpan(
          text: _time(second),
          style: const TextStyle(color: Color(0xff94a3b8), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x + 3, 2));
    }
    for (final marker in markers) {
      final x = marker * pixelsPerSecond;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), markerPaint);
    }
  }

  static String _time(double seconds) {
    final value = seconds.round();
    final minutes = value ~/ 60;
    final rest = value % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant _DynamicRulerPainter oldDelegate) =>
      oldDelegate.pixelsPerSecond != pixelsPerSecond ||
      oldDelegate.duration != duration ||
      oldDelegate.markers != markers ||
      oldDelegate.visibleStartSeconds != visibleStartSeconds ||
      oldDelegate.visibleEndSeconds != visibleEndSeconds;
}

/// Owns one trim gesture from mouse-down to mouse-up. The timeline may rebuild
/// for every live preview frame, so the immutable start model and accumulated
/// pointer distance must live in State rather than in DynamicTimelineView's
/// build method.
class _TimelineClipTrimHandle extends StatefulWidget {
  const _TimelineClipTrimHandle({
    super.key,
    required this.model,
    required this.editor,
    required this.clipId,
    required this.startEdge,
    required this.pixelsPerSecond,
    required this.onPreview,
    this.onCommit,
  });

  final TimelineModel model;
  final TimelineEditor editor;
  final String clipId;
  final bool startEdge;
  final double pixelsPerSecond;
  final ValueChanged<TimelineModel> onPreview;
  final VoidCallback? onCommit;

  @override
  State<_TimelineClipTrimHandle> createState() =>
      _TimelineClipTrimHandleState();
}

class _TimelineClipTrimHandleState extends State<_TimelineClipTrimHandle> {
  TimelineModel? _startModel;
  double _dragPixels = 0;

  void _start(DragStartDetails details) {
    _startModel = widget.model;
    _dragPixels = 0;
  }

  void _update(DragUpdateDetails details) {
    final startModel = _startModel ?? widget.model;
    _dragPixels += details.delta.dx;
    widget.onPreview(
      widget.editor.resizeClip(
        startModel,
        clipId: widget.clipId,
        startEdge: widget.startEdge,
        deltaSeconds: _dragPixels / widget.pixelsPerSecond,
      ),
    );
  }

  void _finish() {
    _startModel = null;
    _dragPixels = 0;
    widget.onCommit?.call();
  }

  void _cancel() {
    final startModel = _startModel;
    if (startModel != null) widget.onPreview(startModel);
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _start,
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: (_) => _finish(),
        onHorizontalDragCancel: _cancel,
        child: SizedBox(
          width: 8,
          child: Align(
            alignment:
                widget.startEdge ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xffcbd5e1).withOpacity(0.72),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DynamicWaveformPainter extends CustomPainter {
  const _DynamicWaveformPainter({
    required this.color,
    required this.peaks,
    required this.peaksPerSecond,
    required this.sourceStart,
    required this.duration,
    this.visibleStartFraction = 0,
    this.visibleEndFraction = 1,
  });

  final Color color;
  final List<double> peaks;
  final double peaksPerSecond;
  final double sourceStart;
  final double duration;
  final double visibleStartFraction;
  final double visibleEndFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || duration <= 0 || size.width <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final center = size.height / 2;
    final firstX = (size.width * visibleStartFraction).clamp(0.0, size.width);
    final lastX = (size.width * visibleEndFraction).clamp(firstX, size.width);
    final visibleWidth = lastX - firstX;
    if (visibleWidth <= 0) return;
    final bars = math.max(1, (visibleWidth / 2).floor());
    for (var bar = 0; bar < bars; bar++) {
      final startFraction = visibleStartFraction +
          (visibleEndFraction - visibleStartFraction) * bar / bars;
      final endFraction = visibleStartFraction +
          (visibleEndFraction - visibleStartFraction) * (bar + 1) / bars;
      final startSecond = sourceStart + duration * startFraction;
      final endSecond = sourceStart + duration * endFraction;
      final first =
          (startSecond * peaksPerSecond).floor().clamp(0, peaks.length - 1);
      final last = math
          .max(first + 1, (endSecond * peaksPerSecond).ceil())
          .clamp(0, peaks.length);
      var peak = 0.0;
      for (var index = first; index < last; index++) {
        peak = math.max(peak, peaks[index]);
      }
      final height = math.max(1.0, peak * size.height * 0.46);
      final x = firstX + (bar + 0.5) * visibleWidth / bars;
      canvas.drawLine(
        Offset(x, center - height),
        Offset(x, center + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DynamicWaveformPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.peaks != peaks ||
      oldDelegate.peaksPerSecond != peaksPerSecond ||
      oldDelegate.sourceStart != sourceStart ||
      oldDelegate.duration != duration ||
      oldDelegate.visibleStartFraction != visibleStartFraction ||
      oldDelegate.visibleEndFraction != visibleEndFraction;
}
