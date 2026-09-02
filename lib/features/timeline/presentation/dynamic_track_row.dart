part of 'dynamic_timeline_view.dart';

extension _DynamicTrackRow on DynamicTimelineView {
  ({double time, double? guide, Set<String> ids})? _moveProposal(
      BuildContext context, TimelineClipDragData data, Offset fallback) {
    final box = context.findRenderObject() as RenderBox?;
    final source = model.clipById(data.clipId)?.clip;
    if (box == null || source == null) return null;
    final ids =
        selectedClipIds.contains(source.id) ? selectedClipIds : {source.id};
    // DragTarget's offset is the feedback origin, not the grabbed pointer.
    final local = box.globalToLocal(fallback);
    // The feedback origin already accounts for dragStartPoint. Subtracting
    // the grab offset a second time makes clips jump left on drop.
    final proposed = math.max(0.0, local.dx / pixelsPerSecond);
    final snapped = TimelineGestureSnap.resolve(model,
        movingIds: ids,
        anchorId: source.id,
        proposedStart: proposed,
        duration: source.duration,
        pixelsPerSecond: pixelsPerSecond,
        playhead: _playheadOverrideSeconds(),
        markers: markers,
        enabled: !HardwareKeyboard.instance.isAltPressed);
    final earliest = ids
        .map((id) => model.clipById(id)?.clip.timelineStart)
        .whereType<double>()
        .fold<double>(source.timelineStart, math.min);
    final time = source.timelineStart +
        math.max(-earliest, snapped.time - source.timelineStart);
    return (
      time: time,
      guide: time == snapped.time ? snapped.guideTime : null,
      ids: ids
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
                        editor.updateTrack(
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
                        editor.updateTrack(
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
                          final ids = selectedClipIds.contains(data.clipId)
                              ? selectedClipIds
                              : {data.clipId};
                          return source?.track.type == track.type &&
                              !ids.any((id) =>
                                  model.clipById(id)?.track.isLocked !=
                                  false) &&
                              !LinkedAudioEditGuard.blocks(model, ids);
                        }
                        return false;
                      },
                      onMove: (details) {
                        final data = details.data;
                        if (data is! TimelineClipDragData) return;
                        final proposal =
                            _moveProposal(rowContext, data, details.offset);
                        if (proposal == null) return;
                        final source = model.clipById(data.clipId)!;
                        final next = editor.moveClips(model,
                            clipIds: proposal.ids,
                            anchorClipId: data.clipId,
                            targetTrackId: track.id,
                            timelineStart: proposal.time,
                            snap: false);
                        gestureFeedback?.value = TimelineGestureFeedback(
                            time: proposal.time,
                            duration: source.clip.duration,
                            guide: proposal.guide,
                            valid: !identical(next, model) ||
                                (!track.isLocked &&
                                    source.track.id == track.id &&
                                    proposal.time ==
                                        source.clip.timelineStart));
                      },
                      onLeave: (_) => gestureFeedback?.value = null,
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
                        final proposal =
                            _moveProposal(rowContext, data, details.offset);
                        if (proposal == null) return;
                        final next = editor.moveClips(
                          model,
                          clipIds: proposal.ids,
                          anchorClipId: source.id,
                          targetTrackId: track.id,
                          timelineStart: proposal.time,
                          playhead: playheadSeconds,
                          markers: markers,
                          snap: false,
                        );
                        gestureFeedback?.value = null;
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
                              color: rejected.isNotEmpty
                                  ? const Color(0x337f1d1d)
                                  : candidates.isEmpty
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
                                  (clip) =>
                                      // A linked source-audio companion is
                                      // represented by the waveform lane in
                                      // its owning video clip. Rendering it
                                      // again on A1 makes one A/V edit look
                                      // like two independent objects. Once
                                      // detached, isLinkedAudio is false and
                                      // the clip correctly appears here.
                                      !(track.type == TrackType.audio &&
                                          clip.isLinkedAudio) &&
                                      _intersectsVisibleRange(
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
                                peaksPerSecond:
                                    waveformPeaksPerSecondByMedia[musicPath!] ??
                                        waveformPeaksPerSecond,
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
}
