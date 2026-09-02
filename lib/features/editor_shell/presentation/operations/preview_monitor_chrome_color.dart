part of '../editor_application.dart';

// preview operations owned by the editor state; extracted without changing timing.
extension _PreviewMonitorChromeColor on _EditorScreenState {
  Color get _monitorChromeColor =>
      _isLightUi ? const Color(0xfff8fafc) : const Color(0xff17191e);

  Color get _monitorChromeBorderColor =>
      _isLightUi ? const Color(0xffd6dde8) : const Color(0xff30343d);

  Color get _monitorChromeTextColor =>
      _isLightUi ? const Color(0xff172033) : const Color(0xffe4e7ec);

  Color get _monitorCanvasColor =>
      _isLightUi ? const Color(0xffffffff) : const Color(0xff090b0f);

  void _applyProjectTransform(Object? value) {
    final data = value is Map ? value : const {};
    double number(String key, double fallback) =>
        double.tryParse('${data[key] ?? fallback}') ?? fallback;
    _speed = number('speed', _speed);
    _flip = '${data['flip'] ?? _flip}';
    _scaleX = number('scaleX', _scaleX);
    _scaleY = number('scaleY', _scaleY);
    _zoom = number('zoom', _zoom);
    _panX = number('panX', _panX);
    _panY = number('panY', _panY);
    final canvasMode = '${data['canvasMode'] ?? _canvasMode}'.toLowerCase();
    _canvasMode =
        const {'none', 'blur', 'color', 'pattern'}.contains(canvasMode)
            ? canvasMode
            : 'none';
    final canvasPattern =
        '${data['canvasPattern'] ?? _canvasPattern}'.toLowerCase();
    _canvasPattern =
        const {'grid', 'stripes', 'checker', 'dots'}.contains(canvasPattern)
            ? canvasPattern
            : 'grid';
    _canvasColor =
        _parseHexColor('${data['canvasColor'] ?? ''}') ?? _canvasColor;
    _canvasBlur = number('canvasBlur', _canvasBlur).clamp(4, 80).toDouble();
  }

  void _saveSelectedTransformEdit() {
    if (_videos.isEmpty ||
        _selectedVideoIndex < 0 ||
        _selectedVideoIndex >= _videos.length) {
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    _clipTimelineEdits[path] =
        _clipEditWithCurrentTransform(_clipTimelineEditFor(path));
  }

  void _updateCanvasSettings({
    String? mode,
    Color? color,
    String? pattern,
    double? blur,
    bool applyToAll = false,
  }) {
    final selectedIds = _effectiveSelectedTimelineClipIds;
    final editableIds = <String>{};
    for (final track in _multiTrackTimeline.videoTracks) {
      if (track.isLocked) continue;
      for (final clip in track.clips) {
        if (applyToAll || selectedIds.contains(clip.id)) {
          editableIds.add(clip.id);
        }
      }
    }
    if (editableIds.isEmpty) {
      _showMessage('Select an unlocked video clip first.');
      return;
    }
    _recordEditorHistory('video-canvas');
    _updateEditor(() {
      _canvasMode = mode ?? _canvasMode;
      _canvasColor = color ?? _canvasColor;
      _canvasPattern = pattern ?? _canvasPattern;
      _canvasBlur = (blur ?? _canvasBlur).clamp(4, 80).toDouble();
      var next = _multiTrackTimeline;
      for (final clipId in editableIds) {
        final result = next.clipById(clipId);
        if (result == null || result.track.type != TrackType.video) continue;
        next = _timelineEditor.updateClipTransform(
          next,
          clipId,
          result.clip.transform.copyWith(
            canvasMode: _canvasMode,
            canvasColor: _colorToHex(_canvasColor),
            canvasPattern: _canvasPattern,
            canvasBlur: _canvasBlur,
          ),
        );
      }
      _applyTimelineModelUpdate(next);
      _storeActiveCompositionTimeline();
      _status = applyToAll
          ? 'Canvas applied to all video clips'
          : 'Canvas updated for ${editableIds.length} clip${editableIds.length == 1 ? '' : 's'}';
    });
    unawaited(_autosaveProject());
  }

  void _setSelectedTransformEdit(
      _ClipTimelineEdit Function(_ClipTimelineEdit) update) {
    if (_videos.isEmpty) {
      _updateEditor(() {});
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    final current = _clipTimelineEditFor(path);
    final next = update(_clipEditWithCurrentTransform(current));
    if (current.sameAs(next)) return;
    _recordEditorHistory('video-transform');
    _updateEditor(() {
      _clipTimelineUndoStacks.putIfAbsent(path, () => []).add(current);
      _clipTimelineRedoStacks[path]?.clear();
      if (_selectedVideoIndex > 0) {
        _clipTransformOverrides.add(path);
      }
      _clipTimelineEdits[path] = next;
      _applyClipTimelineEdit(next);
      _updateSelectedTimelineClipTransform(next);
    });
    unawaited(_autosaveProject());
  }

  void _applyCurrentTransformToAllVideos() {
    if (_videos.isEmpty) return;
    unawaited(_showApplySelectedVideoSettingsDialog());
  }

  String _availablePreviewPath(PickedVideo video) {
    final proxy = video.proxyPath;
    if (_shouldUseProxy(video) && proxy != null && File(proxy).existsSync()) {
      return proxy;
    }
    // Opening the editor must never wait for a full-length proxy render.
    // Only one bounded source decoder is opened while the lightweight proxy
    // is prepared in the background; the controller switches when ready.
    return video.path;
  }

  Future<void> _togglePreview() async {
    var controller = _previewController;
    final wasPlaying = controller?.value.isPlaying == true;
    if (wasPlaying) {
      _previewFramePrimeGeneration++;
      await controller!.pause();
      await _pauseMusicPreview();
      MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
      unawaited(_loadVisibleTimelineMedia());
      _scheduleNeededProxies(_videos);
      if (mounted) _updateEditor(() {});
      return;
    }

    var playStart =
        _requestedTimelinePlayheadSeconds.value ?? _liveTimelineSeconds;
    playStart = _programPlayStartSeconds(playStart);
    if (_hasAuthoritativeProgramTimeline) {
      var target = _programTargetForTimelineSeconds(playStart);
      if (target?.isGap == true) {
        final next = ProgramTimelineMapper.nextPlayableVideoClip(
          _programPreviewTimeline,
          atOrAfterTimelineSeconds: playStart,
        );
        if (next == null) return;
        playStart = next.timelineStart;
        target = _programTargetForTimelineSeconds(playStart);
      }
      if (target == null || target.isGap) return;
      _requestedTimelinePlayheadSeconds.value = playStart;
      _setLiveTimelinePlayhead(playStart);
      if (!await _seekProgramPreview(playStart)) return;
    } else {
      if (controller == null || !controller.value.isInitialized) {
        if (!await _seekProgramPreview(playStart)) return;
      }
      await _seekPreviewToPlayablePosition();
    }

    controller = _previewController;
    if (controller == null || !controller.value.isInitialized) return;
    await MediaJobManager.instance.pauseBackgroundWork(owner: 'playback');
    if (!mounted || !identical(controller, _previewController)) {
      MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
      return;
    }
    _previewFramePrimeGeneration++;
    await _applyProgramClipPlaybackSettings(_programTimelineClipId);
    try {
      await controller.play();
      await _playMusicPreview();
    } catch (_) {
      MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
      rethrow;
    }
    if (mounted) _updateEditor(() {});
  }

  double _programPlaybackDurationSeconds() {
    if (_hasAuthoritativeProgramTimeline) {
      return ProgramTimelineMapper.duration(_programPreviewTimeline)
          .clamp(0.0, double.infinity)
          .toDouble();
    }
    return math
        .max(
          _actualMultiTrackExportDuration(),
          _timelineSequenceDuration(),
        )
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  double _programPlayStartSeconds(double seconds) {
    final duration = _programPlaybackDurationSeconds();
    if (duration <= 0.001) {
      return seconds.clamp(0.0, double.infinity).toDouble();
    }
    if (seconds >= duration) return 0.0;
    return seconds.clamp(0.0, duration).toDouble();
  }

  Future<void> _toggleSourcePreview() async {
    final controller = _sourceController;
    if (controller == null || !controller.value.isInitialized) return;
    _sourceFramePrimeGeneration++;
    await controller.setVolume(_previewAudioVolume(_sourceVolume));
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      // If the user scrubbed the source slider, start from that position.
      final inPoint = _sourceInPoint;
      if (inPoint != null) {
        await controller.seekTo(
          Duration(milliseconds: (inPoint * 1000).round()),
        );
        _sourceInPoint = null;
      } else {
        // If we're at the end, wrap back to the start.
        final pos = controller.value.position.inMilliseconds;
        final dur = controller.value.duration.inMilliseconds;
        if (dur > 0 && pos >= dur - 80) {
          await controller.seekTo(Duration.zero);
        }
      }
      await controller.play();
    }
    if (mounted) _updateEditor(() {});
  }

  Future<bool> _seekProgramPreview(double seconds) async {
    if (_videos.isEmpty) return false;
    final generation = ++_timelineSeekGeneration;
    _timelineSeekDebounce?.cancel();
    final requested =
        seconds.clamp(0.0, _programPlaybackDurationSeconds()).toDouble();
    _requestedTimelinePlayheadSeconds.value = requested;
    _setLiveTimelinePlayhead(requested);
    return await _programSeekQueue.run<bool>(
          isCurrent: () => mounted && generation == _timelineSeekGeneration,
          operation: () => _performProgramPreviewSeek(requested, generation),
        ) ??
        false;
  }

  Future<bool> _performProgramPreviewSeek(
      double seconds, int generation) async {
    // Toolbar, autoplay and ruler all share one source/program seek adapter.
    final target = _programTargetForTimelineSeconds(seconds);
    await _performMultiTrackTimelineSeek(seconds, generation);
    return mounted &&
        generation == _timelineSeekGeneration &&
        target != null &&
        !target.isGap;
  }

  Future<void> _seekSourcePreview(double seconds) async {
    final controller = _sourceController;
    if (controller == null || !controller.value.isInitialized) return;
    final wasPlaying = controller.value.isPlaying;
    await controller.seekTo(Duration(milliseconds: (seconds * 1000).round()));
    if (!wasPlaying) _schedulePausedFramePrime(controller, source: true);
    if (mounted) _updateEditor(() {});
  }

  void _scheduleLoadedMonitorFramePrime(
    VideoPlayerController? sourceController,
    VideoPlayerController? previewController,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sourceController != null) {
        _schedulePausedFramePrime(sourceController, source: true);
      }
      if (previewController != null) {
        _schedulePausedFramePrime(previewController, source: false);
      }
    });
  }

  void _schedulePausedFramePrime(
    VideoPlayerController controller, {
    required bool source,
  }) {
    // An existing warm-up is already decoding the newest seek position.
    // Do not invalidate it or the controller could be left playing silently.
    if (controller.value.isPlaying) return;
    final generation =
        source ? ++_sourceFramePrimeGeneration : ++_previewFramePrimeGeneration;
    unawaited(_primePausedFrame(controller, source, generation));
  }

  Future<void> _primePausedFrame(
    VideoPlayerController controller,
    bool source,
    int generation,
  ) async {
    final activeController = source ? _sourceController : _previewController;
    if (!mounted ||
        controller != activeController ||
        !controller.value.isInitialized ||
        controller.value.isPlaying) {
      return;
    }
    final restoreVolume = source ? _sourceVolume : _effectiveOriginalVolume;
    try {
      await controller.setVolume(0);
      await controller.play();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final currentGeneration =
          source ? _sourceFramePrimeGeneration : _previewFramePrimeGeneration;
      final currentController = source ? _sourceController : _previewController;
      if (!mounted ||
          generation != currentGeneration ||
          controller != currentController) {
        return;
      }
      await controller.pause();
      await controller.setVolume(_previewAudioVolume(restoreVolume));
      if (mounted) _updateEditor(() {});
    } catch (_) {
      // A failed warm-up must not make normal playback unusable.
      if (controller == (source ? _sourceController : _previewController)) {
        try {
          await controller.setVolume(_previewAudioVolume(restoreVolume));
        } catch (_) {}
      }
    }
  }

  Future<void> _seekPreviewToPlayablePosition({
    bool preferNext = false,
  }) async {
    final controller = _previewController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _videos.isEmpty) {
      return;
    }
    final edit = _clipTimelineEditFor(_videos[_selectedVideoIndex].path);
    final parts =
        edit.timelineParts(_videos[_selectedVideoIndex].durationSeconds);
    if (parts.isEmpty) return;

    final seconds = controller.value.position.inMilliseconds / 1000;
    final target = _playableSecondsForPosition(
      seconds,
      parts,
      preferNext: preferNext,
    );
    if ((target - seconds).abs() < 0.01) return;
    await controller.seekTo(Duration(milliseconds: (target * 1000).round()));
  }

  double _playableSecondsForPosition(
    double seconds,
    List<({double start, double end})> parts, {
    required bool preferNext,
  }) {
    if (parts.isEmpty) return seconds;
    final resolved = PlayableSourceRanges.resolve(seconds, parts);
    if (resolved != null) return resolved;
    return preferNext ? parts.last.start : parts.first.start;
  }

  bool _shouldSkipCurrentPreviewPosition(double seconds) {
    if (_isSkippingPreviewEdit ||
        _videos.isEmpty ||
        _selectedVideoIndex < 0 ||
        _selectedVideoIndex >= _videos.length) {
      return false;
    }
    final edit = _clipTimelineEditFor(_videos[_selectedVideoIndex].path);
    final parts =
        edit.timelineParts(_videos[_selectedVideoIndex].durationSeconds);
    if (parts.isEmpty) return false;
    return !PlayableSourceRanges.contains(seconds, parts);
  }

  Future<void> _skipPreviewEditAt(double seconds) async {
    final controller = _previewController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _videos.isEmpty) {
      return;
    }
    _isSkippingPreviewEdit = true;
    try {
      final edit = _clipTimelineEditFor(_videos[_selectedVideoIndex].path);
      final parts =
          edit.timelineParts(_videos[_selectedVideoIndex].durationSeconds);
      final resolved = PlayableSourceRanges.resolve(seconds, parts);
      if (resolved != null) {
        if (resolved != seconds) {
          await controller.seekTo(
            Duration(microseconds: (resolved * 1000000).round()),
          );
        }
        return;
      }
      if (_exportTimelineTogether && _selectedVideoIndex < _videos.length - 1) {
        await _playNextTimelineClip();
        return;
      }
      await controller.pause();
      await _pauseMusicPreview();
      if (parts.isNotEmpty) {
        await controller.seekTo(
          Duration(milliseconds: (parts.last.end * 1000).round()),
        );
      }
    } finally {
      _isSkippingPreviewEdit = false;
      if (mounted) _updateEditor(() {});
    }
  }

  void _attachPreviewListener(VideoPlayerController? controller) {
    controller?.addListener(_handlePreviewTick);
  }

  void _handlePreviewTick() {
    final controller = _previewController;
    if (controller == null || !controller.value.isInitialized) return;
    // Seek callbacks and native completion ticks can interleave. Never use
    // transitional positions to advance a clip or publish a playhead.
    if (_programSeekQueue.hasPending ||
        _timelineSeekDebounce?.isActive == true ||
        controller.value.hasError) {
      return;
    }
    if (widget.active) {
      _setLiveTimelinePlayhead(_currentProgramSeconds());
    }
    final requested = _requestedTimelinePlayheadSeconds.value;
    if (requested != null &&
        requested < _programPlaybackDurationSeconds() &&
        (_currentProgramSeconds() - requested).abs() <= 0.2) {
      _requestedTimelinePlayheadSeconds.value = null;
    }
    final position = controller.value.position;
    if (_hasAuthoritativeProgramTimeline) {
      if (controller.value.isPlaying) {
        final seconds = position.inMilliseconds / 1000;
        final programClipId = _programTimelineClipId;
        final programClip = programClipId == null
            ? null
            : _multiTrackTimeline.clipById(programClipId)?.clip;
        if (programClip != null &&
            BackendClipEndPolicy.shouldAdvance(
              sourceSeconds: seconds,
              sourceStart: programClip.sourceStart,
              sourceEnd: programClip.sourceEnd,
              isPlaying: controller.value.isPlaying,
              hasError: controller.value.hasError,
              seekPending: _programSeekQueue.hasPending,
            ) &&
            !_autoAdvancingPreview) {
          _autoAdvancingPreview = true;
          unawaited(_playNextProgramTimelineClip(programClip));
        }
      }
      return;
    }
    final duration = controller.value.duration;
    if (controller.value.isPlaying) {
      final seconds = position.inMilliseconds / 1000;
      final programClipId = _programTimelineClipId;
      final programClip = programClipId == null
          ? null
          : _multiTrackTimeline.clipById(programClipId)?.clip;
      if (programClip != null &&
          BackendClipEndPolicy.shouldAdvance(
            sourceSeconds: seconds,
            sourceStart: programClip.sourceStart,
            sourceEnd: programClip.sourceEnd,
            isPlaying: controller.value.isPlaying,
            hasError: controller.value.hasError,
            seekPending: _programSeekQueue.hasPending,
          ) &&
          !_autoAdvancingPreview) {
        _autoAdvancingPreview = true;
        unawaited(_playNextProgramTimelineClip(programClip));
        return;
      }
      if (_shouldSkipCurrentPreviewPosition(seconds)) {
        unawaited(_skipPreviewEditAt(seconds));
        return;
      }
    }
    if (PlayableSourceRanges.hasCompleted(
      position: position,
      duration: duration,
      isPlaying: controller.value.isPlaying,
      backendCompleted: controller.value.isCompleted,
    )) {
      if (widget.settings.autoAdvanceTimeline &&
          _exportTimelineTogether &&
          !_autoAdvancingPreview &&
          _selectedVideoIndex < _videos.length - 1) {
        _autoAdvancingPreview = true;
        unawaited(_playNextTimelineClip());
        return;
      }
      unawaited(_pauseMusicPreview());
    }
  }

  Future<void> _playMusicPreview() async {
    final path = _musicPath;
    if (path == null || path.isEmpty) {
      await _stopMusicPreview();
      return;
    }

    try {
      await _musicPreviewPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPreviewPlayer
          .setVolume(_previewAudioVolume(_effectiveMusicVolume));
      if (_musicPreviewPath != path) {
        await _musicPreviewPlayer.stop();
        await _musicPreviewPlayer.play(DeviceFileSource(path));
        _musicPreviewPath = path;
      } else {
        await _musicPreviewPlayer.resume();
      }
    } catch (error) {
      if (!mounted) return;
      _updateEditor(() => _status = 'Cannot preview music: $error');
    }
  }

  Future<void> _pauseMusicPreview() async {
    await _musicPreviewPlayer.pause();
  }

  Future<void> _stopMusicPreview() async {
    await _musicPreviewPlayer.stop();
    _musicPreviewPath = null;
  }

  void _pauseRenderQueue() {
    if (!_isExporting || _exportCancelToken?.isCanceled == true) return;
    _exportCancelToken?.pause();
    _updateEditor(() {
      _renderQueuePaused = true;
      _status = 'Render queue paused...';
    });
    final view = _exportProgressView.value;
    final details = view.details;
    if (details != null) {
      _updateExportProgressView(
        details: details,
        progress: _progress,
        elapsed: view.elapsed,
        status: 'Render queue paused...',
      );
    }
  }

  bool _sameTransform(_ClipTimelineEdit a, _ClipTimelineEdit b) {
    return (a.speed - b.speed).abs() < 0.001 &&
        a.flip == b.flip &&
        (a.scaleX - b.scaleX).abs() < 0.001 &&
        (a.scaleY - b.scaleY).abs() < 0.001 &&
        (a.zoom - b.zoom).abs() < 0.001 &&
        (a.panX - b.panX).abs() < 0.001 &&
        (a.panY - b.panY).abs() < 0.001;
  }
}
