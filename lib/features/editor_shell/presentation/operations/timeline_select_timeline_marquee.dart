part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineSelectTimelineMarquee on _EditorScreenState {
  Future<void> _selectTimelineMarquee(
    Set<String> itemIds, {
    required bool additive,
  }) async {
    final nextClips =
        additive ? <String>{..._effectiveSelectedTimelineClipIds} : <String>{};
    final nextCaptions =
        additive ? <String>{..._effectiveSelectedCaptionIds} : <String>{};
    var nextMusic = additive && _musicTimelineSelected;
    for (final id in itemIds) {
      if (id == 'music-track') {
        nextMusic = true;
      } else if (id.startsWith('caption:')) {
        nextCaptions.add(id);
      } else if (_multiTrackTimeline.clipById(id) != null) {
        nextClips.add(id);
      }
    }
    final total = nextClips.length + nextCaptions.length + (nextMusic ? 1 : 0);
    if (total == 0) {
      _updateEditor(() {
        _selectedTimelineClipIds.clear();
        _selectedCaptionIds.clear();
        _selectedTimelineClipId = null;
        _musicTimelineSelected = false;
        _editorSelection = const EditorSelection.none();
        _status = 'Selection cleared';
      });
      return;
    }
    if (nextClips.isNotEmpty) {
      await _selectMultiTrackClip(nextClips.last);
    } else if (nextCaptions.isNotEmpty) {
      await _selectDynamicTimelineCaption(nextCaptions.last);
    } else if (nextMusic) {
      _selectTimelineMusic();
    }
    if (!mounted) return;
    _updateEditor(() {
      _selectedTimelineClipIds
        ..clear()
        ..addAll(nextClips);
      _selectedCaptionIds
        ..clear()
        ..addAll(nextCaptions);
      _selectedTimelineClipId = nextClips.isEmpty ? null : nextClips.last;
      _musicTimelineSelected = nextMusic;
      _status = '$total timeline item${total == 1 ? '' : 's'} selected';
    });
  }

  Future<void> _selectMultiTrackClip(
    String clipId, {
    bool toggle = false,
    bool range = false,
  }) async {
    final result = _multiTrackTimeline.clipById(clipId);
    if (result == null) return;
    final nextSelection = _timelineClipSelectionFor(
      clipId,
      toggle: toggle,
      range: range,
    );
    final primaryId = nextSelection.contains(clipId)
        ? clipId
        : (nextSelection.isEmpty ? null : nextSelection.last);
    if (primaryId == null) {
      _updateEditor(() {
        _selectedTimelineClipIds.clear();
        _selectedTimelineClipId = null;
        _editorSelection = const EditorSelection.none();
        _status = 'Selection cleared';
      });
      return;
    }
    final primaryResult = _multiTrackTimeline.clipById(primaryId);
    if (primaryResult == null) return;
    if (result.track.type == TrackType.text) {
      final index = _textOverlays.indexWhere(
        (overlay) =>
            overlay.id == result.clip.mediaPath || overlay.id == clipId,
      );
      if (index >= 0) {
        _selectTextOverlay(index);
        if (!mounted) return;
        _updateEditor(() {
          _selectedTimelineClipIds
            ..clear()
            ..addAll(nextSelection);
          if (!toggle && !range) {
            _selectedCaptionIds.clear();
            _musicTimelineSelected = false;
          }
          _selectedTimelineClipId = primaryId;
          _status = nextSelection.length > 1
              ? '${nextSelection.length} timeline clips selected'
              : 'Text clip selected';
        });
      }
      return;
    }
    _updateEditor(() {
      _selectedTimelineClipIds
        ..clear()
        ..addAll(nextSelection);
      if (!toggle && !range) {
        _selectedCaptionIds.clear();
        _musicTimelineSelected = false;
      }
      _selectedTimelineClipId = primaryId;
      if (primaryResult.track.type == TrackType.video) {
        _programTimelineClipId = primaryId;
      }
      _editorSelection = primaryResult.track.type == TrackType.audio
          ? EditorSelection.audio(primaryId)
          : EditorSelection.video(primaryId);
      _status = nextSelection.length > 1
          ? '${nextSelection.length} timeline clips selected'
          : '${primaryResult.track.label} clip selected';
    });
    final videoIndex = _videos.indexWhere(
      (video) => video.path == primaryResult.clip.mediaPath,
    );
    if (videoIndex >= 0 && videoIndex != _selectedVideoIndex) {
      await _selectVideo(videoIndex, saveCurrentEdit: false);
      if (mounted) _updateEditor(() => _selectedTimelineClipId = primaryId);
    }
    if (primaryResult.track.type == TrackType.video) {
      if (mounted) {
        _updateEditor(() {
          _loadTimelineClipTransformIntoInspector(primaryResult.clip);
          _selectedTimelineClipId = primaryId;
          _programTimelineClipId = primaryId;
        });
      }
      final timelineStart = _programEditingTimeline
          .clipById(primaryResult.clip.id)!
          .clip
          .timelineStart;
      _timelineSeekDebounce?.cancel();
      _timelineSeekGeneration++;
      _requestedTimelinePlayheadSeconds.value = timelineStart;
      _setLiveTimelinePlayhead(timelineStart);
      await _seekProgramPreview(timelineStart);
    }
  }

  void _selectTimelineMusic({bool toggle = false}) {
    _updateEditor(() {
      _musicTimelineSelected = toggle ? !_musicTimelineSelected : true;
      if (!toggle) {
        _selectedTimelineClipIds.clear();
        _selectedCaptionIds.clear();
        _selectedTimelineClipId = null;
      }
      _editorSelection = _musicTimelineSelected
          ? const EditorSelection.audio('music-track')
          : const EditorSelection.none();
      _visibleWorkspacePanels.add('inspector');
      _status =
          _musicTimelineSelected ? 'Music track selected' : 'Selection cleared';
    });
  }

  bool _ensureTimelineClipUnlocked(
    String? clipId, {
    String action = 'editing',
  }) {
    if (clipId == null) return true;
    final result = _multiTrackTimeline.clipById(clipId);
    if (result?.track.isLocked != true) return true;
    _showMessage('Unlock ${result!.track.label} before $action.');
    return false;
  }

  void _copySelectedTimelineClip() {
    final selectedIds = _effectiveSelectedTimelineClipIds;
    if (selectedIds.length > 1) {
      final copied = <({
        ClipModel clip,
        TrackType type,
        int trackIndex,
        ClipModel? linkedAudio,
      })>[];
      for (final id in selectedIds) {
        final result = _programEditingTimeline.clipById(id);
        if (result == null || result.track.type == TrackType.text) continue;
        copied.add((
          clip: result.clip,
          type: result.track.type,
          trackIndex: result.track.index,
          linkedAudio: result.track.type == TrackType.video
              ? _programEditingTimeline.linkedAudioForVideo(result.clip.id)
              : null,
        ));
      }
      if (copied.isNotEmpty) {
        _timelineMultiClipboard = copied;
        _timelineClipboard = null;
        _textOverlayClipboard = null;
        _updateEditor(() => _status = '${copied.length} clips copied');
      }
      return;
    }
    final id = _selectedTimelineClipId;
    if (id == null) return;
    final result = _programEditingTimeline.clipById(id);
    if (result == null) return;
    if (result.track.type == TrackType.text) {
      _saveSelectedTextOverlay();
      final index = _textOverlays.indexWhere(
        (overlay) => overlay.id == result.clip.id,
      );
      if (index >= 0) {
        _textOverlayClipboard = _textOverlays[index];
        _timelineClipboard = null;
        _timelineMultiClipboard = const [];
      }
    } else {
      _timelineClipboard = (clip: result.clip, type: result.track.type);
      _textOverlayClipboard = null;
      _timelineMultiClipboard = const [];
    }
    _updateEditor(() => _status = '${result.track.label} clip copied');
  }

  void _cutSelectedTimelineClip() {
    if (_effectiveSelectedTimelineClipIds.length > 1) {
      final unlocked = _effectiveSelectedTimelineClipIds.where((id) {
        return _multiTrackTimeline.clipById(id)?.track.isLocked != true;
      }).toSet();
      if (unlocked.length != _effectiveSelectedTimelineClipIds.length) {
        _showMessage('Unlock the selected tracks before cutting clips.');
        return;
      }
      _copySelectedTimelineClip();
      _deleteSelectedTimelineItems();
      return;
    }
    final id = _selectedTimelineClipId;
    if (id == null) return;
    if (!_ensureTimelineClipUnlocked(id, action: 'cutting this clip')) return;
    _copySelectedTimelineClip();
    final result = _multiTrackTimeline.clipById(id);
    if (result?.track.type == TrackType.text) {
      final index = _textOverlays.indexWhere((overlay) => overlay.id == id);
      if (index >= 0) _deleteTextOverlayAt(index);
      return;
    }
    _recordEditorHistory('timeline-cut');
    _updateEditor(() {
      _multiTrackTimeline = _timelineEditor.deleteClip(_multiTrackTimeline, id);
      _selectedTimelineClipIds.clear();
      _selectedTimelineClipId = null;
      _status = 'Clip cut';
    });
    unawaited(_autosaveProject());
  }

  void _pasteTimelineClipGroup() {
    final copied = _timelineMultiClipboard;
    if (copied.isEmpty) return;
    _recordEditorHistory('timeline-group-paste');
    final earliest =
        copied.map((item) => item.clip.timelineStart).reduce(math.min);
    var next = _programEditingTimeline;
    final insertedIds = <String>{};
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var index = 0; index < copied.length; index++) {
      final item = copied[index];
      TrackModel? target;
      for (final track in next.tracks) {
        if (track.type == item.type &&
            track.index == item.trackIndex &&
            !track.isLocked) {
          target = track;
          break;
        }
      }
      if (target == null) {
        for (final track in next.tracks) {
          if (track.type == item.type && !track.isLocked) {
            target = track;
            break;
          }
        }
      }
      if (target == null) {
        next = _programTimelineEditor.addTrack(next, item.type);
        target = next.tracks.where((track) => track.type == item.type).last;
      }
      final id = 'clip-$stamp-$index';
      final clip = item.clip.copyWith(
        id: id,
        timelineStart:
            _currentProgramSeconds() + (item.clip.timelineStart - earliest),
        clearReplacesClipId: true,
        clearTransitionIn: true,
      );
      next = _programTimelineEditor.insertClip(next,
          trackId: target.id, clip: clip);
      insertedIds.add(id);
      final linked = item.linkedAudio;
      if (linked != null) {
        TrackModel? audioTarget;
        for (final track in next.audioTracks) {
          if (!track.isLocked) {
            audioTarget = track;
            break;
          }
        }
        if (audioTarget == null) {
          next = _programTimelineEditor.addTrack(next, TrackType.audio);
          audioTarget = next.audioTracks.last;
        }
        next = _programTimelineEditor.insertClip(
          next,
          trackId: audioTarget.id,
          clip: linked.copyWith(
            id: 'audio-$id',
            timelineStart: clip.timelineStart,
            sourceStart: clip.sourceStart,
            duration: clip.duration,
            isLinkedAudio: true,
            linkedClipId: id,
            clearTransitionIn: true,
          ),
        );
      }
    }
    _updateEditor(() {
      _multiTrackTimeline = _sourceTimelineFromProgramEdit(next.normalized());
      _selectedTimelineClipIds
        ..clear()
        ..addAll(insertedIds);
      _selectedTimelineClipId = insertedIds.isEmpty ? null : insertedIds.last;
      _status = '${insertedIds.length} clips pasted at playhead';
    });
    unawaited(_autosaveProject());
  }

  void _pasteTimelineClip() {
    if (_timelineMultiClipboard.isNotEmpty) {
      _pasteTimelineClipGroup();
      return;
    }
    final text = _textOverlayClipboard;
    if (text != null) {
      _recordEditorHistory('timeline-paste');
      final id = 'text-${DateTime.now().microsecondsSinceEpoch}';
      final copy = text.copyWith(
        id: id,
        timelineStart: _currentProgramSeconds(),
        trackIndex: _nextTextTrackIndex(),
        isLocked: false,
      );
      _updateEditor(() {
        if (_textOverlays.length == 1 &&
            _textOverlays.first.text.trim().isEmpty) {
          _textOverlays.clear();
        }
        _textOverlays.add(copy);
        _selectedTextOverlayIndex = _textOverlays.length - 1;
        _loadTextOverlay(copy);
        _insertTextTimelineClip(copy);
        _selectedTimelineClipId = id;
        _editorSelection = EditorSelection.text(id, label: copy.text);
        _status = 'Text pasted at playhead';
      });
      unawaited(_autosaveProject());
      return;
    }
    final copied = _timelineClipboard;
    if (copied == null) return;
    final linkedSource = copied.type == TrackType.video
        ? _programEditingTimeline.linkedAudioForVideo(copied.clip.id)
        : null;
    _recordEditorHistory('timeline-paste');
    var target = _selectedTimelineClipId == null
        ? null
        : _multiTrackTimeline.clipById(_selectedTimelineClipId!)?.track;
    if (target?.type != copied.type || target?.isLocked == true) {
      target = null;
      for (final track in _multiTrackTimeline.tracks) {
        if (track.type == copied.type && !track.isLocked) {
          target = track;
          break;
        }
      }
    }
    if (target == null) {
      _multiTrackTimeline =
          _programTimelineEditor.addTrack(_multiTrackTimeline, copied.type);
      target = _multiTrackTimeline.tracks
          .where((track) => track.type == copied.type)
          .last;
    }
    final id = 'clip-${DateTime.now().microsecondsSinceEpoch}';
    final clip = copied.clip.copyWith(
      id: id,
      timelineStart: _currentProgramSeconds(),
      clearReplacesClipId: true,
      clearTransitionIn: true,
    );
    var next = _programTimelineEditor.insertClip(
      _programEditingTimeline,
      trackId: target.id,
      clip: clip,
    );
    if (linkedSource != null) {
      var audioTrack = next.audioTracks.firstWhere(
        (track) => !track.isLocked,
        orElse: () => const TrackModel(
          id: '',
          type: TrackType.audio,
          index: 0,
        ),
      );
      if (audioTrack.id.isEmpty) {
        next = _programTimelineEditor.addTrack(next, TrackType.audio);
        audioTrack = next.audioTracks.last;
      }
      next = _programTimelineEditor.insertClip(
        next,
        trackId: audioTrack.id,
        clip: linkedSource.copyWith(
          id: 'audio-$id',
          timelineStart: clip.timelineStart,
          sourceStart: clip.sourceStart,
          duration: clip.duration,
          isLinkedAudio: true,
          linkedClipId: id,
          clearTransitionIn: true,
        ),
      );
    }
    _updateEditor(() {
      _multiTrackTimeline = _sourceTimelineFromProgramEdit(next);
      _selectedTimelineClipId = id;
      _status = 'Clip pasted at playhead';
    });
    unawaited(_autosaveProject());
  }

  void _duplicateSelectedTimelineClip() {
    final id = _selectedTimelineClipId;
    if (id == null) return;
    if (!_ensureTimelineClipUnlocked(id, action: 'duplicating this clip')) {
      return;
    }
    final result = _multiTrackTimeline.clipById(id);
    if (result?.track.type == TrackType.text) {
      _duplicateTextOverlay();
      return;
    }
    _copySelectedTimelineClip();
    _pasteTimelineClip();
  }

  void _copySelectedClipAttributes() {
    final id = _selectedTimelineClipId;
    if (id == null) return;
    final clip = _multiTrackTimeline.clipById(id)?.clip;
    if (clip == null) return;
    _timelineAttributeClipboard = (
      transform: clip.transform,
      effects: [...clip.effects],
      keyframes: [...clip.keyframes],
    );
    _updateEditor(() => _status = 'Clip attributes copied');
  }

  void _pasteSelectedClipAttributes() {
    final id = _selectedTimelineClipId;
    final attributes = _timelineAttributeClipboard;
    if (id == null || attributes == null) return;
    if (!_ensureTimelineClipUnlocked(id, action: 'changing attributes')) {
      return;
    }
    _updateEditor(() {
      var next = _timelineEditor.updateClipTransform(
        _multiTrackTimeline,
        id,
        attributes.transform,
      );
      final result = next.clipById(id);
      if (result != null) {
        next = _timelineEditor.updateTrack(
          next,
          result.track.id,
          (track) => track.copyWith(
            clips: [
              for (final clip in track.clips)
                if (clip.id == id)
                  clip.copyWith(
                    effects: [...attributes.effects],
                    keyframes: [...attributes.keyframes],
                  )
                else
                  clip,
            ],
          ),
        );
      }
      _multiTrackTimeline = next;
      _status = 'Clip attributes pasted';
    });
    unawaited(_autosaveProject());
  }

  void _toggleSelectedTimelineClipActive() {
    final id = _selectedTimelineClipId;
    if (id == null) return;
    final result = _multiTrackTimeline.clipById(id);
    if (result == null) return;
    if (!_ensureTimelineClipUnlocked(id, action: 'changing this clip')) return;
    final nextMuted = !result.clip.isMuted;
    final selectedIds = _effectiveSelectedTimelineClipIds.where((clipId) {
      final selected = _multiTrackTimeline.clipById(clipId);
      return selected != null && !selected.track.isLocked;
    }).toSet();
    if (selectedIds.isEmpty) selectedIds.add(id);
    _updateEditor(() {
      _multiTrackTimeline = _multiTrackTimeline.copyWith(
        tracks: [
          for (final track in _multiTrackTimeline.tracks)
            !track.isLocked
                ? track.copyWith(
                    clips: [
                      for (final clip in track.clips)
                        if (selectedIds.contains(clip.id))
                          clip.copyWith(isMuted: nextMuted)
                        else
                          clip,
                    ],
                  )
                : track,
        ],
      );
      _status = selectedIds.length > 1
          ? '${selectedIds.length} clips ${nextMuted ? 'deactivated' : 'activated'}'
          : nextMuted
              ? 'Clip deactivated'
              : 'Clip activated';
    });
    unawaited(_autosaveProject());
  }

  void _extractSelectedClipAudio() {
    final id = _selectedTimelineClipId;
    if (id == null) return;
    final result = _multiTrackTimeline.clipById(id);
    if (result == null || result.track.type != TrackType.video) return;
    if (result.track.isLocked) {
      _showMessage('Unlock ${result.track.label} before extracting audio.');
      return;
    }
    var timeline = _multiTrackTimeline;
    final linkedAudio = timeline.linkedAudioForVideo(result.clip.id);
    if (linkedAudio == null) {
      _showMessage('This video audio is already extracted.');
      return;
    }
    final linkedResult = timeline.clipById(linkedAudio.id);
    if (linkedResult == null) return;
    final extractedId =
        'extracted-audio-${DateTime.now().microsecondsSinceEpoch}';
    final next = DetachAudioEdit.apply(timeline, id, extractedId,
        legacySpeeds: _videoPlaybackSpeedsForExport(timeline));
    if (identical(next, timeline)) {
      _showMessage('Unlock the linked audio track before extracting audio.');
      return;
    }
    _recordEditorHistory('extract-audio');
    timeline = next;
    final resolvedTrack = timeline.clipById(extractedId)?.track;
    _updateEditor(() {
      _multiTrackTimeline = timeline;
      _selectedTimelineClipId = extractedId;
      _editorSelection = EditorSelection.audio(extractedId);
      _status = 'Audio extracted to ${resolvedTrack?.label ?? 'audio track'}';
    });
    unawaited(_autosaveProject());
  }
}
