part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineClipTimelineEditWithRanges on _EditorScreenState {
  _ClipTimelineEdit _clipTimelineEditWithRanges(
    _ClipTimelineEdit current,
    List<({double start, double end})> selectedRanges,
    double duration,
  ) {
    final normalized = selectedRanges
        .map(
          (range) => (
            start: range.start.clamp(0.0, duration).toDouble(),
            end: range.end.clamp(0.0, duration).toDouble(),
          ),
        )
        .where((range) => range.end > range.start)
        .toList();
    final boundaries = <double>{0, duration};
    for (final range in normalized) {
      boundaries
        ..add(range.start)
        ..add(range.end);
    }
    final sortedBoundaries = boundaries.toList()..sort();
    final splitPoints = sortedBoundaries
        .where((value) => value > 0.001 && value < duration - 0.001)
        .toList();
    final keepKeys = {
      for (final range in normalized)
        '${range.start.toStringAsFixed(3)}-${range.end.toStringAsFixed(3)}',
    };
    final deletedRanges = <({double start, double end})>[];
    for (var index = 0; index < sortedBoundaries.length - 1; index++) {
      final part = (
        start: sortedBoundaries[index],
        end: sortedBoundaries[index + 1],
      );
      final key =
          '${part.start.toStringAsFixed(3)}-${part.end.toStringAsFixed(3)}';
      if (!keepKeys.contains(key) && part.end > part.start) {
        deletedRanges.add(part);
      }
    }
    return current.copyWith(
      trimStartSeconds: 0,
      trimEndSeconds: duration,
      splitEverySeconds: 0,
      splitPoints: splitPoints,
      deletedRanges: deletedRanges,
      partOrder: normalized.map((range) => range.start).toList(),
    );
  }

  List<Widget> _selectedTimelineAudioControls({String? audioClipId}) {
    final id = audioClipId ?? _selectedTimelineClipId;
    if (audioClipId == null &&
        (_musicTimelineSelected || _editorSelection.id == 'music-track')) {
      return [
        _sectionTitle('Background Music'),
        _slider(
          'Volume',
          _musicVolume.clamp(0, _EditorScreenState._maxAudioBoost),
          0,
          _EditorScreenState._maxAudioBoost,
          (value) {
            if (_musicTrackLocked) return;
            _recordEditorHistory('music-volume', coalesce: false);
            _updateEditor(() => _musicVolume = value);
            unawaited(
              _musicPreviewPlayer.setVolume(
                _previewAudioVolume(_effectiveMusicVolume),
              ),
            );
            unawaited(_autosaveProject());
          },
          divisions: 100,
          valueFormatter: _EditorScreenState._volumeDbText,
          valueParser: _EditorScreenState._parseVolumeDb,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const KText('Mute music'),
          value: _musicTrackMuted,
          onChanged: (value) {
            if (_musicTrackLocked) return;
            _recordEditorHistory('music-mute', coalesce: false);
            _updateEditor(() => _musicTrackMuted = value);
            if (value) unawaited(_pauseMusicPreview());
            unawaited(_autosaveProject());
          },
        ),
        const SizedBox(height: 10),
        _propertySummaryRow('Track', 'M1'),
        _propertySummaryRow(
          'File',
          _musicPath == null
              ? 'No music selected'
              : platform.basename(_musicPath!),
        ),
      ];
    }
    final result = id == null ? null : _multiTrackTimeline.clipById(id);
    if (result == null || result.track.type != TrackType.audio) {
      return [
        KText(
          'Select an audio block on the timeline.',
          style: TextStyle(color: _mutedTextColor),
        ),
      ];
    }
    final clip = result.clip;
    final selectedAudioIds = (audioClipId == null
            ? _effectiveSelectedTimelineClipIds
            : {audioClipId})
        .where((clipId) {
      final selected = _multiTrackTimeline.clipById(clipId);
      return selected != null &&
          selected.track.type == TrackType.audio &&
          !selected.track.isLocked;
    }).toSet();
    if (selectedAudioIds.isEmpty) selectedAudioIds.add(clip.id);
    void update(ClipModel Function(ClipModel clip) change) {
      if (result.track.isLocked) {
        _showMessage('Unlock ${result.track.label} before editing audio.');
        return;
      }
      _recordEditorHistory('audio-properties', coalesce: false);
      _updateEditor(() {
        _multiTrackTimeline = _multiTrackTimeline.copyWith(
          tracks: [
            for (final track in _multiTrackTimeline.tracks)
              track.type == TrackType.audio && !track.isLocked
                  ? track.copyWith(
                      clips: [
                        for (final item in track.clips)
                          if (selectedAudioIds.contains(item.id))
                            change(item)
                          else
                            item,
                      ],
                    )
                  : track,
          ],
        );
        _status = selectedAudioIds.length > 1
            ? '${selectedAudioIds.length} audio clips updated'
            : '${result.track.label} audio updated';
      });
      unawaited(_autosaveProject());
    }

    return [
      if (result.track.isLocked)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.amber.withOpacity(0.45)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock, size: 17, color: Colors.amber),
              SizedBox(width: 7),
              Expanded(child: KText('Unlock this track to edit its audio.')),
            ],
          ),
        ),
      _sectionTitle('Clip Audio'),
      _slider(
        'Volume',
        clip.volume.clamp(0, _EditorScreenState._maxAudioBoost),
        0,
        _EditorScreenState._maxAudioBoost,
        (value) => update((item) => item.copyWith(volume: value)),
        divisions: 100,
        valueFormatter: _EditorScreenState._volumeDbText,
        valueParser: _EditorScreenState._parseVolumeDb,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const KText('Mute clip'),
        subtitle: KText(
          clip.isMuted ? 'This audio block is silent' : 'Audio is active',
          style: TextStyle(fontSize: 10, color: _mutedTextColor),
        ),
        value: clip.isMuted,
        onChanged: (value) => update(
          (item) => item.copyWith(isMuted: value),
        ),
      ),
      const SizedBox(height: 10),
      _sectionTitle('Timing'),
      _propertySummaryRow('Track', result.track.label),
      _propertySummaryRow('Start', _formatDuration(clip.timelineStart)),
      _propertySummaryRow('Duration', _formatDuration(clip.duration)),
      _propertySummaryRow('Source', _formatDuration(clip.sourceStart)),
    ];
  }

  ClipEffect? _clipAdjustment(
    ClipModel clip,
    ClipEffectType type,
  ) {
    for (final effect in clip.effects.reversed) {
      if (effect.type == type) return effect;
    }
    return null;
  }

  double _clipAdjustmentValue(ClipModel clip, ClipEffectType type) {
    final effect = _clipAdjustment(clip, type);
    return effect == null || !effect.enabled ? 0 : effect.amount;
  }

  void _setClipAdjustment(ClipEffectType type, double amount) {
    final target = _professionalTargetClip();
    if (target == null) return;
    if (!_ensureTimelineClipUnlocked(
      target.clip.id,
      action: 'adjusting this clip',
    )) {
      return;
    }
    final targets = _selectedProfessionalTargets();
    if (targets.isEmpty) return;
    _recordEditorHistory('adjust-${target.clip.id}-${type.name}');
    var next = _multiTrackTimeline;
    var serial = DateTime.now().microsecondsSinceEpoch;
    for (final selected in targets) {
      final current = next.clipById(selected.clip.id)?.clip ?? selected.clip;
      final existing = _clipAdjustment(current, type);
      if (existing == null && amount.abs() < 0.001) continue;
      if (existing == null) {
        next = _timelineEditor.addClipEffect(
          next,
          selected.clip.id,
          ClipEffect(
            id: 'adjust-${type.name}-${serial++}',
            type: type,
            amount: amount,
          ),
        );
      } else if (amount.abs() < 0.001) {
        next = _timelineEditor.removeClipEffect(
          next,
          selected.clip.id,
          existing.id,
        );
      } else {
        next = _timelineEditor.updateClipEffect(
          next,
          selected.clip.id,
          existing.id,
          (effect) => effect.copyWith(amount: amount, enabled: true),
        );
      }
    }
    _updateEditor(() {
      _multiTrackTimeline = next;
      _status = targets.length > 1
          ? '${type.label} updated on ${targets.length} clips'
          : '${type.label} updated on ${target.track.label}';
    });
    unawaited(_autosaveProject());
  }

  void _resetSelectedClipAdjustments() {
    final target = _professionalTargetClip();
    if (target == null) return;
    if (!_ensureTimelineClipUnlocked(
      target.clip.id,
      action: 'resetting adjustments',
    )) {
      return;
    }
    final removable = target.clip.effects
        .where((effect) =>
            _EditorScreenState._clipAdjustmentTypes.contains(effect.type))
        .toList();
    if (removable.isEmpty) return;
    _recordEditorHistory('adjust-reset-${target.clip.id}');
    var next = _multiTrackTimeline;
    for (final effect in removable) {
      next = _timelineEditor.removeClipEffect(
        next,
        target.clip.id,
        effect.id,
      );
    }
    _updateEditor(() {
      _multiTrackTimeline = next;
      _status = 'Adjustments reset on ${target.track.label}';
    });
    unawaited(_autosaveProject());
  }

  void _applyClipAdjustmentLook(
    String name,
    Map<ClipEffectType, double> values,
  ) {
    final target = _professionalTargetClip();
    if (target == null) return;
    if (!_ensureTimelineClipUnlocked(
      target.clip.id,
      action: 'applying this look',
    )) {
      return;
    }
    final targets = _selectedProfessionalTargets();
    _recordEditorHistory('adjust-look-${target.clip.id}');
    var next = _multiTrackTimeline;
    var serial = DateTime.now().microsecondsSinceEpoch;
    for (final selected in targets) {
      final current = next.clipById(selected.clip.id)?.clip ?? selected.clip;
      for (final effect in current.effects.where((effect) =>
          _EditorScreenState._clipAdjustmentTypes.contains(effect.type))) {
        next = _timelineEditor.removeClipEffect(
          next,
          selected.clip.id,
          effect.id,
        );
      }
      for (final entry in values.entries.where((entry) => entry.value != 0)) {
        next = _timelineEditor.addClipEffect(
          next,
          selected.clip.id,
          ClipEffect(
            id: 'look-${entry.key.name}-${serial++}',
            type: entry.key,
            amount: entry.value,
          ),
        );
      }
    }
    _updateEditor(() {
      _multiTrackTimeline = next;
      _status = targets.length > 1
          ? '$name adjustments applied to ${targets.length} clips'
          : '$name adjustments applied to ${target.track.label}';
    });
    unawaited(_autosaveProject());
  }

  Widget _clipAdjustmentSlider(
    ClipModel clip,
    ClipEffectType type, {
    double min = -1,
    double max = 1,
  }) {
    return _slider(
      type.label,
      _clipAdjustmentValue(clip, type).clamp(min, max),
      min,
      max,
      (value) => _setClipAdjustment(type, value),
      divisions: 40,
    );
  }

  Widget _clipAdjustmentLibrary() {
    final target = _professionalTargetClip();
    if (target == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 36, color: _mutedTextColor),
              const SizedBox(height: 10),
              const KText(
                'Select a timeline clip',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              KText(
                'Select a video clip to open its complete adjustment controls.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _mutedTextColor),
              ),
            ],
          ),
        ),
      );
    }
    final clip = target.clip;
    final activeCount = clip.effects
        .where((effect) =>
            effect.enabled &&
            _EditorScreenState._clipAdjustmentTypes.contains(effect.type))
        .length;
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _controlSurfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _panelBorderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.video_settings_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KText(
                      platform.basename(clip.mediaPath),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    KText(
                      '${target.track.label} • $activeCount active adjustments',
                      style: TextStyle(fontSize: 10, color: _mutedTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const KText(
          'QUICK LOOKS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              label: const KText('Original'),
              onPressed: _resetSelectedClipAdjustments,
            ),
            ActionChip(
              label: const KText('Clean'),
              onPressed: () => _applyClipAdjustmentLook('Clean', const {
                ClipEffectType.exposure: 0.06,
                ClipEffectType.contrast: 0.14,
                ClipEffectType.saturation: 0.10,
                ClipEffectType.sharpen: 0.12,
              }),
            ),
            ActionChip(
              label: const KText('Warm'),
              onPressed: () => _applyClipAdjustmentLook('Warm', const {
                ClipEffectType.temperature: 0.36,
                ClipEffectType.exposure: 0.06,
                ClipEffectType.saturation: 0.14,
              }),
            ),
            ActionChip(
              label: const KText('Cool'),
              onPressed: () => _applyClipAdjustmentLook('Cool', const {
                ClipEffectType.temperature: -0.36,
                ClipEffectType.tint: -0.08,
                ClipEffectType.contrast: 0.12,
              }),
            ),
            ActionChip(
              label: const KText('Cinema'),
              onPressed: () => _applyClipAdjustmentLook('Cinema', const {
                ClipEffectType.brightness: -0.08,
                ClipEffectType.contrast: 0.42,
                ClipEffectType.saturation: -0.12,
                ClipEffectType.vignette: 0.28,
              }),
            ),
            ActionChip(
              label: const KText('Mono'),
              onPressed: () => _applyClipAdjustmentLook('Mono', const {
                ClipEffectType.grayscale: 1,
                ClipEffectType.contrast: 0.25,
              }),
            ),
            ActionChip(
              label: const KText('Vintage'),
              onPressed: () => _applyClipAdjustmentLook('Vintage', const {
                ClipEffectType.temperature: 0.28,
                ClipEffectType.saturation: -0.22,
                ClipEffectType.fade: 0.35,
                ClipEffectType.vignette: 0.24,
              }),
            ),
            ActionChip(
              label: const KText('Teal & Orange'),
              onPressed: () => _applyClipAdjustmentLook('Teal & Orange', const {
                ClipEffectType.temperature: 0.18,
                ClipEffectType.tint: -0.24,
                ClipEffectType.contrast: 0.30,
                ClipEffectType.saturation: 0.16,
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const KText(
          'COLOR',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        _clipAdjustmentSlider(clip, ClipEffectType.temperature),
        _clipAdjustmentSlider(clip, ClipEffectType.tint),
        _clipAdjustmentSlider(clip, ClipEffectType.saturation),
        const SizedBox(height: 10),
        const KText(
          'LIGHT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        _clipAdjustmentSlider(clip, ClipEffectType.exposure),
        _clipAdjustmentSlider(clip, ClipEffectType.brightness),
        _clipAdjustmentSlider(clip, ClipEffectType.contrast),
        _clipAdjustmentSlider(clip, ClipEffectType.highlights),
        _clipAdjustmentSlider(clip, ClipEffectType.shadows),
        _clipAdjustmentSlider(clip, ClipEffectType.whites),
        _clipAdjustmentSlider(clip, ClipEffectType.blacks),
        _clipAdjustmentSlider(clip, ClipEffectType.brilliance),
        _clipAdjustmentSlider(clip, ClipEffectType.gamma),
        const SizedBox(height: 10),
        const KText(
          'DETAIL & STYLE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        _clipAdjustmentSlider(
          clip,
          ClipEffectType.sharpen,
          min: 0,
          max: 2,
        ),
        _clipAdjustmentSlider(
          clip,
          ClipEffectType.clarity,
          min: 0,
          max: 2,
        ),
        _clipAdjustmentSlider(
          clip,
          ClipEffectType.fade,
          min: 0,
          max: 2,
        ),
        _clipAdjustmentSlider(
          clip,
          ClipEffectType.vignette,
          min: 0,
          max: 2,
        ),
        _clipAdjustmentSlider(
          clip,
          ClipEffectType.blur,
          min: 0,
          max: 2,
        ),
        _clipAdjustmentSlider(
          clip,
          ClipEffectType.hueRotate,
          min: 0,
          max: 2,
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    activeCount == 0 ? null : _resetSelectedClipAdjustments,
                icon: const Icon(Icons.restart_alt),
                label: const KText('Reset'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    activeCount == 0 ? null : _applyAdjustmentsToAllClips,
                icon: const Icon(Icons.copy_all_outlined),
                label: const KText('Apply to all'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _applyAdjustmentsToAllClips() {
    final target = _professionalTargetClip();
    if (target == null) return;
    final source = target.clip.effects
        .where((effect) =>
            _EditorScreenState._clipAdjustmentTypes.contains(effect.type))
        .toList();
    if (source.isEmpty) return;
    _recordEditorHistory('adjust-apply-all');
    var serial = DateTime.now().microsecondsSinceEpoch;
    var next = _multiTrackTimeline;
    for (final track in next.videoTracks) {
      if (track.isLocked) continue;
      next = _timelineEditor.updateTrack(
        next,
        track.id,
        (current) => current.copyWith(
          clips: [
            for (final clip in current.clips)
              clip.copyWith(
                effects: [
                  ...clip.effects.where(
                    (effect) => !_EditorScreenState._clipAdjustmentTypes
                        .contains(effect.type),
                  ),
                  for (final effect in source)
                    ClipEffect(
                      id: 'adjust-all-${serial++}',
                      type: effect.type,
                      amount: effect.amount,
                      enabled: effect.enabled,
                    ),
                ],
              ),
          ],
        ),
      );
    }
    _updateEditor(() {
      _multiTrackTimeline = next;
      _status = 'Adjustments applied to all unlocked video clips';
    });
    unawaited(_autosaveProject());
  }
}
