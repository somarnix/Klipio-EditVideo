part of 'dynamic_timeline_view.dart';

extension _DynamicIsLight on DynamicTimelineView {
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

  double _playheadOverrideSeconds() {
    final value = playheadOverride?.value;
    if (value is Duration) return value.inMicroseconds / 1000000;
    if (value is num) return value.toDouble();
    return playheadSeconds;
  }

  bool _intersectsVisibleRange(double start, double end) {
    final viewportDuration =
        math.max(0, visibleEndSeconds - visibleStartSeconds);
    final buffer = math.max(2.0, viewportDuration * 0.08);
    return end >= visibleStartSeconds - buffer &&
        start <= visibleEndSeconds + buffer;
  }

  double _defaultRowHeightFor(TrackType type) => switch (type) {
        TrackType.video => compact ? 78.0 : 94.0,
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
            (onScrubUpdate ?? onSeek).call(
              _secondsForLocalPosition(local, labelWidth),
            );
          },
          onHorizontalDragStart: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.globalPosition);
            (onScrubStart ?? onSeek).call(
              _secondsForLocalPosition(local, labelWidth),
            );
          },
          onHorizontalDragEnd: (_) {
            final seconds = _playheadOverrideSeconds();
            onScrubEnd?.call(seconds);
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
}
