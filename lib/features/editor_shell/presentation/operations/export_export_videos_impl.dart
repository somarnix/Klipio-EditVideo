part of '../editor_application.dart';

// export operations owned by the editor state; extracted without changing timing.
extension _ExportExportVideosImpl on _EditorScreenState {
  Future<void> _exportVideosImpl({
    required bool prepareForCapCut,
    required bool showSettingsDialog,
  }) async {
    if (_videos.isEmpty) {
      _showMessage('Select one or more videos first.');
      return;
    }
    await _pausePlaybackForExport();

    final baseFolder = _outputFolder ?? await _defaultOutputFolder();
    final folder = prepareForCapCut && baseFolder != null
        ? _capCutReadyFolder(baseFolder)
        : baseFolder;
    if (folder == null) {
      _showMessage('Select an output folder first.');
      return;
    }

    if (!_exportAvailable) {
      _showMessage(
        platform.isAndroid || platform.isIos
            ? 'This Flutter mobile UI is ready. Add an FFmpeg mobile plugin/backend to enable phone export.'
            : 'Install FFmpeg and add it to PATH to enable export on this PC.',
      );
      return;
    }

    _syncCutFields();
    var jobs = _buildExportJobs(folder, applyNumberRange: false);
    if (prepareForCapCut) {
      jobs = _capCutJobs(
        jobs,
        rootFolder: folder,
        oneFolder: _capCutOneFolder,
        renderEdits: _capCutRenderEdits,
      );
    }
    if (jobs.isEmpty) {
      _showMessage('No export jobs were created. Check cut/split values.');
      return;
    }

    String exportFolder;
    if (showSettingsDialog) {
      final confirmed = await _showExportSettingsDialog(
        folder,
        jobs,
        prepareForCapCut: prepareForCapCut,
      );
      if (!confirmed || !mounted) return;
      exportFolder = _confirmedExportFolder ?? _outputFolder ?? folder;
      _confirmedExportFolder = null;
      jobs = _buildExportJobs(exportFolder);
      if (prepareForCapCut) {
        jobs = _capCutJobs(
          jobs,
          rootFolder: exportFolder,
          oneFolder: _capCutOneFolder,
          renderEdits: _capCutRenderEdits,
        );
      }
    } else {
      exportFolder = _outputFolder ?? folder;
      jobs = _buildExportJobs(exportFolder);
      if (prepareForCapCut) {
        jobs = _capCutJobs(
          jobs,
          rootFolder: exportFolder,
          oneFolder: _capCutOneFolder,
          renderEdits: _capCutRenderEdits,
        );
      }
    }
    if (jobs.isEmpty) {
      _showMessage('No videos are inside the selected number range.');
      return;
    }

    // "One timeline video" is authoritative. A project may remember the
    // separate-parts preference, but that must never silently replace the
    // edited timeline with short source fragments.
    final activeTimelineMediaPaths = <String>{
      for (final track in _multiTrackTimeline.videoTracks)
        if (!track.isMuted)
          for (final clip in track.clips)
            if (!clip.isMuted && clip.duration > 0.001) clip.mediaPath,
    };
    // A single imported source can produce several timeline clips after hook,
    // split, trim, or delete edits. Those clips are one edited movie, not
    // separate export jobs. This also repairs older projects that remembered
    // the obsolete separate-output preference.
    final isSingleSourceEditedTimeline =
        _videos.length == 1 && activeTimelineMediaPaths.length == 1;
    final exportTimelineTogether = !prepareForCapCut &&
        (_exportTimelineTogether || isSingleSourceEditedTimeline);
    final exportDetails = _buildExportDialogDetails(
      exportFolder,
      jobs,
      exportTimelineTogether: exportTimelineTogether,
      titleOverride: prepareForCapCut ? 'Prepare for CapCut' : null,
      nameOverride: prepareForCapCut
          ? '${_groupQueuedExports(jobs).length} CapCut clips'
          : null,
    );
    final useMultiTrackExport = !prepareForCapCut &&
        exportTimelineTogether &&
        _compositionPaths.length <= 1 &&
        activeTimelineMediaPaths.isNotEmpty;
    if (useMultiTrackExport) {
      final timelineDuration = _actualMultiTrackExportDuration();
      final timelineDetails = exportDetails.copyWith(
        durationSeconds: timelineDuration,
        estimatedSize: _estimatedExportSizeLabel(
          timelineDuration,
          _exportBitrateKbps,
          1,
        ),
      );
      await _runMultiTrackExport(exportFolder, timelineDetails);
      return;
    }
    final cancelToken = ExportCancelToken();
    _exportCancelToken = cancelToken;
    _updateExportProgressView(
      details: exportDetails,
      progress: 0,
      elapsed: Duration.zero,
      status: prepareForCapCut
          ? 'Preparing CapCut clips...'
          : 'Preparing export...',
    );
    final exportStartedAt = DateTime.now();
    _showExportProgressDialog();

    _updateEditor(() {
      _isExporting = true;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _progress = 0;
      _status = prepareForCapCut ? 'Preparing CapCut clips...' : 'Exporting...';
    });

    if (exportTimelineTogether) {
      _updateEditor(() {
        _progress = 0;
        _status = 'Rendering timeline sequence...';
      });
      var lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      final result = await exportVideoSequence(
        SequenceExportJob(
          jobs: [
            for (final item in jobs)
              ExportJob(
                inputPath: item.video.path,
                outputPath: item.outputPath,
                settings: item.settings,
                cancelToken: cancelToken,
              ),
          ],
          outputPath: _timelineOutputPath(exportFolder),
          settings: _settings,
          cancelToken: cancelToken,
          onProgress: (progress, status) {
            final now = DateTime.now();
            if (now.difference(lastProgressUpdate).inMilliseconds < 250 &&
                progress < 1) {
              return;
            }
            lastProgressUpdate = now;
            if (!mounted) return;
            _updateEditor(() {
              _progress = progress.clamp(0.0, 1.0).toDouble();
              _status = status;
            });
            _updateExportProgressView(
              details: exportDetails,
              progress: progress,
              elapsed: DateTime.now().difference(exportStartedAt),
              status: 'Rendering timeline sequence...',
            );
          },
        ),
      );
      if (!mounted) return;
      if (result.success) {
        _updateEditor(() {
          _isExporting = false;
          _renderQueuePaused = false;
          _renderQueueStopRequested = false;
          _exportCancelToken = null;
          _progress = 1;
          _status = 'Ready';
        });
        MediaJobManager.instance.resumeBackgroundWork();
        _updateExportProgressView(
          details: exportDetails,
          progress: 1,
          elapsed: DateTime.now().difference(exportStartedAt),
          status: 'Export complete',
        );
        _closeExportProgressDialog();
        _playExportCompleteSound();
        _showMessage('Timeline export complete: ${result.outputPath}');
      } else {
        final canceled = result.message == 'Export canceled.';
        _updateEditor(() {
          _isExporting = false;
          _renderQueuePaused = false;
          _renderQueueStopRequested = false;
          _exportCancelToken = null;
          _status = canceled ? 'Export canceled' : 'Ready';
        });
        MediaJobManager.instance.resumeBackgroundWork();
        _closeExportProgressDialog();
        _showMessage(canceled
            ? 'Export canceled.'
            : 'Timeline export failed: ${result.message}');
      }
      return;
    }

    final exportGroups = _groupQueuedExports(jobs);
    var success = 0;
    var failed = 0;
    String? lastError;
    var lastProgressUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    for (var index = 0; index < exportGroups.length; index++) {
      final canContinue = await _waitForRenderQueueResume(
        details: exportDetails,
        exportStartedAt: exportStartedAt,
      );
      if (!canContinue) {
        lastError = 'Export canceled.';
        break;
      }
      final group = exportGroups[index];
      final outputName = platform.basename(group.outputPath);
      void onClipProgress(double clipProgress, String status) {
        final now = DateTime.now();
        if (now.difference(lastProgressUpdate).inMilliseconds < 250 &&
            clipProgress < 1) {
          return;
        }
        lastProgressUpdate = now;
        if (!mounted) return;
        // The dialog already identifies the current item as "N of total".
        // Its meter therefore reports this video's own 0-100% progress and
        // restarts for the next video instead of showing a combined batch
        // percentage that can never reach 100% for items before the last one.
        final currentVideoProgress = clipProgress.clamp(0.0, 1.0).toDouble();
        _updateEditor(() {
          _progress = currentVideoProgress;
          _status = prepareForCapCut
              ? 'Preparing CapCut clip ${index + 1} of ${exportGroups.length}: $outputName'
              : 'Exporting ${index + 1} of ${exportGroups.length}: $outputName';
        });
        _updateExportProgressView(
          details: exportDetails.copyWith(
            name: outputName,
            durationSeconds: _queuedExportGroupDuration(group),
            thumbnailPath: group.video.thumbnailPath,
          ),
          progress: currentVideoProgress,
          elapsed: DateTime.now().difference(exportStartedAt),
          status: prepareForCapCut
              ? 'Preparing CapCut clip ${index + 1} of ${exportGroups.length}'
              : 'Exporting ${index + 1} of ${exportGroups.length}',
        );
      }

      final result = await _exportQueuedVideoComposition(
        group,
        cancelToken: cancelToken,
        onProgress: onClipProgress,
      );
      if (!mounted) return;
      if (result.success) {
        success++;
      } else {
        failed++;
        lastError = '$outputName: ${result.message}';
        if (result.message == 'Export canceled.') {
          break;
        }
      }
      _updateEditor(() {
        _progress = 1;
        _status = prepareForCapCut
            ? 'Prepared ${index + 1} of ${exportGroups.length}'
            : 'Exported ${index + 1} of ${exportGroups.length}';
      });
    }

    _updateEditor(() {
      _isExporting = false;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _exportCancelToken = null;
      _status = lastError?.contains('Export canceled.') == true
          ? 'Export canceled'
          : 'Ready';
    });
    MediaJobManager.instance.resumeBackgroundWork();
    _updateExportProgressView(
      details: exportDetails,
      progress: 1,
      elapsed: DateTime.now().difference(exportStartedAt),
      status: lastError == null
          ? prepareForCapCut
              ? 'CapCut clips ready'
              : 'Export complete'
          : 'Export finished',
    );
    _closeExportProgressDialog();
    if (lastError?.contains('Export canceled.') == true) {
      _showMessage('Export canceled.');
    } else if (lastError == null) {
      _playExportCompleteSound();
      if (prepareForCapCut) {
        _showMessage(
          'CapCut-ready folder complete. Success: $success, failed: $failed.',
        );
      } else {
        _showMessage('Export complete. Success: $success, failed: $failed.');
      }
    } else {
      _showMessage(
        'Export complete. Success: $success, failed: $failed. Last error: $lastError',
      );
    }
  }

  Future<void> _runMultiTrackExport(
    String exportFolder,
    KlipioExportDialogDetails exportDetails,
  ) async {
    final outputPath = _timelineOutputPath(exportFolder);
    final dimensions = _multiTrackOutputDimensions();
    final sourceTimelineDuration = _actualMultiTrackExportDuration();
    final sourceTimeline =
        _multiTrackTimeline.copyWith(duration: sourceTimelineDuration);
    final compositionPath = _selectedCompositionPath;
    final playbackSpeed = (compositionPath == null
            ? _speed
            : _clipTimelineEditFor(compositionPath).speed)
        .clamp(_EditorScreenState._minVideoSpeed,
            _EditorScreenState._maxVideoSpeed)
        .toDouble();
    final renderSnapshot = _programRenderSnapshot(sourceTimeline);
    final playbackSpeeds = renderSnapshot.playbackSpeedsByMediaPath;
    final exportTimeline = renderSnapshot.outputTimeline;
    final timelineDuration = _actualMultiTrackExportDuration(exportTimeline);
    final timelineCaptionCues = _exportTimelineCaptionCues(
      sourceTimeline,
      outputTimeline: exportTimeline,
      playbackSpeedsByMediaPath: playbackSpeeds,
    );
    final captionSettings = timelineCaptionCues.isEmpty
        ? null
        : _settings.copyWith(
            automaticCaptions: false,
            captionCues: timelineCaptionCues,
            textOverlays: const [],
            speed: 1,
            trimStartSeconds: 0,
            trimEndSeconds: timelineDuration,
          );
    final cancelToken = ExportCancelToken();
    _exportCancelToken = cancelToken;
    _updateExportProgressView(
      details: exportDetails,
      progress: 0,
      elapsed: Duration.zero,
      status: 'Preparing multi-track filter graph...',
    );
    _showExportProgressDialog();
    final startedAt = DateTime.now();
    _updateEditor(() {
      _isExporting = true;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _progress = 0;
      _status = 'Rendering dynamic multi-track timeline...';
    });
    final result = await exportMultiTrackTimeline(
      MultiTrackExportJob(
        timeline: exportTimeline.copyWith(duration: timelineDuration),
        outputPath: outputPath,
        width: dimensions.width,
        height: dimensions.height,
        frameRate: _exportFrameRate > 0 ? _exportFrameRate : _projectFrameRate,
        videoBitrateKbps: _exportBitrateKbps,
        exportCodec: _exportCodec,
        hardwareEncoding: widget.settings.hardwareEncoding,
        hardwareDecoding: widget.settings.hardwareDecoding,
        playbackSpeedsByMediaPath: playbackSpeeds,
        textOverlays: _retimeTextOverlaysForExport(
          _exportManualTextOverlays(),
          playbackSpeed,
          timeline: exportTimeline,
        ),
        captionSettings: captionSettings,
        captionParagraphSpec: _captionParagraphSpec,
        cancelToken: cancelToken,
        onProgress: (progress, status) {
          if (!mounted) return;
          _updateEditor(() {
            _progress = progress.clamp(0, 1).toDouble();
            _status = status;
          });
          _updateExportProgressView(
            details: exportDetails,
            progress: progress,
            elapsed: DateTime.now().difference(startedAt),
            status: status,
          );
        },
      ),
    );
    if (!mounted) return;
    _updateEditor(() {
      _isExporting = false;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _progress = result.success ? 1 : 0;
      _status = result.success
          ? 'Multi-track export complete'
          : 'Multi-track export failed';
    });
    MediaJobManager.instance.resumeBackgroundWork();
    _exportCancelToken = null;
    _updateExportProgressView(
      details: exportDetails,
      progress: result.success ? 1 : 0,
      elapsed: DateTime.now().difference(startedAt),
      status: result.success ? 'Multi-track export complete' : result.message,
    );
    _closeExportProgressDialog();
    if (result.success) {
      _playExportCompleteSound();
      _showMessage('Multi-track export complete: $outputPath');
    } else {
      _showMessage(result.message);
    }
  }
}
