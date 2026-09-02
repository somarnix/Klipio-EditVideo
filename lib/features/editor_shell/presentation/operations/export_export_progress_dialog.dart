part of '../editor_application.dart';

// export operations owned by the editor state; extracted without changing timing.
extension _ExportExportProgressDialog on _EditorScreenState {
  Widget _exportProgressDialog(KlipioExportProgressView view) {
    final details = view.details;
    final progress = view.progress;
    final isCapCutDraft = details?.title == 'Create CapCut Draft';
    return Dialog(
      backgroundColor: _panelColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: _panelBorderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                children: [
                  KText(
                    details?.title ?? 'Export',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  KText(
                    view.status,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _panelBorderColor),
            Padding(
              padding: const EdgeInsets.all(26),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _exportPreviewImage(details),
                  const SizedBox(width: 34),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _softBarColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KText(
                            isCapCutDraft
                                ? 'Creating Draft'
                                : details?.title == 'Prepare for CapCut'
                                    ? 'Preparing'
                                    : 'Exporting',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _exportInfoRow('Video Name:', details?.name ?? ''),
                          _exportInfoRow(
                            'Duration:',
                            _formatDuration(details?.durationSeconds ?? 0),
                          ),
                          _exportInfoRow(
                            'Size:',
                            isCapCutDraft
                                ? 'Uses original files'
                                : details?.estimatedSize ?? 'Calculating...',
                          ),
                          if (isCapCutDraft) ...[
                            _exportInfoRow('Type:', 'CapCut draft'),
                            _exportInfoRow('Render:', 'No video render'),
                          ] else ...[
                            _exportInfoRow('Resolution:', _qualityPreset),
                            _exportInfoRow('Bitrate:', 'Higher'),
                            _exportInfoRow('Codec:', 'H.264'),
                            _exportInfoRow('Format:', 'mp4'),
                            _exportInfoRow('Frame rate:', 'Source fps'),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              decoration: BoxDecoration(color: _panelHeaderColor),
              child: Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: KText('${(progress * 100).toStringAsFixed(1)}%'),
                  ),
                  SizedBox(width: 78, child: KText(_formatClock(view.elapsed))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress <= 0 ? null : progress,
                      minHeight: 3,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: _panelBorderColor,
                    ),
                  ),
                  const SizedBox(width: 18),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        unawaited(_returnToHome(closeDialog: true)),
                    icon: const Icon(Icons.home_outlined),
                    label: const KText('Back to Home'),
                  ),
                  const SizedBox(width: 8),
                  if (!isCapCutDraft) ...[
                    FilledButton.tonalIcon(
                      onPressed: _renderQueuePaused
                          ? _resumeRenderQueue
                          : _pauseRenderQueue,
                      icon: Icon(
                        _renderQueuePaused
                            ? Icons.play_arrow
                            : Icons.pause_outlined,
                      ),
                      label: KText(_renderQueuePaused ? 'Resume' : 'Pause'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: () => unawaited(_confirmCancelExport()),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const KText('Cancel export'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportPreviewImage(KlipioExportDialogDetails? details) {
    final thumbnailPath = details?.thumbnailPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 300,
        height: 400,
        color: Colors.black,
        child: thumbnailPath == null
            ? const Center(
                child: Icon(Icons.movie_outlined,
                    size: 72, color: Color(0xffa3a3a3)),
              )
            : Image.file(File(thumbnailPath), fit: BoxFit.cover),
      ),
    );
  }

  Widget _exportInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: KText(label, style: TextStyle(color: _mutedTextColor)),
          ),
          Expanded(
            child: KText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _exportInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _controlSurfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: _panelBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: _panelBorderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _exportDialogDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _exportInputDecoration(label),
      dropdownColor: _panelColor,
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: KText(item)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _exportStaticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: KText(label, style: TextStyle(color: _mutedTextColor)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _controlSurfaceColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _panelBorderColor),
              ),
              child: KText(value),
            ),
          ),
        ],
      ),
    );
  }

  KlipioExportDialogDetails _buildExportDialogDetails(
      String folder, List<_QueuedExport> jobs,
      {bool? exportTimelineTogether,
      String? titleOverride,
      String? nameOverride}) {
    final timelineTogether = exportTimelineTogether ?? _exportTimelineTogether;
    final outputCount = timelineTogether ? 1 : _groupQueuedExports(jobs).length;
    final duration = jobs.fold<double>(
      0,
      (sum, job) => sum + _queuedExportDuration(job),
    );
    final selectedVideo = _videos.isEmpty
        ? null
        : _videos[_selectedVideoIndex.clamp(0, _videos.length - 1)];
    final typed = _safeName(_nameController.text);
    final name = nameOverride ??
        (timelineTogether
            ? '${typed.isEmpty ? 'timeline_export' : typed}.mp4'
            : outputCount == 1
                ? '${_exportBaseName(jobs.first.video)}.mp4'
                : '$outputCount videos');
    return KlipioExportDialogDetails(
      title: titleOverride ??
          (timelineTogether ? 'Export timeline' : 'Export videos'),
      name: name,
      outputFolder: folder,
      durationSeconds: duration,
      estimatedSize: _estimatedExportSizeLabel(
        duration,
        _exportBitrateKbps,
        outputCount,
      ),
      thumbnailPath: selectedVideo?.thumbnailPath,
    );
  }

  double _queuedExportDuration(_QueuedExport job) {
    final start = job.settings.trimStartSeconds;
    final end = job.settings.trimEndSeconds;
    final duration = end > start
        ? end - start
        : (job.video.durationSeconds ?? 0).clamp(0.0, double.infinity);
    return duration /
        job.settings.speed.clamp(_EditorScreenState._minVideoSpeed,
            _EditorScreenState._maxVideoSpeed);
  }

  double _queuedExportGroupDuration(_QueuedExportGroup group) {
    return group.parts.fold<double>(
      0,
      (sum, part) => sum + _queuedExportDuration(part),
    );
  }

  Map<String, double> _videoPlaybackSpeedsForExport(
    TimelineModel sourceTimeline,
  ) {
    return {
      for (final track in sourceTimeline.videoTracks)
        for (final clip in track.clips)
          clip.mediaPath: _clipTimelineEditFor(clip.mediaPath)
              .speed
              .clamp(_EditorScreenState._minVideoSpeed,
                  _EditorScreenState._maxVideoSpeed)
              .toDouble(),
    };
  }

  List<TextOverlaySettings> _retimeTextOverlaysForExport(
    List<TextOverlaySettings> overlays,
    double requestedSpeed, {
    TimelineModel? timeline,
  }) {
    final speed = requestedSpeed.clamp(
        _EditorScreenState._minVideoSpeed, _EditorScreenState._maxVideoSpeed);
    return [
      for (final overlay in overlays)
        if (timeline?.clipById(overlay.id) != null)
          TitleTimelineResolver.bind(overlay, timeline!)
        else
          overlay.withComposition(
            start: overlay.timelineStart / speed,
            end: overlay.timelineEnd <= 0 ? 0 : overlay.timelineEnd / speed,
            animationDuration: overlay.animationDuration / speed,
            animationOffset: overlay.animationOffset / speed,
            keyframes: [
              for (final frame in overlay.keyframes)
                ClipKeyframe(
                    offset: frame.offset / speed, transform: frame.transform)
            ],
          ),
    ];
  }

  Future<ExportResult> _exportQueuedVideoComposition(
    _QueuedExportGroup group, {
    required ExportCancelToken cancelToken,
    required void Function(double progress, String status) onProgress,
  }) async {
    final storedTimeline = group.video.path == _selectedCompositionPath
        ? _multiTrackTimeline
        : _timelinesByComposition[group.video.path];
    final hasStoredVideo = storedTimeline != null &&
        storedTimeline.videoTracks.any(
          (track) =>
              !track.isMuted &&
              track.clips.any(
                (clip) => !clip.isMuted && clip.duration > 0.001,
              ),
        );
    // Separate-part exports must contain only that requested part. Older
    // project files can also be missing their saved timeline. Build a small
    // canonical timeline for both cases so every export uses the exact same
    // transform/canvas/caption renderer as Program Monitor.
    final useStoredTimeline =
        hasStoredVideo && !group.parts.any((part) => part.partIndex != null);
    final requestedTimeline = useStoredTimeline
        ? storedTimeline
        : _timelineForQueuedExportGroup(group);
    final dimensions = _multiTrackOutputDimensions();
    final playbackSpeed = group.parts.first.settings.speed
        .clamp(_EditorScreenState._minVideoSpeed,
            _EditorScreenState._maxVideoSpeed)
        .toDouble();
    final sourceTimelineDuration =
        _actualMultiTrackExportDuration(requestedTimeline);
    final sourceTimeline = requestedTimeline.copyWith(
      duration: sourceTimelineDuration,
    );
    final renderSnapshot = _programRenderSnapshot(sourceTimeline);
    final playbackSpeeds = renderSnapshot.playbackSpeedsByMediaPath;
    final exportTimeline = renderSnapshot.outputTimeline;
    final timelineDuration = _actualMultiTrackExportDuration(exportTimeline);
    final captionCues = _exportTimelineCaptionCues(
      sourceTimeline,
      outputTimeline: exportTimeline,
      playbackSpeedsByMediaPath: playbackSpeeds,
    );
    final captionSettings = captionCues.isEmpty
        ? null
        : _settings.copyWith(
            automaticCaptions: false,
            speed: 1,
            trimStartSeconds: 0,
            trimEndSeconds: timelineDuration,
            textOverlays: const [],
            captionCues: captionCues,
          );
    return exportMultiTrackTimeline(
      MultiTrackExportJob(
        timeline: exportTimeline.copyWith(duration: timelineDuration),
        outputPath: group.outputPath,
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
        onProgress: onProgress,
      ),
    );
  }

  TimelineModel _timelineForQueuedExportGroup(_QueuedExportGroup group) {
    final videoClips = <ClipModel>[];
    final audioClips = <ClipModel>[];
    var cursor = 0.0;
    for (var index = 0; index < group.parts.length; index++) {
      final part = group.parts[index];
      final settings = part.settings;
      final sourceStart = settings.trimStartSeconds.clamp(0.0, double.infinity);
      final sourceEnd = settings.trimEndSeconds > sourceStart
          ? settings.trimEndSeconds
          : group.video.durationSeconds ?? sourceStart + 0.001;
      final sourceDuration =
          math.max(0.001, sourceEnd - sourceStart).toDouble();
      final clipId = 'queued-${group.video.path.hashCode}-$index';
      final transform = ClipTransform(
        scaleX: settings.scaleX * settings.zoom,
        scaleY: settings.scaleY * settings.zoom,
        positionX: (0.5 + settings.panX * 0.5).clamp(0.0, 1.0).toDouble(),
        positionY: (0.5 + settings.panY * 0.5).clamp(0.0, 1.0).toDouble(),
        flip: settings.flip,
        canvasMode: settings.canvasMode,
        canvasColor: settings.canvasColor,
        canvasPattern: settings.canvasPattern,
        canvasBlur: settings.canvasBlur,
      );
      final videoClip = ClipModel(
        id: clipId,
        mediaPath: group.video.path,
        timelineStart: cursor,
        duration: sourceDuration,
        sourceStart: sourceStart,
        zIndex: 0,
        transform: transform,
      );
      videoClips.add(videoClip);
      if (group.video.hasAudio && settings.originalVolume > 0) {
        audioClips.add(
          videoClip.copyWith(
            id: 'audio-$clipId',
            volume: settings.originalVolume,
            isLinkedAudio: true,
            linkedClipId: clipId,
          ),
        );
      }
      cursor += sourceDuration;
    }
    final tracks = <TrackModel>[
      TrackModel(
        id: 'video-1',
        type: TrackType.video,
        index: 1,
        clips: videoClips,
      ),
      TrackModel(
        id: 'audio-1',
        type: TrackType.audio,
        index: 1,
        clips: audioClips,
      ),
    ];
    return TimelineModel(
      tracks: tracks,
      duration: TimelineModel.calculateDuration(tracks),
    ).normalized();
  }

  double _actualMultiTrackExportDuration([TimelineModel? requestedTimeline]) {
    final timeline = requestedTimeline ?? _multiTrackTimeline;
    var videoEnd = 0.0;
    for (final track in timeline.videoTracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        if (clip.isMuted) continue;
        videoEnd = math.max(videoEnd, clip.timelineEnd);
      }
    }
    if (videoEnd > 0.001) return videoEnd;

    var fallbackEnd = 0.0;
    for (final track in timeline.tracks) {
      if (track.isMuted || track.type == TrackType.video) continue;
      for (final clip in track.clips) {
        if (!clip.isMuted) {
          fallbackEnd = math.max(fallbackEnd, clip.timelineEnd);
        }
      }
    }
    if (fallbackEnd > 0.001) return fallbackEnd;
    return requestedTimeline == null
        ? math.max(timeline.duration, _timelineSequenceDuration())
        : timeline.duration;
  }

  String _estimatedExportSizeLabel(
    double durationSeconds,
    int bitrateKbps,
    int fileCount,
  ) {
    if (durationSeconds <= 0) return 'Calculating...';
    const audioKbps = 192;
    final bytes = durationSeconds * (bitrateKbps + audioKbps) * 1000 / 8;
    final suffix = fileCount > 1 ? ' total estimated' : ' estimated';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB$suffix';
    }
    return '${(bytes / (1024 * 1024)).round()} MB$suffix';
  }

  int get _exportBitrateKbps {
    return switch (_qualityPreset) {
      '4K' => 35000,
      '1080p' => 8000,
      '720p' => 5000,
      '480p' => 2500,
      'Low' => 1200,
      'Custom' => _customBitrateKbps.round(),
      _ => 8000,
    };
  }

  String _safeExportCodec(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'hevc' || 'h265' || 'h.265' => 'hevc',
      _ => 'h264',
    };
  }

  double _safeExportFrameRate(double value) {
    if (value <= 0) return 0;
    const supported = [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0];
    return supported.reduce(
      (a, b) => (value - a).abs() <= (value - b).abs() ? a : b,
    );
  }

  bool get _exportsSeparatePartFiles => _exportSplitPartsAsFiles;
}
