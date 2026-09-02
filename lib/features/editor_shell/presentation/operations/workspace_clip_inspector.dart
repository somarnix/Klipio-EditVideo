part of '../editor_application.dart';

/// Inspector controls edit the primary timeline instance through the same
/// timeline commands as the canvas. Draft numeric values stay in the control.
extension _WorkspaceClipInspector on _EditorScreenState {
  List<Widget> _clipSourceAudioControls() {
    final target = _professionalTargetClip();
    final linked = target == null
        ? null
        : _multiTrackTimeline.linkedAudioForVideo(target.clip.id);
    if (target == null || linked == null) {
      return const [
        Text(
            'No linked audio companion. Select independent audio on the timeline to edit it.')
      ];
    }
    return [
      const Text('Linked to this clip instance',
          style: TextStyle(fontSize: 11)),
      ..._selectedTimelineAudioControls(audioClipId: linked.id),
      OutlinedButton.icon(
          onPressed: target.track.isLocked ||
                  _multiTrackTimeline.clipById(linked.id)!.track.isLocked
              ? null
              : _extractSelectedClipAudio,
          icon: const Icon(Icons.link_off, size: 16),
          label: const Text('Detach audio')),
    ];
  }

  List<Widget> _clipCompositionControls() {
    final id = _selectedTimelineClipId;
    final target = id == null ? null : _multiTrackTimeline.clipById(id);
    if (target == null) return const [Text('Select a timeline layer.')];
    return [
      if (target.track.isLocked) const Text('Track locked'),
      if (_effectiveSelectedTimelineClipIds.length > 1)
        const Text('Editing the primary selected layer.'),
      ClipTransformControls(
        key: ValueKey('transform-${target.clip.id}'),
        transform:
            _transformPreview.valueFor(_multiTrackTimeline, target.clip.id) ??
                target.clip.transform,
        enabled: !target.track.isLocked,
        onPreview: (value) =>
            _updateProgramMonitorTransform(target.clip.id, value),
        onCancel: _cancelProgramTransform,
        onChanged: (transform) {
          final live = _multiTrackTimeline.clipById(target.clip.id);
          if (live == null ||
              live.track.isLocked ||
              _selectedTimelineClipId != live.clip.id) return;
          _commitTimelineModelChange(_timelineEditor.updateClipTransform(
              _multiTrackTimeline, live.clip.id, transform));
          if (live.track.type == TrackType.video) {
            _loadTimelineClipTransformIntoInspector(
                _multiTrackTimeline.clipById(live.clip.id)!.clip);
          }
        },
      ),
    ];
  }

  List<Widget> _clipMotionControls() {
    final id = _selectedTimelineClipId;
    final target = id == null ? null : _multiTrackTimeline.clipById(id);
    if (target == null) return const [];
    final programClip = _programEditingTimeline.clipById(target.clip.id)!.clip;
    final speed = target.clip.resolvedPlaybackSpeed();
    final offset =
        (_currentProgramSeconds() - programClip.timelineStart) * speed;
    final editable = !target.track.isLocked;
    final frames = [...target.clip.keyframes]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    final previous = frames.where((f) => f.offset < offset).lastOrNull;
    final next = frames.where((f) => f.offset > offset).firstOrNull;
    final atPlayhead = frames
        .where(
            (f) => TimelineBoundary.adjacent(f.offset / speed, offset / speed))
        .firstOrNull;
    return [
      const Text(
          'Set composition values, then capture a keyframe at the playhead. Between keyframes, the shared timeline resolver interpolates the layer.',
          style: TextStyle(fontSize: 11)),
      const SizedBox(height: 8),
      Row(children: [
        IconButton(
            tooltip: 'Previous keyframe',
            icon: const Icon(Icons.skip_previous),
            onPressed: previous == null
                ? null
                : () => _requestMultiTrackTimelineSeek(
                    programClip.timelineStart + previous.offset / speed)),
        IconButton(
            tooltip: 'Next keyframe',
            icon: const Icon(Icons.skip_next),
            onPressed: next == null
                ? null
                : () => _requestMultiTrackTimelineSeek(
                    programClip.timelineStart + next.offset / speed)),
        if (atPlayhead != null)
          TextButton.icon(
              icon: const Icon(Icons.diamond_outlined, size: 16),
              label: const Text('Remove current'),
              onPressed: !editable
                  ? null
                  : () => _commitTimelineModelChange(
                      _timelineEditor.removeClipKeyframe(_multiTrackTimeline,
                          target.clip.id, atPlayhead.offset))),
      ]),
      OutlinedButton.icon(
        icon: const Icon(Icons.diamond_outlined, size: 16),
        label: const Text('Capture at playhead'),
        onPressed: editable && offset >= 0 && offset < target.clip.duration
            ? () {
                _commitTimelineModelChange(_timelineEditor.setClipKeyframe(
                    _multiTrackTimeline,
                    target.clip.id,
                    ClipKeyframe(
                        offset: offset, transform: target.clip.transform)));
              }
            : null,
      ),
      if (frames.isEmpty)
        const Text('No composition keyframes', style: TextStyle(fontSize: 11)),
      for (final frame in frames)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.diamond_outlined, size: 16),
          title: Text(timelineEditTime(frame.offset / speed)),
          subtitle: Text(
              'Scale ${TransformDisplayUnits.percent(frame.transform.scaleX)} / ${TransformDisplayUnits.percent(frame.transform.scaleY)} · ${TransformDisplayUnits.degrees(frame.transform.rotationDegrees)}'),
          onTap: () => _requestMultiTrackTimelineSeek(
              programClip.timelineStart + frame.offset / speed),
          trailing: IconButton(
              tooltip: 'Remove keyframe',
              icon: const Icon(Icons.close, size: 16),
              onPressed: editable
                  ? () => _commitTimelineModelChange(
                      _timelineEditor.removeClipKeyframe(
                          _multiTrackTimeline, target.clip.id, frame.offset))
                  : null),
        ),
    ];
  }

  List<Widget> _transitionInspectorControls() {
    final target = _professionalTargetClip();
    final transition = target?.clip.transitionIn;
    if (target == null || transition == null) {
      return [
        const Text('No incoming transition on this clip.'),
        TextButton.icon(
            onPressed: target == null
                ? null
                : () => _openEffectsWorkspace(
                    _EffectsWorkspaceCategory.transitions),
            icon: const Icon(Icons.add),
            label: const Text('Browse transitions'))
      ];
    }
    return [
      ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.blur_on),
          title: Text(transition.type.label),
          subtitle: const Text('Incoming clip transition')),
      InspectorValueControl(
          key: ValueKey('transition-duration-${target.clip.id}'),
          label: 'Duration (seconds)',
          value: transition.duration / target.clip.resolvedPlaybackSpeed(),
          min: 0,
          max: 5 / target.clip.resolvedPlaybackSpeed(),
          divisions: 500,
          enabled: !target.track.isLocked,
          onChanged: (value) {
            if (value <= 0 || _selectedTimelineClipId != target.clip.id) return;
            // The production transition command owns adjacency and handle limits.
            _commitTransition(
                target.clip.id,
                ClipTransition(
                    type: transition.type,
                    duration: value * target.clip.resolvedPlaybackSpeed()));
          }),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
            onPressed: target.track.isLocked
                ? null
                : () => _openEffectsWorkspace(
                    _EffectsWorkspaceCategory.transitions),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Replace')),
        TextButton.icon(
            onPressed: target.track.isLocked ? null : _removeClipTransition,
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('Remove')),
      ]),
    ];
  }

  Future<void> _selectTimelineTransition(String clipId) async {
    await _selectMultiTrackClip(clipId);
    if (!mounted ||
        _selectedTimelineClipId != clipId ||
        _multiTrackTimeline.clipById(clipId)?.clip.transitionIn == null) return;
    _updateEditor(() {
      _editorSelection = EditorSelection.transition(clipId);
      _visibleWorkspacePanels.add('inspector');
      _compactWorkspacePanel = 'inspector';
    });
  }
}
