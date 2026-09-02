part of '../editor_application.dart';

// controls operations owned by the editor state; extracted without changing timing.
extension _ControlsIsLightUi on _EditorScreenState {
  bool get _isLightUi => Theme.of(context).brightness == Brightness.light;

  void _ensureComposition(PickedVideo video) {
    if (!_compositionPaths.contains(video.path)) {
      _compositionPaths.add(video.path);
    }
    _projectMediaPathsByComposition.putIfAbsent(
      video.path,
      () => [video.path],
    );
    _timelinesByComposition.putIfAbsent(
      video.path,
      () => _timelineWithFirstVideo(video),
    );
  }

  Future<void> _selectComposition(String path) async {
    final index = _videos.indexWhere((video) => video.path == path);
    if (index < 0) return;
    _storeActiveCompositionTimeline();
    final timeline = _timelinesByComposition[path] ??
        _timelineWithFirstVideo(_videos[index]);
    final clips = timeline.videoTracks.expand((track) => track.clips).toList();
    final firstClip = clips.isEmpty ? null : clips.first;
    _updateEditor(() {
      _selectedCompositionPath = path;
      _multiTrackTimeline = timeline;
      _selectedTimelineClipId = firstClip?.id;
      _programTimelineClipId = firstClip?.id;
      _timelineMarkers.clear();
      _status = 'Opened ${_videos[index].name} timeline';
    });
    unawaited(_loadVisibleTimelineMedia());
    await _selectVideo(index, saveCurrentEdit: false);
    if (firstClip != null) {
      await _seekProgramPreview(firstClip.timelineStart);
    }
  }

  void _scheduleNeededProxies(Iterable<PickedVideo> videos) {
    for (final video in videos) {
      if (!_projectProxyEnabled &&
          widget.settings.proxyMode == ProxyMode.auto &&
          (_videos.isEmpty ||
              video.path != _videos[_selectedVideoIndex].path)) {
        continue;
      }
      if (_shouldUseProxy(video)) unawaited(_ensureProxyForVideo(video));
    }
  }

  Future<void> _showTitleCheckDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final titles = _pastedVideoTitles();
          final masterNumbers = [
            for (final video in _videos)
              titles.indexWhere(
                (title) =>
                    normalizeVideoTitle(title) ==
                    normalizeVideoTitle(video.name),
              ),
          ];
          final matchCount = masterNumbers.where((index) => index >= 0).length;

          return AlertDialog(
            title: const KText('Call Check - Video Order'),
            content: SizedBox(
              width: 820,
              height: 620,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KText(
                    'Paste your full master title list, one title per line. Each loaded project video is searched anywhere in that list.',
                    style: TextStyle(color: _mutedTextColor),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _titleCheckController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Master video title list',
                      hintText:
                          'Paste the complete list here, one title per line',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),
                  KText(
                    '$matchCount of ${_videos.length} project videos found  |  ${titles.length} master titles pasted',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _videos.isEmpty
                        ? const Center(
                            child: KText(
                                'Import project videos first, then paste the master title list.'))
                        : ListView.builder(
                            itemCount: _videos.length,
                            itemBuilder: (context, index) {
                              final actual =
                                  _withoutExtension(_videos[index].name);
                              final masterIndex = masterNumbers[index];
                              final isMatch = masterIndex >= 0;
                              final color = isMatch ? Colors.green : Colors.red;
                              return Card(
                                color: color.withOpacity(0.10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                    child: KText(
                                        isMatch ? '${masterIndex + 1}' : '!'),
                                  ),
                                  title: KText(
                                    actual,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: KText(
                                    isMatch
                                        ? 'Found at master number ${masterIndex + 1}  |  Project position ${index + 1}'
                                        : 'Not found in the pasted master list  |  Project position ${index + 1}',
                                  ),
                                  trailing: isMatch
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : FilledButton.icon(
                                          onPressed: () async {
                                            await _replaceVideoAt(index);
                                            if (dialogContext.mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                          icon: const Icon(Icons.swap_horiz),
                                          label: const KText('Replace'),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: matchCount < 2
                    ? null
                    : () async {
                        final ranked = [
                          for (var index = 0; index < _videos.length; index++)
                            (
                              video: _videos[index],
                              master: masterNumbers[index]
                            ),
                        ]..sort((a, b) {
                            final aRank = a.master < 0 ? 1 << 30 : a.master;
                            final bRank = b.master < 0 ? 1 << 30 : b.master;
                            return aRank.compareTo(bRank);
                          });
                        await _setPickedVideos(
                          ranked.map((item) => item.video).toList(),
                          resetEdits: false,
                        );
                        if (dialogContext.mounted) {
                          setDialogState(() {});
                        }
                      },
                icon: const Icon(Icons.sort_by_alpha),
                label: const KText('Sort by master list'),
              ),
              TextButton(
                onPressed: () {
                  _titleCheckController.clear();
                  setDialogState(() {});
                },
                child: const KText('Clear'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const KText('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  ProgramRenderSnapshot _programRenderSnapshot(TimelineModel timeline) {
    return ProgramRenderSnapshot.build(
      sourceTimeline: timeline,
      playbackSpeedsByMediaPath: _videoPlaybackSpeedsForExport(timeline),
      minimumSpeed: _EditorScreenState._minVideoSpeed,
      maximumSpeed: _EditorScreenState._maxVideoSpeed,
    );
  }

  // All active timeline presentation and pointer commands use program seconds.
  // The durable sequence remains source-clock for compatibility and export.
  TimelineModel get _programEditingTimeline =>
      _programRenderSnapshot(_multiTrackTimeline).outputTimeline;

  TimelineEditor get _programTimelineEditor =>
      TimelineEditor.program(sourceDurations: {
        for (final video in _videos)
          if (video.durationSeconds != null) video.path: video.durationSeconds!
      });

  TimelineModel _sourceTimelineFromProgramEdit(TimelineModel program) =>
      ProgramRenderSnapshot.trySourceFromProgram(program) ??
      _multiTrackTimeline;

  TimelineModel _editInProgramTime(
      TimelineModel source,
      TimelineModel Function(TimelineEditor editor, TimelineModel program)
          edit) {
    final program = _programRenderSnapshot(source).outputTimeline;
    final next = edit(_programTimelineEditor, program);
    return identical(next, program)
        ? source
        : ProgramRenderSnapshot.trySourceFromProgram(next) ?? source;
  }

  double _currentProgramSeconds() {
    if (_videos.isEmpty ||
        _selectedVideoIndex < 0 ||
        _selectedVideoIndex >= _videos.length) {
      return 0;
    }
    final requestedTimelineSeconds = _requestedTimelinePlayheadSeconds.value;
    if (requestedTimelineSeconds != null) {
      final duration = _programPlaybackDurationSeconds();
      return requestedTimelineSeconds
          .clamp(0.0, math.max(duration, 0.0))
          .toDouble();
    }
    final programClipId = _programTimelineClipId;
    if (programClipId != null) {
      final result = _programPreviewTimeline.clipById(programClipId);
      if (result != null &&
          result.track.type == TrackType.video &&
          result.clip.mediaPath == _videos[_selectedVideoIndex].path) {
        final sourceSeconds = _currentPlayheadSeconds();
        return ProgramTimelineMapper.timelineSecondsForSource(
          clip: result.clip,
          sourceSeconds: sourceSeconds,
          playbackSpeed: result.clip.resolvedPlaybackSpeed(
              _clipTimelineEditFor(result.clip.mediaPath).speed),
        );
      }
    }
    if (_hasAuthoritativeProgramTimeline) {
      return _liveTimelineSeconds
          .clamp(0.0, _programPlaybackDurationSeconds())
          .toDouble();
    }
    var sequenceSeconds = 0.0;
    for (final item in _visibleTimelineVideos()) {
      final index = item.index;
      final video = item.video;
      final parts = _clipTimelineEditFor(video.path).timelineParts(
        video.durationSeconds,
      );
      if (index < _selectedVideoIndex) {
        sequenceSeconds += parts.fold<double>(
          0,
          (sum, part) => sum + (part.end - part.start).abs(),
        );
        continue;
      }
      if (index == _selectedVideoIndex) {
        final sourceSeconds = _currentPlayheadSeconds();
        for (final part in parts) {
          final partDuration = (part.end - part.start).abs();
          if (sourceSeconds >= part.start - 0.001 &&
              sourceSeconds <= part.end + 0.001) {
            return sequenceSeconds +
                (sourceSeconds - part.start).clamp(0.0, partDuration);
          }
          sequenceSeconds += partDuration;
        }
        return sequenceSeconds.clamp(0.0, _timelineSequenceDuration());
      }
    }
    return sequenceSeconds;
  }

  Future<void> _createCapCutDraft({bool showSettingsDialog = true}) async {
    _lastCapCutDraftSuccess = false;
    _lastCapCutDraftFolder = null;
    _lastCapCutDraftMessage = '';
    if (_videos.isEmpty) {
      _lastCapCutDraftMessage = 'Select one or more videos first.';
      _showMessage('Select one or more videos first.');
      return;
    }
    if (!platform.isDesktop || !Platform.isWindows) {
      _lastCapCutDraftMessage =
          'CapCut draft export is available on Windows desktop only.';
      _showMessage('CapCut draft export is available on Windows desktop only.');
      return;
    }
    if (await isCapCutDesktopRunning()) {
      _lastCapCutDraftMessage =
          'Close CapCut before creating drafts, then try again.';
      _showMessage('Close CapCut before creating drafts, then try again.');
      return;
    }

    _syncCutFields();
    final initialFolder = _outputFolder ?? await _defaultOutputFolder();
    if (initialFolder == null) return;
    final selectedFolder = showSettingsDialog
        ? await _showCapCutDraftSettingsDialog(initialFolder)
        : initialFolder;
    if (selectedFolder == null || selectedFolder.trim().isEmpty) return;
    final scratchFolder = selectedFolder.trim();
    final jobs = _buildExportJobs(
      scratchFolder,
      applyNumberRange: !_capCutRangeNumbersAllVideos,
    );
    if (jobs.isEmpty) {
      _lastCapCutDraftMessage =
          'No videos are inside the selected number range.';
      _showMessage('No videos are inside the selected number range.');
      return;
    }

    final draftGroups = _capCutDraftGroups(jobs);
    final multipleDrafts = draftGroups.length > 1;
    final renderDraftClips = _capCutDraftNeedsRenderedClips(jobs);
    if (renderDraftClips && !_exportAvailable) {
      _lastCapCutDraftMessage = platform.isAndroid || platform.isIos
          ? 'A mobile FFmpeg backend is required to render CapCut draft effects.'
          : 'Install FFmpeg and add it to PATH to render CapCut draft effects.';
      _showMessage(
        platform.isAndroid || platform.isIos
            ? 'This Flutter mobile UI is ready. Add an FFmpeg mobile plugin/backend to render CapCut draft effects.'
            : 'Install FFmpeg and add it to PATH to render CapCut draft effects.',
      );
      return;
    }
    final renderFolder =
        renderDraftClips ? await _capCutDraftRenderFolder(scratchFolder) : null;
    final projectName = multipleDrafts
        ? '${draftGroups.length} CapCut drafts'
        : _capCutDraftProjectName(
            draftGroups.first,
            useTypedName: _exportTimelineTogether,
          );

    _updateEditor(() {
      _isExporting = true;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _progress = 0;
      _status = 'Creating CapCut draft...';
    });
    final exportDetails = _buildExportDialogDetails(
      scratchFolder,
      jobs,
      exportTimelineTogether: true,
      titleOverride: 'Create CapCut Draft',
      nameOverride: projectName,
    );
    _updateExportProgressView(
      details: exportDetails,
      progress: 0,
      elapsed: Duration.zero,
      status: 'Creating CapCut draft...',
    );
    final cancelToken = ExportCancelToken();
    _exportCancelToken = cancelToken;
    _showExportProgressDialog();

    final results = <CapCutDraftResult>[];
    for (var index = 0; index < draftGroups.length; index++) {
      if (cancelToken.isCanceled || _renderQueueStopRequested) {
        results.add(
          const CapCutDraftResult(
            success: false,
            message: 'Export canceled.',
          ),
        );
        break;
      }
      final group = draftGroups[index];
      final groupName = _capCutDraftProjectName(
        group,
        useTypedName: _exportTimelineTogether,
      );
      final status = multipleDrafts
          ? 'Creating CapCut draft ${index + 1} of ${draftGroups.length}: $groupName'
          : 'Creating CapCut draft...';
      if (mounted) {
        _updateEditor(() {
          _progress = index / draftGroups.length;
          _status = status;
        });
        _updateExportProgressView(
          details: exportDetails,
          progress: index / draftGroups.length,
          elapsed: _exportProgressView.value.elapsed,
          status: status,
        );
      }

      try {
        final clips = renderDraftClips
            ? await _renderCapCutDraftClips(
                group,
                renderFolder!,
                groupIndex: index,
                groupCount: draftGroups.length,
                details: exportDetails,
                cancelToken: cancelToken,
              )
            : [
                for (final job in group)
                  CapCutDraftClip(
                    inputPath: job.video.path,
                    name: _capCutDraftJobClipName(job),
                    settings: job.settings,
                  ),
              ];
        results.add(
          await createCapCutDraft(
            projectName: groupName,
            outputRoot: scratchFolder,
            clips: clips,
            launchCapCut: false,
            includeCaptionsInDraft: false,
            exportCaptionSrt: true,
          ).timeout(const Duration(hours: 1)),
        );
      } catch (error) {
        final message =
            cancelToken.isCanceled ? 'Export canceled.' : error.toString();
        results.add(
          CapCutDraftResult(
            success: false,
            message: message,
          ),
        );
        if (cancelToken.isCanceled) break;
      }
    }

    if (!mounted) return;
    final successResults = results.where((result) => result.success).toList();
    final failedResults = results.where((result) => !result.success).toList();
    final allSucceeded = failedResults.isEmpty && successResults.isNotEmpty;
    _lastCapCutDraftSuccess = allSucceeded;
    _lastCapCutDraftMessage = allSucceeded
        ? successResults.last.message
        : (failedResults.isEmpty
            ? 'Unknown CapCut draft error.'
            : failedResults.last.message);
    if (successResults.isNotEmpty) {
      _lastCapCutDraftFolder = successResults.first.draftFolder;
    }
    _updateEditor(() {
      _isExporting = false;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _exportCancelToken = null;
      _progress = allSucceeded ? 1 : successResults.length / draftGroups.length;
      _status =
          failedResults.any((result) => result.message == 'Export canceled.')
              ? 'Export canceled'
              : 'Ready';
    });
    MediaJobManager.instance.resumeBackgroundWork();
    _updateExportProgressView(
      details: exportDetails,
      progress: allSucceeded ? 1 : successResults.length / draftGroups.length,
      elapsed: _exportProgressView.value.elapsed,
      status:
          failedResults.any((result) => result.message == 'Export canceled.')
              ? 'CapCut draft canceled'
              : allSucceeded
                  ? 'CapCut draft ready'
                  : 'CapCut draft failed',
    );
    _closeExportProgressDialog();

    if (failedResults.any((result) => result.message == 'Export canceled.')) {
      _showMessage('CapCut draft canceled.');
      return;
    }

    if (successResults.isNotEmpty) {
      if (failedResults.isEmpty) {
        _showMessage(
          multipleDrafts
              ? 'CapCut drafts ready: ${successResults.length} drafts saved with Caption SRT folders.'
              : 'CapCut draft ready: ${successResults.first.projectName ?? projectName}. Caption SRT: ${successResults.first.captionFolder ?? 'no caption cues available'}',
        );
      } else {
        _showMessage(
          'CapCut drafts complete. Success: ${successResults.length}, failed: ${failedResults.length}. Last error: ${failedResults.last.message}',
        );
      }
    } else {
      _showMessage(
        'CapCut draft failed: ${failedResults.isEmpty ? 'Unknown error' : failedResults.last.message}',
      );
    }
  }
}
