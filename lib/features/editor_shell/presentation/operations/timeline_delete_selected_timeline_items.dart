part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineDeleteSelectedTimelineItems on _EditorScreenState {
  bool _deleteSelectedTimelineItems() {
    if (_editorSelection.kind == EditorSelectionKind.transition) {
      _removeClipTransition();
      return true;
    }
    final captionIds = _effectiveSelectedCaptionIds;
    if (_editorSelection.kind == EditorSelectionKind.captionCue &&
        captionIds.isNotEmpty) {
      if (_captionTrackLocked) {
        _showMessage('Unlock T1 before deleting captions.');
        return true;
      }
      _recordEditorHistory('caption-multi-delete');
      final removals = <String, List<int>>{};
      for (final id in captionIds) {
        if (!id.startsWith('caption:')) continue;
        final separator = id.lastIndexOf(':');
        if (separator <= 'caption:'.length) continue;
        final path = Uri.decodeComponent(
          id.substring('caption:'.length, separator),
        );
        final index = int.tryParse(id.substring(separator + 1));
        if (index != null) removals.putIfAbsent(path, () => []).add(index);
      }
      _updateEditor(() {
        var removed = 0;
        for (final entry in removals.entries) {
          final cues = [...?_captionCuesByVideo[entry.key]];
          final indexes = entry.value.toSet().toList()
            ..sort((a, b) => b.compareTo(a));
          for (final index in indexes) {
            if (index >= 0 && index < cues.length) {
              cues.removeAt(index);
              removed++;
            }
          }
          _captionCuesByVideo[entry.key] = cues;
        }
        _selectedCaptionIds.clear();
        _selectedCaptionCueIndex = 0;
        _editorSelection = const EditorSelection.none();
        _status = '$removed caption clip${removed == 1 ? '' : 's'} deleted';
      });
      unawaited(_autosaveProject());
      return true;
    }

    final selectedIds = _effectiveSelectedTimelineClipIds;
    if (selectedIds.length <= 1) {
      if (_musicTimelineSelected) {
        unawaited(_deleteMusicTimelineTrack());
        return true;
      }
      return false;
    }
    final deletable = <String>[];
    final textIds = <String>{};
    if (selectedIds.any(
            (id) => _multiTrackTimeline.clipById(id)?.track.isLocked == true) ||
        LinkedAudioEditGuard.blocks(_multiTrackTimeline, selectedIds)) {
      _showMessage(
          'Unlock the selected tracks and linked audio before deleting.');
      return true;
    }
    for (final id in selectedIds) {
      final result = _multiTrackTimeline.clipById(id);
      if (result == null || result.track.isLocked) continue;
      deletable.add(id);
      if (result.track.type == TrackType.text) {
        textIds.addAll([result.clip.id, result.clip.mediaPath]);
      }
    }
    if (deletable.isEmpty) {
      _showMessage('Unlock the selected tracks before deleting clips.');
      return true;
    }
    var next = _multiTrackTimeline;
    for (final id in deletable) {
      // A selected companion may already have been removed with its owner.
      if (next.clipById(id) == null) continue;
      final changed = _timelineEditor.deleteClip(next, id);
      if (identical(changed, next)) {
        _showMessage('Delete rejected: locked content would be changed.');
        return true;
      }
      next = changed;
    }
    _recordEditorHistory('timeline-multi-delete', coalesce: false);
    _updateEditor(() {
      _multiTrackTimeline = next.normalized();
      if (textIds.isNotEmpty) {
        _textOverlays.removeWhere(
          (overlay) => textIds.contains(overlay.id),
        );
        if (_textOverlays.isEmpty) {
          _textOverlays.add(const _TextOverlayDraft());
        }
      }
      _selectedTimelineClipIds.clear();
      _selectedTimelineClipId = null;
      _programTimelineClipId = null;
      _editorSelection = const EditorSelection.none();
      _status = '${deletable.length} timeline clips deleted';
    });
    unawaited(_autosaveProject());
    return true;
  }

  void _deleteClipPartAtPlayhead() {
    if (_deleteSelectedTimelineItems()) return;
    if (_videos.isEmpty) return;
    final selectedTimelineClip = _selectedTimelineClipId == null
        ? null
        : _multiTrackTimeline.clipById(_selectedTimelineClipId!);
    if (selectedTimelineClip?.track.type == TrackType.text) {
      if (!_ensureTimelineClipUnlocked(
        selectedTimelineClip!.clip.id,
        action: 'deleting this text',
      )) {
        return;
      }
      final index = _textOverlays.indexWhere(
        (overlay) => overlay.id == selectedTimelineClip.clip.id,
      );
      if (index >= 0) _deleteTextOverlayAt(index);
      return;
    }
    if (selectedTimelineClip != null) {
      if (!_ensureTimelineClipUnlocked(
        selectedTimelineClip.clip.id,
        action: 'deleting this clip',
      )) {
        return;
      }
      final next = _timelineEditor.deleteClip(
          _multiTrackTimeline, selectedTimelineClip.clip.id);
      if (identical(next, _multiTrackTimeline)) {
        _showMessage('Delete rejected: locked content would be changed.');
        return;
      }
      _recordEditorHistory('timeline-delete', coalesce: false);
      _updateEditor(() {
        _multiTrackTimeline = next;
        _selectedTimelineClipIds.clear();
        _selectedTimelineClipId = null;
        if (_programTimelineClipId == selectedTimelineClip.clip.id) {
          _programTimelineClipId = null;
        }
        _status = 'Clip deleted';
      });
      unawaited(_autosaveProject());
      return;
    }
    final video = _videos[_selectedVideoIndex];
    final current = _clipTimelineEditFor(video.path);
    final part = current.timelinePartAt(
      _currentPlayheadSeconds(),
      video.durationSeconds,
    );
    if (part == null) return;
    _setSelectedClipTimelineEdit(
      current.copyWith(
        deletedRanges: [
          ...current.deletedRanges,
          (start: part.start, end: part.end),
        ],
      ),
    );
    _updateEditor(() {
      _status = 'Deleted ${_formatDuration(part.end - part.start)} section';
    });
  }

  void _beginTimelineTrim() {
    if (_videos.isEmpty || _activeTimelineTrimOriginal != null) return;
    if (!_ensureTimelineClipUnlocked(
      _selectedTimelineClipId,
      action: 'trimming this clip',
    )) {
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    _activeTimelineTrimPath = path;
    _activeTimelineTrimOriginal = _clipTimelineEditFor(path);
  }

  void _updateTimelineTrim({
    required bool startEdge,
    required double deltaPixels,
  }) {
    final path = _activeTimelineTrimPath;
    if (path == null || _videos.isEmpty) return;
    final index = _videos.indexWhere((video) => video.path == path);
    if (index < 0) return;
    final video = _videos[index];
    final duration = video.durationSeconds ?? 0;
    if (duration <= 0) return;
    final edit = _clipTimelineEditFor(path);
    final deltaSeconds = deltaPixels / _timelinePixelsPerSecond();
    final start = edit.trimStartSeconds.clamp(0.0, duration).toDouble();
    final end = edit.trimEndSeconds > start
        ? edit.trimEndSeconds.clamp(start, duration).toDouble()
        : duration;
    final minimumDuration = math.min(0.05, duration);
    final maximumStart = math.max(0.0, end - minimumDuration);
    final minimumEnd = math.min(duration, start + minimumDuration);
    final next = startEdge
        ? edit.copyWith(
            trimStartSeconds:
                (start + deltaSeconds).clamp(0.0, maximumStart).toDouble(),
          )
        : edit.copyWith(
            trimEndSeconds:
                (end + deltaSeconds).clamp(minimumEnd, duration).toDouble(),
          );
    _updateEditor(() => _setClipTimelineEditWithoutHistory(path, next));
    final previewSeconds = startEdge
        ? next.trimStartSeconds
        : next.trimEndSeconds > 0
            ? next.trimEndSeconds
            : duration;
    final controller = _previewController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.seekTo(
        Duration(milliseconds: (previewSeconds * 1000).round()),
      ));
    }
  }

  void _endTimelineTrim() {
    final path = _activeTimelineTrimPath;
    final original = _activeTimelineTrimOriginal;
    _activeTimelineTrimPath = null;
    _activeTimelineTrimOriginal = null;
    if (path == null || original == null) return;
    final current = _clipTimelineEditFor(path);
    if (current.sameAs(original)) return;
    _updateEditor(() {
      _clipTimelineUndoStacks.putIfAbsent(path, () => []).add(original);
      _clipTimelineRedoStacks[path]?.clear();
      _status = 'Clip edge trimmed — Ctrl+Z to undo';
    });
  }

  void _moveSelectedClipPart({
    required int fromVisualIndex,
    required int toVisualIndex,
  }) {
    if (_videos.isEmpty || fromVisualIndex == toVisualIndex) return;
    final video = _videos[_selectedVideoIndex];
    final current = _clipTimelineEditFor(video.path);
    final parts = current.timelineParts(video.durationSeconds);
    if (fromVisualIndex < 0 ||
        fromVisualIndex >= parts.length ||
        toVisualIndex < 0 ||
        toVisualIndex >= parts.length) {
      return;
    }
    final keys = parts.map(_timelinePartKey).toList();
    final moved = keys.removeAt(fromVisualIndex);
    keys.insert(toVisualIndex, moved);
    _setSelectedClipTimelineEdit(current.copyWith(partOrder: keys));
  }

  double _timelinePartKey(({double start, double end}) part) {
    return double.parse(part.start.toStringAsFixed(3));
  }

  void _setSelectedClipTimelineEdit(_ClipTimelineEdit edit) {
    if (_videos.isEmpty) return;
    final selectedId = _selectedTimelineClipId;
    final selected =
        selectedId == null ? null : _multiTrackTimeline.clipById(selectedId);
    if (selected?.track.isLocked == true) {
      _showMessage('Unlock ${selected!.track.label} before editing.');
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    final current = _clipTimelineEditFor(path);
    if (current.sameAs(edit)) return;
    _recordEditorHistory('clip-edit');
    _updateEditor(() {
      _clipTimelineUndoStacks.putIfAbsent(path, () => []).add(current);
      _clipTimelineRedoStacks[path]?.clear();
      _setClipTimelineEditWithoutHistory(path, edit);
    });
    unawaited(_seekPreviewToPlayablePosition(preferNext: true));
  }

  void _setClipTimelineEditWithoutHistory(String path, _ClipTimelineEdit edit) {
    _clipTimelineEdits[path] = edit;
    if (_videos.isNotEmpty && _videos[_selectedVideoIndex].path == path) {
      _applyClipTimelineEdit(edit);
    }
    if (edit.hasStructuralTimelineEdit) {
      _syncMultiTrackFromLegacy(preferredMediaPath: path);
      return;
    }
    final selectedId = _selectedTimelineClipId;
    final selected =
        selectedId == null ? null : _multiTrackTimeline.clipById(selectedId);
    if (selected != null &&
        selected.track.type == TrackType.video &&
        selected.clip.mediaPath == path) {
      final sourceStart = math.max(0, edit.trimStartSeconds).toDouble();
      final requestedEnd = edit.trimEndSeconds > sourceStart
          ? edit.trimEndSeconds
          : selected.clip.sourceEnd;
      final duration = math.max(0.001, requestedEnd - sourceStart).toDouble();
      final transform = selected.clip.transform.copyWith(
        scaleX: edit.scaleX * edit.zoom,
        scaleY: edit.scaleY * edit.zoom,
        positionX: (0.5 + edit.panX * 0.5).clamp(0, 1).toDouble(),
        positionY: (0.5 + edit.panY * 0.5).clamp(0, 1).toDouble(),
      );
      final linkedAudioId =
          _multiTrackTimeline.linkedAudioForVideo(selected.clip.id)?.id;
      _multiTrackTimeline = _multiTrackTimeline.copyWith(
        tracks: [
          for (final track in _multiTrackTimeline.tracks)
            track.copyWith(
              clips: [
                for (final clip in track.clips)
                  if (clip.id == selected.clip.id ||
                      (linkedAudioId != null && clip.id == linkedAudioId))
                    clip.copyWith(
                      sourceStart: sourceStart,
                      duration: duration,
                      transform: clip.id == selected.clip.id
                          ? transform
                          : clip.transform,
                    )
                  else
                    clip,
              ],
            ),
        ],
      ).normalized();
      return;
    }
    // Legacy projects without a selected timeline block still use the older
    // per-file edit conversion for backward compatibility.
    _syncMultiTrackFromLegacy();
  }

  Widget _timelineVideoClips() {
    return Opacity(
      opacity: _videoTrackHidden ? 0.35 : 1,
      child: _timelineClipStrip(
        children: [
          for (final entry in _visibleTimelineVideos())
            ..._timelineClipParts(
              entry.video,
              entry.index,
              color: entry.index == _selectedVideoIndex
                  ? const Color(0xff60a5fa)
                  : const Color(0xff93c5fd),
            ),
        ],
      ),
    );
  }

  Widget _timelineAudioClips({bool extracted = false}) {
    return _timelineClipStrip(
      children: [
        for (final entry in _visibleTimelineVideos())
          ..._timelineClipParts(
            entry.video,
            entry.index,
            color:
                extracted ? const Color(0xffa78bfa) : const Color(0xff38bdf8),
            audio: true,
            extractedAudio: extracted,
          ),
      ],
    );
  }

  Widget _timelineClipStrip({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: ClipRect(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _timelineClipParts(
    PickedVideo video,
    int index, {
    required Color color,
    bool audio = false,
    bool extractedAudio = false,
  }) {
    final edit = _clipTimelineEditFor(video.path);
    final parts = edit.timelineParts(video.durationSeconds);
    final hasEdit = edit.hasEdit(video.durationSeconds);
    return [
      for (var partIndex = 0; partIndex < parts.length; partIndex++)
        _timelineClipPartDropTarget(
          video: video,
          visualPartIndex: partIndex,
          enabled: _clipEditMode && !audio && index == _selectedVideoIndex,
          child: _timelineClip(
            video,
            index,
            color: color,
            audio: audio,
            partIndex: parts.length > 1 ? partIndex + 1 : null,
            edited: hasEdit,
            trimOnly: hasEdit && parts.length == 1,
            width: _timelinePartWidth(parts[partIndex]),
            extractedAudio: extractedAudio,
            draggable: _clipEditMode &&
                !audio &&
                index == _selectedVideoIndex &&
                parts.length > 1,
            timelinePart: parts[partIndex],
            visualPartIndex: partIndex,
            showStartTrimHandle: _clipEditMode &&
                !audio &&
                index == _selectedVideoIndex &&
                partIndex == 0,
            showEndTrimHandle: _clipEditMode &&
                !audio &&
                index == _selectedVideoIndex &&
                partIndex == parts.length - 1,
          ),
        ),
    ];
  }

  Widget _timelineClipPartDropTarget({
    required PickedVideo video,
    required int visualPartIndex,
    required bool enabled,
    required Widget child,
  }) {
    if (!enabled) return child;
    return DragTarget<_TimelinePartDrag>(
      onWillAcceptWithDetails: (details) =>
          details.data.videoPath == video.path &&
          details.data.visualPartIndex != visualPartIndex,
      onAcceptWithDetails: (details) {
        _moveSelectedClipPart(
          fromVisualIndex: details.data.visualPartIndex,
          toVisualIndex: visualPartIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: active
                ? Border.all(color: const Color(0xfffacc15), width: 2)
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
