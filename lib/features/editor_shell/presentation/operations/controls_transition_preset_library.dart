part of '../editor_application.dart';

// controls operations owned by the editor state; extracted without changing timing.
extension _ControlsTransitionPresetLibrary on _EditorScreenState {
  Widget _transitionPresetLibrary() {
    const transitions = <(ClipTransitionType, IconData)>[
      (ClipTransitionType.dissolve, Icons.blur_on),
      (ClipTransitionType.fadeBlack, Icons.gradient),
      (ClipTransitionType.slideLeft, Icons.arrow_back),
      (ClipTransitionType.slideRight, Icons.arrow_forward),
      (ClipTransitionType.slideUp, Icons.arrow_upward),
      (ClipTransitionType.slideDown, Icons.arrow_downward),
    ];
    final target = _professionalTargetClip();
    final current = target?.clip.transitionIn;
    return CreativeBrowser<ClipTransitionType>(
      key: const ValueKey('transition-browser'),
      items: [
        for (final transition in transitions)
          CreativeBrowserItem(
              id: transition.$1.name,
              label: transition.$1.label,
              value: transition.$1,
              icon: transition.$2,
              tags: const ['transition']),
      ],
      selectedId: current?.type.name,
      disabledReason: target == null
          ? 'Select a video clip to apply a transition'
          : target.track.isLocked
              ? 'Unlock this track to apply a transition'
              : null,
      onApply: _applyClipTransition,
      onPreview: _previewClipTransition,
      onDiscard: _discardTransitionPreview,
      header: Row(
        children: [
          const Expanded(
            child: KText(
              'TRANSITIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          KText(
            target == null ? 'Select a video clip' : target.track.label,
            style: TextStyle(fontSize: 10, color: _mutedTextColor),
          ),
        ],
      ),
      footer: Column(children: [
        if (current != null) ...[
          const SizedBox(height: 6),
          _slider(
            'Transition duration',
            current.duration,
            0.1,
            2,
            (value) {
              _transitionDurationSeconds = value;
              _applyClipTransition(current.type, durationEdit: true);
            },
            divisions: 38,
            valueFormatter: (value) => '${value.toStringAsFixed(2)}s',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _removeClipTransition,
              icon: const Icon(Icons.link_off, size: 16),
              label: const KText('Remove transition'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        KText(
          'Apply a transition to the incoming clip. Klipio overlaps it with the previous clip on the same track and renders matching audio fades.',
          style: TextStyle(fontSize: 10, color: _mutedTextColor),
        ),
      ]),
    );
  }

  Future<void> _showSelectedLayerDialog() async {
    final clipId = _selectedTimelineClipId;
    if (clipId == null) return;
    final result = _multiTrackTimeline.clipById(clipId);
    if (result == null) return;
    var draft = result.clip.transform;
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget slider(
            String label,
            double value,
            double min,
            double max,
            ValueChanged<double> changed,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KText('$label: ${value.toStringAsFixed(2)}'),
                Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: changed,
                ),
              ],
            );
          }

          return AlertDialog(
            title: KText('${result.track.label} Layer Transform'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    slider('Opacity', draft.opacity, 0, 1, (value) {
                      setDialogState(
                        () => draft = draft.copyWith(opacity: value),
                      );
                    }),
                    slider('Scale X', draft.scaleX, 0.05, 3, (value) {
                      setDialogState(
                        () => draft = draft.copyWith(scaleX: value),
                      );
                    }),
                    slider('Scale Y', draft.scaleY, 0.05, 3, (value) {
                      setDialogState(
                        () => draft = draft.copyWith(scaleY: value),
                      );
                    }),
                    slider('Position X', draft.positionX, 0, 1, (value) {
                      setDialogState(
                        () => draft = draft.copyWith(positionX: value),
                      );
                    }),
                    slider('Position Y', draft.positionY, 0, 1, (value) {
                      setDialogState(
                        () => draft = draft.copyWith(positionY: value),
                      );
                    }),
                    slider(
                      'Rotation',
                      draft.rotationDegrees,
                      -180,
                      180,
                      (value) {
                        setDialogState(
                          () => draft = draft.copyWith(
                            rotationDegrees: value,
                          ),
                        );
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: draft.blendMode,
                      decoration: const InputDecoration(
                        labelText: 'Blend mode',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: [
                        for (final value in const [
                          'normal',
                          'multiply',
                          'screen',
                          'overlay',
                          'darken',
                          'lighten',
                          'difference',
                          'addition',
                        ])
                          DropdownMenuItem(
                            value: value,
                            child: KText(value),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(
                            () => draft = draft.copyWith(blendMode: value),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const KText('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.check),
                label: const KText('Apply layer'),
              ),
            ],
          );
        },
      ),
    );
    if (applied != true || !mounted) return;
    _updateEditor(() {
      _multiTrackTimeline = _timelineEditor.updateClipTransform(
        _multiTrackTimeline,
        clipId,
        draft,
      );
      _status = 'Layer transform updated';
    });
    unawaited(_autosaveProject());
  }

  double? _parseAssSeconds(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 3) return null;
    final hours = double.tryParse(parts[0]);
    final minutes = double.tryParse(parts[1]);
    final seconds = double.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return null;
    return hours * 3600 + minutes * 60 + seconds;
  }

  Widget _capCutDraftButton() {
    return OutlinedButton.icon(
      onPressed: _isExporting ? null : () => unawaited(_createCapCutDraft()),
      icon: const Icon(Icons.movie_creation_outlined),
      label: const KText('Create CapCut Draft'),
    );
  }

  Widget _capCutPrepareButton() {
    return OutlinedButton.icon(
      onPressed: _isExporting
          ? null
          : () => unawaited(_exportVideos(prepareForCapCut: true)),
      icon: const Icon(Icons.folder_copy_outlined),
      label: const KText('Prepare CapCut Clip Folder'),
    );
  }

  Widget _ratioSelector() {
    const ratios = ['original', '16:9', '9:16', '4:5', '1:1', '3:4', '4:3'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KText('Output ratio'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ratios.map((ratio) {
            final selected = ratio == _outputRatio;
            return ChoiceChip(
              selected: selected,
              label: KText(ratio == 'original' ? 'Original' : ratio),
              onSelected: (_) {
                _recordEditorHistory('output-ratio');
                _updateEditor(() => _outputRatio = ratio);
              },
              selectedColor: const Color(0xff1f6bff),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xffd1d5db),
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _layerTitle(_TextOverlayDraft overlay, int index) {
    final text = overlay.text.trim();
    return text.isEmpty ? 'Text ${index + 1}' : text;
  }

  Widget _statusRow() {
    return Row(
      children: [
        Icon(
          _exportAvailable ? Icons.check_circle_outline : Icons.info_outline,
          color: _exportAvailable ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: KText(
            _exportAvailable ? _status : 'Export needs FFmpeg.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) {
      return '--:--';
    }
    final whole = seconds.round();
    final h = whole ~/ 3600;
    final m = (whole % 3600) ~/ 60;
    final s = whole % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KText(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KText(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  KText(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int divisions = 20,
    String Function(double value)? valueFormatter,
    double? Function(String text)? valueParser,
  }) {
    return InspectorValueControl(
      key: ValueKey('${_editorSelection.kind}:${_editorSelection.id}:$label'),
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      valueFormatter: valueFormatter,
      valueParser: valueParser,
    );
  }

  Widget _speedPresets() {
    const presets = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final preset in presets)
            ChoiceChip(
              label: KText('${_speedLabel(preset)}x'),
              selected: (_speed - preset).abs() < 0.01,
              onSelected: (_) => unawaited(_setPreviewSpeed(preset)),
            ),
        ],
      ),
    );
  }

  String _speedLabel(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Widget _dropdown(String label, String value, List<String> values,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: KText(item),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
