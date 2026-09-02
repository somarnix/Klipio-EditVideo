part of '../editor_application.dart';

// projects operations owned by the editor state; extracted without changing timing.
extension _ProjectsProxyCacheFolder on _EditorScreenState {
  Future<String> _proxyCacheFolder() async {
    final configured = widget.settings.proxyFolder.trim();
    if (configured.isNotEmpty) return configured;
    final cacheConfigured = widget.settings.cacheFolder.trim();
    final root = cacheConfigured.isNotEmpty
        ? Directory(cacheConfigured)
        : Directory(
            '${(await getCacheDirectory()).path}${Platform.pathSeparator}KlipioCache',
          );
    return '${root.path}${Platform.pathSeparator}proxies';
  }

  Future<void> _addProjectMedia(List<PickedVideo> picked) async {
    final composition = _selectedCompositionPath;
    if (composition == null || picked.isEmpty) return;
    final paths = _projectMediaPathsByComposition.putIfAbsent(
      composition,
      () => [composition],
    );
    final knownByPath = {
      for (final video in _videos) video.path.toLowerCase(): video,
    };
    final cacheDirectory = await getCacheDirectory();
    final thumbnailCache =
        '${cacheDirectory.path}${platform.pathSeparator}klipio_thumbnails';
    final added = <PickedVideo>[];
    for (final item in picked) {
      final key = item.path.toLowerCase();
      var video = knownByPath[key];
      if (video == null) {
        video = await _enrichVideoMetadata(item);
        knownByPath[key] = video;
        added.add(video);
      }
      if (!paths.any((path) => path.toLowerCase() == key)) {
        paths.add(video.path);
      }
    }
    if (!mounted) return;
    _updateEditor(() {
      _videos.addAll(added);
      for (final video in added) {
        _clipTimelineEdits.putIfAbsent(
          video.path,
          () => const _ClipTimelineEdit(),
        );
      }
      _status =
          '${picked.length} media file${picked.length == 1 ? '' : 's'} added inside ${platform.basename(composition)}';
    });
    final generation = ++_filmstripLoadGeneration;
    unawaited(_loadTimelineFilmstrips(generation, thumbnailCache));
    _scheduleNeededProxies(added);
    unawaited(_autosaveProject());
  }

  Future<void> _pickVideoFolder() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null) return;

    final paths = await platform.videoFilesInFolder(folder);
    if (!mounted) return;

    if (paths.isEmpty) {
      _showMessage('No video files found in this folder.');
      return;
    }

    final picked = paths
        .map((path) => PickedVideo(name: platform.basename(path), path: path))
        .toList();
    _rememberFolder(folder);
    await _setPickedVideos(picked);
  }

  Future<void> _openAutosaveProject() async {
    final projects = await _discoverKlipioProjectPaths();
    if (projects.isEmpty) {
      _showMessage('No autosave project found yet.');
      return;
    }
    await _loadProject(projects.first);
  }

  Future<void> _openVideoFolderPath(String folder) async {
    if (!Directory(folder).existsSync()) {
      _showMessage('Folder no longer exists: $folder');
      return;
    }
    final paths = await platform.videoFilesInFolder(folder);
    if (paths.isEmpty) {
      _showMessage('No video files found in this folder.');
      return;
    }
    _rememberFolder(folder);
    await _setPickedVideos(
      paths
          .map((path) => PickedVideo(name: platform.basename(path), path: path))
          .toList(),
    );
  }

  Future<void> _clearProject({
    bool confirm = true,
    bool createProjectFile = true,
    bool invalidateProjectGeneration = true,
  }) async {
    if (confirm && _videos.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const KText('Start a new project?'),
          content: KText(
            'Close the current project with ${_videos.length} loaded video${_videos.length == 1 ? '' : 's'} and start a new one? Your source files and saved projects will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const KText('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.add_box_outlined),
              label: const KText('New project'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    if (invalidateProjectGeneration) {
      ++_projectSaveGeneration;
      _loadingProjectGeneration = null;
    }
    _pendingAutosavePath = null;
    ++_controllerLoadGeneration;
    ++_filmstripLoadGeneration;
    _timelineMediaLoadDebounce?.cancel();
    final exportToken = _exportCancelToken;
    final captionToken = _captionCancelToken;
    try {
      await Future.wait<void>([
        if (exportToken != null)
          exportToken.cancelAndWait(timeout: const Duration(seconds: 8)),
        if (captionToken != null)
          captionToken.cancelAndWait(timeout: const Duration(seconds: 8)),
        platform.cancelBackgroundMediaTasks(),
      ]);
    } catch (_) {
      await terminateAllKlipioWorkers();
    }
    _videoCoverJobsBySource.clear();
    _proxyJobsBySource.clear();
    MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
    MediaJobManager.instance.resumeBackgroundWork(owner: 'source-playback');
    await _stopMusicPreview();
    final source = _sourceController;
    final preview = _previewController;
    source?.removeListener(_handleSourceTick);
    preview?.removeListener(_handlePreviewTick);
    _updateEditor(() {
      _videos.clear();
      _editorUndoHistory.clear();
      _editorRedoHistory.clear();
      _compositionPaths.clear();
      _projectMediaPathsByComposition.clear();
      _timelinesByComposition.clear();
      _selectedCompositionPath = null;
      _clipTimelineEdits.clear();
      _clipTimelineUndoStacks.clear();
      _clipTimelineRedoStacks.clear();
      _captionCuesByVideo.clear();
      _audioWaveformPeaks.clear();
      _audioWaveformPeakRates.clear();
      _textOverlays
        ..clear()
        ..add(const _TextOverlayDraft());
      _selectedTextOverlayIndex = 0;
      _loadTextOverlay(_textOverlays.first);
      _clipTransformOverrides.clear();
      _multiTrackTimeline = TimelineModel.empty();
      _timelineMarkers.clear();
      _selectedTimelineClipId = null;
      _selectedTimelineClipIds.clear();
      _selectedCaptionIds.clear();
      _musicTimelineSelected = false;
      _programTimelineClipId = null;
      _sourceController = null;
      _previewController = null;
      _sourceError = null;
      _previewError = null;
      _selectedVideoIndex = 0;
      _currentProjectPath = null;
      _nameController.clear();
      _numberStartController.text = '1';
      _numberEndController.clear();
      _titleCheckController.clear();
      _status = 'New project ready. Open Project media to import files.';
    });
    await source?.dispose();
    await preview?.dispose();
    if (createProjectFile) {
      await _autosaveProject(includeEmptyProject: true);
    }
  }

  Future<void> _pickOutputFolder() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (!mounted) return;
    _updateEditor(() {
      _outputFolder = folder;
      _status = folder == null ? _status : 'Output folder selected';
    });
  }

  Future<String> _capCutDraftRenderFolder(String scratchFolder) async {
    final folder = '$scratchFolder${Platform.pathSeparator}'
        'CapCut Draft Renders${Platform.pathSeparator}'
        '${DateTime.now().millisecondsSinceEpoch}';
    await Directory(folder).create(recursive: true);
    return folder;
  }

  String _capCutDraftProjectName(
    List<_QueuedExport> jobs, {
    bool useTypedName = true,
  }) {
    final typedName = useTypedName ? _safeName(_nameController.text) : '';
    if (typedName.isNotEmpty) return typedName;
    if (jobs.isEmpty) return 'video';
    return _withoutExtension(_capCutDraftJobClipName(jobs.first));
  }

  String _capCutVideoFolder(_QueuedExport job, String rootFolder) {
    final videoIndex =
        _videos.indexWhere((video) => video.path == job.video.path);
    final order =
        (videoIndex < 0 ? 1 : videoIndex + 1).toString().padLeft(3, '0');
    final base = _safeName(
      job.video.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
    );
    final name = base.isEmpty ? 'video' : base;
    return '$rootFolder${Platform.pathSeparator}${order}_$name';
  }

  _EditorHistorySnapshot _captureEditorHistory() {
    _saveSelectedTextOverlay();
    _saveSelectedClipTimelineEdit();
    return _EditorHistorySnapshot(
      timeline: _multiTrackTimeline,
      timelinesByComposition: Map.of(_timelinesByComposition),
      projectMediaPathsByComposition: {
        for (final entry in _projectMediaPathsByComposition.entries)
          entry.key: List.of(entry.value),
      },
      textOverlays: List.of(_textOverlays),
      clipTimelineEdits: Map.of(_clipTimelineEdits),
      captionCuesByVideo: {
        for (final entry in _captionCuesByVideo.entries)
          entry.key: List.of(entry.value),
      },
      clipTransformOverrides: Set.of(_clipTransformOverrides),
      timelineMarkers: List.of(_timelineMarkers),
      selectedCompositionPath: _selectedCompositionPath,
      selectedTimelineClipId: _selectedTimelineClipId,
      programTimelineClipId: _programTimelineClipId,
      editorSelection: _editorSelection,
      selectedTextOverlayIndex: _selectedTextOverlayIndex,
      selectedCaptionCueIndex: _selectedCaptionCueIndex,
      selectedVideoIndex: _selectedVideoIndex,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      gamma: _gamma,
      originalVolume: _originalVolume,
      musicVolume: _musicVolume,
      watermarkX: _watermarkX,
      watermarkY: _watermarkY,
      watermarkSize: _watermarkSize,
      watermarkPath: _watermarkPath,
      musicPath: _musicPath,
      outputRatio: _outputRatio,
      projectColorSpace: _projectColorSpace,
      projectResolution: _projectResolution,
      projectProxyResolution: _projectProxyResolution,
      projectProxyEnabled: _projectProxyEnabled,
      projectCopyMedia: _projectCopyMedia,
      projectArrangeLayers: _projectArrangeLayers,
      projectFrameRate: _projectFrameRate,
      automaticCaptions: _automaticCaptions,
    );
  }

  void _recordEditorHistory(String key, {bool coalesce = true}) {
    if (_restoringEditorHistory) return;
    _editorHistory.record(key, _captureEditorHistory, coalesce: coalesce);
  }

  bool get _canUndoEditor => _editorUndoHistory.isNotEmpty;
  bool get _canRedoEditor => _editorRedoHistory.isNotEmpty;
  void _undoEditor() {
    final snapshot = _editorHistory.undo(_captureEditorHistory);
    if (snapshot != null) _restoreEditorHistory(snapshot, 'Undo');
  }

  void _redoEditor() {
    final snapshot = _editorHistory.redo(_captureEditorHistory);
    if (snapshot != null) _restoreEditorHistory(snapshot, 'Redo');
  }

  void _restoreEditorHistory(_EditorHistorySnapshot snapshot, String action) {
    _restoringEditorHistory = true;
    _updateEditor(() {
      _multiTrackTimeline = snapshot.timeline;
      _timelinesByComposition
        ..clear()
        ..addAll(snapshot.timelinesByComposition);
      _projectMediaPathsByComposition
        ..clear()
        ..addAll({
          for (final entry in snapshot.projectMediaPathsByComposition.entries)
            entry.key: List.of(entry.value),
        });
      _textOverlays
        ..clear()
        ..addAll(snapshot.textOverlays);
      if (_textOverlays.isEmpty) {
        _textOverlays.add(const _TextOverlayDraft());
      }
      _clipTimelineEdits
        ..clear()
        ..addAll(snapshot.clipTimelineEdits);
      _captionCuesByVideo
        ..clear()
        ..addAll({
          for (final entry in snapshot.captionCuesByVideo.entries)
            entry.key: List.of(entry.value),
        });
      _clipTransformOverrides
        ..clear()
        ..addAll(snapshot.clipTransformOverrides);
      _timelineMarkers
        ..clear()
        ..addAll(snapshot.timelineMarkers);
      _selectedCompositionPath = snapshot.selectedCompositionPath;
      _selectedTimelineClipId = snapshot.selectedTimelineClipId;
      _programTimelineClipId = snapshot.programTimelineClipId;
      _editorSelection = snapshot.editorSelection;
      _selectedTextOverlayIndex =
          snapshot.selectedTextOverlayIndex.clamp(0, _textOverlays.length - 1);
      _selectedCaptionCueIndex = snapshot.selectedCaptionCueIndex;
      _selectedVideoIndex = _videos.isEmpty
          ? 0
          : snapshot.selectedVideoIndex.clamp(0, _videos.length - 1);
      _brightness = snapshot.brightness;
      _contrast = snapshot.contrast;
      _saturation = snapshot.saturation;
      _gamma = snapshot.gamma;
      _originalVolume = snapshot.originalVolume;
      _musicVolume = snapshot.musicVolume;
      _watermarkX = snapshot.watermarkX;
      _watermarkY = snapshot.watermarkY;
      _watermarkSize = snapshot.watermarkSize;
      _watermarkPath = snapshot.watermarkPath;
      _musicPath = snapshot.musicPath;
      _outputRatio = snapshot.outputRatio;
      _projectColorSpace = snapshot.projectColorSpace;
      _projectResolution = snapshot.projectResolution;
      _projectProxyResolution = snapshot.projectProxyResolution;
      _projectProxyEnabled = snapshot.projectProxyEnabled;
      _projectCopyMedia = snapshot.projectCopyMedia;
      _projectArrangeLayers = snapshot.projectArrangeLayers;
      _projectFrameRate = snapshot.projectFrameRate;
      _automaticCaptions = snapshot.automaticCaptions;
      _loadTextOverlay(_textOverlays[_selectedTextOverlayIndex]);
      if (_videos.isNotEmpty) _loadClipTimelineEdit(_selectedVideoIndex);
      final selectedClip = _selectedTimelineClipId == null
          ? null
          : _multiTrackTimeline.clipById(_selectedTimelineClipId!);
      if (selectedClip?.track.type == TrackType.video) {
        _loadTimelineClipTransformIntoInspector(selectedClip!.clip);
      }
      _status = '$action complete';
    });
    _restoringEditorHistory = false;
    _editorHistory.resetCoalescing();
    unawaited(_autosaveProject());
  }

  Future<String?> _defaultOutputFolder() async {
    final configured = widget.settings.defaultExportFolder.trim();
    if (configured.isNotEmpty) {
      await Directory(configured).create(recursive: true);
      if (mounted) _updateEditor(() => _outputFolder = configured);
      return configured;
    }
    final directory = await getApplicationDocumentsDirectory();
    _updateEditor(() => _outputFolder = directory.path);
    return directory.path;
  }

  String _capCutReadyFolder(String folder) {
    if (platform.basename(folder).toLowerCase() == 'capcut ready') {
      return folder;
    }
    return '$folder${Platform.pathSeparator}CapCut Ready';
  }

  Widget _projectDetailsInspector() {
    final projectDirectory =
        _currentProjectPath == null ? null : File(_currentProjectPath!).parent;
    final projectName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : projectDirectory == null
            ? 'Untitled project'
            : platform.basename(projectDirectory.path);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const KText(
          'Project details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        _projectSettingReadout('Name', projectName),
        _projectSettingReadout(
          'Path',
          projectDirectory?.path ?? 'Save the project to create its folder',
        ),
        _projectSettingReadout('Color space', _projectColorSpace),
        _projectSettingReadout(
          'Imported media',
          _projectCopyMedia
              ? 'Copy media to project'
              : 'Stay in original location',
        ),
        _projectSettingReadout(
          'Arrange layers',
          _projectArrangeLayers ? 'Turned on' : 'Turned off',
        ),
        _projectSettingReadout(
          'Proxy',
          _projectProxyEnabled
              ? 'Turned on · $_projectProxyResolution'
              : 'Turned off',
        ),
        const Divider(height: 30),
        _projectSettingReadout('Timeline name', 'Timeline 01'),
        _projectSettingReadout('Aspect ratio', _outputRatio),
        _projectSettingReadout('Resolution', _projectResolution),
        _projectSettingReadout(
          'Frame rate',
          '${_projectFrameRate.toStringAsFixed(2)} fps',
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: _showProjectDetailsDialog,
          icon: const Icon(Icons.tune_outlined, size: 17),
          label: const KText('Modify project'),
        ),
      ],
    );
  }

  Widget _projectImportTabsPanel() {
    return _panelShell(
      title: '',
      workspacePanelId: 'project',
      showHeader: false,
      child: Column(children: [
        SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                for (final entry in const [
                  (
                    LeftWorkspaceTab.media,
                    Icons.video_library_outlined,
                    'Media'
                  ),
                  (LeftWorkspaceTab.audio, Icons.audiotrack, 'Audio'),
                  (LeftWorkspaceTab.text, Icons.title, 'Text'),
                  (
                    LeftWorkspaceTab.captions,
                    Icons.subtitles_outlined,
                    'Captions'
                  ),
                  (
                    LeftWorkspaceTab.effects,
                    Icons.auto_awesome_outlined,
                    'Effects'
                  ),
                ])
                  IconButton(
                    tooltip: '${entry.$3} browser',
                    isSelected: _leftWorkspaceTab == entry.$1,
                    selectedIcon: Icon(entry.$2,
                        color: Theme.of(context).colorScheme.primary),
                    icon: Icon(entry.$2, size: 20),
                    onPressed: () => _openLeftWorkspaceTab(entry.$1),
                  ),
                IconButton(
                    tooltip: 'Transitions browser',
                    icon: const Icon(Icons.compare_arrows),
                    isSelected: _leftWorkspaceTab == LeftWorkspaceTab.effects &&
                        _effectsWorkspaceCategory ==
                            _EffectsWorkspaceCategory.transitions,
                    onPressed: () => _openEffectsWorkspace(
                        _EffectsWorkspaceCategory.transitions)),
              ],
            )),
        Expanded(
            child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 170),
          child: KeyedSubtree(
            key: ValueKey(_leftWorkspaceTab),
            child: switch (_leftWorkspaceTab) {
              LeftWorkspaceTab.media => _mediaDockPanel(),
              LeftWorkspaceTab.text => _textWorkspacePanel(),
              LeftWorkspaceTab.captions => _captionWorkspacePanel(),
              LeftWorkspaceTab.effects => _effectsWorkspacePanel(),
              LeftWorkspaceTab.audio => _focusedControlsPanel('Project audio', [
                  FilledButton.icon(
                      onPressed: _pickMusic,
                      icon: const Icon(Icons.audio_file_outlined),
                      label: const KText('Import audio')),
                  const SizedBox(height: 12),
                  ..._audioMixControlSection(),
                ]),
            },
          ),
        )),
      ]),
    );
  }

  Widget _projectBinsList() {
    return AssetBrowserShell<PickedVideo>(
      key: const ValueKey('project-asset-browser'),
      items: _activeProjectMedia,
      searchText: (video) => '${video.name} ${video.path}',
      searchLabel: 'Search project media',
      loading: _importingDroppedMedia,
      emptyTitle: 'Your project media',
      emptyDescription:
          'Import a video, then drag it onto a track or add it to the timeline. Reuse an asset without changing existing clips.',
      emptyAction: OutlinedButton.icon(
        onPressed: _importingDroppedMedia ? null : _pickProjectVideos,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const KText('Import media'),
      ),
      toolbar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(children: [
          FilledButton.icon(
            onPressed: _importingDroppedMedia ? null : _pickProjectVideos,
            icon: const Icon(Icons.add, size: 16),
            label: const KText('Import'),
          ),
          IconButton(
            tooltip: 'Import folder',
            onPressed: _importingDroppedMedia ? null : _pickProjectVideoFolder,
            icon: const Icon(Icons.folder_open_outlined, size: 20),
          ),
        ]),
      ),
      itemBuilder: (context, video, layout) => layout == AssetBrowserLayout.grid
          ? _projectMediaCard(video)
          : _projectMediaListItem(video),
    );
  }
}
