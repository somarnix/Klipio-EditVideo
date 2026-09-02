import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/timeline_editor.dart';
import '../domain/timeline_models.dart';
import '../domain/linked_audio_edit_guard.dart';
import '../domain/transition_boundary.dart';
import 'timeline_gesture_feedback.dart';

part 'dynamic_is_light.dart';
part 'dynamic_track_row.dart';
part 'dynamic_clip_widget.dart';

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
    this.editor = const TimelineEditor(),
    required this.pixelsPerSecond,
    required this.playheadSeconds,
    required this.onModelChanged,
    required this.onSeek,
    required this.onClipSelected,
    this.selectedClipId,
    this.selectedClipIds = const {},
    this.markers = const [],
    this.thumbnailPaths = const {},
    this.sourceDurations = const {},
    this.audioWaveformPeaks = const {},
    this.waveformPeaksPerSecond = 50,
    this.waveformPeaksPerSecondByMedia = const {},
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
    this.onScrubStart,
    this.onScrubUpdate,
    this.onScrubEnd,
    this.gestureFeedback,
    this.onTransitionSelected,
    this.selectedTransitionClipId,
    this.onNavigationSignal,
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
  final Map<String, double> waveformPeaksPerSecondByMedia;
  final Map<String, double> sourceDurations;
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
  final ValueListenable<dynamic>? playheadOverride;
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
  final ValueChanged<double>? onScrubStart;
  final ValueChanged<double>? onScrubUpdate;
  final ValueChanged<double>? onScrubEnd;
  final ValueNotifier<TimelineGestureFeedback?>? gestureFeedback;
  final ValueChanged<String>? onTransitionSelected;
  final String? selectedTransitionClipId;
  final void Function(PointerSignalEvent)? onNavigationSignal;

  final TimelineEditor editor;

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
    final trackRows = model.displayTracks.where((track) {
      // Source-audio companions are rendered inside their owning video clips.
      // Keep genuinely empty audio tracks (valid drop targets), but suppress a
      // row whose only contents are linked implementation companions.
      if (track.type != TrackType.audio || track.clips.isEmpty) return true;
      return track.clips.any((clip) => !clip.isLinkedAudio);
    }).toList(growable: false);
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
                  child: Listener(
                      onPointerSignal: onNavigationSignal,
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
                                          onPanStart: (details) =>
                                              (onScrubStart ?? onSeek).call(
                                            _secondsForContentX(
                                              details.localPosition.dx,
                                            ),
                                          ),
                                          onPanUpdate: (details) =>
                                              (onScrubUpdate ?? onSeek).call(
                                            _secondsForContentX(
                                              details.localPosition.dx,
                                            ),
                                          ),
                                          onPanEnd: (_) {
                                            final seconds =
                                                _playheadOverrideSeconds();
                                            onScrubEnd?.call(seconds);
                                          },
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                              painter: _DynamicRulerPainter(
                                                pixelsPerSecond:
                                                    pixelsPerSecond,
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
                            if (gestureFeedback != null)
                              Positioned.fill(
                                  child: IgnorePointer(
                                child: ValueListenableBuilder<
                                    TimelineGestureFeedback?>(
                                  valueListenable: gestureFeedback!,
                                  builder: (context, feedback, _) {
                                    if (feedback == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final color = feedback.valid
                                        ? const Color(0xfffacc15)
                                        : const Color(0xfff87171);
                                    return Stack(children: [
                                      if (feedback.guide != null)
                                        Positioned(
                                            left: labelWidth +
                                                feedback.guide! *
                                                    pixelsPerSecond,
                                            top: rulerHeight,
                                            bottom: 0,
                                            child: Container(
                                                key: const ValueKey(
                                                    'timeline-snap-guide'),
                                                width: 1,
                                                color: color)),
                                      Positioned(
                                          left: labelWidth +
                                              visibleStartSeconds *
                                                  pixelsPerSecond +
                                              8,
                                          top: 2,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              color: const Color(0xff111827),
                                              child: Text(
                                                  feedback.valid
                                                      ? '${timelineEditTime(feedback.time)}  ·  ${timelineEditTime(feedback.duration)} duration'
                                                      : 'Locked or incompatible target',
                                                  style: TextStyle(
                                                      color: color,
                                                      fontSize: 10)))),
                                    ]);
                                  },
                                ),
                              )),
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
                              _bluePlayhead(
                                  context, labelWidth, playheadSeconds)
                            else
                              Positioned.fill(
                                child: ValueListenableBuilder<dynamic>(
                                  valueListenable: playheadOverride!,
                                  builder: (context, requested, child) => Stack(
                                    children: [
                                      _bluePlayhead(
                                        context,
                                        labelWidth,
                                        requested is Duration
                                            ? requested.inMicroseconds / 1000000
                                            : (requested as num?)?.toDouble() ??
                                                playheadSeconds,
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
                                                  color:
                                                      const Color(0xff22d3ee),
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
                      )),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hover/focus paint is local to the clip; it never rebuilds the editor or
/// mutates selection, and is painted above cached filmstrip/waveform content.
class _TimelineClipInteractionSurface extends StatefulWidget {
  const _TimelineClipInteractionSurface(
      {required this.child,
      required this.selected,
      required this.locked,
      required this.tooltip});
  final Widget child;
  final bool selected, locked;
  final String tooltip;

  @override
  State<_TimelineClipInteractionSurface> createState() =>
      _TimelineClipInteractionSurfaceState();
}

class _TimelineClipInteractionSurfaceState
    extends State<_TimelineClipInteractionSurface> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) => Focus(
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _focus = value),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Tooltip(
              message: widget.tooltip,
              waitDuration: const Duration(milliseconds: 600),
              child: Stack(fit: StackFit.passthrough, children: [
                widget.child,
                if (_hover || _focus || widget.selected)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _hover && !widget.locked
                          ? const Color(0x14ffffff)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _focus
                              ? const Color(0xfffacc15)
                              : widget.selected
                                  ? const Color(0xffa5f3fc)
                                  : const Color(0xff94a3b8),
                          width: widget.selected || _focus ? 1.5 : 1),
                    ),
                  ))),
              ])),
        ),
      );
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
    final step = TimelineRulerScale.majorStep(pixelsPerSecond);
    final minorStep = step / 5;
    final buffer =
        math.max(2.0, (visibleEndSeconds - visibleStartSeconds) * 0.08);
    final paintStart = math.max(0.0, visibleStartSeconds - buffer);
    final paintEnd = math.min(
      math.max(duration + 2, size.width / pixelsPerSecond),
      visibleEndSeconds + buffer,
    );
    if (minorStep * pixelsPerSecond >= 4) {
      for (var index = (paintStart / minorStep).floor();
          index * minorStep <= paintEnd;
          index++) {
        final second = index * minorStep;
        final x = second * pixelsPerSecond;
        canvas.drawLine(
          Offset(x, size.height - 4),
          Offset(x, size.height),
          line,
        );
      }
    }
    for (var index = (paintStart / step).floor();
        index * step <= paintEnd;
        index++) {
      final second = index * step;
      final x = second * pixelsPerSecond;
      canvas.drawLine(Offset(x, size.height - 8), Offset(x, size.height), line);
      final painter = TextPainter(
        text: TextSpan(
          text: TimelineRulerScale.label(second, step),
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
    this.feedback,
    this.playhead = 0,
    this.markers = const [],
  });

  final TimelineModel model;
  final TimelineEditor editor;
  final String clipId;
  final bool startEdge;
  final double pixelsPerSecond;
  final ValueChanged<TimelineModel> onPreview;
  final VoidCallback? onCommit;
  final ValueNotifier<TimelineGestureFeedback?>? feedback;
  final double playhead;
  final List<double> markers;

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
    final original = startModel.clipById(widget.clipId)?.clip;
    if (original == null) return;
    final edge =
        widget.startEdge ? original.timelineStart : original.timelineEnd;
    final snap = TimelineGestureSnap.resolve(startModel,
        movingIds: {widget.clipId},
        anchorId: widget.clipId,
        proposedStart: edge + _dragPixels / widget.pixelsPerSecond,
        duration: 0,
        pixelsPerSecond: widget.pixelsPerSecond,
        playhead: widget.playhead,
        markers: widget.markers,
        enabled: !HardwareKeyboard.instance.isAltPressed);
    final next = widget.editor.resizeClip(
      startModel,
      clipId: widget.clipId,
      startEdge: widget.startEdge,
      deltaSeconds: snap.time - edge,
    );
    final changed = next.clipById(widget.clipId)!.clip;
    final actualEdge =
        widget.startEdge ? changed.timelineStart : changed.timelineEnd;
    widget.feedback?.value = TimelineGestureFeedback(
        time: changed.timelineStart,
        duration: changed.duration,
        guide: actualEdge == snap.time ? snap.guideTime : null);
    widget.onPreview(next);
  }

  void _finish() {
    _startModel = null;
    _dragPixels = 0;
    widget.feedback?.value = null;
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
          width: 16,
          child: Align(
            alignment:
                widget.startEdge ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 6,
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xff67e8f9),
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
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final center = size.height / 2;
    final firstX = (size.width * visibleStartFraction).clamp(0.0, size.width);
    final lastX = (size.width * visibleEndFraction).clamp(firstX, size.width);
    final visibleWidth = lastX - firstX;
    if (visibleWidth <= 0) return;
    final bars = math.max(1, (visibleWidth / 3).floor());
    for (var bar = 0; bar < bars; bar++) {
      final startFraction = visibleStartFraction +
          (visibleEndFraction - visibleStartFraction) * bar / bars;
      final endFraction = visibleStartFraction +
          (visibleEndFraction - visibleStartFraction) * (bar + 1) / bars;
      final startSecond = sourceStart + duration * startFraction;
      final endSecond = sourceStart + duration * endFraction;
      if (startSecond >= peaks.length / peaksPerSecond || endSecond <= 0) {
        continue;
      }
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
