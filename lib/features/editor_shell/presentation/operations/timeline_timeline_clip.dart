part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineTimelineClip on _EditorScreenState {
  Widget _timelineClip(
    PickedVideo video,
    int index, {
    required Color color,
    bool audio = false,
    bool extractedAudio = false,
    int? partIndex,
    bool edited = false,
    bool trimOnly = false,
    double width = 124,
    bool draggable = false,
    ({double start, double end})? timelinePart,
    int? visualPartIndex,
    bool showStartTrimHandle = false,
    bool showEndTrimHandle = false,
  }) {
    final compactClip = width < 52;
    final hasFilmstrip = !audio &&
        (video.timelineThumbnailPaths.isNotEmpty ||
            video.thumbnailPath != null);
    final showText = width >= 72;
    final showContent = width >= 30;
    final showEditIcon = edited && !audio && width >= 44;
    final clip = InkWell(
      onTap: () => _selectVideo(index),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: color.withOpacity(audio ? 0.45 : 0.68),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: index == _selectedVideoIndex
                ? Colors.white
                : color.withOpacity(0.7),
          ),
        ),
        child: Stack(
          children: [
            if (hasFilmstrip)
              Positioned.fill(
                child: _timelineFilmstrip(
                  video,
                  width: width,
                  timelinePart: timelinePart,
                ),
              ),
            if (hasFilmstrip)
              const Positioned.fill(
                child: ColoredBox(color: Color(0x26000000)),
              ),
            if (audio)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TimelineWaveformPainter(
                      color: const Color(0xff0f172a).withOpacity(0.28),
                    ),
                  ),
                ),
              ),
            if (trimOnly && !audio) ...[
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Color(0xfffacc15),
                  child: SizedBox(width: 4),
                ),
              ),
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Color(0xfffacc15),
                  child: SizedBox(width: 4),
                ),
              ),
            ],
            if (showContent)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: showStartTrimHandle || showEndTrimHandle ? 13 : 6,
                ),
                child: Row(
                  children: [
                    if (!hasFilmstrip)
                      Icon(
                        extractedAudio
                            ? Icons.library_music
                            : audio
                                ? Icons.graphic_eq
                                : Icons.movie_outlined,
                        size: 16,
                        color: const Color(0xff0f172a),
                      ),
                    if (showText) ...[
                      const SizedBox(width: 5),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: hasFilmstrip
                                  ? const Color(0x99000000)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: KText(
                                audio
                                    ? extractedAudio
                                        ? 'Extracted ${_formatDuration(video.durationSeconds)}'
                                        : _formatDuration(video.durationSeconds)
                                    : partIndex == null
                                        ? video.name
                                        : '${video.name}-$partIndex',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasFilmstrip
                                      ? Colors.white
                                      : const Color(0xff0f172a),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  shadows: hasFilmstrip
                                      ? const [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else if (compactClip)
                      const Spacer(),
                    if (showEditIcon)
                      const Icon(
                        Icons.content_cut,
                        size: 13,
                        color: Color(0xff111827),
                      ),
                  ],
                ),
              ),
            if (showStartTrimHandle)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _timelineTrimHandle(startEdge: true),
              ),
            if (showEndTrimHandle)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _timelineTrimHandle(startEdge: false),
              ),
          ],
        ),
      ),
    );
    if (!draggable || timelinePart == null || visualPartIndex == null) {
      return clip;
    }
    return Draggable<_TimelinePartDrag>(
      data: _TimelinePartDrag(
        videoPath: video.path,
        visualPartIndex: visualPartIndex,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width.clamp(72.0, 260.0).toDouble(),
          height: 38,
          child: Opacity(opacity: 0.85, child: clip),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: clip),
      child: clip,
    );
  }

  Widget _timelineFilmstrip(
    PickedVideo video, {
    required double width,
    ({double start, double end})? timelinePart,
  }) {
    final frames = video.timelineThumbnailPaths;
    if (frames.isEmpty) return const SizedBox.shrink();
    final tileCount = math.max(1, (width / 58).ceil());
    final tileWidth = width / tileCount;
    final duration = math.max(0.001, video.durationSeconds ?? 0.001);
    final partStart = timelinePart?.start ?? 0.0;
    final partEnd = timelinePart?.end ?? duration;
    return ClipRect(
      child: Row(
        children: [
          for (var tile = 0; tile < tileCount; tile++)
            SizedBox(
              width: tileWidth,
              child: Image.file(
                File(
                  frames[((partStart +
                              (partEnd - partStart) *
                                  ((tile + 0.5) / tileCount)) /
                          duration *
                          frames.length)
                      .floor()
                      .clamp(0, frames.length - 1)],
                ),
                height: double.infinity,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: const Color(0xff334155),
                  child: Icon(
                    Icons.movie_outlined,
                    size: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineTrimHandle({required bool startEdge}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _beginTimelineTrim(),
        onHorizontalDragUpdate: (details) => _updateTimelineTrim(
          startEdge: startEdge,
          deltaPixels: details.delta.dx,
        ),
        onHorizontalDragEnd: (_) => _endTimelineTrim(),
        onHorizontalDragCancel: _endTimelineTrim,
        child: Tooltip(
          message:
              startEdge ? 'Drag to trim clip start' : 'Drag to trim clip end',
          child: Container(
            width: 11,
            decoration: BoxDecoration(
              color: const Color(0xfffacc15),
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(startEdge ? 3 : 0),
                right: Radius.circular(startEdge ? 0 : 3),
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 3),
              ],
            ),
            child: Center(
              child: Container(
                width: 2,
                height: 14,
                color: const Color(0xff713f12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetSelectedClipCut() {
    if (_videos.isEmpty) return;
    if (!_ensureTimelineClipUnlocked(
      _selectedTimelineClipId,
      action: 'resetting this clip',
    )) {
      return;
    }
    final current = _clipTimelineEditFor(_videos[_selectedVideoIndex].path);
    _setSelectedClipTimelineEdit(
      _ClipTimelineEdit(
        speed: current.speed,
        flip: current.flip,
        scaleX: current.scaleX,
        scaleY: current.scaleY,
        zoom: current.zoom,
        panX: current.panX,
        panY: current.panY,
      ),
    );
  }

  ClipModel? _activeBaseVideoClip(double playhead) {
    final timeline = _programPreviewTimeline;
    if (timeline.videoTracks.isEmpty) return null;
    final track = timeline.videoTracks.first;
    if (track.isMuted) return null;
    for (final clip in track.clips) {
      if (!clip.isMuted &&
          playhead >= clip.timelineStart &&
          playhead < clip.timelineEnd) {
        return clip;
      }
    }
    return null;
  }

  bool get _activeTimelineSourceAudioMuted {
    final videoId = _programTimelineClipId ?? _selectedTimelineClipId;
    if (videoId == null) return false;
    final linked = _multiTrackTimeline.linkedAudioForVideo(videoId);
    if (linked == null) return false;
    final result = _multiTrackTimeline.clipById(linked.id);
    return linked.isMuted || result?.track.isMuted == true;
  }

  int _nextTextTrackIndex() {
    final indexes = <int>{
      for (final track in _multiTrackTimeline.textTracks) track.index,
      for (final overlay in _textOverlays)
        if (overlay.text.trim().isNotEmpty) overlay.trackIndex,
    };
    return indexes.isEmpty ? 1 : indexes.reduce(math.max) + 1;
  }

  void _insertTextTimelineClip(_TextOverlayDraft overlay) {
    if (overlay.id.isEmpty || overlay.text.trim().isEmpty) return;
    var tracks = [..._multiTrackTimeline.tracks];
    var trackIndex = tracks.indexWhere(
      (track) =>
          track.type == TrackType.text && track.index == overlay.trackIndex,
    );
    if (trackIndex < 0) {
      tracks.add(
        TrackModel(
          id: 'text-${overlay.trackIndex}',
          type: TrackType.text,
          index: overlay.trackIndex,
          isMuted: !overlay.isVisible,
          isLocked: overlay.isLocked,
        ),
      );
      trackIndex = tracks.length - 1;
    }
    final track = tracks[trackIndex];
    final existing = _multiTrackTimeline.clipById(overlay.id)?.clip;
    final clip = ClipModel(
      id: overlay.id,
      mediaPath: overlay.id,
      timelineStart: overlay.timelineStart,
      duration: overlay.duration <= 0
          ? math.max(0.5, _timelineSequenceDuration())
          : overlay.duration,
      sourceStart: existing?.sourceStart ?? 0,
      transform: existing?.transform ?? const ClipTransform(),
      keyframes: existing?.keyframes ?? const [],
      textAnimationOffset: existing?.textAnimationOffset ?? 0,
      zIndex: overlay.trackIndex - 1,
    );
    tracks[trackIndex] = track.copyWith(
      isMuted: !overlay.isVisible,
      isLocked: overlay.isLocked,
      clips: [
        ...track.clips.where((item) => item.id != overlay.id),
        clip,
      ],
    );
    _multiTrackTimeline = TimelineModel(
      tracks: tracks,
      duration: TimelineModel.calculateDuration(tracks),
    ).normalized();
  }

  void _ensureTextTimelineTracks() {
    for (var index = 0; index < _textOverlays.length; index++) {
      var overlay = _textOverlays[index];
      if (overlay.text.trim().isEmpty) continue;
      if (overlay.id.isEmpty) {
        final migratedStart =
            overlay.timelineStart > 0 ? overlay.timelineStart : index * 5.0;
        final available = _timelineSequenceDuration() - migratedStart;
        overlay = overlay.copyWith(
          id: 'text-legacy-${index + 1}',
          trackIndex: index + 1,
          timelineStart: migratedStart,
          duration: overlay.duration <= 0
              ? math.max(0.5, math.min(5.0, math.max(0.5, available)))
              : overlay.duration,
        );
        _textOverlays[index] = overlay;
      }
      if (_multiTrackTimeline.clipById(overlay.id) == null) {
        _insertTextTimelineClip(overlay);
      }
    }
  }

  void _applyTimelineModelUpdate(TimelineModel model) {
    _multiTrackTimeline = model;
    final primaryAudio = model.trackById('audio-1');
    if (primaryAudio != null) {
      _originalAudioMuted = primaryAudio.isMuted;
    }
    for (final track in model.textTracks) {
      for (final clip in track.clips) {
        final index = _textOverlays.indexWhere(
          (overlay) => overlay.id == clip.id || overlay.id == clip.mediaPath,
        );
        if (index < 0) continue;
        _textOverlays[index] = _textOverlays[index].copyWith(
          timelineStart: clip.timelineStart,
          duration: clip.duration,
          trackIndex: track.index,
          isVisible: !track.isMuted,
          isLocked: track.isLocked,
        );
      }
    }
  }
}
