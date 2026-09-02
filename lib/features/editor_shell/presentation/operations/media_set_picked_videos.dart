part of '../editor_application.dart';

// media operations owned by the editor state; extracted without changing timing.
extension _MediaSetPickedVideos on _EditorScreenState {
  Future<void> _setPickedVideos(
    List<PickedVideo> picked, {
    bool resetEdits = true,
    int selectedIndex = 0,
    List<String>? compositionPathsToAdd,
  }) async {
    await platform.cancelBackgroundMediaTasks();
    _videoCoverJobsBySource.clear();
    _storeActiveCompositionTimeline();
    final loadGeneration = ++_controllerLoadGeneration;
    final filmstripGeneration = ++_filmstripLoadGeneration;
    _updateEditor(() => _status = 'Reading media metadata...');
    final cacheDirectory = await getCacheDirectory();
    final thumbnailCache =
        '${cacheDirectory.path}${platform.pathSeparator}klipio_thumbnails';
    final enriched = await Future.wait<PickedVideo>([
      for (final video in picked) _enrichVideoMetadata(video),
    ]);

    await _stopMusicPreview();
    final oldSourceController = _sourceController;
    final oldPreviewController = _previewController;
    oldSourceController?.removeListener(_handleSourceTick);
    oldPreviewController?.removeListener(_handlePreviewTick);
    if (mounted) {
      _updateEditor(() {
        _sourceController = null;
        _previewController = null;
        _sourceError = null;
        _previewError = null;
      });
    }
    await oldSourceController?.dispose();
    await oldPreviewController?.dispose();
    VideoPlayerController? sourceController;
    VideoPlayerController? controller;
    String? sourceError;
    String? previewError;
    final initialPreviewPath = _availablePreviewPath(enriched.first);
    try {
      sourceController = await createPreviewController(initialPreviewPath);
      await sourceController.setVolume(_previewAudioVolume(_sourceVolume));
    } catch (error) {
      sourceController = null;
      sourceError = 'Cannot play source: $error';
    }
    try {
      controller = await createPreviewController(initialPreviewPath);
    } catch (error) {
      controller = null;
      previewError = 'Cannot play preview: $error';
    }

    if (!mounted || loadGeneration != _controllerLoadGeneration) {
      await sourceController?.dispose();
      await controller?.dispose();
      return;
    }
    _applyClipTimelineEdit(const _ClipTimelineEdit());
    _updateEditor(() {
      final hadCompositions = _compositionPaths.isNotEmpty;
      _videos
        ..clear()
        ..addAll(enriched);
      if (resetEdits) {
        _compositionPaths.clear();
        _projectMediaPathsByComposition.clear();
        _timelinesByComposition.clear();
        _selectedCompositionPath = null;
      }
      final rootsToAdd = compositionPathsToAdd ??
          ((resetEdits || !hadCompositions)
              ? enriched.map((video) => video.path).toList()
              : const <String>[]);
      for (final path in rootsToAdd) {
        final videoIndex = enriched.indexWhere((video) => video.path == path);
        if (videoIndex >= 0) _ensureComposition(enriched[videoIndex]);
      }
      _numberStartController.text = '1';
      _numberEndController.text = '${enriched.length}';
      if (resetEdits) {
        _clipTimelineEdits
          ..clear()
          ..addEntries(
            enriched.map(
              (video) => MapEntry(video.path, const _ClipTimelineEdit()),
            ),
          );
      } else {
        for (final video in enriched) {
          _clipTimelineEdits.putIfAbsent(
            video.path,
            () => const _ClipTimelineEdit(),
          );
        }
      }
      _clipTimelineUndoStacks.clear();
      _clipTimelineRedoStacks.clear();
      _editorUndoHistory.clear();
      _editorRedoHistory.clear();
      _clipTransformOverrides.removeWhere(
        (path) => !enriched.any((video) => video.path == path),
      );
      _captionCuesByVideo.removeWhere(
        (path, _) => !enriched.any((video) => video.path == path),
      );
      _audioWaveformPeaks.removeWhere(
        (path, _) => !enriched.any((video) => video.path == path),
      );
      if (resetEdits) {
        _clipTransformOverrides.clear();
      }
      _selectedVideoIndex = selectedIndex.clamp(0, enriched.length - 1);
      _sourceController = sourceController;
      _previewController = controller;
      _sourceError = sourceError;
      _previewError = previewError;
      final selectedPath = enriched[_selectedVideoIndex].path;
      if (_compositionPaths.contains(selectedPath)) {
        _selectedCompositionPath = selectedPath;
      } else if (_selectedCompositionPath == null ||
          !_compositionPaths.contains(_selectedCompositionPath)) {
        _selectedCompositionPath =
            _compositionPaths.isEmpty ? selectedPath : _compositionPaths.first;
      }
      _multiTrackTimeline =
          _timelinesByComposition[_selectedCompositionPath!] ??
              _timelineWithFirstVideo(enriched[_selectedVideoIndex]);
      _timelinesByComposition[_selectedCompositionPath!] = _multiTrackTimeline;
      final clips = _multiTrackTimeline.videoTracks
          .expand((track) => track.clips)
          .toList();
      final firstClip = clips.isEmpty ? null : clips.first;
      _selectedTimelineClipId = firstClip?.id;
      _programTimelineClipId = firstClip?.id;
      _status = controller == null
          ? '${enriched.length} selected. Preview is unavailable on this platform.'
          : '${_compositionPaths.length} separate video project${_compositionPaths.length == 1 ? '' : 's'} ready';
    });
    _attachSourceListener(sourceController);
    _attachPreviewListener(controller);
    if (_selectedVideoIndex != 0) {
      await _selectVideo(_selectedVideoIndex, saveCurrentEdit: false);
    } else {
      _scheduleLoadedMonitorFramePrime(sourceController, controller);
    }
    unawaited(
      _loadTimelineFilmstrips(
        filmstripGeneration,
        thumbnailCache,
      ),
    );
    // Covers are cheap single-frame jobs and make every imported video and
    // newly opened timeline visual immediately. Full filmstrips remain lazy so
    // importing several long videos cannot saturate the computer.
    unawaited(
      _loadMissingVideoCovers(
        filmstripGeneration,
        thumbnailCache,
      ),
    );
    _scheduleNeededProxies(enriched);
  }

  Future<String?> _videoCover(
    PickedVideo video,
    String thumbnailCache,
  ) {
    final existingPath = video.thumbnailPath;
    if (existingPath != null && File(existingPath).existsSync()) {
      return Future<String?>.value(existingPath);
    }
    final active = _videoCoverJobsBySource[video.path];
    if (active != null) return active;
    late final Future<String?> job;
    job = platform
        .thumbnailForVideo(video.path, thumbnailCache)
        .catchError((_) => null)
        .whenComplete(() {
      if (identical(_videoCoverJobsBySource[video.path], job)) {
        _videoCoverJobsBySource.remove(video.path);
      }
    });
    _videoCoverJobsBySource[video.path] = job;
    return job;
  }

  Future<void> _loadMissingVideoCovers(
    int generation,
    String thumbnailCache,
  ) async {
    final paths = [for (final video in _videos) video.path];
    for (final path in paths) {
      if (!mounted || generation != _filmstripLoadGeneration) return;
      final index = _videos.indexWhere((video) => video.path == path);
      if (index < 0) continue;
      final video = _videos[index];
      if (video.thumbnailPath != null &&
          File(video.thumbnailPath!).existsSync()) {
        continue;
      }
      final cover = await _videoCover(video, thumbnailCache);
      if (!mounted || generation != _filmstripLoadGeneration) return;
      if (cover == null || !File(cover).existsSync()) continue;
      final currentIndex = _videos.indexWhere((video) => video.path == path);
      if (currentIndex < 0) continue;
      _updateEditor(() {
        _videos[currentIndex] = _videos[currentIndex].copyWith(
          thumbnailPath: cover,
        );
      });
    }
  }

  Future<void> _ensureSelectedVideoCover(String path) async {
    // Timeline frames are independent of the media-browser cover. Do not wait
    // behind all imported covers before scheduling the active source strip.
    unawaited(_loadVisibleTimelineMedia());
    final generation = _filmstripLoadGeneration;
    final index = _videos.indexWhere((video) => video.path == path);
    if (index < 0) return;
    final cacheDirectory = await getCacheDirectory();
    final thumbnailCache =
        '${cacheDirectory.path}${platform.pathSeparator}klipio_thumbnails';
    final cover = await _videoCover(_videos[index], thumbnailCache);
    if (!mounted || generation != _filmstripLoadGeneration) {
      return;
    }
    final currentIndex = _videos.indexWhere((video) => video.path == path);
    if (currentIndex < 0) return;
    if (cover != null && _videos[currentIndex].thumbnailPath != cover) {
      _updateEditor(() {
        _videos[currentIndex] = _videos[currentIndex].copyWith(
          thumbnailPath: cover,
        );
      });
    }
  }

  Future<void> _replaceVideoAt(int index) async {
    if (index < 0 || index > _videos.length) return;
    final isAdding = index == _videos.length;
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    final file =
        result == null || result.files.isEmpty ? null : result.files.first;
    if (file?.path == null) return;

    final replacement = PickedVideo(name: file!.name, path: file.path!);
    final updated = [..._videos];
    if (index == updated.length) {
      updated.add(replacement);
    } else {
      updated[index] = replacement;
    }
    await _setPickedVideos(
      updated,
      resetEdits: false,
      selectedIndex: index,
    );
    _showMessage(
        'Video ${index + 1} ${isAdding ? 'added' : 'replaced'}: ${file.name}.');
  }

  List<String> _pastedVideoTitles() => _titleCheckController.text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Future<void> _selectVideo(int index, {bool saveCurrentEdit = true}) async {
    if (index < 0 || index >= _videos.length) return;
    final loadGeneration = ++_controllerLoadGeneration;
    if (saveCurrentEdit) {
      _saveSelectedClipTimelineEdit();
    }
    await _stopMusicPreview();
    final oldSourceController = _sourceController;
    final oldPreviewController = _previewController;
    oldSourceController?.removeListener(_handleSourceTick);
    oldPreviewController?.removeListener(_handlePreviewTick);
    if (mounted) {
      _updateEditor(() {
        _selectedVideoIndex = index;
        _selectedCaptionCueIndex = 0;
        _sourceController = null;
        _previewController = null;
        _sourceError = null;
        _previewError = null;
        _clipEditMode = true;
        _status = 'Loading ${_videos[index].name}...';
      });
      _loadClipTimelineEdit(index);
    }
    await oldSourceController?.dispose();
    await oldPreviewController?.dispose();
    VideoPlayerController? sourceController;
    VideoPlayerController? controller;
    String? sourceError;
    String? previewError;
    final selectedVideo = _videos[index];
    final previewPath = _availablePreviewPath(selectedVideo);
    try {
      sourceController = await createPreviewController(previewPath);
      await sourceController.setVolume(_previewAudioVolume(_sourceVolume));
    } catch (error) {
      sourceController = null;
      sourceError = 'Cannot play source: $error';
    }
    try {
      controller = await createPreviewController(previewPath);
      final edit = _clipTimelineEditFor(selectedVideo.path);
      await controller.setPlaybackSpeed(
        edit.speed
            .clamp(_EditorScreenState._minVideoSpeed,
                _EditorScreenState._maxVideoSpeed)
            .toDouble(),
      );
      await controller.setVolume(_previewAudioVolume(edit.originalVolume));
    } catch (error) {
      controller = null;
      previewError = 'Cannot play preview: $error';
    }
    if (!mounted || loadGeneration != _controllerLoadGeneration) {
      await sourceController?.dispose();
      await controller?.dispose();
      return;
    }
    _updateEditor(() {
      _selectedVideoIndex = index;
      _sourceController = sourceController;
      _previewController = controller;
      _sourceError = sourceError;
      _previewError = previewError;
      _status = 'Selected ${_videos[index].name}';
      _editorSelection = EditorSelection.video(_videos[index].path);
    });
    _attachSourceListener(sourceController);
    _attachPreviewListener(controller);
    _scheduleLoadedMonitorFramePrime(sourceController, controller);
    unawaited(_ensureSelectedVideoCover(selectedVideo.path));
    if (_shouldUseProxy(selectedVideo)) {
      unawaited(_ensureProxyForVideo(selectedVideo));
    }
  }

  Future<void> _removeImportedVideo(int index) async {
    if (index < 0 || index >= _videos.length) return;
    ++_filmstripLoadGeneration;
    await platform.cancelBackgroundMediaTasks();
    _videoCoverJobsBySource.clear();
    _proxyJobsBySource.clear();
    final removed = _videos[index];
    final wasActiveComposition = removed.path == _selectedCompositionPath;
    _storeActiveCompositionTimeline();

    _clipTimelineEdits.remove(removed.path);
    _clipTimelineUndoStacks.remove(removed.path);
    _clipTimelineRedoStacks.remove(removed.path);
    _clipTransformOverrides.remove(removed.path);
    _captionCuesByVideo.remove(removed.path);
    _audioWaveformPeaks.remove(removed.path);
    _audioWaveformPeakRates.remove(removed.path);
    _selectedCaptionIds.removeWhere(
      (id) => _captionSelectionTarget(id)?.path == removed.path,
    );

    _updateEditor(() {
      _compositionPaths.remove(removed.path);
      _projectMediaPathsByComposition.remove(removed.path);
      _timelinesByComposition.remove(removed.path);
      for (final paths in _projectMediaPathsByComposition.values) {
        paths.remove(removed.path);
      }
      _videos.removeAt(index);
      if (_videos.isEmpty) {
        _selectedVideoIndex = 0;
      } else if (index < _selectedVideoIndex) {
        _selectedVideoIndex--;
      }
      if (wasActiveComposition) {
        _selectedCompositionPath =
            _compositionPaths.isEmpty ? null : _compositionPaths.first;
        _multiTrackTimeline = _selectedCompositionPath == null
            ? TimelineModel.empty()
            : (_timelinesByComposition[_selectedCompositionPath!] ??
                TimelineModel.empty());
        final clips = _multiTrackTimeline.videoTracks
            .expand((track) => track.clips)
            .toList();
        _selectedTimelineClipId = clips.isEmpty ? null : clips.first.id;
        _programTimelineClipId = _selectedTimelineClipId;
      }
      _status = 'Removed ${removed.name} from imports';
    });

    if (_compositionPaths.isEmpty) {
      await _stopMusicPreview();
      final oldSourceController = _sourceController;
      final oldPreviewController = _previewController;
      oldSourceController?.removeListener(_handleSourceTick);
      oldPreviewController?.removeListener(_handlePreviewTick);
      _updateEditor(() {
        _sourceController = null;
        _previewController = null;
        _sourceError = null;
        _previewError = null;
        _progress = 0;
      });
      _applyClipTimelineEdit(const _ClipTimelineEdit());
      await oldSourceController?.dispose();
      await oldPreviewController?.dispose();
      return;
    }

    if (wasActiveComposition && _selectedCompositionPath != null) {
      await _selectComposition(_selectedCompositionPath!);
    }
  }

  void _attachSourceListener(VideoPlayerController? controller) {
    controller?.addListener(_handleSourceTick);
  }

  void _handleSourceTick() {
    final controller = _sourceController;
    if (controller == null || !controller.value.isInitialized) return;
    final manager = MediaJobManager.instance;
    if (controller.value.isPlaying) {
      if (!manager.activeWorkloads.contains('source-playback')) {
        unawaited(manager.pauseBackgroundWork(owner: 'source-playback'));
      }
    } else {
      manager.resumeBackgroundWork(owner: 'source-playback');
    }
  }

  Future<void> _selectPreviousVideo() async {
    if (_videos.isEmpty) return;
    final previous =
        _selectedVideoIndex <= 0 ? _videos.length - 1 : _selectedVideoIndex - 1;
    await _selectVideo(previous);
  }

  Future<void> _selectNextVideo() async {
    if (_videos.isEmpty) return;
    final next =
        _selectedVideoIndex >= _videos.length - 1 ? 0 : _selectedVideoIndex + 1;
    await _selectVideo(next);
  }

  bool get _capCutRangeNumbersAllVideos {
    return _useNumberRange &&
        _videos.isNotEmpty &&
        _selectedExportVideoCount() >= _videos.length;
  }

  String _videoBaseName(PickedVideo video) {
    final base = _videoTitle(video);
    return numberedExportBaseName(
      base.isEmpty ? 'video' : base,
      number: _exportNumberForVideo(video),
      enabled: _useNumberRange,
    );
  }

  String _videoTitle(PickedVideo video) =>
      _safeName(_withoutExtension(video.name));

  int _numberRangeVideoCount(String startText, String endText) {
    final start = _numberRangeStartValue(startText);
    final end = _numberRangeEndValue(startText, endText);
    if (end < start) return 0;
    return (end - start + 1).clamp(0, _videos.length);
  }

  Future<void> _chooseHookVideoTargets() async {
    final targets = await _showVideoTargetSelectionDialog(
      title: 'Choose videos for Hook edit',
      actionLabel: 'Create Hook edits',
      description:
          'Enter individual videos or ranges. Example: 1,2,4 to 7,9,10.',
    );
    if (targets == null || targets.isEmpty || !mounted) return;
    await _applyHookVideoEdit(videoIndexes: targets);
  }

  Future<void> _applyHookVideoEdit({
    bool allVideos = false,
    List<int>? videoIndexes,
  }) async {
    try {
      if (_videos.isEmpty) {
        _showMessage('Import a video before creating a hook edit.');
        return;
      }
      _saveSelectedClipTimelineEdit();
      final safeIndex = _selectedVideoIndex.clamp(0, _videos.length - 1);
      final targetIndexes = videoIndexes ??
          (allVideos
              ? List.generate(_videos.length, (index) => index)
              : [safeIndex]);
      final batch = allVideos || videoIndexes != null;
      final plannedEdits = <String, _ClipTimelineEdit>{};
      var skipped = 0;
      for (var queueIndex = 0;
          queueIndex < targetIndexes.length;
          queueIndex++) {
        final videoIndex = targetIndexes[queueIndex];
        final video = _videos[videoIndex];
        final duration = video.durationSeconds ?? 0;
        if (duration < 8) {
          skipped++;
          continue;
        }
        final manualTargetSeconds = _manualHookEditSeconds();
        if (manualTargetSeconds != null && manualTargetSeconds > duration) {
          skipped++;
          if (!batch) {
            _showMessage(
              'Hook length ${_formatDuration(manualTargetSeconds)} is longer than this video (${_formatDuration(duration)}).',
            );
            _updateEditor(() {
              _status = 'Hook length is longer than selected video.';
            });
            return;
          }
          continue;
        }
        final targetSeconds = _hookEditTargetSeconds(duration);
        final hookSeconds = math.min(5.0, math.max(2.0, targetSeconds * 0.12));

        _updateEditor(() {
          _status = batch
              ? 'Scanning hook ${queueIndex + 1}/${targetIndexes.length}: ${video.name}'
              : 'Scanning for hook moments...';
        });
        final scoredMoments = await _scoreHookMoments(
          video.path,
          duration,
          fast: batch,
        );
        if (!mounted) return;

        final ranges = _hookTimelineRanges(
          scoredMoments,
          duration,
          targetSeconds,
          hookSeconds,
        );
        if (ranges.isEmpty) {
          skipped++;
          continue;
        }
        final current = _clipTimelineEditFor(video.path);
        final edit = _clipTimelineEditWithRanges(current, ranges, duration);
        plannedEdits[video.path] = edit;
      }
      if (plannedEdits.isEmpty) {
        _showMessage('Hook edit could not find valid video ranges.');
        return;
      }

      final selectedPath = _videos[safeIndex].path;
      _recordEditorHistory(batch ? 'hook-edit-selected' : 'hook-edit');
      _updateEditor(() {
        for (final entry in plannedEdits.entries) {
          final current = _clipTimelineEditFor(entry.key);
          if (!current.sameAs(entry.value)) {
            _clipTimelineUndoStacks
                .putIfAbsent(entry.key, () => [])
                .add(current);
            _clipTimelineRedoStacks[entry.key]?.clear();
          }
          _clipTimelineEdits[entry.key] = entry.value;
        }
        final selectedEdit = plannedEdits[selectedPath];
        if (selectedEdit != null) {
          _applyClipTimelineEdit(selectedEdit);
        }
        _syncMultiTrackFromLegacy(
          preferredMediaPath: selectedPath,
          allCompositions: batch,
        );
        _exportTimelineTogether = true;
        _status = batch
            ? 'Hook edit applied to ${plannedEdits.length} videos${skipped > 0 ? ', skipped $skipped' : ''}.'
            : 'Hook edit applied to selected video.';
      });

      final selectedClipId = _selectedTimelineClipId;
      final selectedClip = selectedClipId == null
          ? null
          : _multiTrackTimeline.clipById(selectedClipId)?.clip;
      final playStart = batch ? 0.0 : selectedClip?.timelineStart ?? 0.0;
      _timelineSeekDebounce?.cancel();
      _timelineSeekGeneration++;
      _requestedTimelinePlayheadSeconds.value = playStart;
      _setLiveTimelinePlayhead(playStart);
      await _seekProgramPreview(playStart);
      if (!mounted) return;
      unawaited(_autosaveProject());
      _showMessage(
        batch
            ? 'Hook edit applied to ${plannedEdits.length} videos.'
            : 'Hook video edit applied to selected video.',
      );
    } catch (error) {
      if (!mounted) return;
      _updateEditor(() => _status = 'Hook video failed: $error');
      _showMessage('Hook video failed. Try a shorter hook edit length.');
    }
  }

  Widget _mediaDockPanel() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(
            height: 34,
            child: TabBar(
              tabs: [Tab(text: 'PROJECT'), Tab(text: 'IMPORT')],
              labelPadding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_projectBinsList(), _importedVideosList()],
            ),
          ),
        ],
      ),
    );
  }
}
