part of 'dynamic_timeline_view.dart';

extension _DynamicClipWidget on DynamicTimelineView {
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
    final hasLinkedAudio = track.type == TrackType.video &&
        model.linkedAudioForVideo(clip.id) != null;
    // Legacy video-only timelines have implicit source audio. Once an audio
    // track exists, only instance ownership may show an embedded companion;
    // matching the media path would incorrectly relink detached audio.
    final hasSourceAudioFallback = track.type == TrackType.video &&
        model.audioTracks.isEmpty &&
        mediaWithSourceAudio.contains(clip.mediaPath);
    final showAudioStrip = hasLinkedAudio || hasSourceAudioFallback;
    final controllableAudio = track.type == TrackType.audio
        ? clip
        : model.linkedAudioForVideo(clip.id);
    final editLocked =
        track.isLocked || LinkedAudioEditGuard.blocks(model, {clip.id});
    final ordered = [...track.clips]
      ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
    final index = ordered.indexWhere((item) => item.id == clip.id);
    final validTransition = clip.transitionIn != null &&
        index > 0 &&
        TransitionBoundary.joins(ordered[index - 1], clip);
    final color = switch (track.type) {
      TrackType.video => const Color(0xff0f5963),
      TrackType.audio => const Color(0xff176b64),
      TrackType.text => const Color(0xff8b4938),
    };
    final rawContent = RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor:
              editLocked ? SystemMouseCursors.basic : SystemMouseCursors.grab,
          hoverColor: Colors.white.withOpacity(.12),
          focusColor: Colors.white.withOpacity(.18),
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
              color: color
                  .withOpacity(track.isMuted || clip.isMuted ? 0.28 : 0.88),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? const Color(0xff67e8f9)
                    : const Color(0xff2c7780),
                width: selected ? 2.0 : 1.0,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (track.type == TrackType.video)
                  Positioned.fill(
                    top: width >= 52 ? 18 : 0,
                    bottom: showAudioStrip ? 28 : 0,
                    child: _filmstrip(clip, width),
                  )
                else if (track.type == TrackType.audio)
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _DynamicWaveformPainter(
                        color: Colors.white.withOpacity(0.65),
                        peaks: audioWaveformPeaks[clip.mediaPath] ?? const [],
                        peaksPerSecond:
                            waveformPeaksPerSecondByMedia[clip.mediaPath] ??
                                waveformPeaksPerSecond,
                        sourceStart: clip.sourceStart,
                        duration: editor.programTime
                            ? clip.sourceDurationFromProgram()
                            : clip.duration,
                        visibleStartFraction: visibleFractions.startFraction,
                        visibleEndFraction: visibleFractions.endFraction,
                      ),
                    ),
                  ),
                if (showAudioStrip)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      key: ValueKey('linked-audio-waveform-${clip.id}'),
                      height: 28,
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
                            peaksPerSecond:
                                waveformPeaksPerSecondByMedia[clip.mediaPath] ??
                                    waveformPeaksPerSecond,
                            sourceStart: clip.sourceStart,
                            duration: editor.programTime
                                ? clip.sourceDurationFromProgram()
                                : clip.duration,
                            visibleStartFraction:
                                visibleFractions.startFraction,
                            visibleEndFraction: visibleFractions.endFraction,
                          ),
                        ),
                      ),
                    ),
                  ),
                Container(color: Colors.black.withOpacity(0.12)),
                if (validTransition)
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
                      height: 18,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
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
                          fontSize: 9,
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
                if (editLocked)
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
                if (width >= 95)
                  Positioned(
                      left: 7,
                      bottom: showAudioStrip ? 30 : 4,
                      right: 35,
                      child: Text(
                          [
                            if (clip.resolvedPlaybackSpeed() != 1)
                              '${clip.resolvedPlaybackSpeed()}×',
                            if (track.type == TrackType.audio)
                              clip.isLinkedAudio
                                  ? 'Linked audio'
                                  : 'Independent audio',
                            if (track.type == TrackType.video &&
                                model.linkedAudioForVideo(clip.id) != null)
                              'Linked audio',
                          ].join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 3)
                              ]))),
              ],
            ),
          ),
        ),
      ),
    );
    final content = _TimelineClipInteractionSurface(
      selected: selected,
      locked: editLocked,
      tooltip:
          '${_visualClipLabel(clip)}  ${timelineEditTime(clip.timelineStart)} – ${timelineEditTime(clip.timelineEnd)}'
          '${editLocked ? '  •  Locked' : ''}',
      child: rawContent,
    );
    return Positioned(
      left: clip.timelineStart * pixelsPerSecond,
      width: width,
      top: 0,
      bottom: 0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          editLocked
              ? content
              : Draggable<TimelineClipDragData>(
                  data: dragData,
                  onDragStarted: () => gestureFeedback?.value =
                      TimelineGestureFeedback(
                          time: clip.timelineStart, duration: clip.duration),
                  dragAnchorStrategy: (draggable, context, globalPosition) {
                    final box = context.findRenderObject() as RenderBox?;
                    final local = box?.globalToLocal(globalPosition) ??
                        Offset(width / 2, 0);
                    dragData.grabOffsetSeconds = (local.dx / pixelsPerSecond)
                        .clamp(0.0, clip.duration)
                        .toDouble();
                    return local;
                  },
                  onDragEnd: (_) => gestureFeedback?.value = null,
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
          if (validTransition && onTransitionSelected != null && width > 24)
            Positioned(
                left: 7,
                bottom: 3,
                width: math.min(
                    math.max(20, clip.transitionIn!.duration * pixelsPerSecond),
                    width - 14),
                height: 18,
                child: Tooltip(
                    message:
                        '${clip.transitionIn!.type.label} · ${clip.transitionIn!.duration.toStringAsFixed(3)} s',
                    child: Material(
                        color: selectedTransitionClipId == clip.id
                            ? const Color(0xfffacc15)
                            : const Color(0xff155e75),
                        borderRadius: BorderRadius.circular(3),
                        child: InkWell(
                            key: ValueKey('transition-${clip.id}'),
                            onTap: () => onTransitionSelected!(clip.id),
                            child: const Icon(Icons.blur_on,
                                size: 14, color: Colors.white))))),
          if (selected && !editLocked)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _resizeHandle(clip, startEdge: true),
            ),
          if (selected && !editLocked)
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
      editor: editor,
      clipId: clip.id,
      startEdge: startEdge,
      pixelsPerSecond: pixelsPerSecond,
      onPreview: onModelPreviewChanged ?? onModelChanged,
      onCommit: onModelPreviewCommitted,
      feedback: gestureFeedback,
      playhead: _playheadOverrideSeconds(),
      markers: markers,
    );
  }

  void _setClipAudioMuted(ClipModel audioClip, bool muted) {
    final result = model.clipById(audioClip.id);
    if (result == null || result.track.isLocked) return;
    onModelChanged(
      editor.updateTrack(
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
    final visible = _visibleClipFractions(clip);
    final left = width * visible.startFraction;
    final visibleWidth = math.max(
      1.0,
      width * (visible.endFraction - visible.startFraction),
    );
    final count = (visibleWidth / 84).ceil().clamp(1, 32);
    final sourceLength =
        editor.programTime ? clip.sourceDurationFromProgram() : clip.duration;
    final assetDuration = sourceDurations[clip.mediaPath];
    int thumbnailIndex(double fraction) {
      final assetFraction = assetDuration != null && assetDuration > 0
          ? (clip.sourceStart + sourceLength * fraction) / assetDuration
          : fraction;
      // Cached frames are sampled at (index + .5) / count, not endpoints.
      return (assetFraction * paths.length).floor().clamp(0, paths.length - 1);
    }

    String? frameFor(double fraction) {
      if (paths.isEmpty) return null;
      final index = thumbnailIndex(fraction);
      if (paths[index].isNotEmpty) return paths[index];
      // The cache is populated progressively. Reuse the nearest completed
      // sample so a partially loaded filmstrip remains continuous instead of
      // showing large placeholder gaps between decoded thumbnails.
      for (var distance = 1; distance < paths.length; distance++) {
        final left = index - distance;
        if (left >= 0 && paths[left].isNotEmpty) return paths[left];
        final right = index + distance;
        if (right < paths.length && paths[right].isNotEmpty) {
          return paths[right];
        }
      }
      return null;
    }

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
                      child: _filmstripCell(frameFor(visible.startFraction +
                          (visible.endFraction - visible.startFraction) *
                              (index + 0.5) /
                              count))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filmstripPlaceholder() => const ColoredBox(
        color: Color(0xff24424a),
        child: Center(
          child: Icon(Icons.movie_outlined, size: 18, color: Color(0xff92aeb5)),
        ),
      );

  Widget _filmstripCell(String? frame) => frame == null
      ? _filmstripPlaceholder()
      : Image.file(
          File(frame),
          height: double.infinity,
          cacheWidth: 160,
          filterQuality: FilterQuality.low,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _filmstripPlaceholder(),
        );

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
