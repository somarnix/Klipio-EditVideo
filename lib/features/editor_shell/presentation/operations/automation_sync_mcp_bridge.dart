part of '../editor_application.dart';

// automation operations owned by the editor state; extracted without changing timing.
extension _AutomationSyncMcpBridge on _EditorScreenState {
  Future<void> _syncMcpBridge(
      {required bool enabled, required int port}) async {
    final generation = ++_mcpBridgeGeneration;
    await _mcpBridge?.stop();
    _mcpBridge = null;
    if (!enabled || !mounted) return;
    final bridge = MCPBridge(
      onTimelineChanged: (timeline) {
        if (!mounted) return;
        _updateEditor(() {
          _applyTimelineModelUpdate(timeline);
          _status = 'Timeline updated by MCP';
        });
        unawaited(_autosaveProject());
      },
      onSeek: _requestMultiTrackTimelineSeek,
      onPlayPause: () => unawaited(_togglePreview()),
      getCurrentTimeline: () => _multiTrackTimeline,
      getCurrentSelection: () => {
        'clip_id': _selectedTimelineClipId,
        'clip_ids': _effectiveSelectedTimelineClipIds.toList(),
        'caption_ids': _effectiveSelectedCaptionIds.toList(),
      },
      getProjectInfo: () => {
        'project_name': _nameController.text.trim().isEmpty
            ? 'Klipio'
            : _nameController.text.trim(),
        'duration': _timelineSequenceDuration(),
        'path': _currentProjectPath,
      },
      getMediaLibrary: () => [
        for (final video in _videos)
          {
            'name': video.name,
            'path': video.path,
            'duration': video.durationSeconds,
            'has_audio': video.hasAudio,
          },
      ],
      onOpenProject: (path) => unawaited(_openProjectFromMcp(path)),
    );
    _mcpBridge = bridge;
    try {
      await bridge.start(port: port);
      if (!mounted || generation != _mcpBridgeGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('MCP connected at ws://127.0.0.1:$port'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted || generation != _mcpBridgeGeneration) return;
      _mcpBridge = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MCP could not start: $error')),
      );
    }
  }

  Future<void> _runStartupAutomationJob() async {
    final job = startupAutomationJob;
    if (job == null || _startupAutomationStarted) return;
    _startupAutomationStarted = true;
    try {
      await job.writeResult('loading', message: 'Loading videos into Klipio.');
      final sourcePath = job.sourcePath;
      final paths = job.sourceMode == 'folder'
          ? await platform.videoFilesInFolder(sourcePath)
          : [sourcePath];
      final validPaths =
          paths.where((path) => File(path).existsSync()).toList();
      if (validPaths.isEmpty) {
        throw FileSystemException('No video files were found.', sourcePath);
      }
      await _setPickedVideos([
        for (final path in validPaths)
          PickedVideo(name: platform.basename(path), path: path),
      ]);
      if (!mounted) return;
      _updateEditor(() {
        _outputFolder = job.outputFolder.isEmpty ? null : job.outputFolder;
        _outputRatio = job.outputRatio;
        _originalVolume =
            job.originalVolume.clamp(0.0, _EditorScreenState._maxAudioBoost);
        _musicVolume =
            job.musicVolume.clamp(0.0, _EditorScreenState._maxAudioBoost);
        _musicPath = job.musicPath;
        _hookDurationController.text =
            job.hookLength.isEmpty ? 'auto' : job.hookLength;
        _hookEditMode = job.hookMode == 'bestMoments'
            ? _HookEditMode.bestMoments
            : _HookEditMode.hookWithVideo;
        _capCutRenderEdits = job.renderEdits;
        _capCutOneFolder = job.capCutOneFolder;
        _exportTimelineTogether = true;
        _status = 'Automation job loaded.';
      });
      await job.writeResult('editing', message: 'Applying Klipio settings.');
      if (job.hookMode != 'none') {
        await _applyHookVideoEdit(allVideos: true);
      }
      if (!job.createCapCutDraft) {
        await job.writeResult(
          'ready_for_review',
          message: 'Klipio is ready for review.',
        );
        return;
      }
      await job.writeResult('creating_capcut_draft');
      final automationExportAvailable = await isExportAvailable();
      if (mounted) {
        _updateEditor(() => _exportAvailable = automationExportAvailable);
      }
      await _createCapCutDraft();
      await job.writeResult(
        _lastCapCutDraftSuccess ? 'capcut_draft_ready' : 'failed',
        message: _lastCapCutDraftSuccess
            ? 'CapCut draft created by Klipio.'
            : (_lastCapCutDraftMessage.isEmpty
                ? 'Klipio could not create the CapCut draft.'
                : _lastCapCutDraftMessage),
        draftFolder: _lastCapCutDraftFolder,
      );
    } catch (error) {
      if (mounted) _updateEditor(() => _status = 'Automation failed: $error');
      await job.writeResult('failed', message: '$error');
    }
  }
}
