part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineTimelineTracks on _EditorScreenState {
  Widget _timelineTracks({required bool compact}) {
    if (_multiTrackTimeline.tracks.isNotEmpty) {
      final thumbnailPaths = {
        for (final video in _videos) video.path: video.timelineThumbnailPaths,
      };
      final mediaWithSourceAudio = {
        for (final video in _videos)
          if (video.hasAudio) video.path,
      };
      final clipLabels = {
        for (final overlay in _previewTextOverlays())
          if (overlay.id.isNotEmpty) overlay.id: overlay.text,
      };
      return ValueListenableBuilder<double>(
        valueListenable: _timelineScrollOffsetListenable,
        builder: (context, scrollOffset, _) =>
            ValueListenableBuilder<TimelineModel?>(
          valueListenable: _timelineEditPreviewModel,
          builder: (context, previewModel, _) {
            final displayModel = previewModel ?? _programEditingTimeline;
            final pixelsPerSecond = _timelinePixelsPerSecond();
            final labelWidth = compact ? 124.0 : 132.0;
            final visibleStart = math.max(
              0.0,
              (scrollOffset - labelWidth) / pixelsPerSecond,
            );
            final visibleEnd = visibleStart +
                math.max(1.0, _timelineViewportWidth) / pixelsPerSecond;
            return DynamicTimelineView(
              model: displayModel,
              editor: _programTimelineEditor,
              pixelsPerSecond: pixelsPerSecond,
              playheadSeconds: _currentProgramSeconds(),
              playheadOverride: _timelineScrubController.playhead,
              visibleStartSeconds: visibleStart,
              visibleEndSeconds: visibleEnd,
              selectedClipId: _selectedTimelineClipId,
              selectedClipIds: _effectiveSelectedTimelineClipIds,
              markers: _timelineMarkers,
              compact: compact,
              trackHeights: _timelineTrackHeights,
              skimmerSeconds: _timelineSkimmerSeconds,
              gestureFeedback: _timelineGestureFeedback,
              onNavigationSignal: _onTimelineNavigationSignal,
              onTransitionSelected: (id) =>
                  unawaited(_selectTimelineTransition(id)),
              selectedTransitionClipId:
                  _editorSelection.kind == EditorSelectionKind.transition
                      ? _editorSelection.id
                      : null,
              thumbnailPaths: thumbnailPaths,
              sourceDurations: {
                for (final video in _videos)
                  if (video.durationSeconds != null)
                    video.path: video.durationSeconds!
              },
              audioWaveformPeaks: _audioWaveformPeaks,
              waveformPeaksPerSecondByMedia: _audioWaveformPeakRates,
              marqueeController: _timelineMarqueeController,
              onMarqueeSelection: (clipIds, additive) => unawaited(
                _selectTimelineMarquee(clipIds, additive: additive),
              ),
              mediaWithSourceAudio: mediaWithSourceAudio,
              clipLabels: clipLabels,
              captionCues: _dynamicTimelineCaptionCues(displayModel),
              selectedCaptionId:
                  _editorSelection.kind == EditorSelectionKind.captionCue
                      ? _editorSelection.id
                      : null,
              selectedCaptionIds: _effectiveSelectedCaptionIds,
              onCaptionSelected: (id) =>
                  unawaited(_selectDynamicTimelineCaption(id)),
              onCaptionSelectionChanged: (id, toggle, range) => unawaited(
                _selectDynamicTimelineCaption(
                  id,
                  toggle: toggle,
                  range: range,
                ),
              ),
              captionHidden: _captionTrackHidden,
              captionLocked: _captionTrackLocked,
              onCaptionVisibilityChanged: () {
                _updateEditor(() => _captionTrackHidden = !_captionTrackHidden);
                unawaited(_autosaveProject());
              },
              onCaptionLockChanged: () {
                _updateEditor(() => _captionTrackLocked = !_captionTrackLocked);
                unawaited(_autosaveProject());
              },
              onCaptionDeleteRequested: () =>
                  unawaited(_deleteCaptionTimelineTrack()),
              onTrackDeleteRequested: (trackId) =>
                  unawaited(_deleteTimelineTrack(trackId)),
              musicPath: _musicPath,
              musicMuted: _musicTrackMuted,
              musicLocked: _musicTrackLocked,
              onMusicMuteChanged: () {
                _updateEditor(() => _musicTrackMuted = !_musicTrackMuted);
                if (_musicTrackMuted) unawaited(_pauseMusicPreview());
                unawaited(_autosaveProject());
              },
              onMusicLockChanged: () {
                _updateEditor(() => _musicTrackLocked = !_musicTrackLocked);
                unawaited(_autosaveProject());
              },
              onMusicDeleteRequested: () =>
                  unawaited(_deleteMusicTimelineTrack()),
              musicSelected: _musicTimelineSelected,
              onMusicSelected: (id, toggle, range) => _selectTimelineMusic(
                toggle: toggle,
              ),
              onSeek: _requestMultiTrackTimelineSeek,
              onScrubStart: _beginMultiTrackTimelineScrub,
              onScrubUpdate: _updateMultiTrackTimelineScrub,
              onScrubEnd: _endMultiTrackTimelineScrub,
              onClipSelected: (clipId) =>
                  unawaited(_selectMultiTrackClip(clipId)),
              onClipSelectionChanged: (clipId, toggle, range) => unawaited(
                _selectMultiTrackClip(
                  clipId,
                  toggle: toggle,
                  range: range,
                ),
              ),
              onClipContextMenu: (clipId, position) =>
                  unawaited(_showTimelineClipContextMenu(clipId, position)),
              onMediaDropped: _dropProjectMediaOnTimeline,
              onTrackHeightChanged: (trackId, height) {
                _updateEditor(() => _timelineTrackHeights[trackId] = height);
                _scheduleWorkspaceMemorySave();
              },
              onModelPreviewChanged: (model) =>
                  _timelineEditPreviewModel.value = model,
              onModelPreviewCommitted: _commitTimelineEditPreview,
              onModelChanged: (model) {
                if (identical(model, displayModel)) return;
                _commitTimelineModelChange(
                    _sourceTimelineFromProgramEdit(model));
              },
            );
          },
        ),
      );
    }
    final hasCaptionTrack =
        _automaticCaptions || _captionCuesByVideo.isNotEmpty;
    final labels = compact
        ? [if (hasCaptionTrack) 'T1', 'V1', 'A1']
        : [
            if (hasCaptionTrack) 'T1',
            'V2',
            'V1',
            'A1',
            if (_showExtractedAudioTrack) 'A2',
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = compact ? 52.0 : 72.0;
        final maxHeight = constraints.maxHeight.clamp(1.0, 1000.0).toDouble();
        final rulerHeight =
            (maxHeight * 0.16).clamp(12.0, compact ? 20.0 : 26.0);
        const verticalPadding = 4.0;
        final availableHeight =
            (constraints.maxHeight - rulerHeight - verticalPadding)
                .clamp(1.0, 1000.0);
        final clipHeight = (availableHeight / labels.length).toDouble();
        final labelFontSize = clipHeight < 24 ? 10.0 : 12.0;
        final trackMargin = clipHeight < 22 ? 1.0 : 2.0;
        final playheadX = labelWidth + _timelinePlayheadOffset();
        final timelineWidth = constraints.maxWidth - labelWidth;
        return Padding(
          padding: EdgeInsets.fromLTRB(compact ? 2 : 4, 2, 4, 2),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) => _seekTimelineAt(
              details.localPosition.dx - labelWidth,
            ),
            onHorizontalDragUpdate: (details) => _seekTimelineAt(
              details.localPosition.dx - labelWidth,
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Column(
                  children: [
                    SizedBox(
                      height: rulerHeight,
                      child: Row(
                        children: [
                          SizedBox(width: labelWidth),
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) => _seekTimelineAt(
                                  details.localPosition.dx,
                                ),
                                onHorizontalDragStart: (details) =>
                                    _seekTimelineAt(
                                  details.localPosition.dx,
                                ),
                                onHorizontalDragUpdate: (details) =>
                                    _seekTimelineAt(
                                  details.localPosition.dx,
                                ),
                                child: _timelineRuler(
                                  width: timelineWidth,
                                  compact: compact,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final label in labels)
                      SizedBox(
                        height: clipHeight,
                        child: Row(
                          children: [
                            SizedBox(
                              width: labelWidth,
                              child: _timelineTrackLabel(
                                label,
                                fontSize: labelFontSize,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                margin: EdgeInsets.only(bottom: trackMargin),
                                decoration: BoxDecoration(
                                  color: _isLightUi
                                      ? const Color(0xfff7f7f8)
                                      : const Color(0xff171719),
                                  border: Border(
                                    bottom:
                                        BorderSide(color: _panelBorderColor),
                                  ),
                                ),
                                child: label == 'T1'
                                    ? _timelineCaptionClips()
                                    : label == 'V1'
                                        ? _timelineVideoClips()
                                        : label == 'A1'
                                            ? _timelineAudioClips()
                                            : label == 'A2'
                                                ? _timelineAudioClips(
                                                    extracted: true,
                                                  )
                                                : const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Positioned(
                  left: playheadX - 5,
                  top: rulerHeight,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) => _seekTimelineAt(
                        details.localPosition.dx + playheadX - labelWidth,
                      ),
                      child: const SizedBox(width: 12),
                    ),
                  ),
                ),
                Positioned(
                  left: playheadX,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 2,
                      color: const Color(0xff3b82f6),
                    ),
                  ),
                ),
                Positioned(
                  left: playheadX - 5,
                  top: rulerHeight - 2,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(12, 9),
                      painter: _PlayheadHandlePainter(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Set<String> get _effectiveSelectedTimelineClipIds {
    final primary = _selectedTimelineClipId;
    if (_selectedTimelineClipIds.isEmpty) {
      return primary == null ? const {} : {primary};
    }
    if (primary == null || _selectedTimelineClipIds.contains(primary)) {
      return Set.unmodifiable(_selectedTimelineClipIds);
    }
    return {primary};
  }

  Set<String> get _selectedVideoTimelineClipIds => {
        for (final id in _effectiveSelectedTimelineClipIds)
          if (_multiTrackTimeline.clipById(id)?.track.type == TrackType.video)
            id,
      };

  void _setSelectedTimelineClipsSpeed(double value) {
    final selectedIds = _selectedVideoTimelineClipIds;
    final speed = value
        .clamp(_EditorScreenState._minVideoSpeed,
            _EditorScreenState._maxVideoSpeed)
        .toDouble();
    final editable = <({String id, String mediaPath})>[];
    for (final id in selectedIds) {
      final result = _multiTrackTimeline.clipById(id);
      if (result != null && !result.track.isLocked) {
        editable.add((id: id, mediaPath: result.clip.mediaPath));
      }
    }
    if (editable.isEmpty) {
      _showMessage('Select at least one unlocked video clip.');
      return;
    }
    final migrated = ClipSpeedEdit.migrate(_multiTrackTimeline,
        _videoPlaybackSpeedsForExport(_multiTrackTimeline));
    final next = ClipSpeedEdit.apply(
        migrated, editable.map((target) => target.id).toSet(), speed);
    if (identical(next, migrated)) {
      _showMessage('Unlock the selected video and its linked audio first.');
      return;
    }
    _recordEditorHistory('timeline-batch-speed');
    _updateEditor(() {
      _multiTrackTimeline = next;
      _speed = speed;
      _status =
          'Speed ${speed}x applied to ${editable.length} selected clip${editable.length == 1 ? '' : 's'}';
    });
    final controller = _previewController;
    if (controller != null &&
        controller.value.isInitialized &&
        editable.any((target) => target.id == _programTimelineClipId)) {
      unawaited(controller.setPlaybackSpeed(speed));
    }
    unawaited(_autosaveProject());
  }

  void _syncSettingsToTimelineSelection() {
    final selectedIds = _selectedVideoTimelineClipIds;
    final sourceId = selectedIds.contains(_selectedTimelineClipId)
        ? _selectedTimelineClipId
        : (selectedIds.isEmpty ? null : selectedIds.last);
    final source =
        sourceId == null ? null : _multiTrackTimeline.clipById(sourceId);
    if (source == null || source.track.isLocked) {
      _showMessage('Select an unlocked source video clip first.');
      return;
    }
    final targets = <String>{
      for (final id in selectedIds)
        if (_multiTrackTimeline.clipById(id)?.track.isLocked == false) id,
    };
    if (targets.isEmpty) return;
    final sourceEdit = _clipTimelineEditFor(source.clip.mediaPath);
    final linkedAudio = _multiTrackTimeline.linkedAudioForVideo(source.clip.id);
    final settings = VideoRenderSettings(
      mediaPath: source.clip.mediaPath,
      speed: sourceEdit.speed,
      originalVolume: linkedAudio?.volume ?? sourceEdit.originalVolume,
      transform: source.clip.transform,
    );
    _recordEditorHistory('timeline-sync-settings');
    _updateEditor(() {
      final next = applyVideoRenderSettingsToClipIds(
        timeline: _multiTrackTimeline,
        settings: settings,
        targetClipIds: targets,
      );
      _applyTimelineModelUpdate(next);
      for (final id in targets) {
        final target = next.clipById(id);
        if (target == null) continue;
        final transform = target.clip.transform;
        final current = _clipTimelineEditFor(target.clip.mediaPath);
        _clipTimelineEdits[target.clip.mediaPath] = current.copyWith(
          speed: settings.speed,
          originalVolume: settings.originalVolume,
          flip: transform.flip,
          scaleX: transform.scaleX,
          scaleY: transform.scaleY,
          zoom: 1,
          panX: ((transform.positionX - 0.5) * 2).clamp(-1, 1).toDouble(),
          panY: ((transform.positionY - 0.5) * 2).clamp(-1, 1).toDouble(),
        );
        _clipTransformOverrides.add(target.clip.mediaPath);
      }
      _storeActiveCompositionTimeline();
      _loadTimelineClipTransformIntoInspector(source.clip);
      _status =
          'Settings synced from the active clip to ${targets.length} selected clip${targets.length == 1 ? '' : 's'}';
    });
    unawaited(_autosaveProject());
  }

  int get _timelineSelectionCount =>
      _effectiveSelectedTimelineClipIds.length +
      _effectiveSelectedCaptionIds.length +
      (_musicTimelineSelected ? 1 : 0);

  Set<String> _timelineClipSelectionFor(
    String id, {
    required bool toggle,
    required bool range,
  }) {
    final current = {..._effectiveSelectedTimelineClipIds};
    if (range && _selectedTimelineClipId != null) {
      final clicked = _multiTrackTimeline.clipById(id);
      final anchor = _multiTrackTimeline.clipById(_selectedTimelineClipId!);
      if (clicked != null && anchor?.track.id == clicked.track.id) {
        final ordered = [...clicked.track.clips]
          ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
        final first = ordered.indexWhere((clip) => clip.id == anchor!.clip.id);
        final last = ordered.indexWhere((clip) => clip.id == id);
        if (first >= 0 && last >= 0) {
          final low = math.min(first, last);
          final high = math.max(first, last);
          return {
            if (toggle) ...current,
            for (var index = low; index <= high; index++) ordered[index].id,
          };
        }
      }
    }
    if (toggle) {
      if (!current.add(id)) current.remove(id);
      return current;
    }
    return {id};
  }

  Future<void> _deleteTimelineTrack(String trackId) async {
    final track = _multiTrackTimeline.trackById(trackId);
    if (track == null) return;
    if (track.isLocked) {
      _showMessage('Unlock ${track.label} before deleting it.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: KText('Delete ${track.label} track?'),
        content: KText(
          track.clips.isEmpty
              ? 'This empty track will be removed.'
              : 'This removes ${track.clips.length} clip${track.clips.length == 1 ? '' : 's'} from the timeline. Original media files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const KText('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const KText('Delete track'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _recordEditorHistory('track-delete');
    final deletedVideoIds = track.type == TrackType.video
        ? track.clips.map((clip) => clip.id).toSet()
        : const <String>{};
    final deletedTextIds = track.type == TrackType.text
        ? track.clips.expand((clip) => [clip.id, clip.mediaPath]).toSet()
        : const <String>{};
    var tracks = <TrackModel>[
      for (final item in _multiTrackTimeline.tracks)
        if (item.id != trackId)
          item.type == TrackType.audio && deletedVideoIds.isNotEmpty
              ? item.copyWith(
                  clips: item.clips
                      .where(
                        (clip) =>
                            !clip.isLinkedAudio ||
                            !deletedVideoIds.contains(clip.linkedClipId),
                      )
                      .toList(),
                )
              : item,
    ];
    if (!tracks.any((item) => item.type == track.type) &&
        track.type != TrackType.text) {
      tracks = [
        ...tracks,
        TrackModel(
          id: '${track.type.name}-1',
          type: track.type,
          index: 1,
        ),
      ];
    }
    _updateEditor(() {
      if (deletedTextIds.isNotEmpty) {
        _textOverlays.removeWhere(
          (overlay) => deletedTextIds.contains(overlay.id),
        );
        if (_textOverlays.isEmpty) {
          _textOverlays.add(const _TextOverlayDraft());
        }
      }
      _applyTimelineModelUpdate(
        TimelineModel(
          tracks: tracks,
          duration: TimelineModel.calculateDuration(tracks),
        ).normalized(),
      );
      _selectedTimelineClipIds.removeWhere(
        (id) => _multiTrackTimeline.clipById(id) == null,
      );
      _selectedTimelineClipId = null;
      _editorSelection = _videos.isEmpty
          ? const EditorSelection.none()
          : EditorSelection.video(_videos[_selectedVideoIndex].path);
      _status = '${track.label} track deleted';
    });
    unawaited(_autosaveProject());
  }

  Future<void> _deleteMusicTimelineTrack() async {
    if (_musicPath == null) return;
    if (_musicTrackLocked) {
      _showMessage('Unlock M1 before deleting the music track.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const KText('Delete music track?'),
        content: const KText(
          'The background music is removed from the timeline and export. The original audio file is not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const KText('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const KText('Delete music'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _stopMusicPreview();
    if (!mounted) return;
    _recordEditorHistory('music-track-delete');
    _updateEditor(() {
      _musicPath = null;
      _musicTrackMuted = false;
      _musicTrackLocked = false;
      _musicTimelineSelected = false;
      if (_editorSelection.id == 'music-track') {
        _editorSelection = const EditorSelection.none();
      }
      _status = 'Music track deleted';
    });
    unawaited(_autosaveProject());
  }
}
