part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineRepairLoadedTimeline on _EditorScreenState {
  TimelineModel _repairLoadedTimeline(TimelineModel model) {
    final repairedTracks = <TrackModel>[];
    var changed = false;
    for (final track in model.tracks) {
      final clips = [...track.clips];
      final sameMedia = clips.length > 1 &&
          clips.map((clip) => clip.mediaPath).toSet().length == 1;
      final allAtZero = clips.length > 1 &&
          clips.every((clip) => clip.timelineStart.abs() < 0.001);
      final hasSourceOffset = clips.any((clip) => clip.sourceStart > 0.001);
      if (sameMedia && allAtZero && hasSourceOffset) {
        clips.sort((a, b) {
          final source = a.sourceStart.compareTo(b.sourceStart);
          return source != 0 ? source : a.id.compareTo(b.id);
        });
        var cursor = 0.0;
        for (var index = 0; index < clips.length; index++) {
          final clip = clips[index];
          if ((clip.timelineStart - cursor).abs() > 0.001) changed = true;
          clips[index] = clip.copyWith(timelineStart: cursor);
          cursor += math.max(0.001, clip.duration);
        }
      }
      repairedTracks.add(track.copyWith(clips: clips));
    }
    if (!changed) return model;
    return TimelineModel(
      tracks: repairedTracks,
      duration: TimelineModel.calculateDuration(repairedTracks),
    ).normalized();
  }

  _ClipTimelineEdit _clipEditWithCurrentTransform(_ClipTimelineEdit edit) {
    return edit.copyWith(
      speed: _speed,
      flip: _flip,
      scaleX: _scaleX,
      scaleY: _scaleY,
      zoom: _zoom,
      panX: _panX,
      panY: _panY,
      originalVolume: _originalVolume,
    );
  }

  bool _updateSelectedTimelineClipTransform(_ClipTimelineEdit edit) {
    if (_videos.isEmpty ||
        _selectedVideoIndex < 0 ||
        _selectedVideoIndex >= _videos.length) {
      return false;
    }
    final path = _videos[_selectedVideoIndex].path;
    final hasVideo = _multiTrackTimeline.videoTracks.any(
      (track) => track.clips.any((clip) => clip.mediaPath == path),
    );
    if (!hasVideo) return false;
    _applyTimelineModelUpdate(
      _timelineWithAppliedVideoSettings(
        _multiTrackTimeline,
        path,
        edit,
        copyFrame: true,
        copyAudio: true,
      ),
    );
    _storeActiveCompositionTimeline();
    return true;
  }

  TimelineModel _timelineWithAppliedVideoSettings(
    TimelineModel model,
    String videoPath,
    _ClipTimelineEdit edit, {
    required bool copyFrame,
    required bool copyAudio,
    bool copyCanvas = false,
    String? canvasMode,
    String? canvasColor,
    String? canvasPattern,
    double? canvasBlur,
  }) {
    final settings = VideoRenderSettings(
      mediaPath: videoPath,
      speed: edit.speed,
      originalVolume: edit.originalVolume,
      transform: ClipTransform(
        scaleX: edit.scaleX * edit.zoom,
        scaleY: edit.scaleY * edit.zoom,
        positionX: (0.5 + edit.panX * 0.5).clamp(0, 1).toDouble(),
        positionY: (0.5 + edit.panY * 0.5).clamp(0, 1).toDouble(),
        flip: edit.flip,
        canvasMode: canvasMode ?? 'none',
        canvasColor: canvasColor ?? '#F4C70F',
        canvasPattern: canvasPattern ?? 'grid',
        canvasBlur: canvasBlur ?? 24,
      ),
    );
    return applyVideoRenderSettings(
      timeline: model,
      settings: settings,
      copyFrame: copyFrame,
      copyAudio: copyAudio,
      copyCanvas: copyCanvas,
    );
  }

  void _loadTimelineClipTransformIntoInspector(ClipModel clip) {
    _speed =
        clip.resolvedPlaybackSpeed(_clipTimelineEditFor(clip.mediaPath).speed);
    _flip = clip.transform.flip;
    _scaleX = clip.transform.scaleX;
    _scaleY = clip.transform.scaleY;
    _zoom = 1;
    _panX = ((clip.transform.positionX - 0.5) * 2).clamp(-1, 1);
    _panY = ((clip.transform.positionY - 0.5) * 2).clamp(-1, 1);
    _canvasMode = clip.transform.canvasMode;
    _canvasPattern = clip.transform.canvasPattern;
    _canvasColor =
        _parseHexColor(clip.transform.canvasColor) ?? const Color(0xfff4c70f);
    _canvasBlur = clip.transform.canvasBlur;
  }

  TimelineModel _buildLegacyMultiTrackTimeline({
    TimelineModel? previousTimeline,
    Iterable<PickedVideo>? videos,
  }) {
    final previousModel = previousTimeline ?? _multiTrackTimeline;
    final requestedVideos = videos?.toList();
    final activeMedia = _activeProjectMedia;
    final timelineVideos = requestedVideos != null && requestedVideos.isNotEmpty
        ? requestedVideos
        : activeMedia.isNotEmpty
            ? activeMedia
            : _videos;
    final previousClips = <String, ClipModel>{
      for (final track in previousModel.tracks)
        for (final clip in track.clips) clip.id: clip,
    };
    final preservedTracks = [
      for (final track in previousModel.tracks)
        if (track.type == TrackType.text || track.index > 1) track,
    ];
    final movedVideoIds = {
      for (final track in preservedTracks)
        if (track.type == TrackType.video)
          for (final clip in track.clips) clip.replacesClipId ?? clip.id,
    };
    final movedAudioIds = {
      for (final track in preservedTracks)
        if (track.type == TrackType.audio)
          for (final clip in track.clips) clip.replacesClipId ?? clip.id,
    };
    final videoClips = <ClipModel>[];
    final audioClips = <ClipModel>[];
    var timelineCursor = 0.0;
    for (final video in timelineVideos) {
      final edit = _clipTimelineEditFor(video.path);
      final parts = edit.timelineParts(video.durationSeconds);
      for (final part in parts) {
        final duration = math.max(0.001, part.end - part.start).toDouble();
        final baseId = _stableTimelineClipId(video.path, part.start, part.end);
        final previous = previousClips[baseId];
        final clipTimelineStart = previous?.transitionIn != null
            ? math
                .max(
                  0,
                  timelineCursor - previous!.transitionIn!.duration,
                )
                .toDouble()
            : previous?.hasProfessionalEdits == true
                ? previous!.timelineStart
                : timelineCursor;
        final transform = previous?.transform ??
            ClipTransform(
              scaleX: edit.scaleX * edit.zoom,
              scaleY: edit.scaleY * edit.zoom,
              positionX: (0.5 + edit.panX * 0.5).clamp(0, 1).toDouble(),
              positionY: (0.5 + edit.panY * 0.5).clamp(0, 1).toDouble(),
              flip: edit.flip,
            );
        if (!movedVideoIds.contains(baseId)) {
          videoClips.add(
            ClipModel(
              id: baseId,
              mediaPath: video.path,
              timelineStart: clipTimelineStart,
              duration: duration,
              sourceStart: part.start,
              zIndex: 0,
              transform: transform,
              playbackSpeed:
                  previous?.resolvedPlaybackSpeed(edit.speed) ?? edit.speed,
              effects: previous?.effects ?? const [],
              transitionIn: previous?.transitionIn,
              keyframes: previous?.keyframes ?? const [],
            ),
          );
        }
        final audioId = 'audio-$baseId';
        final previousAudio = previousClips[audioId];
        if (video.hasAudio && !movedAudioIds.contains(audioId)) {
          audioClips.add(
            ClipModel(
              id: audioId,
              mediaPath: video.path,
              timelineStart: previousAudio?.transitionIn != null
                  ? clipTimelineStart
                  : previousAudio?.hasProfessionalEdits == true
                      ? previousAudio!.timelineStart
                      : clipTimelineStart,
              duration: duration,
              sourceStart: part.start,
              zIndex: 0,
              volume: previousAudio?.volume ?? edit.originalVolume,
              playbackSpeed:
                  previous?.resolvedPlaybackSpeed(edit.speed) ?? edit.speed,
              isLinkedAudio: previousAudio?.isLinkedAudio ?? true,
              linkedClipId: previousAudio?.linkedClipId ?? baseId,
              transitionIn: previousAudio?.transitionIn,
            ),
          );
        }
        timelineCursor = clipTimelineStart + duration;
      }
    }
    final tracks = <TrackModel>[
      TrackModel(
        id: 'video-1',
        type: TrackType.video,
        index: 1,
        isMuted: _videoTrackHidden,
        clips: videoClips,
      ),
      ...preservedTracks.where((track) => track.type == TrackType.video),
      TrackModel(
        id: 'audio-1',
        type: TrackType.audio,
        index: 1,
        isMuted: _originalAudioMuted,
        clips: audioClips,
      ),
      ...preservedTracks.where((track) => track.type == TrackType.audio),
      ...preservedTracks.where((track) => track.type == TrackType.text),
    ];
    return TimelineModel(
      tracks: tracks,
      duration: TimelineModel.calculateDuration(tracks),
    ).normalized();
  }

  double _videoTimelineEnd([TimelineModel? model]) {
    final timeline = model ?? _multiTrackTimeline;
    var end = 0.0;
    for (final track in timeline.videoTracks) {
      for (final clip in track.clips) {
        end = math.max(end, clip.timelineEnd);
      }
    }
    return end;
  }

  TimelineModel _timelineWithFirstVideo(PickedVideo video) {
    final duration = math.max(0.001, video.durationSeconds ?? 0.001).toDouble();
    final edit = _clipTimelineEditFor(video.path);
    final clipId =
        'clip-${DateTime.now().microsecondsSinceEpoch}-${video.path.hashCode.abs()}';
    final videoClip = ClipModel(
      id: clipId,
      mediaPath: video.path,
      timelineStart: 0,
      duration: duration,
      sourceStart: 0,
      zIndex: 0,
    );
    final tracks = <TrackModel>[
      TrackModel(
        id: 'video-1',
        type: TrackType.video,
        index: 1,
        clips: [videoClip],
      ),
      TrackModel(
        id: 'audio-1',
        type: TrackType.audio,
        index: 1,
        clips: [
          if (video.hasAudio)
            videoClip.copyWith(
              id: 'audio-$clipId',
              volume: edit.originalVolume,
              isLinkedAudio: true,
              linkedClipId: clipId,
            ),
        ],
      ),
    ];
    return TimelineModel(
      tracks: tracks,
      duration: TimelineModel.calculateDuration(tracks),
    ).normalized();
  }

  void _storeActiveCompositionTimeline() {
    final composition = _selectedCompositionPath;
    if (composition == null) return;
    _timelinesByComposition[composition] = _multiTrackTimeline;
  }

  Future<void> _addImportedVideoToTimeline(int index) async {
    await _insertProjectMediaOnTimeline(index);
  }

  Future<void> _insertProjectMediaOnTimeline(
    int index, {
    String? trackId,
    double? timelineStart,
  }) async {
    if (index < 0 || index >= _videos.length) return;
    _recordEditorHistory('timeline-media-add');
    final video = _videos[index];
    final duration = math.max(0.001, video.durationSeconds ?? 0.001).toDouble();
    var timeline = _programEditingTimeline;
    if (timeline.videoTracks.isEmpty) {
      timeline =
          _programRenderSnapshot(_timelineWithFirstVideo(video)).outputTimeline;
    } else {
      final clipId =
          'clip-${DateTime.now().microsecondsSinceEpoch}-${video.path.hashCode.abs()}';
      final start = timelineStart ?? _videoTimelineEnd(timeline);
      final videoClip = ClipModel(
        id: clipId,
        mediaPath: video.path,
        timelineStart: start,
        duration: duration,
        playbackSpeed: 1,
        sourceStart: 0,
        zIndex: 0,
      );
      final videoTrack = trackId == null
          ? timeline.videoTracks.first
          : (timeline.trackById(trackId) ?? timeline.videoTracks.first);
      timeline = _programTimelineEditor.insertClip(
        timeline,
        trackId: videoTrack.id,
        clip: videoClip,
      );
      if (video.hasAudio) {
        var audioTrack =
            timeline.audioTracks.isEmpty ? null : timeline.audioTracks.first;
        if (audioTrack == null) {
          timeline = _programTimelineEditor.addTrack(timeline, TrackType.audio);
          audioTrack = timeline.audioTracks.first;
        }
        timeline = _programTimelineEditor.insertClip(
          timeline,
          trackId: audioTrack.id,
          clip: videoClip.copyWith(
            id: 'audio-$clipId',
            volume: _originalVolume,
            isLinkedAudio: true,
            linkedClipId: clipId,
          ),
        );
      }
    }
    final added = timeline.videoTracks
        .expand((track) => track.clips)
        .where((clip) => clip.mediaPath == video.path)
        .reduce((a, b) => a.timelineStart >= b.timelineStart ? a : b);
    _updateEditor(() {
      _multiTrackTimeline = _sourceTimelineFromProgramEdit(timeline);
      final composition = _selectedCompositionPath;
      if (composition != null) {
        _timelinesByComposition[composition] = _multiTrackTimeline;
      }
      _selectedTimelineClipId = added.id;
      _programTimelineClipId = added.id;
      _status = '${video.name} added as a separate timeline clip';
    });
    if (index != _selectedVideoIndex) {
      await _selectVideo(index, saveCurrentEdit: false);
    }
    await _seekProgramPreview(added.timelineStart);
    unawaited(_autosaveProject());
  }

  void _dropProjectMediaOnTimeline(
    TimelineMediaDragData media,
    String trackId,
    double timelineStart,
  ) {
    final index = _videos.indexWhere((video) => video.path == media.mediaPath);
    if (index < 0) return;
    unawaited(
      _insertProjectMediaOnTimeline(
        index,
        trackId: trackId,
        timelineStart: timelineStart,
      ),
    );
  }

  void _syncMultiTrackFromLegacy({
    String? preferredMediaPath,
    bool allCompositions = false,
  }) {
    if (_videos.isEmpty) {
      _multiTrackTimeline = TimelineModel.empty();
      _selectedTimelineClipId = null;
      _programTimelineClipId = null;
      _selectedTimelineClipIds.clear();
      return;
    }

    if (allCompositions) {
      for (final composition in _compositionPaths) {
        final mediaPaths = _projectMediaPathsByComposition[composition] ??
            <String>[composition];
        final compositionVideos = [
          for (final path in mediaPaths)
            for (final video in _videos)
              if (video.path == path) video,
        ];
        if (compositionVideos.isEmpty) continue;
        final previous = composition == _selectedCompositionPath
            ? _multiTrackTimeline
            : _timelinesByComposition[composition];
        _timelinesByComposition[composition] = _buildLegacyMultiTrackTimeline(
          previousTimeline: previous,
          videos: compositionVideos,
        );
      }
      final active = _selectedCompositionPath;
      if (active != null && _timelinesByComposition[active] != null) {
        _multiTrackTimeline = _timelinesByComposition[active]!;
      } else {
        _multiTrackTimeline = _buildLegacyMultiTrackTimeline();
      }
    } else {
      _multiTrackTimeline = _buildLegacyMultiTrackTimeline();
    }
    _ensureTextTimelineTracks();

    ClipModel? preferredClip;
    if (preferredMediaPath != null) {
      for (final track in _multiTrackTimeline.videoTracks) {
        for (final clip in track.clips) {
          if (clip.mediaPath == preferredMediaPath) {
            preferredClip = clip;
            break;
          }
        }
        if (preferredClip != null) break;
      }
    }
    preferredClip ??= _multiTrackTimeline.videoTracks
        .expand((track) => track.clips)
        .cast<ClipModel?>()
        .firstWhere((clip) => clip != null, orElse: () => null);

    final selectedIsValid = _selectedTimelineClipId != null &&
        _multiTrackTimeline.clipById(_selectedTimelineClipId!) != null;
    if (!selectedIsValid) {
      _selectedTimelineClipId = preferredClip?.id;
    }
    final programIsValid = _programTimelineClipId != null &&
        _multiTrackTimeline.clipById(_programTimelineClipId!) != null;
    if (!programIsValid) {
      _programTimelineClipId = preferredClip?.id;
    }
    _selectedTimelineClipIds.removeWhere(
      (id) => _multiTrackTimeline.clipById(id) == null,
    );
    _storeActiveCompositionTimeline();
  }

  String _stableTimelineClipId(String path, double start, double end) {
    var hash = 2166136261;
    for (final unit in path.toLowerCase().codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return 'clip-$hash-${(start * 1000).round()}-${(end * 1000).round()}';
  }

  Map<String, Object?> _clipEditToJson(_ClipTimelineEdit edit) => {
        'trimStartSeconds': edit.trimStartSeconds,
        'trimEndSeconds': edit.trimEndSeconds,
        'splitEverySeconds': edit.splitEverySeconds,
        'speed': edit.speed,
        'flip': edit.flip,
        'scaleX': edit.scaleX,
        'scaleY': edit.scaleY,
        'zoom': edit.zoom,
        'panX': edit.panX,
        'panY': edit.panY,
        'originalVolume': edit.originalVolume,
        'splitPoints': edit.splitPoints,
        'deletedRanges': [
          for (final range in edit.deletedRanges)
            {'start': range.start, 'end': range.end},
        ],
        'partOrder': edit.partOrder,
      };

  Map<String, _ClipTimelineEdit> _clipEditsFromJson(Object? value) {
    final source = value is Map ? value : const {};
    return {
      for (final entry in source.entries)
        '${entry.key}': _clipEditFromJson(entry.value),
    };
  }

  Set<String> _clipTransformOverridesFromJson(
    Object? value,
    Map<String, _ClipTimelineEdit> edits,
  ) {
    if (value is List) {
      final masterPath = _videos.isEmpty ? null : _videos.first.path;
      return {
        for (final item in value)
          if ('$item'.isNotEmpty && '$item' != masterPath) '$item',
      };
    }
    if (_videos.isEmpty) return {};
    final masterPath = _videos.first.path;
    final master = edits[masterPath] ?? const _ClipTimelineEdit();
    return {
      for (final entry in edits.entries)
        if (entry.key != masterPath && !_sameTransform(entry.value, master))
          entry.key,
    };
  }

  _ClipTimelineEdit _clipEditFromJson(Object? value) {
    final data = value is Map ? value : const {};
    double number(String key) =>
        double.tryParse('${data[key] ?? 0}')?.toDouble() ?? 0;
    return _ClipTimelineEdit(
      trimStartSeconds: number('trimStartSeconds'),
      trimEndSeconds: number('trimEndSeconds'),
      splitEverySeconds: number('splitEverySeconds'),
      speed: double.tryParse('${data['speed'] ?? _speed}') ?? _speed,
      flip: '${data['flip'] ?? _flip}',
      scaleX: double.tryParse('${data['scaleX'] ?? _scaleX}') ?? _scaleX,
      scaleY: double.tryParse('${data['scaleY'] ?? _scaleY}') ?? _scaleY,
      zoom: double.tryParse('${data['zoom'] ?? _zoom}') ?? _zoom,
      panX: double.tryParse('${data['panX'] ?? _panX}') ?? _panX,
      panY: double.tryParse('${data['panY'] ?? _panY}') ?? _panY,
      originalVolume:
          double.tryParse('${data['originalVolume'] ?? _originalVolume}') ??
              _originalVolume,
      splitPoints: [
        for (final item in data['splitPoints'] as List? ?? const [])
          if (double.tryParse('$item') != null) double.parse('$item'),
      ],
      deletedRanges: [
        for (final item in data['deletedRanges'] as List? ?? const [])
          if (item is Map)
            (
              start: double.tryParse('${item['start'] ?? 0}') ?? 0,
              end: double.tryParse('${item['end'] ?? 0}') ?? 0,
            ),
      ],
      partOrder: [
        for (final item in data['partOrder'] as List? ?? const [])
          if (double.tryParse('$item') != null) double.parse('$item'),
      ],
    );
  }

  void _handleTimelineScroll() {
    if (!_timelineScrollController.hasClients) return;
    final nextOffset = _timelineScrollController.offset;
    if ((nextOffset - _timelineScrollOffset).abs() < 24) return;
    _timelineScrollOffset = nextOffset;
    _timelineScrollOffsetListenable.value = nextOffset;
    _timelineMediaLoadDebounce?.cancel();
    _timelineMediaLoadDebounce = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(_loadVisibleTimelineMedia()),
    );
  }
}
