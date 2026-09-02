part of '../editor_application.dart';

// projects operations owned by the editor state; extracted without changing timing.
extension _ProjectsOpenProjectFromMcp on _EditorScreenState {
  Future<void> _openProjectFromMcp(String path) async {
    var projectPath = path.trim();
    if (Directory(projectPath).existsSync()) {
      projectPath = await _projectFileFromSelectedFolder(projectPath) ?? '';
    }
    if (projectPath.isEmpty || !File(projectPath).existsSync()) {
      if (mounted) {
        _updateEditor(() => _status = 'MCP project not found: $path');
      }
      return;
    }
    widget.onShowEditor?.call();
    await _loadProject(projectPath);
  }

  void _rememberProject(String path) {
    _recentProjectPaths
      ..remove(path)
      ..insert(0, path);
    if (_recentProjectPaths.length > _EditorScreenState._maxRecentProjects) {
      _recentProjectPaths.removeRange(
        _EditorScreenState._maxRecentProjects,
        _recentProjectPaths.length,
      );
    }
    unawaited(_saveWorkspaceMemory());
  }

  void _syncRecentProjectPaths(List<String> paths) {
    if (!mounted) return;
    _updateEditor(() {
      _recentProjectPaths
        ..clear()
        ..addAll(paths.take(_EditorScreenState._maxRecentProjects));
    });
  }

  void _syncExternalProjectName(
    String oldPath,
    String newPath,
    String name,
  ) {
    final current = _currentProjectPath;
    if (current == null || current.toLowerCase() != oldPath.toLowerCase()) {
      return;
    }
    _updateEditor(() {
      _currentProjectPath = newPath;
      _nameController.text = name;
      _status = 'Project renamed to $name';
    });
  }

  Future<void> _closeExternallyDeletedProject(String path) async {
    final current = _currentProjectPath;
    if (current == null || current.toLowerCase() != path.toLowerCase()) return;
    await _clearProject(confirm: false, createProjectFile: false);
  }

  void _rememberFolder(String path) {
    if (path.trim().isEmpty) return;
    _recentFolders
      ..remove(path)
      ..insert(0, path);
    if (_recentFolders.length > 8) {
      _recentFolders.removeRange(8, _recentFolders.length);
    }
    unawaited(_saveWorkspaceMemory());
  }

  Future<String> _autosavePath() async {
    final draftsRoot = await _klipioDraftsRoot();
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}-'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final requestedName = _nameController.text.trim();
    final projectDirectory = await _uniqueKlipioProjectDirectory(
      draftsRoot,
      requestedName.isEmpty ? 'Klipio Project $stamp' : requestedName,
    );
    final path =
        '${projectDirectory.path}${Platform.pathSeparator}$_klipioProjectFileName';
    await _ensureKlipioProjectStructure(path);
    return path;
  }

  Future<void> _autosaveProject({bool includeEmptyProject = false}) async {
    if (_loadingProjectGeneration != null) return;
    if (_videos.isEmpty && !includeEmptyProject) return;
    final generation = _projectSaveGeneration;
    try {
      _saveSelectedClipTimelineEdit();
      // Capture before any await: switching projects must never save the new
      // editor contents into the old project's destination.
      final captured = _session.capture(envelope: _projectJson());
      final path = _currentProjectPath ??
          await (_pendingAutosavePath ??= _autosavePath());
      await _session.save(path, revision: captured);
      if (generation != _projectSaveGeneration || !mounted) return;
      _currentProjectPath ??= path;
      _pendingAutosavePath = null;
      _rememberProject(path);
    } catch (error) {
      // Keep editing usable, but never imply that a failed save succeeded.
      if (mounted && generation == _projectSaveGeneration) {
        _pendingAutosavePath = null;
        _updateEditor(() => _status = 'Autosave failed: $error. Retry Save.');
      }
    }
  }

  Future<void> _saveProjectAs() async {
    if (_loadingProjectGeneration != null) {
      _showMessage('Wait for the project to finish opening before saving.');
      return;
    }
    if (_videos.isEmpty) {
      _showMessage('Import videos before saving a project.');
      return;
    }
    _saveSelectedClipTimelineEdit();
    final generation = _projectSaveGeneration;
    final captured = _session.capture(envelope: _projectJson());
    final requestedName = _nameController.text.trim();
    var target = _currentProjectPath;
    if (target == null && _pendingAutosavePath != null) {
      target = await _pendingAutosavePath;
    }
    if (target == null || !await _isManagedKlipioProjectPath(target)) {
      final draftsRoot = await _klipioDraftsRoot();
      final projectDirectory = await _uniqueKlipioProjectDirectory(
        draftsRoot,
        requestedName.isEmpty ? 'Klipio Project' : requestedName,
      );
      target =
          '${projectDirectory.path}${Platform.pathSeparator}$_klipioProjectFileName';
    }
    final saveTarget = target;
    await _session.save(saveTarget, revision: captured);
    if (!mounted || generation != _projectSaveGeneration) return;
    final projectDirectory = File(saveTarget).parent;
    _updateEditor(() {
      _currentProjectPath = saveTarget;
      _status = 'Project saved: ${platform.basename(projectDirectory.path)}';
      _rememberProject(saveTarget);
    });
  }

  Future<void> _openProjectDialog() async {
    final draftsRoot = await _klipioDraftsRoot();
    await draftsRoot.create(recursive: true);
    final selectedFolder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Klipio project folder',
      initialDirectory: draftsRoot.path,
    );
    if (selectedFolder == null) return;
    final path = await _projectFileFromSelectedFolder(selectedFolder);
    if (path == null) {
      _showMessage(
        'Choose one project folder directly inside Klipio Drafts. The internal project file is opened automatically.',
      );
      return;
    }
    await _loadProject(path);
  }

  Future<void> _loadProject(String path) async {
    final generation = ++_projectSaveGeneration;
    _loadingProjectGeneration = generation;
    _pendingAutosavePath = null;
    var durableInstalled = false;
    var bindingsReady = false;
    try {
      final loaded = await _session.read(path);
      if (!mounted || generation != _projectSaveGeneration) return;
      if (loaded.recovered) {
        if (!mounted) return;
        final recover = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const KText('Recover project backup?'),
                  content: const KText(
                      'The project file is damaged. Open its previous '
                      'backup as a new draft? The damaged file and backup will be preserved.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const KText('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const KText('Recover as new draft')),
                  ],
                ));
        if (recover != true ||
            !mounted ||
            generation != _projectSaveGeneration) {
          return;
        }
      }
      final data = loaded.revision.data;
      // Durable state is reconstructed before probing/player preparation.
      // Save is suspended until the UI bindings below are fully installed.
      _session.restore(loaded.revision);
      durableInstalled = true;
      final videos = (data['videos'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => PickedVideo(
                name: '${item['name'] ?? platform.basename('${item['path']}')}',
                path: '${item['path'] ?? ''}',
                durationSeconds:
                    double.tryParse('${item['durationSeconds'] ?? ''}'),
                hasAudio: item['hasAudio'] as bool? ?? true,
                width: int.tryParse('${item['width'] ?? ''}') ?? 0,
                height: int.tryParse('${item['height'] ?? ''}') ?? 0,
                frameRate: double.tryParse('${item['frameRate'] ?? ''}') ?? 0,
                videoCodec: '${item['videoCodec'] ?? 'unknown'}',
                bitrate: int.tryParse('${item['bitrate'] ?? ''}') ?? 0,
                proxyPath: '${item['proxyPath'] ?? ''}'.trim().isEmpty
                    ? null
                    : '${item['proxyPath']}',
              ))
          .where((video) => video.path.isNotEmpty)
          .toList();
      if (videos.isEmpty) {
        await _clearProject(
          confirm: false,
          createProjectFile: false,
          invalidateProjectGeneration: false,
        );
      } else {
        _applyProjectSettings(data['projectSettings']);
        _multiTrackTimeline = TimelineModel.empty();
        _selectedTimelineClipId = null;
        _selectedTimelineClipIds.clear();
        _selectedCaptionIds.clear();
        _musicTimelineSelected = false;
        _programTimelineClipId = null;
        _compositionPaths.clear();
        _projectMediaPathsByComposition.clear();
        _timelinesByComposition.clear();
        _selectedCompositionPath = null;
        await _setPickedVideos(videos, resetEdits: false);
      }
      if (!mounted || generation != _projectSaveGeneration) return;
      _updateEditor(() {
        _session.restore(loaded.revision);
        _currentProjectPath = loaded.recovered ? null : path;
        _outputFolder = data['outputFolder'] as String?;
        _nameController.text = '${data['outputName'] ?? ''}';
        _qualityPreset = '${data['qualityPreset'] ?? _qualityPreset}';
        _exportCodec = _safeExportCodec(
          '${data['exportCodec'] ?? _exportCodec}',
        );
        _exportFrameRate = _safeExportFrameRate(
          double.tryParse('${data['exportFrameRate'] ?? _exportFrameRate}') ??
              _exportFrameRate,
        );
        _outputRatio = '${data['outputRatio'] ?? _outputRatio}';
        _batchRenamePattern = '${data['batchRenamePattern'] ?? ''}';
        _batchRenameController.text = _batchRenamePattern;
        _exportTimelineTogether =
            data['exportTimelineTogether'] as bool? ?? _exportTimelineTogether;
        _applyProjectSettings(data['projectSettings']);
        _applyProjectAdvanced(data['advanced']);
        _applyProjectTransform(data['transform']);
        _applyProjectColor(data['color']);
        _applyProjectAudio(data['audio']);
        _applyProjectCaptions(data['captions']);
        // Captions were restored by the session, including missing-media
        // records. Derived media availability must not delete durable cues.
        _selectedCaptionCueIndex = 0;
        _textOverlays
          ..clear()
          ..addAll(_textOverlaysFromJson(data['textOverlays']));
        if (_textOverlays.isEmpty) _textOverlays.add(const _TextOverlayDraft());
        _selectedTextOverlayIndex = 0;
        _loadTextOverlay(_textOverlays.first);
        _clipTimelineEdits
          ..clear()
          ..addAll(_clipEditsFromJson(data['clipEdits']));
        _clipTransformOverrides
          ..clear()
          ..addAll(
            _clipTransformOverridesFromJson(
              data['clipTransformOverrides'],
              _clipTimelineEdits,
            ),
          );
        final savedCompositions = [
          for (final item in data['compositions'] as List? ?? const [])
            if (_videos.any((video) => video.path == '$item')) '$item',
        ];
        if (savedCompositions.isNotEmpty) {
          _compositionPaths
            ..clear()
            ..addAll(savedCompositions);
        }
        final savedProjectMedia = data['projectMedia'];
        if (savedProjectMedia is Map) {
          _projectMediaPathsByComposition.clear();
          for (final entry in savedProjectMedia.entries) {
            final composition = '${entry.key}';
            if (!_compositionPaths.contains(composition)) continue;
            _projectMediaPathsByComposition[composition] = [
              for (final item in entry.value as List? ?? const [])
                if (_videos.any((video) => video.path == '$item')) '$item',
            ];
          }
        }
        for (final composition in _compositionPaths) {
          _projectMediaPathsByComposition.putIfAbsent(
            composition,
            () => [composition],
          );
        }
        final savedTimelines = data['timelines'];
        if (savedTimelines is Map) {
          _timelinesByComposition.clear();
          for (final entry in savedTimelines.entries) {
            final composition = '${entry.key}';
            if (_compositionPaths.contains(composition)) {
              _timelinesByComposition[composition] =
                  TimelineModel.fromJson(entry.value);
            }
          }
        }
        final requestedComposition = '${data['selectedComposition'] ?? ''}';
        _selectedCompositionPath =
            _compositionPaths.contains(requestedComposition)
                ? requestedComposition
                : (_compositionPaths.isEmpty ? null : _compositionPaths.first);
        if (savedTimelines is Map && _selectedCompositionPath != null) {
          _multiTrackTimeline =
              _timelinesByComposition[_selectedCompositionPath!] ??
                  TimelineModel.empty();
        } else {
          _multiTrackTimeline = data['timeline'] == null
              ? _buildLegacyMultiTrackTimeline()
              : TimelineModel.fromJson(data['timeline']);
          if (_selectedCompositionPath != null) {
            _timelinesByComposition[_selectedCompositionPath!] =
                _multiTrackTimeline;
          }
        }
        // Older project bundles could save split parts with every part at
        // timeline time zero. Repair that data once when opening the project
        // so video and linked audio play as a continuous sequence again.
        _multiTrackTimeline = _repairLoadedTimeline(_multiTrackTimeline);
        _multiTrackTimeline = ClipSpeedEdit.migrate(_multiTrackTimeline,
            _videoPlaybackSpeedsForExport(_multiTrackTimeline));
        if (_selectedCompositionPath != null) {
          _timelinesByComposition[_selectedCompositionPath!] =
              _multiTrackTimeline;
        }
        _ensureTextTimelineTracks();
        _timelineMarkers
          ..clear()
          ..addAll([
            for (final item in data['timelineMarkers'] as List? ?? const [])
              if (double.tryParse('$item') != null) double.parse('$item'),
          ]);
        _selectedTimelineClipId = null;
        _selectedTimelineClipIds.clear();
        _selectedCaptionIds.clear();
        _musicTimelineSelected = false;
        _programTimelineClipId = _multiTrackTimeline.videoTracks
                .expand((track) => track.clips)
                .isEmpty
            ? null
            : _multiTrackTimeline.videoTracks
                .expand((track) => track.clips)
                .first
                .id;
        _rememberProject(path);
        if (_outputFolder != null) _rememberFolder(_outputFolder!);
        _status = loaded.recovered
            ? 'Backup recovered as a new draft; original files preserved.'
            : _isKlipioProjectBundlePath(path)
                ? 'Project loaded: ${platform.basename(File(path).parent.path)}'
                : 'Project loaded: ${platform.basename(path)}';
      });
      final selectedComposition = _selectedCompositionPath;
      if (selectedComposition != null) {
        await _selectComposition(selectedComposition);
      } else {
        _loadClipTimelineEdit(_selectedVideoIndex);
      }
      bindingsReady = true;
    } catch (error) {
      if (mounted && generation == _projectSaveGeneration) {
        _showMessage('Could not open project: $error');
      }
    } finally {
      // If preparation failed after installing intent, do not autosave a mix
      // of the new session and old widget bindings. Retry Open or New resets
      // this guard; recovery rejection/read failures keep the old project usable.
      if (_loadingProjectGeneration == generation &&
          (!durableInstalled || bindingsReady)) {
        _loadingProjectGeneration = null;
      }
    }
  }

  void _applyProjectSettings(Object? value) {
    final data = value is Map ? value : const {};
    _projectColorSpace = '${data['colorSpace'] ?? _projectColorSpace}';
    _projectResolution = '${data['resolution'] ?? _projectResolution}';
    _projectProxyResolution =
        '${data['proxyResolution'] ?? _projectProxyResolution}';
    _projectProxyEnabled =
        data['proxyEnabled'] as bool? ?? _projectProxyEnabled;
    _projectCopyMedia = data['copyMedia'] as bool? ?? _projectCopyMedia;
    _projectArrangeLayers =
        data['arrangeLayers'] as bool? ?? _projectArrangeLayers;
    _projectFrameRate =
        double.tryParse('${data['frameRate'] ?? _projectFrameRate}') ??
            _projectFrameRate;
  }

  void _applyProjectColor(Object? value) {
    final data = value is Map ? value : const {};
    double number(String key, double fallback) =>
        double.tryParse('${data[key] ?? fallback}') ?? fallback;
    _brightness = number('brightness', _brightness);
    _contrast = number('contrast', _contrast);
    _saturation = number('saturation', _saturation);
    _gamma = number('gamma', _gamma);
  }

  void _applyProjectAudio(Object? value) {
    final data = value is Map ? value : const {};
    _musicPath = data['musicPath'] as String?;
    _originalVolume =
        double.tryParse('${data['originalVolume'] ?? _originalVolume}') ??
            _originalVolume;
    _musicVolume = double.tryParse('${data['musicVolume'] ?? _musicVolume}') ??
        _musicVolume;
  }

  Map<String, Object?> _projectJson() {
    _saveSelectedTransformEdit();
    _storeActiveCompositionTimeline();
    return {
      'version': 6,
      'savedAt': DateTime.now().toIso8601String(),
      'videos': [
        for (final video in _videos)
          {
            'name': video.name,
            'path': video.path,
            'hasAudio': video.hasAudio,
            'durationSeconds': video.durationSeconds,
            'width': video.width,
            'height': video.height,
            'frameRate': video.frameRate,
            'videoCodec': video.videoCodec,
            'bitrate': video.bitrate,
            'proxyPath': video.proxyPath,
          },
      ],
      'compositions': _compositionPaths,
      'selectedComposition': _selectedCompositionPath,
      'projectMedia': {
        for (final entry in _projectMediaPathsByComposition.entries)
          entry.key: entry.value,
      },
      'timelines': {
        for (final entry in _timelinesByComposition.entries)
          entry.key: entry.value.toJson(),
      },
      'outputFolder': _outputFolder,
      'outputName': _nameController.text,
      'qualityPreset': _qualityPreset,
      'exportCodec': _exportCodec,
      'exportFrameRate': _exportFrameRate,
      'outputRatio': _outputRatio,
      'batchRenamePattern': _batchRenamePattern,
      'exportTimelineTogether': _exportTimelineTogether,
      'projectSettings': {
        'colorSpace': _projectColorSpace,
        'resolution': _projectResolution,
        'proxyEnabled': _projectProxyEnabled,
        'proxyResolution': _projectProxyResolution,
        'copyMedia': _projectCopyMedia,
        'arrangeLayers': _projectArrangeLayers,
        'frameRate': _projectFrameRate,
      },
      'advanced': {
        'watermarkPath': _watermarkPath,
        'watermarkX': _watermarkX,
        'watermarkY': _watermarkY,
        'watermarkSize': _watermarkSize,
        'customBitrateKbps': _customBitrateKbps,
        'useNumberRange': _useNumberRange,
        'rangeStart': _numberStartController.text,
        'rangeEnd': _numberEndController.text,
        'batchSplitLongVideos': _batchSplitLongVideos,
        'batchSplitSelectedVideoOnly': _batchSplitSelectedVideoOnly,
        'exportSplitPartsAsFiles': _exportSplitPartsAsFiles,
        'batchSplitDuration': _batchSplitMinutesController.text,
        'partLabel': _partLabelController.text,
        'hookMode': _hookEditMode.name,
        'hookDuration': _hookDurationController.text,
        'videoTrackHidden': _videoTrackHidden,
        'originalAudioMuted': _originalAudioMuted,
        'musicTrackMuted': _musicTrackMuted,
        'musicTrackLocked': _musicTrackLocked,
        'captionTrackHidden': _captionTrackHidden,
        'captionTrackLocked': _captionTrackLocked,
        'showExtractedAudioTrack': _showExtractedAudioTrack,
        'capCutOneFolder': _capCutOneFolder,
        'capCutRenderEdits': _capCutRenderEdits,
      },
      'clipEdits': {
        for (final entry in _clipTimelineEdits.entries)
          entry.key: _clipEditToJson(entry.value),
      },
      'clipTransformOverrides': _clipTransformOverrides.toList(),
      'textOverlays': [
        for (final overlay in _previewTextOverlays())
          overlay.toJson(_colorToHex),
      ],
      'transform': {
        'speed': _speed,
        'flip': _flip,
        'scaleX': _scaleX,
        'scaleY': _scaleY,
        'zoom': _zoom,
        'panX': _panX,
        'panY': _panY,
        'canvasMode': _canvasMode,
        'canvasColor': _colorToHex(_canvasColor),
        'canvasPattern': _canvasPattern,
        'canvasBlur': _canvasBlur,
      },
      'color': {
        'brightness': _brightness,
        'contrast': _contrast,
        'saturation': _saturation,
        'gamma': _gamma,
      },
      'audio': {
        'musicPath': _musicPath,
        'originalVolume': _originalVolume,
        'musicVolume': _musicVolume,
      },
      'captions': {
        'enabled': _automaticCaptions,
        'model': _captionModel,
        'language': _captionLanguage,
        'device': _captionDevice,
        'style': _captionStyle,
        'font': _captionFont,
        'fontSize': _captionFontSize,
        'wordsPerLine': _captionWordsPerLine,
        'bold': _captionBold,
        'underline': _captionUnderline,
        'italic': _captionItalic,
        'case': _captionCase,
        'color': _colorToHex(_captionColor),
        'characterSpacing': _captionCharacterSpacing,
        'wordSpacing': _captionWordSpacing,
        'lineSpacing': _captionLineSpacing,
        'opacity': _captionOpacity,
        'strokeEnabled': _captionStrokeEnabled,
        'strokeColor': _colorToHex(_captionStrokeColor),
        'strokeWidth': _captionStrokeWidth,
        'backgroundEnabled': _captionBackgroundEnabled,
        'backgroundColor': _colorToHex(_captionBackgroundColor),
        'backgroundOpacity': _captionBackgroundOpacity,
        'backgroundPadding': _captionBackgroundPadding,
        'glowEnabled': _captionGlowEnabled,
        'glowColor': _colorToHex(_captionGlowColor),
        'glowStrength': _captionGlowStrength,
        'shadowEnabled': _captionShadowEnabled,
        'shadowColor': _colorToHex(_captionShadowColor),
        'shadowStrength': _captionShadowStrength,
        'curve': _captionCurve,
      },
      'captionCues': {
        for (final entry in _captionCuesByVideo.entries)
          entry.key: [for (final cue in entry.value) _captionCueToJson(cue)],
      },
      'timeline': _multiTrackTimeline.toJson(),
      'timelineMarkers': _timelineMarkers,
    };
  }

  void _applyProjectAdvanced(Object? value) {
    final data = value is Map ? value : const {};
    double number(String key, double fallback) =>
        double.tryParse('${data[key] ?? fallback}') ?? fallback;
    final watermarkPath = '${data['watermarkPath'] ?? ''}'.trim();
    _watermarkPath =
        watermarkPath.isNotEmpty && File(watermarkPath).existsSync()
            ? watermarkPath
            : null;
    _watermarkX = number('watermarkX', _watermarkX).clamp(0.0, 1.0).toDouble();
    _watermarkY = number('watermarkY', _watermarkY).clamp(0.0, 1.0).toDouble();
    _watermarkSize =
        number('watermarkSize', _watermarkSize).clamp(0.05, 0.5).toDouble();
    _customBitrateKbps = number('customBitrateKbps', _customBitrateKbps)
        .clamp(1000, 50000)
        .toDouble();
    _exportCodec = _safeExportCodec('${data['exportCodec'] ?? _exportCodec}');
    _exportFrameRate = _safeExportFrameRate(
      double.tryParse('${data['exportFrameRate'] ?? _exportFrameRate}') ??
          _exportFrameRate,
    );
    _useNumberRange = data['useNumberRange'] as bool? ?? _useNumberRange;
    _numberStartController.text = '${data['rangeStart'] ?? '1'}';
    _numberEndController.text = '${data['rangeEnd'] ?? ''}';
    _batchSplitLongVideos =
        data['batchSplitLongVideos'] as bool? ?? _batchSplitLongVideos;
    _batchSplitSelectedVideoOnly =
        data['batchSplitSelectedVideoOnly'] as bool? ??
            _batchSplitSelectedVideoOnly;
    _exportSplitPartsAsFiles =
        data['exportSplitPartsAsFiles'] as bool? ?? _exportSplitPartsAsFiles;
    _batchSplitMinutesController.text = '${data['batchSplitDuration'] ?? '15'}';
    _partLabelController.text = '${data['partLabel'] ?? 'part'}';
    _partLabel = _partLabelController.text;
    _hookEditMode = _HookEditMode.values.firstWhere(
      (mode) => mode.name == '${data['hookMode'] ?? ''}',
      orElse: () => _hookEditMode,
    );
    _hookDurationController.text = '${data['hookDuration'] ?? 'auto'}';
    _videoTrackHidden = data['videoTrackHidden'] as bool? ?? _videoTrackHidden;
    _originalAudioMuted =
        data['originalAudioMuted'] as bool? ?? _originalAudioMuted;
    _musicTrackMuted = data['musicTrackMuted'] as bool? ?? _musicTrackMuted;
    _musicTrackLocked = data['musicTrackLocked'] as bool? ?? _musicTrackLocked;
    _captionTrackHidden =
        data['captionTrackHidden'] as bool? ?? _captionTrackHidden;
    _captionTrackLocked =
        data['captionTrackLocked'] as bool? ?? _captionTrackLocked;
    _showExtractedAudioTrack =
        data['showExtractedAudioTrack'] as bool? ?? _showExtractedAudioTrack;
    _capCutOneFolder = data['capCutOneFolder'] as bool? ?? _capCutOneFolder;
    _capCutRenderEdits =
        data['capCutRenderEdits'] as bool? ?? _capCutRenderEdits;
  }

  List<PickedVideo> get _activeProjectMedia {
    final composition = _selectedCompositionPath;
    if (composition == null) return const [];
    final paths = _projectMediaPathsByComposition[composition] ?? [composition];
    return [
      for (final path in paths)
        for (final video in _videos)
          if (video.path == path) video,
    ];
  }

  Future<void> _pickProjectVideos() async {
    if (_selectedCompositionPath == null) {
      _showMessage('Select a video project in Import first.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.video,
    );
    if (result == null) return;
    await _addProjectMedia([
      for (final file in result.files)
        if (file.path != null) PickedVideo(name: file.name, path: file.path!),
    ]);
  }

  Future<void> _pickProjectVideoFolder() async {
    if (_selectedCompositionPath == null) {
      _showMessage('Select a video project in Import first.');
      return;
    }
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null) return;
    final paths = await platform.videoFilesInFolder(folder);
    if (paths.isEmpty) {
      _showMessage('No video files found in this folder.');
      return;
    }
    _rememberFolder(folder);
    await _addProjectMedia([
      for (final path in paths)
        PickedVideo(name: platform.basename(path), path: path),
    ]);
  }
}
