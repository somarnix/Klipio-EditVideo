part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineProfessionalTargetClip on _EditorScreenState {
  ({TrackModel track, ClipModel clip})? _professionalTargetClip() {
    final selectedId = _selectedTimelineClipId;
    if (selectedId != null) {
      final selected = _multiTrackTimeline.clipById(selectedId);
      if (selected != null && selected.track.type == TrackType.video) {
        return selected;
      }
      // An explicit non-video/stale selection must not edit another clip.
      return null;
    }
    final active = _activeBaseVideoClip(_currentProgramSeconds());
    if (active == null) return null;
    return _multiTrackTimeline.clipById(active.id);
  }

  IconData _clipEffectIcon(ClipEffectType type) => switch (type) {
        ClipEffectType.temperature => Icons.thermostat_outlined,
        ClipEffectType.tint => Icons.colorize_outlined,
        ClipEffectType.exposure => Icons.exposure_outlined,
        ClipEffectType.brightness => Icons.brightness_6_outlined,
        ClipEffectType.contrast => Icons.contrast,
        ClipEffectType.highlights => Icons.light_mode_outlined,
        ClipEffectType.shadows => Icons.dark_mode_outlined,
        ClipEffectType.whites => Icons.wb_sunny_outlined,
        ClipEffectType.blacks => Icons.nights_stay_outlined,
        ClipEffectType.brilliance => Icons.auto_awesome_outlined,
        ClipEffectType.saturation => Icons.color_lens_outlined,
        ClipEffectType.gamma => Icons.tonality_outlined,
        ClipEffectType.clarity => Icons.hdr_strong_outlined,
        ClipEffectType.fade => Icons.gradient_outlined,
        ClipEffectType.grayscale => Icons.filter_b_and_w,
        ClipEffectType.sepia => Icons.coffee_outlined,
        ClipEffectType.blur => Icons.blur_on,
        ClipEffectType.sharpen => Icons.details_outlined,
        ClipEffectType.vignette => Icons.vignette,
        ClipEffectType.invert => Icons.invert_colors,
        ClipEffectType.glitch => Icons.broken_image_outlined,
        ClipEffectType.hueRotate => Icons.filter_alt,
      };

  Widget _clipEffectsLibrary() {
    final target = _professionalTargetClip();
    final activeEffects = target?.clip.effects
            .where((effect) =>
                !_EditorScreenState._clipAdjustmentTypes.contains(effect.type))
            .toList() ??
        const <ClipEffect>[];
    const styles = <(
      String,
      String,
      IconData,
      List<(ClipEffectType, double)>,
      Color,
      Color
    )>[
      (
        'Soft Glow',
        'Portrait',
        Icons.flare,
        [(ClipEffectType.blur, 0.16), (ClipEffectType.brilliance, 0.32)],
        Color(0xfff9a8d4),
        Color(0xff7c3aed)
      ),
      (
        'VHS Glitch',
        'Retro',
        Icons.broken_image_outlined,
        [(ClipEffectType.glitch, 0.70), (ClipEffectType.saturation, 0.22)],
        Color(0xffef4444),
        Color(0xff06b6d4)
      ),
      (
        'Dreamy',
        'Atmosphere',
        Icons.cloud_outlined,
        [
          (ClipEffectType.blur, 0.12),
          (ClipEffectType.fade, 0.30),
          (ClipEffectType.tint, 0.18)
        ],
        Color(0xffc4b5fd),
        Color(0xff60a5fa)
      ),
      (
        'Noir',
        'Classic',
        Icons.filter_b_and_w,
        [
          (ClipEffectType.grayscale, 1),
          (ClipEffectType.contrast, 0.38),
          (ClipEffectType.vignette, 0.34)
        ],
        Color(0xff6b7280),
        Color(0xff111827)
      ),
      (
        'Vintage Film',
        'Retro',
        Icons.movie_filter_outlined,
        [
          (ClipEffectType.sepia, 0.82),
          (ClipEffectType.fade, 0.28),
          (ClipEffectType.vignette, 0.24)
        ],
        Color(0xfff59e0b),
        Color(0xff78350f)
      ),
      (
        'Cyber Hue',
        'Creative',
        Icons.auto_awesome_outlined,
        [
          (ClipEffectType.hueRotate, 1.05),
          (ClipEffectType.saturation, 0.44),
          (ClipEffectType.glitch, 0.18)
        ],
        Color(0xff22d3ee),
        Color(0xffa855f7)
      ),
      (
        'Crisp Detail',
        'Enhance',
        Icons.hdr_strong_outlined,
        [
          (ClipEffectType.sharpen, 0.42),
          (ClipEffectType.clarity, 0.48),
          (ClipEffectType.contrast, 0.14)
        ],
        Color(0xff38bdf8),
        Color(0xff0f766e)
      ),
      (
        'Spotlight',
        'Focus',
        Icons.vignette,
        [(ClipEffectType.vignette, 0.70), (ClipEffectType.brilliance, 0.20)],
        Color(0xfffacc15),
        Color(0xff1e293b)
      ),
      (
        'Negative',
        'Creative',
        Icons.invert_colors,
        [(ClipEffectType.invert, 1)],
        Color(0xfff8fafc),
        Color(0xff0f172a)
      ),
      (
        'Heatwave',
        'Color',
        Icons.thermostat,
        [(ClipEffectType.temperature, 0.68), (ClipEffectType.saturation, 0.28)],
        Color(0xfffb923c),
        Color(0xffdc2626)
      ),
    ];
    return AssetBrowserShell(
      key: const ValueKey('effects-asset-browser'),
      items: styles,
      searchText: (style) => '${style.$1} ${style.$2}',
      categoryOf: (style) => style.$2,
      searchLabel: 'Search effects',
      onViewChanged: _discardEffectPreview,
      toolbar: Padding(
          padding: const EdgeInsets.all(10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KText('CLIP EFFECTS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                target == null
                    ? 'Select a timeline video to apply effects'
                    : target.track.isLocked
                        ? 'Unlock the selected track to apply effects'
                        : 'Preview a style, then click to apply',
                style: Theme.of(context).textTheme.bodySmall),
          ])),
      itemBuilder: (context, style, layout) => EffectPreviewInteraction(
        enabled: target != null && !target.track.isLocked,
        preview: () => _previewClipEffectStyle(style.$4),
        discard: _discardEffectPreview,
        apply: () => _applyClipEffectStyle(style.$1, style.$4),
        child: Container(
          margin: EdgeInsets.only(
              bottom: layout == AssetBrowserLayout.list ? 6 : 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [style.$5.withOpacity(0.82), style.$6]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: layout == AssetBrowserLayout.list
              ? Row(children: [
                  Icon(style.$3, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(style.$1,
                          style: const TextStyle(color: Colors.white))),
                  Text(style.$2,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10))
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Icon(style.$3, color: Colors.white),
                      Text(style.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      Text(style.$2,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
                    ]),
        ),
      ),
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        KText(
          target == null
              ? 'Select a timeline video before adding an effect.'
              : 'Click a style to add it. Manage the active stack below.',
          style: TextStyle(fontSize: 10, color: _mutedTextColor),
        ),
        if (activeEffects.isNotEmpty) ...[
          const SizedBox(height: 14),
          const KText(
            'ACTIVE EFFECTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          for (final effect in activeEffects) _activeClipEffectTile(effect),
        ],
        if (target != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: KText(
                  'MOTION KEYFRAMES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              KText(
                '${target.clip.keyframes.length}',
                style: TextStyle(fontSize: 10, color: _mutedTextColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _addTransformKeyframe,
                  icon: const Icon(Icons.diamond_outlined, size: 16),
                  label: const KText('Add keyframe'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Remove nearest keyframe',
                onPressed: target.clip.keyframes.isEmpty
                    ? null
                    : _removeNearestTransformKeyframe,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
      ]),
    );
  }

  void _discardEffectPreview() {
    if (!mounted) return;
    _updateEditor(_effectPreview.discard);
  }

  void _previewClipEffectStyle(List<(ClipEffectType, double)> effects) {
    final target = _professionalTargetClip();
    if (target == null) return;
    final token = _effectPreview.begin(_multiTrackTimeline, target.clip.id);
    if (token == null) return;
    _updateEditor(() {
      _effectPreview.complete(token, _multiTrackTimeline, [
        for (final entry in effects.indexed)
          ClipEffect(
              id: 'preview-${token.generation}-${entry.$1}',
              type: entry.$2.$1,
              amount: entry.$2.$2),
      ]);
    });
  }

  bool _commitEffectEdit(EffectEdit? edit, String key, String status,
      {bool coalesce = false}) {
    final applied = _session.commitEffect(edit,
        beforeChange: () => _recordEditorHistory(key, coalesce: coalesce));
    if (!applied) return false;
    _updateEditor(() {
      _effectPreview.discard();
      _status = status;
    });
    unawaited(_autosaveProject());
    return true;
  }

  void _applyClipEffectStyle(
      String name, List<(ClipEffectType, double)> effects) {
    final target = _professionalTargetClip();
    if (target == null) return;
    final selectedIds = _effectiveSelectedTimelineClipIds;
    final targets = selectedIds.isEmpty
        ? [target]
        : [
            for (final id in selectedIds)
              if (_multiTrackTimeline.clipById(id) case final item?) item
          ];
    if (selectedIds.isNotEmpty && targets.length != selectedIds.length) return;
    var serial = DateTime.now().microsecondsSinceEpoch;
    // Existing product semantics deliberately stack a new instance per click.
    // Validate the entire selection before recording history or changing any clip.
    final edit = EffectEdit.apply(_multiTrackTimeline, {
      for (final selected in targets)
        selected.clip.id: [
          for (final entry in effects)
            ClipEffect(
                id: 'style-${serial++}', type: entry.$1, amount: entry.$2),
        ],
    });
    if (!_commitEffectEdit(edit, 'effect-apply', '$name applied')) {
      _discardEffectPreview();
      _showMessage('Effect not applied: select unlocked video clips.');
    }
  }

  Widget _activeClipEffectTile(ClipEffect effect) {
    final signedAmount = {
      ClipEffectType.temperature,
      ClipEffectType.tint,
      ClipEffectType.exposure,
      ClipEffectType.brightness,
      ClipEffectType.contrast,
      ClipEffectType.highlights,
      ClipEffectType.shadows,
      ClipEffectType.whites,
      ClipEffectType.blacks,
      ClipEffectType.brilliance,
      ClipEffectType.saturation,
      ClipEffectType.gamma,
    }.contains(effect.type);
    final minimum = signedAmount ? -1.0 : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: _controlSurfaceColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 3, 6),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_clipEffectIcon(effect.type), size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: KText(
                    effect.type.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: effect.enabled,
                  onChanged: (enabled) =>
                      _updateClipEffect(effect.id, enabled: enabled),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove effect',
                  onPressed: () => _removeClipEffect(effect.id),
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
            if (effect.type != ClipEffectType.invert)
              Row(
                children: [
                  const KText('Amount', style: TextStyle(fontSize: 10)),
                  Expanded(
                    child: Slider(
                      value: effect.amount.clamp(minimum, 2),
                      min: minimum,
                      max: 2,
                      divisions: signedAmount ? 60 : 40,
                      onChanged: (amount) =>
                          _updateClipEffect(effect.id, amount: amount),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: KText(
                      effect.amount.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _updateClipEffect(String effectId, {double? amount, bool? enabled}) {
    final target = _professionalTargetClip();
    if (target == null) return;
    _commitEffectEdit(
        EffectEdit.change(_multiTrackTimeline, target.clip.id, effectId,
            amount: amount, enabled: enabled),
        'effect-$effectId',
        'Effect stack updated',
        coalesce: amount != null);
  }

  void _removeClipEffect(String effectId) {
    final target = _professionalTargetClip();
    if (target == null) return;
    _commitEffectEdit(
        EffectEdit.change(_multiTrackTimeline, target.clip.id, effectId,
            remove: true),
        'effect-remove',
        'Effect removed');
  }

  void _discardTransitionPreview() {
    if (mounted) _updateEditor(_transitionPreview.discard);
  }

  void _previewClipTransition(ClipTransitionType type) {
    final target = _professionalTargetClip();
    if (target == null) return;
    _updateEditor(() {
      _effectPreview.discard();
      final token =
          _transitionPreview.begin(_multiTrackTimeline, target.clip.id);
      _transitionPreview.complete(token, _multiTrackTimeline,
          ClipTransition(type: type, duration: _transitionDurationSeconds));
    });
  }

  void _commitTransition(String clipId, ClipTransition? value,
      {bool durationEdit = false}) {
    final edit = TransitionEdit.prepare(_multiTrackTimeline, clipId, value);
    final changed = _session.commitTransition(edit,
        beforeChange: () =>
            _recordEditorHistory('transition-$clipId', coalesce: durationEdit));
    _updateEditor(() {
      _transitionPreview.discard();
      _effectPreview.discard();
      _status = changed
          ? (value == null ? 'Transition removed' : 'Transition applied')
          : 'Transition unchanged: select an unlocked adjacent pair';
    });
    if (changed) unawaited(_autosaveProject());
  }

  void _applyClipTransition(ClipTransitionType type,
      {bool durationEdit = false}) {
    final target = _professionalTargetClip();
    if (target == null) return;
    _commitTransition(target.clip.id,
        ClipTransition(type: type, duration: _transitionDurationSeconds),
        durationEdit: durationEdit);
  }

  void _removeClipTransition() {
    final target = _professionalTargetClip();
    if (target != null) _commitTransition(target.clip.id, null);
  }
}
