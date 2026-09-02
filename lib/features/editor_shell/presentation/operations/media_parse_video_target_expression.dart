part of '../editor_application.dart';

// media operations owned by the editor state; extracted without changing timing.
extension _MediaParseVideoTargetExpression on _EditorScreenState {
  ({List<int> indexes, String? error}) _parseVideoTargetExpression(
    String expression,
  ) {
    final result = parseVideoTargetSelection(expression, _videos.length);
    return (indexes: result.indexes, error: result.error);
  }

  String _videoTargetSummary(List<int> indexes) {
    if (indexes.isEmpty) return 'No videos selected';
    return '${indexes.length} selected: ${indexes.map((index) => index + 1).join(', ')}';
  }

  Future<List<int>?> _showVideoTargetSelectionDialog({
    required String title,
    required String actionLabel,
    required String description,
  }) async {
    final controller = TextEditingController(
      text: _videos.length == 1 ? '1' : '1 to ${_videos.length}',
    );
    var expression = controller.text;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parsed = _parseVideoTargetExpression(expression);
          return AlertDialog(
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            title: KText(title),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KText(description),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Video numbers',
                      hintText: '1,2,4 to 7,9,10',
                      helperText:
                          parsed.error ?? _videoTargetSummary(parsed.indexes),
                      errorText: parsed.error,
                    ),
                    onChanged: (value) =>
                        setDialogState(() => expression = value),
                    onSubmitted: (_) {
                      if (parsed.error == null && parsed.indexes.isNotEmpty) {
                        Navigator.pop(dialogContext, parsed.indexes);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const KText('Cancel'),
              ),
              FilledButton(
                onPressed: parsed.error == null && parsed.indexes.isNotEmpty
                    ? () => Navigator.pop(dialogContext, parsed.indexes)
                    : null,
                child: KText(actionLabel),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showApplySelectedVideoSettingsDialog() async {
    if (_selectedVideoIndex < 0 || _selectedVideoIndex >= _videos.length) {
      return;
    }
    // Modern composition values already belong to the clip. Writing legacy
    // inspector fields back here would erase rotation/opacity before capture.
    if (!_hasAuthoritativeProgramTimeline) _saveSelectedClipTimelineEdit();
    _storeActiveCompositionTimeline();
    final videoPaths = _videos.map((video) => video.path).toList();
    final sourceName = _videos[_selectedVideoIndex].name;
    final sourcePath = _videos[_selectedVideoIndex].path;
    final source = _clipTimelineEditFor(sourcePath);
    final selectedSourceTarget = _selectedTimelineClipId == null
        ? null
        : _multiTrackTimeline.clipById(_selectedTimelineClipId!);
    final selectedSourceClip =
        selectedSourceTarget?.track.type == TrackType.video
            ? selectedSourceTarget?.clip
            : null;
    final sourceClip = selectedSourceClip?.mediaPath == sourcePath
        ? selectedSourceClip
        : _multiTrackTimeline.videoTracks
            .expand((track) => track.clips)
            .where((clip) => clip.mediaPath == sourcePath)
            .firstOrNull;
    final sourceCanvasMode = sourceClip?.transform.canvasMode ?? _canvasMode;
    final sourceCanvasColor =
        sourceClip?.transform.canvasColor ?? _colorToHex(_canvasColor);
    final sourceCanvasPattern =
        sourceClip?.transform.canvasPattern ?? _canvasPattern;
    final sourceCanvasBlur = sourceClip?.transform.canvasBlur ?? _canvasBlur;
    final captured = VideoRenderSettings(
      mediaPath: sourcePath,
      speed: sourceClip?.resolvedPlaybackSpeed(source.speed) ?? source.speed,
      originalVolume: sourceClip == null
          ? source.originalVolume
          : (_multiTrackTimeline.linkedAudioForVideo(sourceClip.id)?.volume ??
              source.originalVolume),
      transform: sourceClip?.transform ??
          ClipTransform(
            scaleX: source.scaleX * source.zoom,
            scaleY: source.scaleY * source.zoom,
            positionX: (0.5 + source.panX * 0.5).clamp(0, 1).toDouble(),
            positionY: (0.5 + source.panY * 0.5).clamp(0, 1).toDouble(),
            flip: source.flip,
            canvasMode: sourceCanvasMode,
            canvasColor: sourceCanvasColor,
            canvasPattern: sourceCanvasPattern,
            canvasBlur: sourceCanvasBlur,
          ),
    );
    var copySpeed = true;
    var copyFrame = true;
    var copyAudio = true;
    var copyCanvas = true;
    final targetController = TextEditingController(
      text: _videos.length == 1 ? '1' : '1 to ${_videos.length}',
    );
    var targetExpression = targetController.text;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final targets = _parseVideoTargetExpression(targetExpression);
          return AlertDialog(
            icon: const Icon(Icons.copy_all_outlined),
            title: const KText('Apply selected video settings'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KText(
                      'Copy settings from $sourceName. Every target remains independently editable afterward.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      decoration: InputDecoration(
                        labelText: 'Apply to video numbers',
                        hintText: '1,2,4 to 7,9,10',
                        helperText: targets.error == null
                            ? _videoTargetSummary(targets.indexes)
                            : null,
                        errorText: targets.error,
                      ),
                      onChanged: (value) =>
                          setDialogState(() => targetExpression = value),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: copySpeed,
                      onChanged: (value) => setDialogState(
                        () => copySpeed = value ?? false,
                      ),
                      title: const KText('Speed'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: copyFrame,
                      onChanged: (value) => setDialogState(
                        () => copyFrame = value ?? false,
                      ),
                      title: const KText(
                          'Transform, rotation, opacity and position'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: copyAudio,
                      onChanged: (value) => setDialogState(
                        () => copyAudio = value ?? false,
                      ),
                      title: const KText('Source audio level'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: copyCanvas,
                      onChanged: (value) => setDialogState(
                        () => copyCanvas = value ?? false,
                      ),
                      title: const KText('Canvas background and blur'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const KText('Cancel'),
              ),
              FilledButton(
                onPressed: targets.error == null &&
                        targets.indexes.isNotEmpty &&
                        (copySpeed || copyFrame || copyAudio || copyCanvas)
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const KText('Apply to selected videos'),
              ),
            ],
          );
        },
      ),
    );
    final targetResult = _parseVideoTargetExpression(targetExpression);
    targetController.dispose();
    if (confirmed != true || !mounted) return;
    if (targetResult.error != null || targetResult.indexes.isEmpty) return;
    if (videoPaths.length != _videos.length ||
        Iterable<int>.generate(videoPaths.length)
            .any((i) => videoPaths[i] != _videos[i].path)) {
      _showMessage('The video list changed. Open Apply settings again.');
      return;
    }
    final targetPaths = targetResult.indexes.map((i) => videoPaths[i]).toSet();
    final prepared = <String, TimelineModel>{};
    TimelineModel? prepare(TimelineModel original) {
      final model = ClipSpeedEdit.migrate(
          original, _videoPlaybackSpeedsForExport(original));
      final ids = {
        for (final track in model.videoTracks)
          for (final clip in track.clips)
            if (targetPaths.contains(clip.mediaPath)) clip.id,
      };
      return applyVideoSettingsBatch(
        timeline: model,
        settings: captured,
        targetClipIds: ids,
        copySpeed: copySpeed,
        copyFrame: copyFrame,
        copyAudio: copyAudio,
        copyCanvas: copyCanvas,
      );
    }

    final activeTimeline = prepare(_multiTrackTimeline);
    if (activeTimeline == null) {
      _showMessage(
          'Unlock the target video and affected linked audio tracks before applying. No settings were changed.');
      return;
    }
    for (final entry in _timelinesByComposition.entries) {
      final updated = prepare(entry.value);
      if (updated == null) {
        _showMessage(
            'Unlock the target video and affected linked audio tracks before applying. No settings were changed.');
        return;
      }
      prepared[entry.key] = updated;
    }
    _recordEditorHistory('apply-video-settings-all');
    _updateEditor(() {
      for (final index in targetResult.indexes) {
        final video = _videos[index];
        final current = _clipTimelineEditFor(video.path);
        final applied = current.copyWith(
          speed: copySpeed ? captured.speed : current.speed,
          flip: copyFrame ? captured.transform.flip : current.flip,
          scaleX: copyFrame ? captured.transform.scaleX : current.scaleX,
          scaleY: copyFrame ? captured.transform.scaleY : current.scaleY,
          zoom: copyFrame ? 1 : current.zoom,
          panX: copyFrame
              ? (captured.transform.positionX - 0.5) * 2
              : current.panX,
          panY: copyFrame
              ? (captured.transform.positionY - 0.5) * 2
              : current.panY,
          originalVolume:
              copyAudio ? captured.originalVolume : current.originalVolume,
        );
        _clipTimelineEdits[video.path] = applied;
      }
      _timelinesByComposition.addAll(prepared);
      _clipTransformOverrides.addAll(
        targetResult.indexes.map((index) => _videos[index].path),
      );
      _applyTimelineModelUpdate(activeTimeline);
      _storeActiveCompositionTimeline();
      _applyClipTimelineEdit(
        _clipTimelineEditFor(_videos[_selectedVideoIndex].path),
      );
      final selected = _selectedTimelineClipId == null
          ? null
          : _multiTrackTimeline.clipById(_selectedTimelineClipId!);
      if (selected?.track.type == TrackType.video) {
        _loadTimelineClipTransformIntoInspector(selected!.clip);
      }
      _status =
          'Latest settings applied to ${targetResult.indexes.length} video${targetResult.indexes.length == 1 ? '' : 's'}';
    });
    final end = _programPlaybackDurationSeconds();
    if (_liveTimelineSeconds > end) {
      _requestMultiTrackTimelineSeek(end);
    } else {
      _setLiveTimelinePlayhead(_currentProgramSeconds());
    }
    unawaited(_applyProgramClipPlaybackSettings(_programTimelineClipId));
    unawaited(_autosaveProject());
  }

  List<PickedVideo> get _compositionVideos => [
        for (final path in _compositionPaths)
          for (final video in _videos)
            if (video.path == path) video,
      ];

  Future<void> _pickVideos() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.video,
    );
    if (result == null) return;

    final picked = result.files
        .where((file) => file.path != null)
        .map((file) => PickedVideo(name: file.name, path: file.path!))
        .toList();
    if (picked.isEmpty) return;

    final existingPaths =
        _videos.map((video) => video.path.toLowerCase()).toSet();
    final newVideos = picked
        .where((video) => !existingPaths.contains(video.path.toLowerCase()))
        .toList();
    if (newVideos.isEmpty) {
      _showMessage('Those video files are already in the project.');
      return;
    }

    await _setPickedVideos(
      [..._videos, ...newVideos],
      resetEdits: false,
      selectedIndex: _videos.length,
      compositionPathsToAdd: [for (final video in newVideos) video.path],
    );
  }

  Future<PickedVideo> _enrichVideoMetadata(PickedVideo video) async {
    // Offline media still belongs to the project. Keep saved intent/metadata;
    // player preparation may report unavailability without erasing the asset.
    if (!await File(video.path).exists()) return video;
    final info = await platform.probeMedia(video.path);
    final savedProxy = video.proxyPath;
    return video.copyWith(
      durationSeconds: info.durationSeconds ?? video.durationSeconds,
      hasAudio: info.hasAudio,
      width: info.width,
      height: info.height,
      frameRate: info.frameRate,
      videoCodec: info.videoCodec,
      bitrate: info.bitrate,
      proxyPath: savedProxy != null && File(savedProxy).existsSync()
          ? savedProxy
          : null,
    );
  }

  platform.MediaProbeInfo _probeInfoForVideo(PickedVideo video) => (
        durationSeconds: video.durationSeconds,
        width: video.width,
        height: video.height,
        frameRate: video.frameRate,
        videoCodec: video.videoCodec,
        bitrate: video.bitrate,
        hasAudio: video.hasAudio,
      );

  bool _shouldUseProxy(PickedVideo video) {
    return widget.settings.shouldGenerateProxy(
        demandingMedia: platform.mediaNeedsProxy(_probeInfoForVideo(video)),
        projectOverride: _projectProxyEnabled);
  }

  Future<String?> _ensureProxyForVideo(PickedVideo video) {
    if (!_shouldUseProxy(video)) return Future<String?>.value(null);
    final existing = video.proxyPath;
    if (existing != null && File(existing).existsSync()) {
      return Future<String?>.value(existing);
    }
    final active = _proxyJobsBySource[video.path];
    if (active != null) return active;
    late final Future<String?> job;
    job = () async {
      final cacheFolder = await _proxyCacheFolder();
      final proxy = await platform.generateProxyMedia(
        video.path,
        cacheFolder,
        resolution: _projectProxyResolution,
        durationSeconds: video.durationSeconds,
      );
      if (proxy == null || !File(proxy).existsSync()) {
        if (MediaJobManager.instance.isBackgroundPaused) return null;
        if (mounted) {
          final index = _videos.indexWhere((item) => item.path == video.path);
          final shouldReload = index == _selectedVideoIndex;
          _updateEditor(() {
            _status =
                'Proxy unavailable for ${video.name}; using source preview';
          });
          if (shouldReload) {
            await _selectVideo(index, saveCurrentEdit: false);
          }
        }
        return null;
      }
      if (!mounted || !_shouldUseProxy(video)) return proxy;
      final index = _videos.indexWhere((item) => item.path == video.path);
      if (index < 0) return proxy;
      final shouldReload = index == _selectedVideoIndex;
      _updateEditor(() {
        _videos[index] = _videos[index].copyWith(proxyPath: proxy);
        _status = 'Lightweight preview ready for ${video.name}';
      });
      unawaited(_autosaveProject());
      if (shouldReload &&
          mounted &&
          _previewController?.value.isPlaying != true) {
        await _selectVideo(index, saveCurrentEdit: false);
      }
      return proxy;
    }();
    _proxyJobsBySource[video.path] = job;
    unawaited(job.whenComplete(() {
      if (identical(_proxyJobsBySource[video.path], job)) {
        _proxyJobsBySource.remove(video.path);
      }
    }));
    return job;
  }

  bool _isSupportedVideoPath(String path) {
    const extensions = {
      '.mp4',
      '.mov',
      '.mkv',
      '.avi',
      '.webm',
      '.m4v',
      '.wmv',
      '.flv',
      '.mpeg',
      '.mpg',
      '.mts',
      '.m2ts',
      '.3gp',
    };
    final lower = path.toLowerCase();
    return extensions.any(lower.endsWith);
  }

  Future<void> _importDroppedMedia(List<DropItem> items) async {
    if (items.isEmpty || _importingDroppedMedia) return;
    _updateEditor(() {
      _draggingMediaFiles = false;
      _importingDroppedMedia = true;
      _status = 'Scanning dropped files and folders...';
    });
    try {
      final paths = <String>[];
      for (final item in items) {
        final path = item.path;
        if (path.trim().isEmpty) continue;
        if (await Directory(path).exists()) {
          paths.addAll(await platform.videoFilesInFolder(path));
          _rememberFolder(path);
        } else if (await File(path).exists() && _isSupportedVideoPath(path)) {
          paths.add(path);
        }
      }

      final existing = _videos.map((v) => v.path.toLowerCase()).toSet();
      final uniquePaths = <String>[];
      final seen = <String>{...existing};
      for (final path in paths) {
        if (seen.add(path.toLowerCase())) uniquePaths.add(path);
      }
      if (uniquePaths.isEmpty) {
        if (mounted) {
          _updateEditor(() => _status = paths.isEmpty
              ? 'No supported video files found in the drop.'
              : 'All dropped videos are already imported.');
        }
        return;
      }
      final startIndex = _videos.length;
      await _setPickedVideos(
        [
          ..._videos,
          for (final path in uniquePaths)
            PickedVideo(name: platform.basename(path), path: path),
        ],
        resetEdits: false,
        selectedIndex: startIndex,
        compositionPathsToAdd: uniquePaths,
      );
      if (mounted) {
        _updateEditor(() => _status =
            'Imported ${uniquePaths.length} video${uniquePaths.length == 1 ? '' : 's'} into Media. Double-click one to add it to the timeline.');
      }
    } catch (error) {
      if (mounted) _updateEditor(() => _status = 'Drop import failed: $error');
    } finally {
      if (mounted) _updateEditor(() => _importingDroppedMedia = false);
    }
  }

  Widget _mediaFileDropTarget({required Widget child}) {
    return DropTarget(
      onDragEntered: (_) => _updateEditor(() => _draggingMediaFiles = true),
      onDragExited: (_) => _updateEditor(() => _draggingMediaFiles = false),
      onDragDone: (details) => unawaited(_importDroppedMedia(details.files)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (_draggingMediaFiles)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xdd111827),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xff22d3ee), width: 2),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined,
                          color: Color(0xff22d3ee), size: 42),
                      SizedBox(height: 10),
                      KText('Drop video files or folders',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      KText(
                        'All supported videos will be added',
                        style: TextStyle(color: Color(0xffcbd5e1)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
