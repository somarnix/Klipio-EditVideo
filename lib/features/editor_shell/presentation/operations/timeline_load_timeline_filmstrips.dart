part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineLoadTimelineFilmstrips on _EditorScreenState {
  void _publishTimelineFrames(
      String path, int generation, List<String> frames) {
    if (!mounted || generation != _filmstripLoadGeneration) return;
    final index = _videos.indexWhere((video) => video.path == path);
    if (index < 0) return;
    _updateEditor(() {
      _videos[index] = _videos[index].copyWith(timelineThumbnailPaths: frames);
    });
  }

  Future<void> _loadTimelineFilmstrips(
    int generation,
    String thumbnailCache,
  ) async {
    // Startup work is deliberately limited to the selected and visible
    // timeline clips.  The viewport loader below refines this set as the
    // user scrolls; importing a project must not decode every long asset.
    final pixelsPerSecond = _timelinePixelsPerSecond();
    final labelWidth =
        MediaQuery.sizeOf(context).shortestSide <= 600 ? 124.0 : 132.0;
    final visibleStart =
        math.max(0.0, (_timelineScrollOffset - labelWidth) / pixelsPerSecond);
    final visibleEnd =
        visibleStart + math.max(1.0, _timelineViewportWidth) / pixelsPerSecond;
    final nearStart = math.max(0.0, visibleStart - 15.0);
    final nearEnd = visibleEnd + 15.0;
    final activePaths = <String>{
      for (final track in _programEditingTimeline.tracks)
        for (final clip in track.clips)
          if (clip.timelineEnd > nearStart && clip.timelineStart < nearEnd)
            clip.mediaPath,
    };
    final pendingPaths = [
      for (final video in _videos)
        if (activePaths.contains(video.path) &&
            (video.thumbnailPath == null ||
                video.timelineThumbnailPaths.isEmpty ||
                (video.hasAudio &&
                    !_audioWaveformPeaks.containsKey(video.path))))
          video.path,
    ];
    for (var itemIndex = 0; itemIndex < pendingPaths.length; itemIndex++) {
      if (!mounted || generation != _filmstripLoadGeneration) return;
      final path = pendingPaths[itemIndex];
      final currentIndex = _videos.indexWhere((video) => video.path == path);
      if (currentIndex < 0) continue;
      final video = _videos[currentIndex];
      // A media-browser cover is one cheap sample. Timeline filmstrips are
      // requested exclusively by _loadVisibleTimelineMedia with explicit
      // source windows; startup never asks for a whole-asset overview.
      final cover =
          video.thumbnailPath ?? await _videoCover(video, thumbnailCache);
      final frames = video.timelineThumbnailPaths;
      if (!mounted || generation != _filmstripLoadGeneration) return;
      final nextIndex = _videos.indexWhere((item) => item.path == path);
      if (nextIndex < 0) continue;
      _updateEditor(() {
        _videos[nextIndex] = _videos[nextIndex].copyWith(
          thumbnailPath: cover,
          timelineThumbnailPaths: frames,
        );
        _status = !frames.any((frame) => frame.isNotEmpty)
            ? 'Timeline images unavailable for ${video.name}'
            : 'Loading timeline media ${itemIndex + 1} of ${pendingPaths.length}';
      });
    }
    if (mounted && generation == _filmstripLoadGeneration) {
      unawaited(_loadVisibleTimelineMedia());
    }
    // Publish visual overviews for every active clip before decoding long
    // audio streams. A slow waveform must not hold completed images hostage.
    for (final path in pendingPaths) {
      if (!mounted || generation != _filmstripLoadGeneration) return;
      final video = _videos.where((item) => item.path == path).firstOrNull;
      if (video == null ||
          !video.hasAudio ||
          _audioWaveformPeaks.containsKey(path)) {
        continue;
      }
      await _ensureTimelineWaveform(path, generation,
          duration: video.durationSeconds);
    }
    if (mounted && generation == _filmstripLoadGeneration) {
      _updateEditor(() => _status = 'Timeline thumbnails and waveforms ready');
      unawaited(_loadVisibleTimelineMedia());
    }
  }

  Future<void> _loadVisibleTimelineMedia() async {
    final requestGeneration = ++_timelineMediaRequestGeneration;
    if (!mounted || _multiTrackTimeline.tracks.isEmpty) {
      return;
    }
    if (_timelineMediaLoadRunning) {
      _timelineMediaLoadAgain = true;
      return;
    }
    _timelineMediaLoadRunning = true;
    final generation = _filmstripLoadGeneration;
    try {
      final pixelsPerSecond = _timelinePixelsPerSecond();
      final labelWidth =
          MediaQuery.sizeOf(context).shortestSide <= 600 ? 124.0 : 132.0;
      final visibleStart = math.max(
        0.0,
        (_timelineScrollOffset - labelWidth) / pixelsPerSecond,
      );
      final visibleEnd = visibleStart +
          math.max(1.0, _timelineViewportWidth) / pixelsPerSecond;
      final sourceWindows = <String, ({double start, double end})>{};
      final waveformPaths = <String>{};
      // The viewport is in program seconds; decoding windows are in source
      // seconds and belong to each clip instance, not its reused media asset.
      for (final track in _programEditingTimeline.tracks) {
        if (track.type == TrackType.text) continue;
        for (final clip in track.clips) {
          final start = math.max(visibleStart, clip.timelineStart);
          final end = math.min(visibleEnd, clip.timelineEnd);
          if (end <= start) continue;
          final video =
              _videos.where((v) => v.path == clip.mediaPath).firstOrNull;
          if (track.type == TrackType.audio || video?.hasAudio == true) {
            waveformPaths.add(clip.mediaPath);
          }
          if (track.type != TrackType.video) continue;
          final sourceStart = clip.sourceTimeAtProgramTime(start);
          final sourceEnd = clip.sourceTimeAtProgramTime(end);
          final previous = sourceWindows[clip.mediaPath];
          sourceWindows[clip.mediaPath] = (
            start: previous == null
                ? sourceStart
                : math.min(previous.start, sourceStart),
            end: previous == null
                ? sourceEnd
                : math.max(previous.end, sourceEnd),
          );
        }
      }
      if (_musicPath != null) waveformPaths.add(_musicPath!);
      for (final path in waveformPaths) {
        final video = _videos.where((v) => v.path == path).firstOrNull;
        unawaited(_ensureTimelineWaveform(path, generation,
            duration: video?.durationSeconds));
      }
      if (sourceWindows.isEmpty) return;
      final cacheDirectory = await getCacheDirectory();
      final thumbnailCache =
          '${cacheDirectory.path}${platform.pathSeparator}klipio_thumbnails';
      for (final entry in sourceWindows.entries) {
        if (!mounted ||
            generation != _filmstripLoadGeneration ||
            requestGeneration != _timelineMediaRequestGeneration) return;
        final index = _videos.indexWhere((video) => video.path == entry.key);
        if (index < 0) continue;
        final video = _videos[index];
        bool requestCanceled() =>
            !mounted ||
            generation != _filmstripLoadGeneration ||
            requestGeneration != _timelineMediaRequestGeneration ||
            !_multiTrackTimeline.tracks.any((track) =>
                track.clips.any((clip) => clip.mediaPath == video.path));
        final paths = await platform.timelineThumbnailsForVideo(
          video.path,
          thumbnailCache,
          video.durationSeconds,
          visibleSourceStart: entry.value.start,
          visibleSourceEnd: entry.value.end,
          onFrames: (frames) {
            if (!requestCanceled()) {
              _publishTimelineFrames(video.path, generation, frames);
            }
          },
          isCanceled: requestCanceled,
        );
        if (!mounted ||
            generation != _filmstripLoadGeneration ||
            requestGeneration != _timelineMediaRequestGeneration) return;
        final currentIndex =
            _videos.indexWhere((video) => video.path == entry.key);
        if (currentIndex < 0 || paths.isEmpty) continue;
        _updateEditor(() {
          _videos[currentIndex] = _videos[currentIndex].copyWith(
            timelineThumbnailPaths: paths,
          );
        });
      }
    } finally {
      _timelineMediaLoadRunning = false;
      if (_timelineMediaLoadAgain && mounted) {
        _timelineMediaLoadAgain = false;
        unawaited(_loadVisibleTimelineMedia());
      }
    }
  }

  bool get _hasAuthoritativeProgramTimeline =>
      ProgramTimelineMapper.hasPlayableVideo(_multiTrackTimeline);

  Future<void> _applyProgramClipPlaybackSettings(String? clipId) async {
    final controller = _previewController;
    if (controller == null || !controller.value.isInitialized) return;
    final generation = _timelineSeekGeneration;
    final playback =
        _programRenderSnapshot(_multiTrackTimeline).playbackForClip(clipId);
    final edit = _videos.isEmpty
        ? const _ClipTimelineEdit()
        : _clipTimelineEditFor(
            _videos[_selectedVideoIndex.clamp(0, _videos.length - 1)].path,
          );
    final speed = (playback?.speed ?? edit.speed)
        .clamp(_EditorScreenState._minVideoSpeed,
            _EditorScreenState._maxVideoSpeed)
        .toDouble();
    final volume = playback?.volume ?? edit.originalVolume;
    await controller.setPlaybackSpeed(speed);
    if (!mounted ||
        generation != _timelineSeekGeneration ||
        !identical(controller, _previewController)) return;
    await controller.setVolume(_previewAudioVolume(volume));
  }

  TimelineModel get _programPreviewTimeline {
    final visual = _effectPreview.resolve(_transitionPreview
        .resolve(_transformPreview.resolve(_multiTrackTimeline)));
    if (!_hasAuthoritativeProgramTimeline) return visual;
    return _programRenderSnapshot(visual).outputTimeline;
  }

  Future<void> _playNextProgramTimelineClip(ClipModel current) async {
    try {
      final previewTimeline = _programPreviewTimeline;
      final previewCurrent = previewTimeline.clipById(current.id)?.clip;
      final next = ProgramTimelineMapper.nextPlayableVideoClip(
        previewTimeline,
        atOrAfterTimelineSeconds:
            previewCurrent?.timelineEnd ?? current.timelineEnd,
        excludingClipId: current.id,
        includeOverlapping: true,
      );
      if (next == null) {
        final generation = _timelineSeekGeneration;
        await _previewController?.pause();
        MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
        if (!mounted || generation != _timelineSeekGeneration) return;
        await _pauseMusicPreview();
        if (!mounted || generation != _timelineSeekGeneration) return;
        final end = _programPlaybackDurationSeconds();
        await _seekProgramPreview(end);
        return;
      }
      // _seekProgramPreview reserves its generation synchronously. A user
      // seek may supersede it before this awaiting continuation is resumed.
      final expectedGeneration = _timelineSeekGeneration + 1;
      if (!await _seekProgramPreview(math.max(next.timelineStart,
              previewCurrent?.timelineEnd ?? next.timelineStart)) ||
          !mounted ||
          expectedGeneration != _timelineSeekGeneration) return;
      await _previewController?.play();
      if (!mounted || expectedGeneration != _timelineSeekGeneration) return;
      await _playMusicPreview();
    } finally {
      _autoAdvancingPreview = false;
      if (mounted) _updateEditor(() {});
    }
  }

  Future<void> _playNextTimelineClip() async {
    if (_hasAuthoritativeProgramTimeline) {
      final currentId = _programTimelineClipId;
      final current = currentId == null
          ? null
          : _multiTrackTimeline.clipById(currentId)?.clip;
      if (current != null) await _playNextProgramTimelineClip(current);
      return;
    }
    await _selectVideo(_selectedVideoIndex + 1);
    final controller = _previewController;
    if (controller != null && controller.value.isInitialized) {
      await _seekPreviewToPlayablePosition();
      await controller.play();
      await _playMusicPreview();
    }
    _autoAdvancingPreview = false;
  }

  ({int width, int height}) _multiTrackOutputDimensions() {
    final base = switch (_outputRatio) {
      '9:16' => (width: 1080, height: 1920),
      '4:5' => (width: 1080, height: 1350),
      '1:1' => (width: 1080, height: 1080),
      '3:4' => (width: 1080, height: 1440),
      '4:3' => (width: 1440, height: 1080),
      _ => (width: 1920, height: 1080),
    };
    final scale = switch (_projectResolution) {
      '3840x2160' => 2.0,
      '1280x720' => 2 / 3,
      _ => 1.0,
    };
    int even(double value) => math.max(2, (value / 2).round() * 2);
    return (
      width: even(base.width * scale),
      height: even(base.height * scale),
    );
  }

  bool _capCutDraftNeedsRenderedClips(List<_QueuedExport> jobs) {
    return false;
  }

  Future<List<CapCutDraftClip>> _renderCapCutDraftClips(
    List<_QueuedExport> group,
    String renderFolder, {
    required int groupIndex,
    required int groupCount,
    required KlipioExportDialogDetails details,
    required ExportCancelToken cancelToken,
  }) async {
    final clips = <CapCutDraftClip>[];
    for (var clipIndex = 0; clipIndex < group.length; clipIndex++) {
      if (cancelToken.isCanceled) {
        throw Exception('Export canceled.');
      }
      final job = group[clipIndex];
      final draftClipName = _capCutDraftJobClipName(job);
      final outputPath = _capCutDraftRenderedClipPath(
        renderFolder,
        job,
        groupIndex,
        clipIndex,
      );
      final status = 'Rendering CapCut draft clip ${clipIndex + 1} '
          'of ${group.length}: $draftClipName';
      if (mounted) {
        _updateEditor(() => _status = status);
        _updateExportProgressView(
          details: details.copyWith(
            name: draftClipName,
            durationSeconds: _queuedExportDuration(job),
            thumbnailPath: job.video.thumbnailPath,
          ),
          progress: groupCount <= 0
              ? 0
              : ((groupIndex + (clipIndex / group.length)) / groupCount)
                  .clamp(0.0, 1.0)
                  .toDouble(),
          elapsed: _exportProgressView.value.elapsed,
          status: status,
        );
      }
      final result = await exportVideo(
        ExportJob(
          inputPath: job.video.path,
          outputPath: outputPath,
          settings: job.settings,
          cancelToken: cancelToken,
          onProgress: (clipProgress, _) {
            if (!mounted) return;
            final totalProgress = groupCount <= 0
                ? clipProgress
                : ((groupIndex + ((clipIndex + clipProgress) / group.length)) /
                        groupCount)
                    .clamp(0.0, 1.0)
                    .toDouble();
            _updateExportProgressView(
              details: details.copyWith(
                name: draftClipName,
                durationSeconds: _queuedExportDuration(job),
                thumbnailPath: job.video.thumbnailPath,
              ),
              progress: totalProgress,
              elapsed: _exportProgressView.value.elapsed,
              status: status,
            );
          },
        ),
      );
      if (!result.success) {
        throw Exception(
            'Render failed for ${job.video.name}: ${result.message}');
      }
      clips.add(
        CapCutDraftClip(
          inputPath: outputPath,
          name: platform.basename(outputPath),
          settings: _capCutRenderedClipSettings(job.settings),
        ),
      );
    }
    return clips;
  }

  String _capCutDraftRenderedClipPath(
    String renderFolder,
    _QueuedExport job,
    int groupIndex,
    int clipIndex,
  ) {
    final group = (groupIndex + 1).toString().padLeft(3, '0');
    final clip = (clipIndex + 1).toString().padLeft(3, '0');
    return '$renderFolder${Platform.pathSeparator}clip_${group}_$clip.mp4';
  }

  VideoEditSettings _capCutRenderedClipSettings(VideoEditSettings source) {
    return VideoEditSettings(
      speed: 1,
      flip: 'none',
      scaleX: 1,
      scaleY: 1,
      zoom: 1,
      watermarkPath: null,
      watermarkPosition: 'custom',
      watermarkSize: _watermarkSize,
      musicPath: null,
      originalVolume: 1,
      musicVolume: 0,
      outputRatio: 'original',
      panX: 0,
      panY: 0,
      overlayText: '',
      textOverlays: const [],
      brightness: 0,
      contrast: 1,
      saturation: 1,
      gamma: 1,
      trimStartSeconds: 0,
      trimEndSeconds: 0,
      videoBitrateKbps: source.videoBitrateKbps,
      exportCodec: source.exportCodec,
      exportFrameRate: source.exportFrameRate,
      hardwareEncoding: source.hardwareEncoding,
      hardwareDecoding: source.hardwareDecoding,
    );
  }

  String _capCutDraftClipName(PickedVideo video) {
    final typed = _safeName(_nameController.text);
    final base =
        typed.isEmpty ? _safeName(_withoutExtension(video.name)) : typed;
    final name = base.isEmpty ? 'video' : base;
    final extension = _extensionOrDefault(video.name);
    if (!_useNumberRange) return '$name$extension';

    final number = _capCutRangeNumbersAllVideos
        ? _exportRangeStart() +
            _videos.indexWhere((item) => item.path == video.path)
        : _exportNumberForVideo(video);
    return '$number.$name$extension';
  }

  String _capCutDraftJobClipName(_QueuedExport job) {
    if ((job.partCount ?? 0) > 1 && job.partIndex != null) {
      final videoIndex =
          _videos.indexWhere((video) => video.path == job.video.path);
      final base = _partExportBaseName(
        videoIndex < 0 ? 0 : videoIndex,
        job.video,
        job.partIndex!,
      );
      return '$base${_extensionOrDefault(job.video.name)}';
    }
    return _capCutDraftClipName(job.video);
  }

  VideoEditSettings _settingsForClip(_ClipTimelineEdit edit) {
    return _settings.copyWith(
      speed: edit.speed,
      flip: edit.flip,
      scaleX: edit.scaleX,
      scaleY: edit.scaleY,
      zoom: edit.zoom,
      panX: edit.panX,
      panY: edit.panY,
      originalVolume: edit.originalVolume,
    );
  }

  double get _batchSplitSeconds {
    return _parseDurationSeconds(
      _batchSplitMinutesController.text,
      plainNumberSeconds: 60,
    );
  }

  String _capCutClipOutputPath(
      _QueuedExport job, String rootFolder, int globalIndex, int clipIndex,
      {required bool oneFolder}) {
    final folder = oneFolder ? rootFolder : _capCutVideoFolder(job, rootFolder);
    final outputBase =
        _safeName(_withoutExtension(platform.basename(job.outputPath)));
    final base = outputBase.isNotEmpty
        ? outputBase
        : _safeName(
            job.video.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
          );
    final name = base.isEmpty ? 'video' : base;
    return '$folder${Platform.pathSeparator}$name.mp4';
  }

  _ClipTimelineEdit _clipTimelineEditFor(String path) {
    return _rawClipTimelineEditFor(path);
  }

  _ClipTimelineEdit _rawClipTimelineEditFor(String path) {
    return _clipTimelineEdits[path] ?? const _ClipTimelineEdit();
  }

  void _saveSelectedClipTimelineEdit() {
    if (_videos.isEmpty ||
        _selectedVideoIndex < 0 ||
        _selectedVideoIndex >= _videos.length) {
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    final previous = _clipTimelineEditFor(path);
    final start = _parseDurationSeconds(_trimStartController.text);
    final end = _parseDurationSeconds(_trimEndController.text);
    final split = _parseDurationSeconds(_splitEveryController.text);
    final edit = _ClipTimelineEdit(
      trimStartSeconds: start < 0 ? 0 : start,
      trimEndSeconds: end < 0 ? 0 : end,
      splitEverySeconds: split < 0 ? 0 : split,
      speed: _hasAuthoritativeProgramTimeline ? previous.speed : _speed,
      flip: _flip,
      scaleX: _scaleX,
      scaleY: _scaleY,
      zoom: _zoom,
      panX: _panX,
      panY: _panY,
      originalVolume: _originalVolume,
      splitPoints:
          _clipTimelineEditFor(_videos[_selectedVideoIndex].path).splitPoints,
      deletedRanges:
          _clipTimelineEditFor(_videos[_selectedVideoIndex].path).deletedRanges,
      partOrder:
          _clipTimelineEditFor(_videos[_selectedVideoIndex].path).partOrder,
    );
    _clipTimelineEdits[path] = edit;
    _trimStartSeconds = edit.trimStartSeconds;
    _trimEndSeconds = edit.trimEndSeconds;
    if (!previous.sameAs(edit) && !_updateSelectedTimelineClipTransform(edit)) {
      _syncMultiTrackFromLegacy();
    }
  }

  void _loadClipTimelineEdit(int index) {
    if (index < 0 || index >= _videos.length) return;
    _applyClipTimelineEdit(_clipTimelineEditFor(_videos[index].path));
  }

  void _applyClipTimelineEdit(_ClipTimelineEdit edit) {
    _trimStartSeconds = edit.trimStartSeconds;
    _trimEndSeconds = edit.trimEndSeconds;
    _speed = edit.speed;
    _flip = edit.flip;
    _scaleX = edit.scaleX;
    _scaleY = edit.scaleY;
    _zoom = edit.zoom;
    _panX = edit.panX;
    _panY = edit.panY;
    _originalVolume = edit.originalVolume;
    _trimStartController.text = _fieldNumber(edit.trimStartSeconds);
    _trimEndController.text =
        edit.trimEndSeconds <= 0 ? '' : _fieldNumber(edit.trimEndSeconds);
    _splitEveryController.text =
        edit.splitEverySeconds <= 0 ? '' : _fieldNumber(edit.splitEverySeconds);
  }

  String _timelineOutputPath(String folder) {
    final typed = _safeName(_nameController.text);
    final base = typed.isEmpty ? 'timeline_export' : typed;
    return '$folder${platform.pathSeparator}$base.mp4';
  }

  List<({double start, double end})> _hookTimelineRanges(
    List<({double start, double score})> scoredMoments,
    double duration,
    double targetSeconds,
    double hookSeconds,
  ) {
    if (_batchSplitLongVideos && _batchSplitSeconds > 0) {
      return _splitAwareHookTimelineRanges(
        scoredMoments,
        duration,
        hookSeconds,
      );
    }
    final hook = _hookRangeForSection(scoredMoments, 0, duration, hookSeconds);
    if (_hookEditMode == _HookEditMode.hookWithVideo) {
      return _hookWithVideoTimelineRanges(hook, duration, targetSeconds);
    }
    final mainSegments =
        _bestMainHookSegments(scoredMoments, duration, hook, targetSeconds);
    return _safeHookTimelineRanges([hook, ...mainSegments], duration);
  }

  List<({double start, double end})> _hookWithVideoTimelineRanges(
    ({double start, double end}) hook,
    double duration,
    double targetSeconds,
  ) {
    final ranges = <({double start, double end})>[hook];
    var remaining = math.max(0.0, targetSeconds - (hook.end - hook.start));
    for (final span in _availableHookSpans(duration, hook)) {
      if (remaining <= 0.001) break;
      final keep = math.min(remaining, span.end - span.start);
      if (keep > 0.05) {
        ranges.add((start: span.start, end: span.start + keep));
        remaining -= keep;
      }
    }
    return _safeHookTimelineRanges(ranges, duration);
  }

  List<({double start, double end})> _splitAwareHookTimelineRanges(
    List<({double start, double score})> scoredMoments,
    double duration,
    double hookSeconds,
  ) {
    final splitSeconds = _batchSplitSeconds;
    if (splitSeconds <= 0) return const [];
    final ranges = <({double start, double end})>[];
    var sectionStart = 0.0;
    while (sectionStart < duration - 0.05) {
      final sectionEnd = math.min(duration, sectionStart + splitSeconds);
      if (sectionEnd - sectionStart < 1) break;
      final hook = _hookRangeForSection(
        scoredMoments,
        sectionStart,
        sectionEnd,
        hookSeconds,
      );
      ranges.add(hook);
      if (sectionStart < hook.start - 0.05) {
        ranges.add((start: sectionStart, end: hook.start));
      }
      if (hook.end < sectionEnd - 0.05) {
        ranges.add((start: hook.end, end: sectionEnd));
      }
      sectionStart = sectionEnd;
    }
    return _safeHookTimelineRanges(ranges, duration);
  }

  List<({double start, double end})> _safeHookTimelineRanges(
    List<({double start, double end})> ranges,
    double duration,
  ) {
    final safe = <({double start, double end})>[];
    for (final range in ranges) {
      final start = range.start.clamp(0.0, duration).toDouble();
      final end = range.end.clamp(0.0, duration).toDouble();
      if (end - start < 0.05) continue;
      final candidate = (start: start, end: end);
      if (safe.any((item) => _rangesOverlap(item, candidate))) continue;
      safe.add(candidate);
    }
    return safe;
  }
}
