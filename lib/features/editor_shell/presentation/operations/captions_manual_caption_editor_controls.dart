part of '../editor_application.dart';

// captions operations owned by the editor state; extracted without changing timing.
extension _CaptionsManualCaptionEditorControls on _EditorScreenState {
  Widget _manualCaptionEditorControls() {
    final cues = _selectedCaptionCues;
    final selected = _selectedCaptionCueIndex.clamp(0, cues.length - 1);
    final cue = cues[selected];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Caption cue on T1',
                prefixIcon: Icon(Icons.subtitles_outlined),
              ),
              items: [
                for (var index = 0; index < cues.length; index++)
                  DropdownMenuItem(
                    value: index,
                    child: KText(
                      '${index + 1}. ${_formatDuration(cues[index].start)}  ${cues[index].text}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateEditor(() {
                    _selectedCaptionCueIndex = value;
                    _editorSelection = EditorSelection.caption(
                      _captionTimelineId(
                        _videos[_selectedVideoIndex].path,
                        value,
                      ),
                      label: cues[value].text,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            KText(
              '${_subtitleTime(cue.start, comma: false)} → ${_subtitleTime(cue.end, comma: false)}',
              style: TextStyle(color: _mutedTextColor, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _showCaptionCueEditor(index: selected),
                  icon: const Icon(Icons.edit_outlined),
                  label: const KText('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: _splitSelectedCaptionCue,
                  icon: const Icon(Icons.call_split_outlined),
                  label: const KText('Split'),
                ),
                OutlinedButton.icon(
                  onPressed: cues.length < 2 ? null : _mergeSelectedCaptionCue,
                  icon: const Icon(Icons.merge_outlined),
                  label: const KText('Merge'),
                ),
                OutlinedButton.icon(
                  onPressed: _deleteSelectedCaptionCue,
                  icon: const Icon(Icons.delete_outline),
                  label: const KText('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _CaptionPreset _captionPreset(String id) {
    return _captionPresets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => _captionPresets.first,
    );
  }

  List<Shadow> _captionTextShadows(
    _CaptionPreset preset,
    double scale, {
    bool custom = false,
  }) {
    final resolved = _resolvedCaptionStyle;
    final outlineSource = custom ? resolved.strokeWidth : preset.outline;
    final shadowSource = custom ? resolved.shadowBlur : preset.shadow;
    final outline = (outlineSource * scale).clamp(0.0, 18.0).toDouble();
    final shadow = (shadowSource * scale).clamp(0.0, 20.0).toDouble();
    final outlineColor = custom ? resolved.strokeColor : preset.outlineColor;
    final shadowColor = custom ? resolved.shadowColor : preset.outlineColor;
    final shadows = <Shadow>[];
    if (outline > 0) {
      for (final offset in const [
        Offset(-1, -1),
        Offset(0, -1),
        Offset(1, -1),
        Offset(-1, 0),
        Offset(1, 0),
        Offset(-1, 1),
        Offset(0, 1),
        Offset(1, 1),
      ]) {
        shadows.add(
          Shadow(
            color: outlineColor,
            blurRadius: outline * 0.25,
            offset: Offset(offset.dx * outline, offset.dy * outline),
          ),
        );
      }
    }
    if (shadow > 0) {
      shadows.add(
        Shadow(
          color: shadowColor.withOpacity(0.82),
          blurRadius: shadow,
          offset: custom
              ? Offset(
                  resolved.shadowOffsetX * scale,
                  resolved.shadowOffsetY * scale,
                )
              : Offset(shadow * 0.7, shadow * 0.9),
        ),
      );
    }
    if (custom && _captionGlowEnabled && _captionGlowStrength > 0) {
      shadows.addAll([
        Shadow(
          color: _captionGlowColor.withOpacity(0.9),
          blurRadius:
              (_captionGlowStrength * scale).clamp(0.5, 35.0).toDouble(),
        ),
        Shadow(
          color: _captionGlowColor.withOpacity(0.55),
          blurRadius:
              (_captionGlowStrength * scale * 1.8).clamp(1.0, 50.0).toDouble(),
        ),
      ]);
    }
    return shadows;
  }

  Widget _captionTypographyControls({
    required bool bold,
    required bool underline,
    required bool italic,
    required String letterCase,
    required Color color,
    required double characterSpacing,
    required double wordSpacing,
    required double lineSpacing,
    required ValueChanged<bool> onBold,
    required ValueChanged<bool> onUnderline,
    required ValueChanged<bool> onItalic,
    required ValueChanged<String> onCase,
    required ValueChanged<Color> onColor,
    required ValueChanged<double> onCharacterSpacing,
    required ValueChanged<double> onWordSpacing,
    required ValueChanged<double> onLineSpacing,
  }) {
    Widget patternButton({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onPressed,
    }) {
      return Tooltip(
        message: label,
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor:
                selected ? _controlSelectedColor : _controlSurfaceColor,
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : _controlBorderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: Icon(icon, size: 20),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 76, child: KText('Pattern')),
            patternButton(
              label: 'Bold',
              icon: Icons.format_bold,
              selected: bold,
              onPressed: () => onBold(!bold),
            ),
            const SizedBox(width: 7),
            patternButton(
              label: 'Underline',
              icon: Icons.format_underline,
              selected: underline,
              onPressed: () => onUnderline(!underline),
            ),
            const SizedBox(width: 7),
            patternButton(
              label: 'Italic',
              icon: Icons.format_italic,
              selected: italic,
              onPressed: () => onItalic(!italic),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 76, child: KText('Case')),
            Expanded(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'upper', label: KText('TT')),
                  ButtonSegment(value: 'lower', label: KText('tt')),
                  ButtonSegment(value: 'title', label: KText('Tt')),
                  ButtonSegment(value: 'original', label: KText('Aa')),
                ],
                selected: {letterCase},
                onSelectionChanged: (value) => onCase(value.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _colorSelector('Caption color', color, onColor),
        _EditableSlider(
          label: 'Character spacing',
          value: characterSpacing,
          min: -20,
          max: 100,
          divisions: 120,
          onChanged: onCharacterSpacing,
        ),
        _EditableSlider(
          label: 'Word spacing',
          value: wordSpacing,
          min: 0,
          max: 100,
          divisions: 100,
          onChanged: onWordSpacing,
        ),
        _EditableSlider(
          label: 'Line spacing',
          value: lineSpacing,
          min: -20,
          max: 100,
          divisions: 120,
          onChanged: onLineSpacing,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _captionEffectsControls() {
    Widget section({
      required String title,
      required bool enabled,
      required ValueChanged<bool> onChanged,
      required List<Widget> children,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _controlSurfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _controlBorderColor),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(
            children: [
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                controlAffinity: ListTileControlAffinity.leading,
                value: enabled,
                onChanged: (value) => onChanged(value ?? false),
                title: KText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (enabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Column(children: children),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KText(
          'Caption effects',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _EditableSlider(
          label: 'Opacity',
          value: _captionOpacity * 100,
          min: 0,
          max: 100,
          divisions: 100,
          valueFormatter: (value) => '${value.round()}%',
          onChanged: (value) =>
              _updateEditor(() => _captionOpacity = value / 100),
        ),
        section(
          title: 'Stroke',
          enabled: _captionStrokeEnabled,
          onChanged: (value) =>
              _updateEditor(() => _captionStrokeEnabled = value),
          children: [
            _colorSelector(
              'Stroke color',
              _captionStrokeColor,
              (value) => _updateEditor(() => _captionStrokeColor = value),
            ),
            _EditableSlider(
              label: 'Stroke width',
              value: _captionStrokeWidth,
              min: 0,
              max: 30,
              divisions: 60,
              onChanged: (value) =>
                  _updateEditor(() => _captionStrokeWidth = value),
            ),
          ],
        ),
        section(
          title: 'Background',
          enabled: _captionBackgroundEnabled,
          onChanged: (value) =>
              _updateEditor(() => _captionBackgroundEnabled = value),
          children: [
            _colorSelector(
              'Background color',
              _captionBackgroundColor,
              (value) => _updateEditor(() => _captionBackgroundColor = value),
            ),
            _EditableSlider(
              label: 'Background opacity',
              value: _captionBackgroundOpacity * 100,
              min: 0,
              max: 100,
              divisions: 100,
              valueFormatter: (value) => '${value.round()}%',
              onChanged: (value) =>
                  _updateEditor(() => _captionBackgroundOpacity = value / 100),
            ),
            _EditableSlider(
              label: 'Background padding',
              value: _captionBackgroundPadding,
              min: 0,
              max: 60,
              divisions: 60,
              onChanged: (value) =>
                  _updateEditor(() => _captionBackgroundPadding = value),
            ),
          ],
        ),
        section(
          title: 'Glow',
          enabled: _captionGlowEnabled,
          onChanged: (value) =>
              _updateEditor(() => _captionGlowEnabled = value),
          children: [
            _colorSelector(
              'Glow color',
              _captionGlowColor,
              (value) => _updateEditor(() => _captionGlowColor = value),
            ),
            _EditableSlider(
              label: 'Glow strength',
              value: _captionGlowStrength,
              min: 0,
              max: 40,
              divisions: 80,
              onChanged: (value) =>
                  _updateEditor(() => _captionGlowStrength = value),
            ),
          ],
        ),
        section(
          title: 'Shadow',
          enabled: _captionShadowEnabled,
          onChanged: (value) =>
              _updateEditor(() => _captionShadowEnabled = value),
          children: [
            _colorSelector(
              'Shadow color',
              _captionShadowColor,
              (value) => _updateEditor(() => _captionShadowColor = value),
            ),
            _EditableSlider(
              label: 'Shadow strength',
              value: _captionShadowStrength,
              min: 0,
              max: 30,
              divisions: 60,
              onChanged: (value) =>
                  _updateEditor(() => _captionShadowStrength = value),
            ),
          ],
        ),
        section(
          title: 'Curve',
          enabled: _captionCurve.abs() > 0.01,
          onChanged: (value) =>
              _updateEditor(() => _captionCurve = value ? 35 : 0),
          children: [
            _EditableSlider(
              label: 'Curve amount',
              value: _captionCurve,
              min: -100,
              max: 100,
              divisions: 200,
              onChanged: (value) => _updateEditor(() => _captionCurve = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
