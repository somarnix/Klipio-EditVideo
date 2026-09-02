part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineShowTimelineClipContextMenu on _EditorScreenState {
  Future<void> _showTimelineClipContextMenu(
    String clipId,
    Offset position,
  ) async {
    final result = _multiTrackTimeline.clipById(clipId);
    if (result == null) return;
    _selectedTimelineClipId = clipId;
    final editable = !result.track.isLocked &&
        !LinkedAudioEditGuard.blocks(_multiTrackTimeline, {clipId});
    final canSplit = editable &&
        result.track.type != TrackType.text &&
        !identical(
            _multiTrackTimeline,
            _editInProgramTime(
                _multiTrackTimeline,
                (editor, program) => editor.splitClip(program,
                    clipId: clipId, playhead: _currentProgramSeconds())));
    final canDelete = editable &&
        !identical(_multiTrackTimeline,
            _timelineEditor.deleteClip(_multiTrackTimeline, clipId));
    final canTransition = editable &&
        TransitionEdit.prepare(
                _multiTrackTimeline,
                clipId,
                const ClipTransition(
                    type: ClipTransitionType.dissolve, duration: .5)) !=
            null;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<_TimelineClipAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
            value: _TimelineClipAction.copy,
            child: Text('Copy                         Ctrl+C')),
        PopupMenuItem(
            value: _TimelineClipAction.cut,
            enabled: editable,
            child: const Text('Cut                              Ctrl+X')),
        PopupMenuItem(
          value: _TimelineClipAction.paste,
          enabled: _timelineClipboard != null ||
              _timelineMultiClipboard.isNotEmpty ||
              _textOverlayClipboard != null,
          child: const Text('Paste                          Ctrl+V'),
        ),
        PopupMenuItem(
            value: _TimelineClipAction.duplicate,
            enabled: editable,
            child: const Text('Duplicate                    Ctrl+D')),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: _TimelineClipAction.copyAttributes,
            child: Text('Copy attributes')),
        PopupMenuItem(
          value: _TimelineClipAction.pasteAttributes,
          enabled: editable && _timelineAttributeClipboard != null,
          child: const Text('Paste attributes'),
        ),
        PopupMenuItem(
            value: _TimelineClipAction.split,
            enabled: canSplit,
            child: const Text('Split at playhead          Ctrl+K')),
        PopupMenuItem(
            value: _TimelineClipAction.delete,
            enabled: canDelete,
            child: Text(result.track.id ==
                    _multiTrackTimeline.videoTracks.firstOrNull?.id
                ? 'Ripple delete                 Delete'
                : 'Delete                         Delete')),
        if (result.track.type == TrackType.video) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _TimelineClipAction.effects,
            enabled: editable,
            child: const Text('Clip effects'),
          ),
          PopupMenuItem(
              value: _TimelineClipAction.transitions,
              enabled: canTransition || result.clip.transitionIn != null,
              child: const Text('Add transition')),
          const PopupMenuItem(
              value: _TimelineClipAction.captions,
              child: Text('Generate captions')),
          PopupMenuItem(
              value: _TimelineClipAction.extractAudio,
              enabled: editable &&
                  _multiTrackTimeline.linkedAudioForVideo(clipId) != null,
              child: const Text('Detach audio')),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _TimelineClipAction.deactivate,
          enabled: editable,
          child:
              Text(result.clip.isMuted ? 'Activate clip' : 'Deactivate clip'),
        ),
        const PopupMenuItem(
            value: _TimelineClipAction.details,
            child: Text('Show in Inspector')),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _TimelineClipAction.copy:
        _copySelectedTimelineClip();
      case _TimelineClipAction.cut:
        _cutSelectedTimelineClip();
      case _TimelineClipAction.paste:
        _pasteTimelineClip();
      case _TimelineClipAction.duplicate:
        _duplicateSelectedTimelineClip();
      case _TimelineClipAction.copyAttributes:
        _copySelectedClipAttributes();
      case _TimelineClipAction.pasteAttributes:
        _pasteSelectedClipAttributes();
      case _TimelineClipAction.split:
        _splitClipAtPlayhead();
      case _TimelineClipAction.delete:
        _deleteClipPartAtPlayhead();
      case _TimelineClipAction.captions:
        _openLeftWorkspaceTab(LeftWorkspaceTab.captions);
      case _TimelineClipAction.extractAudio:
        _extractSelectedClipAudio();
      case _TimelineClipAction.effects:
        _openEffectsWorkspace(_EffectsWorkspaceCategory.effects);
      case _TimelineClipAction.transitions:
        _openEffectsWorkspace(_EffectsWorkspaceCategory.transitions);
      case _TimelineClipAction.deactivate:
        _toggleSelectedTimelineClipActive();
      case _TimelineClipAction.details:
        unawaited(_selectMultiTrackClip(clipId));
    }
  }

  void _addTimelineMarker() {
    final value = _currentProgramSeconds();
    if (_timelineMarkers.any((marker) => (marker - value).abs() < 0.03)) {
      _showMessage('A marker already exists at this position.');
      return;
    }
    _recordEditorHistory('marker-add');
    _updateEditor(() {
      _timelineMarkers.add(value);
      _timelineMarkers.sort();
      _status = 'Marker added at ${_formatDuration(value)}';
    });
    unawaited(_autosaveProject());
  }

  double _timelinePlayheadOffset() {
    if (_hasAuthoritativeProgramTimeline) {
      return (_currentProgramSeconds() * _timelinePixelsPerSecond())
          .clamp(0.0, _timelineContentWidth())
          .toDouble();
    }
    var offset = 0.0;
    for (final item in _visibleTimelineVideos()) {
      final index = item.index;
      final video = item.video;
      final parts = _clipTimelineEditFor(video.path).timelineParts(
        video.durationSeconds,
      );
      if (index < _selectedVideoIndex) {
        offset += parts.fold<double>(
          0,
          (sum, part) => sum + _timelinePartWidth(part),
        );
        continue;
      }
      if (index == _selectedVideoIndex) {
        final position = _currentPlayheadSeconds();
        if (parts.isEmpty) return offset;
        for (var partIndex = 0; partIndex < parts.length; partIndex++) {
          final part = parts[partIndex];
          final width = _timelinePartWidth(part);
          if (position < part.start - 0.001 || position > part.end + 0.001) {
            offset += width;
            continue;
          }
          final duration = (part.end - part.start).abs() <= 0.001
              ? 1.0
              : part.end - part.start;
          final localProgress =
              ((position - part.start) / duration).clamp(0.0, 1.0).toDouble();
          return offset + width * localProgress;
        }
        return offset.clamp(0.0, _timelineContentWidth());
      }
    }
    return offset;
  }

  double _timelineSequenceDuration() {
    if (_multiTrackTimeline.duration > 0.001) {
      return _programEditingTimeline.duration;
    }
    return _visibleTimelineVideos().fold<double>(0, (sum, item) {
      final video = item.video;
      final parts = _clipTimelineEditFor(video.path).timelineParts(
        video.durationSeconds,
      );
      return sum +
          parts.fold<double>(
            0,
            (partSum, part) => partSum + (part.end - part.start).abs(),
          );
    });
  }

  Future<void> _seekTimelineAt(double timelineX) async {
    if (_videos.isEmpty) return;
    if (_hasAuthoritativeProgramTimeline) {
      final timelineSeconds = timelineX.clamp(0.0, double.infinity).toDouble() /
          _timelinePixelsPerSecond();
      _requestMultiTrackTimelineSeek(timelineSeconds);
      return;
    }
    final target = _timelinePositionForOffset(timelineX);
    if (target == null) return;
    final wasPlaying = _previewController?.value.isPlaying == true;
    if (target.videoIndex != _selectedVideoIndex) {
      await _selectVideo(target.videoIndex);
    }
    final controller = _previewController;
    if (controller != null && controller.value.isInitialized) {
      await controller.seekTo(
        Duration(milliseconds: (target.seconds * 1000).round()),
      );
      if (wasPlaying) {
        await controller.play();
      }
    }
    if (mounted) _updateEditor(() {});
  }

  ({int videoIndex, double seconds})? _timelinePositionForOffset(double x) {
    var remaining = x.clamp(0.0, double.infinity).toDouble();
    final visibleVideos = _visibleTimelineVideos();
    for (final item in visibleVideos) {
      final index = item.index;
      final video = item.video;
      final parts = _clipTimelineEditFor(video.path).timelineParts(
        video.durationSeconds,
      );
      for (final part in parts) {
        final width = _timelinePartWidth(part);
        if (remaining <= width) {
          final duration = (part.end - part.start).abs() <= 0.001
              ? 1.0
              : part.end - part.start;
          final progress = (remaining / width).clamp(0.0, 1.0).toDouble();
          return (videoIndex: index, seconds: part.start + duration * progress);
        }
        remaining -= width;
      }
    }
    final lastIndex =
        visibleVideos.isEmpty ? _videos.length - 1 : visibleVideos.last.index;
    return (
      videoIndex: lastIndex,
      seconds: _videos[lastIndex].durationSeconds ?? 0,
    );
  }

  ({int videoIndex, double seconds})? _timelinePositionForSequenceSeconds(
    double seconds,
  ) {
    if (_videos.isEmpty) return null;
    var remaining = seconds.clamp(0.0, double.infinity).toDouble();
    final visibleVideos = _visibleTimelineVideos();
    for (final item in visibleVideos) {
      final index = item.index;
      final video = item.video;
      final parts = _clipTimelineEditFor(video.path).timelineParts(
        video.durationSeconds,
      );
      for (final part in parts) {
        final duration = (part.end - part.start).abs();
        if (remaining <= duration) {
          return (
            videoIndex: index,
            seconds: part.start + remaining.clamp(0.0, duration),
          );
        }
        remaining -= duration;
      }
    }
    for (final item in visibleVideos.reversed) {
      final index = item.index;
      final video = item.video;
      final parts = _clipTimelineEditFor(video.path).timelineParts(
        video.durationSeconds,
      );
      if (parts.isNotEmpty) {
        return (videoIndex: index, seconds: parts.last.end);
      }
    }
    final lastIndex =
        visibleVideos.isEmpty ? _videos.length - 1 : visibleVideos.last.index;
    return (
      videoIndex: lastIndex,
      seconds: _videos[lastIndex].durationSeconds ?? 0,
    );
  }

  ({
    int videoIndex,
    double? sourceSeconds,
    String? clipId,
    double timelineSeconds,
    bool isGap,
  })? _programTargetForTimelineSeconds(
    double seconds, {
    ProgramRenderSnapshot? renderSnapshot,
  }) {
    if (_videos.isEmpty) return null;
    final playhead = seconds.clamp(0.0, double.infinity).toDouble();
    if (_hasAuthoritativeProgramTimeline) {
      final snapshot =
          renderSnapshot ?? _programRenderSnapshot(_multiTrackTimeline);
      final resolved = ProgramTimelineMapper.resolveMonitor(
        snapshot.outputTimeline,
        playhead,
        frameRate: _projectFrameRate,
        playbackSpeedsByMediaPath: snapshot.playbackSpeedsByMediaPath,
      );
      final clip = resolved.clip;
      if (clip == null) {
        return (
          videoIndex: _selectedVideoIndex.clamp(0, _videos.length - 1).toInt(),
          sourceSeconds: null,
          clipId: null,
          timelineSeconds: resolved.timelineSeconds,
          isGap: true,
        );
      }
      final videoIndex =
          _videos.indexWhere((video) => video.path == clip.mediaPath);
      if (videoIndex >= 0) {
        return (
          videoIndex: videoIndex,
          sourceSeconds: resolved.sourceSeconds,
          clipId: clip.id,
          timelineSeconds: resolved.timelineSeconds,
          isGap: false,
        );
      }
      return (
        videoIndex: _selectedVideoIndex.clamp(0, _videos.length - 1).toInt(),
        sourceSeconds: null,
        clipId: null,
        timelineSeconds: resolved.timelineSeconds,
        isGap: true,
      );
    }

    final legacy = _timelinePositionForSequenceSeconds(playhead);
    if (legacy == null) return null;
    return (
      videoIndex: legacy.videoIndex,
      sourceSeconds: legacy.seconds,
      clipId: null,
      timelineSeconds: playhead,
      isGap: false,
    );
  }

  double _currentPlayheadSeconds() {
    final controller = _previewController;
    if (controller == null || !controller.value.isInitialized) {
      return 0;
    }
    return controller.value.position.inMilliseconds / 1000;
  }

  Future<void> _nudgePlayhead(double deltaSeconds) async {
    if (_videos.isEmpty) return;
    final duration = _programPlaybackDurationSeconds();
    final target = (_currentProgramSeconds() + deltaSeconds)
        .clamp(0.0, math.max(0.0, duration))
        .toDouble();
    _requestMultiTrackTimelineSeek(target);
  }

  ({TrackModel track, ClipModel clip})? _editableClipAtProgramPlayhead(
    double playhead,
  ) {
    final program = _programEditingTimeline;
    bool contains(ClipModel clip) =>
        playhead > clip.timelineStart + 0.04 &&
        playhead < clip.timelineEnd - 0.04;

    final selectedId = _selectedTimelineClipId;
    if (selectedId != null) {
      final selected = program.clipById(selectedId);
      if (selected != null &&
          selected.track.type != TrackType.text &&
          !selected.track.isLocked &&
          contains(selected.clip)) {
        return selected;
      }
    }

    // When selection is stale or empty, edit the visible unlocked video under
    // the blue program playhead. Higher video layers win, matching preview.
    for (final track in program.videoTracks.reversed) {
      if (track.isLocked) continue;
      for (final clip in track.clips.reversed) {
        if (contains(clip)) return (track: track, clip: clip);
      }
    }
    for (final track in program.audioTracks.reversed) {
      if (track.isLocked) continue;
      for (final clip in track.clips.reversed) {
        if (!clip.isLinkedAudio && contains(clip)) {
          return (track: track, clip: clip);
        }
      }
    }
    return null;
  }

  void _cutClipStartAtPlayhead() {
    if (_videos.isEmpty) return;
    final playhead = _currentProgramSeconds();
    final selected = _editableClipAtProgramPlayhead(playhead);
    if (selected != null) {
      final keptId = '${selected.clip.id}-b-${(playhead * 1000).round()}';
      _recordEditorHistory('timeline-trim-start');
      _updateEditor(() {
        final next = _editInProgramTime(
            _multiTrackTimeline,
            (editor, program) => editor.keepClipAfterPlayhead(
                  program,
                  clipId: selected.clip.id,
                  playhead: playhead,
                ));
        _applyTimelineModelUpdate(next);
        _selectedTimelineClipId = next.clipById(keptId) == null ? null : keptId;
        _selectedTimelineClipIds
          ..clear()
          ..addAll(_selectedTimelineClipId == null
              ? const <String>[]
              : [_selectedTimelineClipId!]);
        if (selected.track.type == TrackType.video) {
          _programTimelineClipId = _selectedTimelineClipId;
        }
        _status =
            'Removed ${_formatDuration(playhead - selected.clip.timelineStart)} before the playhead';
      });
      unawaited(_autosaveProject());
      return;
    }
    if (_hasAuthoritativeProgramTimeline) {
      _showMessage('Move the blue playhead inside an unlocked video clip.');
      return;
    }
    if (!_ensureTimelineClipUnlocked(
      _selectedTimelineClipId,
      action: 'trimming this clip',
    )) {
      return;
    }
    final seconds = _currentPlayheadSeconds();
    final video = _videos[_selectedVideoIndex];
    final current = _clipTimelineEditFor(video.path);
    final duration = video.durationSeconds ?? 0;
    final end = current.trimEndSeconds > current.trimStartSeconds
        ? current.trimEndSeconds
        : duration;
    if (end > 0 && seconds >= end - 0.05) {
      _showMessage('Move the playhead before the current clip end.');
      return;
    }
    _setSelectedClipTimelineEdit(
      current.copyWith(trimStartSeconds: seconds),
    );
    _updateEditor(
        () => _status = 'Trimmed start to ${_formatDuration(seconds)}');
  }

  void _cutClipEndAtPlayhead() {
    if (_videos.isEmpty) return;
    final playhead = _currentProgramSeconds();
    final selected = _editableClipAtProgramPlayhead(playhead);
    if (selected != null) {
      final keptId = '${selected.clip.id}-a-${(playhead * 1000).round()}';
      _recordEditorHistory('timeline-trim-end');
      _updateEditor(() {
        final next = _editInProgramTime(
            _multiTrackTimeline,
            (editor, program) => editor.keepClipBeforePlayhead(
                  program,
                  clipId: selected.clip.id,
                  playhead: playhead,
                ));
        _applyTimelineModelUpdate(next);
        _selectedTimelineClipId = next.clipById(keptId) == null ? null : keptId;
        _selectedTimelineClipIds
          ..clear()
          ..addAll(_selectedTimelineClipId == null
              ? const <String>[]
              : [_selectedTimelineClipId!]);
        if (selected.track.type == TrackType.video) {
          _programTimelineClipId = _selectedTimelineClipId;
        }
        _status =
            'Removed ${_formatDuration(selected.clip.timelineEnd - playhead)} after the playhead';
      });
      unawaited(_autosaveProject());
      return;
    }
    if (_hasAuthoritativeProgramTimeline) {
      _showMessage('Move the blue playhead inside an unlocked video clip.');
      return;
    }
    if (!_ensureTimelineClipUnlocked(
      _selectedTimelineClipId,
      action: 'trimming this clip',
    )) {
      return;
    }
    final seconds = _currentPlayheadSeconds();
    final current = _clipTimelineEditFor(_videos[_selectedVideoIndex].path);
    if (seconds <= current.trimStartSeconds + 0.05) {
      _showMessage('Move the playhead after the current clip start.');
      return;
    }
    _setSelectedClipTimelineEdit(
      current.copyWith(trimEndSeconds: seconds),
    );
    _updateEditor(() => _status = 'Trimmed end to ${_formatDuration(seconds)}');
  }

  void _splitClipAtPlayhead() {
    if (_videos.isEmpty) return;
    final selectedIds = _effectiveSelectedTimelineClipIds;
    if (selectedIds.length > 1) {
      final playhead = _currentProgramSeconds();
      var next = _multiTrackTimeline;
      final nextSelected = <String>{};
      var splitCount = 0;
      for (final id in selectedIds) {
        final result = _programRenderSnapshot(next).outputTimeline.clipById(id);
        if (result == null ||
            result.track.type == TrackType.text ||
            result.track.isLocked ||
            playhead <= result.clip.timelineStart + 0.04 ||
            playhead >= result.clip.timelineEnd - 0.04) {
          nextSelected.add(id);
          continue;
        }
        next = _editInProgramTime(
            next,
            (editor, program) => editor.splitClip(
                  program,
                  clipId: id,
                  playhead: playhead,
                ));
        nextSelected.add('$id-a-${(playhead * 1000).round()}');
        splitCount++;
      }
      if (splitCount == 0) {
        _showMessage('Move the playhead inside the selected unlocked clips.');
        return;
      }
      _recordEditorHistory('timeline-multi-split');
      _updateEditor(() {
        _multiTrackTimeline = next;
        _selectedTimelineClipIds
          ..clear()
          ..addAll(nextSelected.where(
            (id) => next.clipById(id) != null,
          ));
        _selectedTimelineClipId = _selectedTimelineClipIds.isEmpty
            ? null
            : _selectedTimelineClipIds.last;
        _status = '$splitCount clips split at ${_formatDuration(playhead)}';
      });
      unawaited(_autosaveProject());
      return;
    }
    final playhead = _currentProgramSeconds();
    final selectedTimelineClip = _editableClipAtProgramPlayhead(playhead);
    if (selectedTimelineClip?.track.type == TrackType.text) {
      _showMessage(
          'Resize text timing with the handles on its timeline block.');
      return;
    }
    if (selectedTimelineClip != null) {
      if (!_ensureTimelineClipUnlocked(
        selectedTimelineClip.clip.id,
        action: 'splitting this clip',
      )) {
        return;
      }
      final next = _editInProgramTime(
          _multiTrackTimeline,
          (editor, program) => editor.splitClip(
                program,
                clipId: selectedTimelineClip.clip.id,
                playhead: playhead,
              ));
      if (identical(next, _multiTrackTimeline)) {
        _showMessage('Move the playhead inside the selected timeline clip.');
        return;
      }
      _recordEditorHistory('timeline-split');
      _updateEditor(() {
        _multiTrackTimeline = next;
        _selectedTimelineClipId =
            '${selectedTimelineClip.clip.id}-a-${(playhead * 1000).round()}';
        if (selectedTimelineClip.track.type == TrackType.video) {
          _programTimelineClipId = _selectedTimelineClipId;
        }
        _status = 'Clip split at ${_formatDuration(playhead)}';
      });
      unawaited(_autosaveProject());
      return;
    }
    if (_hasAuthoritativeProgramTimeline) {
      _showMessage('Move the blue playhead inside an unlocked video clip.');
      return;
    }
    final seconds = _currentPlayheadSeconds();
    if (seconds <= 0.05) return;
    final video = _videos[_selectedVideoIndex];
    final duration = video.durationSeconds ?? 0;
    if (duration > 0 && seconds >= duration - 0.05) return;
    final current = _clipTimelineEditFor(video.path);
    if (current.timelinePartAt(seconds, video.durationSeconds) == null) {
      _showMessage('Move the playhead onto a visible clip before splitting.');
      return;
    }
    if (current.splitPoints.any((point) => (point - seconds).abs() < 0.03)) {
      _showMessage('A split already exists at this position.');
      return;
    }
    final points = {...current.splitPoints, seconds}.toList()..sort();
    _setSelectedClipTimelineEdit(current.copyWith(splitPoints: points));
    _updateEditor(() => _status = 'Split at ${_formatDuration(seconds)}');
  }
}
