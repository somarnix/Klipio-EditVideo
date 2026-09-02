part of '../editor_application.dart';

// text operations owned by the editor state; extracted without changing timing.
extension _TextTextOverlaysFromJson on _EditorScreenState {
  List<_TextOverlayDraft> _textOverlaysFromJson(Object? value) {
    final items = value as List? ?? const [];
    return [
      for (final item in items)
        if (item is Map) _textOverlayFromJson(item),
    ];
  }

  _TextOverlayDraft _textOverlayFromJson(Map item) {
    double number(String key, double fallback) =>
        double.tryParse('${item[key] ?? fallback}') ?? fallback;
    Color color(String key, Color fallback) =>
        _parseHexColor('${item[key] ?? ''}') ?? fallback;
    return _TextOverlayDraft(
      id: '${item['id'] ?? ''}',
      text: '${item['text'] ?? ''}',
      font: '${item['font'] ?? 'Arial'}',
      size: number('size', 44),
      color: color('color', Colors.white),
      opacity: number('opacity', 1),
      stroke: number('stroke', 3),
      strokeColor: color('strokeColor', Colors.black),
      strokeOpacity: number('strokeOpacity', 0.9),
      shadowColor: color('shadowColor', Colors.black),
      shadowOpacity: number('shadowOpacity', 0.65),
      animation: '${item['animation'] ?? 'none'}',
      animationDuration: number('animationDuration', 1),
      x: number('x', 0.5),
      y: number('y', 0.75),
      startX: number('startX', 0.5),
      startY: number('startY', 1),
      timelineStart: number('timelineStart', 0),
      duration: number('duration', 0),
      trackIndex: math.max(1, number('trackIndex', 1).round()),
      isVisible: item['isVisible'] as bool? ?? true,
      isLocked: item['isLocked'] as bool? ?? false,
      tracking: number('tracking', 0),
      curve: number('curve', 0),
    );
  }

  Future<void> _pickWatermark() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    _recordEditorHistory('watermark-file');
    _updateEditor(() {
      _watermarkPath = path;
      _status = 'Watermark selected';
    });
  }

  String _automaticNumberRangeEndText(String startText, String endText) {
    final trimmed = endText.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final start = _numberRangeStartValue(startText);
    return '${_videos.isEmpty ? start : start + _videos.length - 1}';
  }

  String _withoutExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return name.substring(0, dot);
  }

  List<_CaptionPreset> _visibleTextStylePresets() {
    final query = _textStyleSearchController.text.trim().toLowerCase();
    return _captionPresets.where((preset) {
      final categoryMatches = _selectedTextStyleCategory == 'All' ||
          _textStyleCategory(preset) == _selectedTextStyleCategory ||
          (_selectedTextStyleCategory == 'Trending' &&
              _captionPresets.indexOf(preset) < 12);
      final queryMatches = query.isEmpty ||
          preset.name.toLowerCase().contains(query) ||
          preset.id.replaceAll('_', ' ').contains(query);
      return categoryMatches && queryMatches;
    }).toList();
  }

  String _textStyleCategory(_CaptionPreset preset) {
    final id = preset.id;
    if (id.contains('box') || id == 'news_lower') return 'Box';
    if (id.contains('glow') ||
        id.contains('cyan') ||
        id.contains('aqua') ||
        id.contains('pink') ||
        id.contains('lime')) {
      return 'Neon';
    }
    if (const {
      'clean',
      'minimal',
      'documentary',
      'classic_gold',
      'white_impact',
      'typewriter',
      'mono_focus',
    }.contains(id)) {
      return 'Classic';
    }
    return 'Social';
  }

  Widget _textStylePresetCard(_CaptionPreset preset) {
    final selected = _editorSelection.kind == EditorSelectionKind.textLayer &&
        _selectedTextOverlayIndex >= 0 &&
        _selectedTextOverlayIndex < _textOverlays.length &&
        _textOverlays[_selectedTextOverlayIndex].text.trim().isNotEmpty;
    final background = preset.activeBoxColor != Colors.transparent
        ? preset.activeBoxColor
        : preset.backgroundColor;
    final previewText = preset.uppercase ? 'STYLE' : 'Style';
    final outline = preset.outline.clamp(0.0, 8.0).toDouble();
    final shadows = <Shadow>[
      if (outline > 0)
        Shadow(
          color: preset.outlineColor,
          blurRadius: 1,
          offset: Offset(outline * 0.45, outline * 0.45),
        ),
      if (preset.shadow > 0)
        Shadow(
          color: preset.motion == 'glow'
              ? preset.accentColor
              : preset.outlineColor,
          blurRadius: preset.motion == 'glow' ? preset.shadow * 2 : 2,
          offset: preset.motion == 'glow' ? Offset.zero : const Offset(2, 2),
        ),
    ];
    return Material(
      color: const Color(0xff151922),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _videos.isEmpty ? null : () => _applyTextStylePreset(preset),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff252a35), Color(0xff0b0e14)],
                ),
              ),
            ),
            Center(
              child: Container(
                padding: background == Colors.transparent
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: KText(
                  previewText,
                  maxLines: 1,
                  style: TextStyle(
                    color: preset.accentColor,
                    fontFamily: _textStyleFont(preset),
                    fontSize: 21,
                    fontWeight: preset.bold ? FontWeight.w900 : FontWeight.w500,
                    fontStyle:
                        preset.italic ? FontStyle.italic : FontStyle.normal,
                    shadows: shadows,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 6,
              right: 25,
              bottom: 5,
              child: KText(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffdbe2ed),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: 3,
              bottom: 1,
              child: Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                color: const Color(0xff22c55e),
                size: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyTextStylePreset(_CaptionPreset preset) {
    final hasSelectedText =
        _editorSelection.kind == EditorSelectionKind.textLayer &&
            _selectedTextOverlayIndex >= 0 &&
            _selectedTextOverlayIndex < _textOverlays.length &&
            _textOverlays[_selectedTextOverlayIndex].text.trim().isNotEmpty;
    if (!hasSelectedText) _addTextOverlay();
    if (_selectedTextOverlayIndex < 0 ||
        _selectedTextOverlayIndex >= _textOverlays.length) {
      return;
    }
    _recordEditorHistory('text-style');
    _updateEditor(() {
      _saveSelectedTextOverlay();
      final current = _textOverlays[_selectedTextOverlayIndex];
      final animation = switch (preset.motion) {
        'pop' || 'bounce' || 'big_word' => 'pop up line',
        'glow' => 'pulse',
        'box' => 'fade in',
        _ when preset.id == 'typewriter' => 'text typing',
        _ => 'fade in',
      };
      final next = current.copyWith(
        font: _textStyleFont(preset),
        size: preset.id == 'big_word_pop' ? 64 : 48,
        color: preset.accentColor,
        stroke: preset.outline,
        strokeColor: preset.outlineColor,
        strokeOpacity: preset.outline <= 0 ? 0 : 1,
        shadowColor: preset.activeBoxColor != Colors.transparent
            ? preset.activeBoxColor
            : preset.outlineColor,
        shadowOpacity: preset.shadow <= 0 ? 0 : 0.8,
        animation: animation,
        animationDuration: preset.motion == 'bounce' ? 0.65 : 1,
        y: preset.id == 'news_lower' ? 0.84 : current.y,
      );
      _textOverlays[_selectedTextOverlayIndex] = next;
      _loadTextOverlay(next);
      _insertTextTimelineClip(next);
      _selectedTimelineClipId = next.id;
      _editorSelection = EditorSelection.text(next.id, label: next.text);
      _status = '${preset.name} applied to ${next.text}';
    });
    unawaited(_autosaveProject());
  }

  Widget _textLayerManagerTile(int index, _TextOverlayDraft overlay) {
    final selected = index == _selectedTextOverlayIndex &&
        _editorSelection.kind == EditorSelectionKind.textLayer;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: selected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
          : _controlSurfaceColor,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 9, right: 2),
        onTap: () => _selectTextOverlay(index),
        leading: Icon(Icons.title,
            size: 18, color: overlay.isVisible ? null : _mutedTextColor),
        title: KText(
          _layerTitle(overlay, index),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: overlay.isVisible ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: KText(
          'T${overlay.trackIndex}  ${_formatDuration(overlay.timelineStart)} - ${_formatDuration(overlay.timelineStart + overlay.duration)}',
          style: TextStyle(fontSize: 9, color: _mutedTextColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: overlay.isVisible ? 'Hide layer' : 'Show layer',
              onPressed: () => _toggleTextOverlayVisibility(index),
              icon: Icon(
                  overlay.isVisible ? Icons.visibility : Icons.visibility_off,
                  size: 16),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: overlay.isLocked ? 'Unlock layer' : 'Lock layer',
              onPressed: () => _toggleTextOverlayLock(index),
              icon: Icon(overlay.isLocked ? Icons.lock : Icons.lock_open,
                  size: 15),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete layer',
              onPressed: () => _deleteTextOverlayAt(index),
              icon: const Icon(Icons.delete_outline, size: 17),
            ),
          ],
        ),
      ),
    );
  }

  void _setTextAnimation(String value) {
    _updateTextControl('text-animation', () {
      _overlayTextAnimation = value;
      switch (value) {
        case 'flow up':
          _overlayTextStartX = _overlayTextX;
          _overlayTextStartY = 1;
          break;
        case 'flow down':
          _overlayTextStartX = _overlayTextX;
          _overlayTextStartY = 0;
          break;
        case 'flow left':
          _overlayTextStartX = 0;
          _overlayTextStartY = _overlayTextY;
          break;
        case 'flow right':
          _overlayTextStartX = 1;
          _overlayTextStartY = _overlayTextY;
          break;
      }
    });
  }

  _TextOverlayDraft _currentTextOverlayDraft() {
    final current = _selectedTextOverlayIndex >= 0 &&
            _selectedTextOverlayIndex < _textOverlays.length
        ? _textOverlays[_selectedTextOverlayIndex]
        : const _TextOverlayDraft();
    return _TextOverlayDraft(
      id: current.id,
      text: _overlayTextController.text,
      font: _overlayFont,
      size: _overlayTextSize,
      color: _overlayTextColor,
      opacity: _overlayTextOpacity,
      stroke: _overlayTextStroke,
      strokeColor: _overlayTextStrokeColor,
      strokeOpacity: _overlayTextStrokeOpacity,
      shadowColor: _overlayTextShadowColor,
      shadowOpacity: _overlayTextShadowOpacity,
      animation: _overlayTextAnimation,
      animationDuration: _overlayTextAnimationDuration,
      x: _overlayTextX,
      y: _overlayTextY,
      startX: _overlayTextStartX,
      startY: _overlayTextStartY,
      timelineStart: current.timelineStart,
      duration: current.duration,
      trackIndex: current.trackIndex,
      isVisible: current.isVisible,
      isLocked: current.isLocked,
      tracking: _overlayTextTracking,
      curve: _overlayTextCurve,
    );
  }

  void _saveSelectedTextOverlay() {
    if (_selectedTextOverlayIndex < 0 ||
        _selectedTextOverlayIndex >= _textOverlays.length) {
      return;
    }
    final current = _currentTextOverlayDraft();
    _textOverlays[_selectedTextOverlayIndex] = current;
    final selectedTextIds = _effectiveSelectedTimelineClipIds.where((id) {
      final result = _multiTrackTimeline.clipById(id);
      return result?.track.type == TrackType.text &&
          result?.track.isLocked != true;
    }).toSet();
    if (selectedTextIds.length <= 1) return;
    for (var index = 0; index < _textOverlays.length; index++) {
      final overlay = _textOverlays[index];
      if (overlay.id == current.id ||
          !selectedTextIds.contains(overlay.id) ||
          overlay.isLocked) {
        continue;
      }
      _textOverlays[index] = overlay.copyWith(
        font: current.font,
        size: current.size,
        color: current.color,
        opacity: current.opacity,
        stroke: current.stroke,
        strokeColor: current.strokeColor,
        strokeOpacity: current.strokeOpacity,
        shadowColor: current.shadowColor,
        shadowOpacity: current.shadowOpacity,
        animation: current.animation,
        animationDuration: current.animationDuration,
        x: current.x,
        y: current.y,
        startX: current.startX,
        startY: current.startY,
        tracking: current.tracking,
        curve: current.curve,
      );
    }
  }

  void _loadTextOverlay(_TextOverlayDraft overlay) {
    _overlayTextController.text = overlay.text;
    _overlayFont = overlay.font;
    _overlayTextSize = overlay.size;
    _overlayTextColor = overlay.color;
    _overlayTextOpacity = overlay.opacity;
    _overlayTextStroke = overlay.stroke;
    _overlayTextStrokeColor = overlay.strokeColor;
    _overlayTextStrokeOpacity = overlay.strokeOpacity;
    _overlayTextShadowColor = overlay.shadowColor;
    _overlayTextShadowOpacity = overlay.shadowOpacity;
    _overlayTextAnimation = overlay.animation;
    _overlayTextAnimationDuration = overlay.animationDuration;
    _overlayTextX = overlay.x;
    _overlayTextY = overlay.y;
    _overlayTextStartX = overlay.startX;
    _overlayTextStartY = overlay.startY;
    _overlayTextTracking = overlay.tracking;
    _overlayTextCurve = overlay.curve;
  }

  void _selectTextOverlay(int index) {
    if (index < 0 || index >= _textOverlays.length) return;
    _updateEditor(() {
      _saveSelectedTextOverlay();
      _selectedTextOverlayIndex = index;
      _loadTextOverlay(_textOverlays[index]);
      _selectedTimelineClipId = _textOverlays[index].id;
      _editorSelection = EditorSelection.text(
        _textOverlays[index].id,
        label: _layerTitle(_textOverlays[index], index),
      );
      _visibleWorkspacePanels.add('inspector');
    });
  }

  void _toggleTextOverlayVisibility(int index) {
    if (index < 0 || index >= _textOverlays.length) return;
    _recordEditorHistory('text-visibility');
    _updateEditor(() {
      final next = _textOverlays[index].copyWith(
        isVisible: !_textOverlays[index].isVisible,
      );
      _textOverlays[index] = next;
      _insertTextTimelineClip(next);
    });
  }

  void _toggleTextOverlayLock(int index) {
    if (index < 0 || index >= _textOverlays.length) return;
    _recordEditorHistory('text-lock');
    _updateEditor(() {
      final next = _textOverlays[index].copyWith(
        isLocked: !_textOverlays[index].isLocked,
      );
      _textOverlays[index] = next;
      _insertTextTimelineClip(next);
    });
  }

  void _addTextOverlay({String template = 'default'}) {
    _recordEditorHistory('text-add');
    _updateEditor(() {
      _saveSelectedTextOverlay();
      if (_textOverlays.length == 1 &&
          _textOverlays.first.text.trim().isEmpty) {
        _textOverlays.clear();
        _selectedTextOverlayIndex = 0;
      }
      final index = _textOverlays.length;
      final id = 'text-${DateTime.now().microsecondsSinceEpoch}';
      final trackIndex = _nextTextTrackIndex();
      final playhead = _currentProgramSeconds();
      final sequenceEnd = _timelineSequenceDuration() > 0
          ? _timelineSequenceDuration()
          : playhead + 5;
      final duration = math.max(0.5, math.min(5.0, sequenceEnd - playhead));
      final next = _TextOverlayDraft(
        id: id,
        text: template == 'lower_third' ? 'Lower Third' : 'Text ${index + 1}',
        font: template == 'trending' ? 'Impact' : 'Arial',
        size: template == '3d' ? 64 : 44,
        color: template == 'trending' ? const Color(0xffffe500) : Colors.white,
        stroke: template == '3d' ? 7 : 3,
        shadowOpacity: template == '3d' ? 0.9 : 0.65,
        animation: template == 'lower_third' ? 'flow right' : 'none',
        x: template == 'lower_third' ? 0.28 : 0.5,
        y: (0.25 + index * 0.12).clamp(0.0, 0.9).toDouble(),
        timelineStart: playhead,
        duration: duration,
        trackIndex: trackIndex,
      );
      _textOverlays.add(next);
      _selectedTextOverlayIndex = _textOverlays.length - 1;
      _loadTextOverlay(next);
      _insertTextTimelineClip(next);
      _selectedTimelineClipId = id;
      _editorSelection = EditorSelection.text(id, label: next.text);
      _status = 'Added ${next.text} on T$trackIndex at the playhead';
    });
    unawaited(_autosaveProject());
  }

  void _duplicateTextOverlay() {
    _recordEditorHistory('text-duplicate');
    _updateEditor(() {
      _saveSelectedTextOverlay();
      final copy = _textOverlays[_selectedTextOverlayIndex].copyWith(
        id: 'text-${DateTime.now().microsecondsSinceEpoch}',
        y: (_overlayTextY + 0.08).clamp(0.0, 1.0).toDouble(),
        trackIndex: _nextTextTrackIndex(),
      );
      _textOverlays.add(copy);
      _selectedTextOverlayIndex = _textOverlays.length - 1;
      _loadTextOverlay(copy);
      _insertTextTimelineClip(copy);
      _selectedTimelineClipId = copy.id;
      _editorSelection = EditorSelection.text(copy.id, label: copy.text);
    });
    unawaited(_autosaveProject());
  }

  void _deleteTextOverlay() {
    _deleteTextOverlayAt(_selectedTextOverlayIndex);
  }
}
