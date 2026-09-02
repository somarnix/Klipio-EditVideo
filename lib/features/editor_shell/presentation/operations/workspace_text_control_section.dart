part of '../editor_application.dart';

// workspace operations owned by the editor state; extracted without changing timing.
extension _WorkspaceTextControlSection on _EditorScreenState {
  List<Widget> _textControlSection({bool includeLayerPicker = true}) {
    final textLocked = _selectedTextOverlayIndex >= 0 &&
        _selectedTextOverlayIndex < _textOverlays.length &&
        _textOverlays[_selectedTextOverlayIndex].isLocked;
    return [
      if (textLocked)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0x22f59e0b),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0x88f59e0b)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock, size: 16, color: Color(0xfff59e0b)),
              SizedBox(width: 7),
              Expanded(child: KText('Unlock this text track to edit it.')),
            ],
          ),
        ),
      if (includeLayerPicker)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedTextOverlayIndex,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Text layer',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var index = 0; index < _textOverlays.length; index++)
                    DropdownMenuItem(
                      value: index,
                      child: KText(
                        '${index + 1}. ${_layerTitle(_textOverlays[index], index)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _selectTextOverlay(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _addTextOverlay,
              icon: const Icon(Icons.add),
              tooltip: 'Add text',
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _duplicateTextOverlay,
              icon: const Icon(Icons.copy),
              tooltip: 'Duplicate text',
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: _textOverlays.every((item) => item.text.trim().isEmpty)
                  ? null
                  : _deleteTextOverlay,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete text',
            ),
          ],
        ),
      if (includeLayerPicker) const SizedBox(height: 10),
      TextField(
        controller: _overlayTextController,
        minLines: 2,
        maxLines: 6,
        enabled: !textLocked,
        onTap: () => _recordEditorHistory('text-content'),
        decoration: const InputDecoration(
          labelText: 'Text',
          helperText: 'Leave empty for no text',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.text_fields),
        ),
        onChanged: (_) {
          _updateEditor(() {
            if (_selectedTextOverlayIndex >= 0 &&
                _selectedTextOverlayIndex < _textOverlays.length) {
              final next = _currentTextOverlayDraft();
              _textOverlays[_selectedTextOverlayIndex] = next;
              _insertTextTimelineClip(next);
            }
          });
        },
      ),
      const SizedBox(height: 10),
      _fontDropdown(
        'Font',
        _overlayFont,
        (value) => _updateTextControl(
          'text-font',
          () => _overlayFont = value,
        ),
      ),
      _slider(
        'Text size',
        _overlayTextSize,
        16,
        96,
        (value) => _updateTextControl(
          'text-size',
          () => _overlayTextSize = value,
        ),
      ),
      _slider(
        'Text opacity',
        _overlayTextOpacity,
        0.1,
        1.0,
        (value) => _updateTextControl(
          'text-opacity',
          () => _overlayTextOpacity = value,
        ),
      ),
      _slider(
        'Tracking',
        _overlayTextTracking,
        -5,
        30,
        (value) => _updateTextControl(
          'text-tracking',
          () => _overlayTextTracking = value,
        ),
        divisions: 70,
      ),
      _slider(
        'Curve',
        _overlayTextCurve,
        -100,
        100,
        (value) => _updateTextControl(
          'text-curve',
          () => _overlayTextCurve = value,
        ),
        divisions: 80,
      ),
      _colorSelector(
        'Text color',
        _overlayTextColor,
        (value) => _updateTextControl(
          'text-color',
          () => _overlayTextColor = value,
        ),
      ),
      _slider(
        'Stroke',
        _overlayTextStroke,
        0,
        10,
        (value) => _updateTextControl(
          'text-stroke',
          () => _overlayTextStroke = value,
        ),
      ),
      _colorSelector(
        'Stroke color',
        _overlayTextStrokeColor,
        (value) => _updateTextControl(
          'text-stroke-color',
          () => _overlayTextStrokeColor = value,
        ),
      ),
      _slider(
        'Stroke opacity',
        _overlayTextStrokeOpacity,
        0,
        1,
        (value) => _updateTextControl(
          'text-stroke-opacity',
          () => _overlayTextStrokeOpacity = value,
        ),
      ),
      _colorSelector(
        'Shadow color',
        _overlayTextShadowColor,
        (value) => _updateTextControl(
          'text-shadow-color',
          () => _overlayTextShadowColor = value,
        ),
      ),
      _slider(
        'Shadow opacity',
        _overlayTextShadowOpacity,
        0,
        1,
        (value) => _updateTextControl(
          'text-shadow-opacity',
          () => _overlayTextShadowOpacity = value,
        ),
      ),
      _dropdown(
        'Text animation',
        _overlayTextAnimation,
        const [
          'none',
          'fade in',
          'fade out',
          'text typing',
          'flow up',
          'flow down',
          'flow left',
          'flow right',
          'pop up line',
          'pulse',
        ],
        _setTextAnimation,
      ),
      _slider(
        'Animation duration',
        _overlayTextAnimationDuration,
        0.2,
        5,
        (value) => _updateTextControl(
          'text-animation-duration',
          () => _overlayTextAnimationDuration = value,
        ),
      ),
      Row(
        children: [
          Expanded(
            child: _slider(
              'Start X',
              _overlayTextStartX,
              0,
              1,
              (value) => _updateTextControl(
                'text-start-x',
                () => _overlayTextStartX = value,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _slider(
              'Start Y',
              _overlayTextStartY,
              0,
              1,
              (value) => _updateTextControl(
                'text-start-y',
                () => _overlayTextStartY = value,
              ),
            ),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: _slider(
              'End X',
              _overlayTextX,
              0,
              1,
              (value) => _updateTextControl(
                'text-end-x',
                () => _overlayTextX = value,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _slider(
              'End Y',
              _overlayTextY,
              0,
              1,
              (value) => _updateTextControl(
                'text-end-y',
                () => _overlayTextY = value,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _colorControlSection() {
    return [
      _sectionTitle('Color Correction'),
      ..._colorCorrectionControlSection(),
      const SizedBox(height: 18),
      _sectionTitle('Text Colors'),
      ..._textControlSection(),
      const SizedBox(height: 18),
      _sectionTitle('Output Ratio'),
      _ratioSelector(),
    ];
  }

  Widget _renderQueueControlButton() {
    return OutlinedButton.icon(
      onPressed: _renderQueuePaused ? _resumeRenderQueue : _pauseRenderQueue,
      icon: Icon(_renderQueuePaused ? Icons.play_arrow : Icons.pause_outlined),
      label: KText(_renderQueuePaused ? 'Resume Queue' : 'Pause Queue'),
    );
  }

  List<Widget> _colorCorrectionControlSection() {
    return [
      Row(
        children: [
          Expanded(child: _colorWheel('Lift')),
          const SizedBox(width: 8),
          Expanded(child: _colorWheel('Gamma')),
          const SizedBox(width: 8),
          Expanded(child: _colorWheel('Gain')),
        ],
      ),
      const SizedBox(height: 12),
      _slider(
        'Brightness',
        _brightness,
        -1,
        1,
        (value) {
          _recordEditorHistory('color-brightness');
          _updateEditor(() => _brightness = value);
        },
        divisions: 40,
      ),
      _slider(
        'Contrast',
        _contrast,
        0,
        3,
        (value) {
          _recordEditorHistory('color-contrast');
          _updateEditor(() => _contrast = value);
        },
        divisions: 30,
      ),
      _slider(
        'Saturation',
        _saturation,
        0,
        3,
        (value) {
          _recordEditorHistory('color-saturation');
          _updateEditor(() => _saturation = value);
        },
        divisions: 30,
      ),
      _slider(
        'Gamma',
        _gamma,
        0.1,
        3,
        (value) {
          _recordEditorHistory('color-gamma');
          _updateEditor(() => _gamma = value);
        },
        divisions: 29,
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () {
            _recordEditorHistory('color-reset');
            _updateEditor(() {
              _brightness = 0;
              _contrast = 1;
              _saturation = 1;
              _gamma = 1;
            });
          },
          icon: const Icon(Icons.restart_alt),
          label: const KText('Reset color'),
        ),
      ),
    ];
  }

  Widget _inspectorSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(bottom: BorderSide(color: _panelBorderColor)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          minTileHeight: 36,
          tilePadding: const EdgeInsets.symmetric(horizontal: 7),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 9),
          leading: Icon(
            icon,
            size: 16,
            color: _mutedTextColor,
          ),
          title: KText(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.25,
            ),
          ),
          trailing: const Icon(Icons.expand_more, size: 18),
          children: children,
        ),
      ),
    );
  }
}
