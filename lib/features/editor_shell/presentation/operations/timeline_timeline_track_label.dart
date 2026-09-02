part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineTimelineTrackLabel on _EditorScreenState {
  Widget _timelineTrackLabel(String label, {required double fontSize}) {
    final isVideo = label.startsWith('V');
    final isCaption = label.startsWith('T');
    final isPrimaryVideo = label == 'V1';
    final isVideoAudio = label == 'A1' || label == 'A2';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isCaption)
            Icon(
              Icons.subtitles_outlined,
              size: fontSize + 3,
              color: const Color(0xfff97316),
            )
          else if (isPrimaryVideo)
            _timelineTrackToggle(
              icon: _videoTrackHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              tooltip:
                  _videoTrackHidden ? 'Show video track' : 'Hide video track',
              active: !_videoTrackHidden,
              onPressed: () => _updateEditor(() {
                _videoTrackHidden = !_videoTrackHidden;
              }),
            )
          else if (isVideo)
            Icon(
              Icons.visibility_outlined,
              size: fontSize + 2,
              color: _mutedTextColor,
            )
          else
            _timelineTrackToggle(
              icon: (isVideoAudio ? _originalAudioMuted : _musicTrackMuted)
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
              tooltip: (isVideoAudio ? _originalAudioMuted : _musicTrackMuted)
                  ? 'Unmute track'
                  : 'Mute track',
              active: !(isVideoAudio ? _originalAudioMuted : _musicTrackMuted),
              onPressed: () {
                _updateEditor(() {
                  if (isVideoAudio) {
                    _originalAudioMuted = !_originalAudioMuted;
                  } else {
                    _musicTrackMuted = !_musicTrackMuted;
                  }
                });
                final controller = _previewController;
                if (controller != null && controller.value.isInitialized) {
                  unawaited(
                    controller.setVolume(
                      _previewAudioVolume(_effectiveOriginalVolume),
                    ),
                  );
                }
                unawaited(
                  _musicPreviewPlayer.setVolume(
                    _previewAudioVolume(_effectiveMusicVolume),
                  ),
                );
              },
            ),
          const SizedBox(width: 5),
          KText(
            label,
            style: TextStyle(
              color: _mutedTextColor,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineTrackToggle({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      iconSize: 15,
      color: active ? const Color(0xff94a3b8) : const Color(0xff64748b),
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
    );
  }

  Widget _timelineRuler({required double width, required bool compact}) {
    return CustomPaint(
      painter: _TimelineRulerPainter(
        marks: _timelineRulerMarks(width, compact: compact),
        compact: compact,
        axisColor: _panelBorderColor,
        labelColor: _mutedTextColor,
      ),
      child: const SizedBox.expand(),
    );
  }

  List<({double x, double seconds, bool major})> _timelineRulerMarks(
    double width, {
    required bool compact,
  }) {
    if (_videos.isEmpty || width <= 0) {
      return const [];
    }
    final step = _timelineTickStep();
    final majorEvery = _timelineMajorTickEvery(step);
    final marks = <({double x, double seconds, bool major})>[];
    final sequenceDuration = _timelineSequenceDuration();
    final pixelsPerSecond = _timelinePixelsPerSecond();
    final viewportWidth = _timelineScrollController.hasClients
        ? _timelineScrollController.position.viewportDimension
        : width;
    final labelWidth = compact ? 52.0 : 72.0;
    const bufferPx = 240.0;
    final visibleStartPx =
        (_timelineScrollOffset - labelWidth - bufferPx).clamp(0.0, width);
    final visibleEndPx =
        (_timelineScrollOffset + viewportWidth - labelWidth + bufferPx)
            .clamp(0.0, width);
    var second = (visibleStartPx / pixelsPerSecond / step).floor() * step;
    var index = (second / step).round();
    final maxSecond =
        (visibleEndPx / pixelsPerSecond).clamp(0.0, sequenceDuration);
    while (second <= sequenceDuration + 0.001) {
      if (second > maxSecond + step) break;
      marks.add((
        x: (second * pixelsPerSecond).clamp(0.0, width),
        seconds: second,
        major: index % majorEvery == 0,
      ));
      second += step;
      index++;
    }
    if (sequenceDuration * pixelsPerSecond >= visibleStartPx &&
        sequenceDuration * pixelsPerSecond <= visibleEndPx &&
        (marks.isEmpty || marks.last.seconds < sequenceDuration)) {
      marks.add((
        x: (sequenceDuration * pixelsPerSecond).clamp(0.0, width),
        seconds: sequenceDuration,
        major: true,
      ));
    }
    return marks;
  }

  double _timelineTickStep() {
    final px = _timelinePixelsPerSecond();
    if (px >= 140) return 0.1;
    if (px >= 70) return 0.25;
    if (px >= 36) return 0.5;
    if (px >= 16) return 1;
    if (px >= 8) return 2;
    if (px >= 4) return 5;
    return 10;
  }

  int _timelineMajorTickEvery(double step) {
    if (step < 1) return (1 / step).round();
    if (step <= 1) return 5;
    return 2;
  }

  Widget _timelineActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
    bool primary = false,
    bool danger = false,
    bool iconOnly = false,
  }) {
    final foreground = danger ? const Color(0xffef4444) : null;
    final style = primary
        ? FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 6 : 9),
            minimumSize: const Size(0, 28),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: danger ? const BorderSide(color: Color(0xff7f1d1d)) : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 6 : 8),
            minimumSize: const Size(0, 28),
          );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        if (!iconOnly) ...[
          const SizedBox(width: 4),
          KText(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
      child: Tooltip(
        message: tooltip,
        child: primary
            ? FilledButton(onPressed: onPressed, style: style, child: child)
            : OutlinedButton(onPressed: onPressed, style: style, child: child),
      ),
    );
  }

  Widget _timelineToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool selected = false,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      onPressed: onPressed,
      style: selected
          ? IconButton.styleFrom(
              backgroundColor: const Color(0xff1d4ed8),
              foregroundColor: Colors.white,
            )
          : null,
      icon: Icon(icon),
      tooltip: tooltip,
    );
  }

  Widget _timelineAddTrackMenu({required bool enabled}) {
    return PopupMenuButton<TrackType>(
      enabled: enabled,
      tooltip: 'Add track',
      onSelected: _addTimelineTrack,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: TrackType.video,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.video_call_outlined, size: 18),
            title: KText('Video track'),
          ),
        ),
        PopupMenuItem(
          value: TrackType.audio,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.playlist_add, size: 18),
            title: KText('Audio track'),
          ),
        ),
        PopupMenuItem(
          value: TrackType.text,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.title_outlined, size: 18),
            title: KText('Text track'),
          ),
        ),
      ],
      child: Container(
        height: 28,
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: _panelBorderColor),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          Icons.add_to_photos_outlined,
          size: 16,
          color: enabled ? null : _mutedTextColor.withOpacity(0.45),
        ),
      ),
    );
  }

  void _addTimelineTrack(TrackType type) {
    _recordEditorHistory('add-${type.name}-track');
    _updateEditor(() {
      _multiTrackTimeline = _timelineEditor.addTrack(
        _multiTrackTimeline,
        type,
      );
      _status = 'Added ${type.name} track';
    });
    unawaited(_autosaveProject());
  }

  Widget _timelineSpeedMenu({
    required bool enabled,
    required bool compact,
  }) {
    final accent = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<double>(
      enabled: enabled,
      tooltip: 'Clip speed',
      onSelected: _setPreviewSpeed,
      itemBuilder: (context) => [
        for (final value in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
          PopupMenuItem<double>(
            value: value,
            child: Row(
              children: [
                Icon(
                  (_speed - value).abs() < 0.01 ? Icons.check : Icons.speed,
                  size: 16,
                  color: (_speed - value).abs() < 0.01 ? accent : null,
                ),
                const SizedBox(width: 8),
                KText('${value.toStringAsFixed(value == 1 ? 0 : 2)}x'),
              ],
            ),
          ),
      ],
      child: Container(
        height: 28,
        margin: const EdgeInsets.only(right: 4),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: (_speed - 1).abs() > 0.01
              ? accent.withOpacity(0.14)
              : Colors.transparent,
          border: Border.all(color: _panelBorderColor),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed,
                size: 16,
                color: enabled ? null : _mutedTextColor.withOpacity(0.45)),
            if (!compact) ...[
              const SizedBox(width: 4),
              KText('${_speed.toStringAsFixed(1)}x',
                  style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  void _zoomTimelineIn() {
    _setTimelineZoom((_timelineZoom + 5).clamp(0, 100).toDouble());
  }

  void _zoomTimelineOut() {
    _setTimelineZoom((_timelineZoom - 5).clamp(0, 100).toDouble());
  }

  void _fitTimelineZoom() {
    _setTimelineZoom(0, resetScroll: true);
  }

  void _setTimelineZoom(
    double value, {
    bool resetScroll = false,
    double? pointerViewportX,
  }) {
    final nextZoom = value.clamp(0.0, 100.0).toDouble();
    if (!resetScroll && (nextZoom - _timelineZoom).abs() < 0.001) return;

    final oldPixelsPerSecond = _timelinePixelsPerSecond();
    final oldOffset = _timelineScrollController.hasClients
        ? _timelineScrollController.offset
        : _timelineScrollOffset;
    final anchorViewportX = pointerViewportX ??
        (_liveTimelineSeconds * oldPixelsPerSecond - oldOffset);
    final anchorSeconds = ((oldOffset + anchorViewportX) / oldPixelsPerSecond)
        .clamp(0.0, math.max(0.0, _timelineSequenceDuration()))
        .toDouble();
    final generation = ++_timelineZoomGeneration;

    _updateEditor(() => _timelineZoom = nextZoom);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _timelineZoomGeneration ||
          !_timelineScrollController.hasClients) {
        return;
      }
      final position = _timelineScrollController.position;
      final target = resetScroll
          ? 0.0
          : anchorSeconds * _timelinePixelsPerSecond() - anchorViewportX;
      final clamped = target.clamp(0.0, position.maxScrollExtent).toDouble();
      if ((position.pixels - clamped).abs() > 0.5) {
        _timelineScrollController.jumpTo(clamped);
      }
      _timelineScrollOffset = clamped;
      _timelineScrollOffsetListenable.value = clamped;
    });
  }

  double _timelinePixelsPerSecond() {
    final progress = _timelineZoom.clamp(0, 100) / 100;
    final duration = math.max(0.1, _timelineSequenceDuration() + 2);
    final viewport = _timelineViewportWidth > 0 ? _timelineViewportWidth : 900;
    // Zero percent is a true wide overview. Short edits remain readable while
    // long projects shrink enough to show their complete duration.
    final fitScale = (viewport * 0.62 / duration).clamp(0.08, 160.0).toDouble();
    return fitScale * math.pow(160 / fitScale, progress).toDouble();
  }

  double _timelinePartWidth(({double start, double end}) part) {
    final duration = (part.end - part.start).abs();
    return (duration * _timelinePixelsPerSecond())
        .clamp(1.0, double.infinity)
        .toDouble();
  }

  double _timelineContentWidth({double minimumWidth = 420}) {
    if (_multiTrackTimeline.tracks.isNotEmpty) {
      return math.max(minimumWidth,
          (_timelineSequenceDuration() + 2) * _timelinePixelsPerSecond());
    }
    var width = 0.0;
    for (final item in _visibleTimelineVideos()) {
      final parts = _clipTimelineEditFor(item.video.path).timelineParts(
        item.video.durationSeconds,
      );
      for (final part in parts) {
        width += _timelinePartWidth(part);
      }
    }
    final dynamicWidth =
        (_multiTrackTimeline.duration + 2) * _timelinePixelsPerSecond();
    width = math.max(width, dynamicWidth);
    return width < minimumWidth ? minimumWidth : width;
  }

  double get _liveTimelineSeconds =>
      _timelineScrubController.playhead.value.inMicroseconds / 1000000;

  void _setLiveTimelinePlayhead(double seconds) {
    _timelineScrubController.setExternalPosition(
      Duration(microseconds: (math.max(0, seconds) * 1000000).round()),
    );
  }

  void _beginMultiTrackTimelineScrub(double seconds) {
    if (_videos.isEmpty) return;
    _timelineSeekDebounce?.cancel();
    _activeScrubSnapshot = _programRenderSnapshot(_multiTrackTimeline);
    _timelineScrubController.begin(
      Duration(
          microseconds: (seconds.clamp(
                      0.0, _activeScrubSnapshot!.outputTimeline.duration) *
                  1000000)
              .round()),
    );
  }

  void _updateMultiTrackTimelineScrub(double seconds) {
    if (_videos.isEmpty) return;
    _timelineScrubController.update(
      Duration(
          microseconds: (seconds.clamp(
                      0.0,
                      _activeScrubSnapshot?.outputTimeline.duration ??
                          _timelineSequenceDuration()) *
                  1000000)
              .round()),
    );
  }

  void _endMultiTrackTimelineScrub(double seconds) {
    if (_videos.isEmpty) return;
    unawaited(
      _timelineScrubController
          .end(
            Duration(
              microseconds: (seconds.clamp(
                          0.0,
                          _activeScrubSnapshot?.outputTimeline.duration ??
                              _timelineSequenceDuration()) *
                      1000000)
                  .round(),
            ),
          )
          .whenComplete(() => _activeScrubSnapshot = null),
    );
  }

  void _requestMultiTrackTimelineSeek(double seconds) {
    if (_videos.isEmpty) return;
    final duration = _programPlaybackDurationSeconds();
    final requested = seconds.clamp(0.0, duration).toDouble();
    final generation = ++_timelineSeekGeneration;
    _requestedTimelinePlayheadSeconds.value = requested;
    _setLiveTimelinePlayhead(requested);
    _timelineSeekDebounce?.cancel();
    _timelineSeekDebounce = Timer(
      const Duration(milliseconds: 35),
      () => unawaited(
        _commitMultiTrackTimelineSeek(requested, generation),
      ),
    );
  }

  Future<void> _commitMultiTrackTimelineSeek(
    double seconds,
    int generation, {
    ProgramRenderSnapshot? renderSnapshot,
    bool exactSeek = true,
  }) async {
    await _programSeekQueue.run<void>(
      isCurrent: () => mounted && generation == _timelineSeekGeneration,
      operation: () => _performMultiTrackTimelineSeek(seconds, generation,
          renderSnapshot: renderSnapshot, exactSeek: exactSeek),
    );
  }

  Future<void> _performMultiTrackTimelineSeek(
    double seconds,
    int generation, {
    ProgramRenderSnapshot? renderSnapshot,
    bool exactSeek = true,
  }) async {
    bool isCurrent() => mounted && generation == _timelineSeekGeneration;
    if (_videos.isEmpty || !isCurrent()) return;
    final target = _programTargetForTimelineSeconds(
      seconds,
      renderSnapshot: renderSnapshot,
    );
    if (target == null) return;
    final wasPlaying = _previewController?.value.isPlaying == true;
    if (target.isGap) {
      await _previewController?.pause();
      if (!isCurrent()) return;
      await _pauseMusicPreview();
      if (!isCurrent()) return;
      _programTimelineClipId = null;
      if (generation == _timelineSeekGeneration) {
        _requestedTimelinePlayheadSeconds.value = target.timelineSeconds;
        _setLiveTimelinePlayhead(target.timelineSeconds);
      }
      if (mounted && exactSeek) _updateEditor(() {});
      return;
    }
    final wasClipEditMode = _clipEditMode;
    final switchingVideo = target.videoIndex != _selectedVideoIndex;
    final controllerUnavailable = _previewController == null ||
        _previewController?.value.isInitialized != true;
    if (switchingVideo || controllerUnavailable) {
      await _selectVideo(
        target.videoIndex,
        saveCurrentEdit: switchingVideo,
      );
      if (!isCurrent()) return;
      if (mounted && _clipEditMode != wasClipEditMode) {
        _updateEditor(() => _clipEditMode = wasClipEditMode);
      }
    }
    final targetClip = target.clipId == null
        ? null
        : _multiTrackTimeline.clipById(target.clipId!)?.clip;
    if (targetClip != null && exactSeek) {
      _loadTimelineClipTransformIntoInspector(targetClip);
    }
    final controller = _previewController;
    if (controller != null && controller.value.isInitialized) {
      _programTimelineClipId = target.clipId;
      await _applyProgramClipPlaybackSettings(target.clipId);
      if (!isCurrent() || !identical(controller, _previewController)) return;
      await controller.seekTo(
        Duration(microseconds: (target.sourceSeconds! * 1000000).round()),
      );
      if (!isCurrent() || !identical(controller, _previewController)) return;
      if (target.timelineSeconds >= _programPlaybackDurationSeconds()) {
        await controller.pause();
        if (!isCurrent()) return;
        await _pauseMusicPreview();
        _requestedTimelinePlayheadSeconds.value = target.timelineSeconds;
      } else if (wasPlaying) {
        await controller.play();
      } else if (exactSeek) {
        _schedulePausedFramePrime(controller, source: false);
      }
    }
    if (generation == _timelineSeekGeneration) {
      _setLiveTimelinePlayhead(target.timelineSeconds);
    }
  }

  void _commitTimelineEditPreview() {
    final preview = _timelineEditPreviewModel.value;
    if (preview == null) return;
    _timelineEditPreviewModel.value = null;
    if (jsonEncode(preview.toJson()) ==
        jsonEncode(_programEditingTimeline.toJson())) return;
    _commitTimelineModelChange(_sourceTimelineFromProgramEdit(preview));
  }

  void _commitTimelineModelChange(TimelineModel model) {
    if (identical(model, _multiTrackTimeline)) return;
    _recordEditorHistory('timeline-model-change', coalesce: false);
    _updateEditor(() {
      _applyTimelineModelUpdate(model);
      _status = 'Multi-track timeline updated';
    });
    final controller = _previewController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(
        controller.setVolume(
          _previewAudioVolume(_effectiveOriginalVolume),
        ),
      );
    }
    unawaited(_autosaveProject());
  }
}
