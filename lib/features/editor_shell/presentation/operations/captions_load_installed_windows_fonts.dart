part of '../editor_application.dart';

// captions operations owned by the editor state; extracted without changing timing.
extension _CaptionsLoadInstalledWindowsFonts on _EditorScreenState {
  Future<void> _loadInstalledWindowsFonts() async {
    if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') {
      return;
    }
    final discovered = <String>{..._EditorScreenState._defaultFontChoices};
    const registryKeys = [
      r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
      r'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
    ];
    for (final key in registryKeys) {
      try {
        final result = await Process.run('reg.exe', ['query', key]);
        if (result.exitCode != 0) continue;
        for (final line in '${result.stdout}'.split(RegExp(r'[\r\n]+'))) {
          final match = RegExp(
            r'^\s*(.*?)\s+REG_(?:SZ|EXPAND_SZ)\s+',
            caseSensitive: false,
          ).firstMatch(line);
          var name = match?.group(1)?.trim() ?? '';
          name = name
              .replaceFirst(
                RegExp(r'\s+\((?:TrueType|OpenType|All Res)\)$',
                    caseSensitive: false),
                '',
              )
              .trim();
          name = _normalizedFontFamily(name);
          if (_isReadableFontFamily(name)) discovered.add(name);
        }
      } catch (_) {
        // The built-in font list remains available if Registry access fails.
      }
    }
    final unique = <String, String>{};
    for (final name in discovered) {
      unique.putIfAbsent(name.toLowerCase(), () => name);
    }
    final sorted = unique.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;
    _updateEditor(() {
      _fontChoices
        ..clear()
        ..addAll(sorted);
    });
  }

  String _normalizedFontFamily(String value) {
    var name = value.trim().replaceFirst(RegExp(r'^@+'), '');
    for (final builtIn in _EditorScreenState._defaultFontChoices) {
      if (builtIn.toLowerCase() == name.toLowerCase()) return builtIn;
    }
    name = name.replaceFirst(
      RegExp(
        r'\s+(?:regular|roman|book|medium|semi[- ]?bold|demi[- ]?bold|extra[- ]?bold|ultra[- ]?bold|bold|extra[- ]?light|ultra[- ]?light|light|thin|black|italic|oblique)(?:\s+(?:italic|oblique))?$',
        caseSensitive: false,
      ),
      '',
    );
    return name.trim();
  }

  bool _isReadableFontFamily(String name) {
    if (name.length < 2 || name.length > 80) return false;
    final lower = name.toLowerCase();
    if (RegExp(
      r'barcode|bar code|symbol|wingdings|webdings|marlett|dingbat|ornament|icon|emoji|music|demo|trial|personal use',
    ).hasMatch(lower)) {
      return false;
    }
    return RegExp(r'[a-zA-Z\u1780-\u17ff]').hasMatch(name);
  }

  String _safeCaptionFont(String value) {
    final normalized = _normalizedFontFamily(value);
    if (!_isReadableFontFamily(normalized)) return 'Arial';
    for (final font in _fontChoices) {
      if (font.toLowerCase() == normalized.toLowerCase()) return font;
    }
    return _EditorScreenState._defaultFontChoices.contains(normalized)
        ? normalized
        : 'Arial';
  }

  double _captionUiFontSize(double value) {
    final normalized = value > 40 ? value / 4.5 : value;
    return normalized.clamp(6.0, 36.0).toDouble();
  }

  double _captionAssFontSize(double value) {
    final normalized = value <= 40 ? value * 4.5 : value;
    return normalized.clamp(27.0, 162.0).toDouble();
  }

  double _captionPreviewFontSize({
    required double scale,
    required double previewHeight,
  }) {
    return (_captionAssFontSize(_captionFontSize) * scale)
        .clamp(1.0, previewHeight * 0.8)
        .toDouble();
  }

  void _applyProjectCaptions(Object? value) {
    final data = value is Map ? value : const {};
    _automaticCaptions = data['enabled'] as bool? ?? _automaticCaptions;
    _captionModel = '${data['model'] ?? _captionModel}';
    _captionLanguage = '${data['language'] ?? _captionLanguage}';
    _captionDevice = '${data['device'] ?? _captionDevice}';
    final savedCaptionStyle = '${data['style'] ?? _captionStyle}';
    _captionStyle = _captionPresets.any(
      (preset) => preset.id == savedCaptionStyle,
    )
        ? savedCaptionStyle
        : 'capcut';
    _captionFont = _safeCaptionFont('${data['font'] ?? _captionFont}');
    _captionFontSize = _captionUiFontSize(
      double.tryParse('${data['fontSize'] ?? _captionFontSize}') ??
          _captionFontSize,
    );
    _captionWordsPerLine =
        int.tryParse('${data['wordsPerLine'] ?? _captionWordsPerLine}') ??
            _captionWordsPerLine;
    _captionBold = data['bold'] as bool? ?? _captionBold;
    _captionUnderline = data['underline'] as bool? ?? _captionUnderline;
    _captionItalic = data['italic'] as bool? ?? _captionItalic;
    _captionCase = '${data['case'] ?? _captionCase}';
    _captionColor = _parseHexColor('${data['color'] ?? ''}') ?? _captionColor;
    _captionCharacterSpacing =
        double.tryParse('${data['characterSpacing'] ?? 0}') ?? 0;
    _captionWordSpacing = double.tryParse('${data['wordSpacing'] ?? 4}') ?? 4;
    _captionLineSpacing = double.tryParse('${data['lineSpacing'] ?? 0}') ?? 0;
    _captionOpacity =
        (double.tryParse('${data['opacity'] ?? 1}') ?? 1).clamp(0.0, 1.0);
    _captionStrokeEnabled =
        data['strokeEnabled'] as bool? ?? _captionStrokeEnabled;
    _captionStrokeColor =
        _parseHexColor('${data['strokeColor'] ?? ''}') ?? _captionStrokeColor;
    _captionStrokeWidth = double.tryParse('${data['strokeWidth'] ?? 6}') ?? 6;
    _captionBackgroundEnabled =
        data['backgroundEnabled'] as bool? ?? _captionBackgroundEnabled;
    _captionBackgroundColor =
        _parseHexColor('${data['backgroundColor'] ?? ''}') ??
            _captionBackgroundColor;
    _captionBackgroundOpacity =
        double.tryParse('${data['backgroundOpacity'] ?? 0.75}') ?? 0.75;
    _captionBackgroundPadding =
        double.tryParse('${data['backgroundPadding'] ?? 10}') ?? 10;
    _captionGlowEnabled = data['glowEnabled'] as bool? ?? _captionGlowEnabled;
    _captionGlowColor =
        _parseHexColor('${data['glowColor'] ?? ''}') ?? _captionGlowColor;
    _captionGlowStrength = double.tryParse('${data['glowStrength'] ?? 8}') ?? 8;
    _captionShadowEnabled =
        data['shadowEnabled'] as bool? ?? _captionShadowEnabled;
    _captionShadowColor =
        _parseHexColor('${data['shadowColor'] ?? ''}') ?? _captionShadowColor;
    _captionShadowStrength =
        double.tryParse('${data['shadowStrength'] ?? 3}') ?? 3;
    _captionCurve = double.tryParse('${data['curve'] ?? 0}') ?? 0;
  }

  Map<String, Object?> _captionCueToJson(_CaptionCue cue) => cue.toJson();

  CaptionStyle get _resolvedCaptionStyle {
    final preset = _captionPreset(_captionStyle);
    final background = _captionBackgroundEnabled
        ? _captionBackgroundColor
        : preset.backgroundColor;
    final backgroundOpacity = _captionBackgroundEnabled
        ? _captionBackgroundOpacity
        : background.opacity;
    return CaptionStyle(
      id: preset.id,
      name: preset.name,
      fontFamily: _safeCaptionFont(_captionFont),
      fontSize: _captionAssFontSize(_captionFontSize),
      color: _captionColor,
      highlightColor: preset.accentColor,
      backgroundColor: background.withOpacity(1),
      strokeColor: _captionStrokeColor,
      strokeWidth: _captionStrokeEnabled ? _captionStrokeWidth : 0,
      bold: _captionBold,
      italic: _captionItalic,
      underline: _captionUnderline,
      opacity: _captionOpacity,
      shadowColor: _captionShadowColor,
      shadowBlur: _captionShadowEnabled ? _captionShadowStrength : 0,
      shadowOffsetX: _captionShadowEnabled ? _captionShadowStrength * 0.7 : 0,
      shadowOffsetY: _captionShadowEnabled ? _captionShadowStrength * 0.9 : 0,
      backgroundOpacity: backgroundOpacity,
      borderRadius: 8,
      padding: _captionBackgroundEnabled
          ? _captionBackgroundPadding
          : backgroundOpacity > 0
              ? 12
              : 0,
      alignment: TextAlign.center,
      position: const Offset(0.5, 0.78),
      letterSpacing: _captionCharacterSpacing,
      wordSpacing: _captionWordSpacing,
      lineSpacing: _captionLineSpacing,
      animation: preset.motion,
      wordsPerLine: _captionWordsPerLine,
    );
  }

  List<CaptionCueSettings> _captionSettingsForVideo(String path) =>
      _captionTrackHidden ? const [] : _session.captionExport(path);

  String _textStyleFont(_CaptionPreset preset) {
    if (preset.id == 'typewriter') return 'Courier New';
    if (preset.id == 'documentary') return 'Georgia';
    if (!preset.bold) return 'Arial';
    return 'Impact';
  }

  Widget _captionWorkspacePanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _automaticCaptions,
          onChanged: (value) => _updateEditor(() => _automaticCaptions = value),
          title: const KText(
            'Generate captions on export',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const KText('Faster-Whisper transcription and word timing'),
        ),
        _dropdown(
          'Whisper model',
          _captionModel,
          const [
            'tiny.en',
            'base.en',
            'small.en',
            'tiny',
            'base',
            'small',
            'medium'
          ],
          (value) => _updateEditor(() {
            _captionModel = value;
            if (value.endsWith('.en')) _captionLanguage = 'en';
          }),
        ),
        _dropdown(
          'Language',
          _captionLanguage,
          const ['en', 'auto', 'km'],
          (value) => _updateEditor(() {
            _captionLanguage = value;
            if (value != 'en' && _captionModel.endsWith('.en')) {
              _captionModel =
                  _captionModel.substring(0, _captionModel.length - 3);
            }
          }),
        ),
        _dropdown(
          'Processing device',
          _captionDevice,
          const ['auto', 'cuda', 'cpu'],
          (value) => _updateEditor(() => _captionDevice = value),
        ),
        const SizedBox(height: 6),
        _captionPresetPicker(
          selected: _captionStyle,
          onChanged: _applyCaptionPreset,
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _captionGenerateAllVideos,
          onChanged: _isGeneratingCaptions
              ? null
              : (value) => _updateEditor(() {
                    _captionGenerateAllVideos = value ?? false;
                    if (_captionGenerateAllVideos &&
                        _captionVideoTargetsController.text.trim().isEmpty) {
                      _captionVideoTargetsController.text =
                          _videos.length == 1 ? '1' : '1 to ${_videos.length}';
                    }
                  }),
          title: const KText(
            'Choose video numbers',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const KText(
            'Uses each video\'s edited cuts and hook duration, not the full original source.',
          ),
        ),
        if (_captionGenerateAllVideos) ...[
          Builder(
            builder: (context) {
              final parsed = _parseVideoTargetExpression(
                _captionVideoTargetsController.text,
              );
              return TextField(
                controller: _captionVideoTargetsController,
                enabled: !_isGeneratingCaptions,
                decoration: InputDecoration(
                  labelText: 'Caption video numbers',
                  hintText: '1,2,4 to 7,9,10',
                  helperText: parsed.error == null
                      ? _videoTargetSummary(parsed.indexes)
                      : null,
                  errorText: parsed.error,
                ),
                onChanged: (_) => _updateEditor(() {}),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _videos.isEmpty || _isGeneratingCaptions
              ? null
              : _generateSelectedCaptionPreview,
          icon: _isGeneratingCaptions
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: KText(
            _isGeneratingCaptions
                ? 'Generating...'
                : _captionGenerateAllVideos
                    ? 'Generate Selected Captions'
                    : 'Generate Current Captions',
          ),
        ),
        if (_selectedCaptionCues.isNotEmpty) ...[
          const SizedBox(height: 12),
          _manualCaptionEditorControls(),
        ],
      ],
    );
  }

  String _captionTimelineId(String path, int index) =>
      'caption:${Uri.encodeComponent(path)}:$index';

  ({String path, int index})? _captionSelectionTarget(String id) {
    final match = RegExp(r'^caption:(.*):(\d+)$').firstMatch(id);
    if (match == null) return null;
    final index = int.tryParse(match.group(2)!);
    if (index == null) return null;
    return (path: Uri.decodeComponent(match.group(1)!), index: index);
  }

  void _selectAllCaptionsForCurrentVideo() {
    if (_videos.isEmpty) return;
    final path = _videos[_selectedVideoIndex].path;
    final cues = _captionCuesByVideo[path] ?? const <_CaptionCue>[];
    if (cues.isEmpty) return;
    _updateEditor(() {
      _selectedCaptionIds
        ..clear()
        ..addAll([
          for (var index = 0; index < cues.length; index++)
            _captionTimelineId(path, index),
        ]);
      _selectedCaptionCueIndex = 0;
      _editorSelection = EditorSelection.caption(
        _captionTimelineId(path, 0),
        label: cues.first.text,
      );
    });
  }

  void _setSelectedCaptionPosition({double? x, double? y}) {
    if (_videos.isEmpty || _captionTrackLocked) return;
    final currentPath = _videos[_selectedVideoIndex].path;
    final currentCues =
        _captionCuesByVideo[currentPath] ?? const <_CaptionCue>[];
    if (currentCues.isEmpty) return;
    var ids = _effectiveSelectedCaptionIds;
    if (ids.isEmpty) {
      ids = {
        _captionTimelineId(currentPath,
            _selectedCaptionCueIndex.clamp(0, currentCues.length - 1))
      };
    }
    _recordEditorHistory('caption-position');
    _updateEditor(() {
      final updates = <String, List<_CaptionCue>>{};
      for (final id in ids) {
        final target = _captionSelectionTarget(id);
        if (target == null) continue;
        final cues =
            updates[target.path] ?? [...?_captionCuesByVideo[target.path]];
        if (target.index < 0 || target.index >= cues.length) continue;
        final cue = cues[target.index];
        cues[target.index] = cue.copyWith(
          x: (x ?? cue.x).clamp(0.02, 0.98).toDouble(),
          y: (y ?? cue.y).clamp(0.02, 0.98).toDouble(),
        );
        updates[target.path] = cues;
      }
      for (final entry in updates.entries) {
        _captionCuesByVideo[entry.key] = entry.value;
      }
      _status = 'Moved ${ids.length} caption${ids.length == 1 ? '' : 's'}';
    });
  }

  void _dragSelectedCaptions(_CaptionCue active, Offset normalizedDelta) {
    if (_videos.isEmpty || _captionTrackLocked) return;
    String? path;
    var index = -1;
    for (final entry in _captionCuesByVideo.entries) {
      final candidate = entry.value.indexOf(active);
      if (candidate < 0) continue;
      path = entry.key;
      index = candidate;
      break;
    }
    if (path == null || index < 0) return;
    final activeId = _captionTimelineId(path, index);
    if (!_effectiveSelectedCaptionIds.contains(activeId)) {
      _selectedCaptionIds
        ..clear()
        ..add(activeId);
      _selectedCaptionCueIndex = index;
      _editorSelection = EditorSelection.caption(activeId, label: active.text);
    }
    _setSelectedCaptionPosition(
      x: active.x + normalizedDelta.dx,
      y: active.y + normalizedDelta.dy,
    );
  }

  List<TimelineCaptionCueData> _dynamicTimelineCaptionCues([
    TimelineModel? timeline,
  ]) {
    final result = <TimelineCaptionCueData>[];
    for (final track in (timeline ?? _programEditingTimeline).videoTracks) {
      for (final clip in track.clips) {
        final cues = _captionCuesByVideo[clip.mediaPath];
        if (cues == null || cues.isEmpty) continue;
        for (var index = 0; index < cues.length; index++) {
          final cue = cues[index];
          final visibleStart = math.max(cue.start, clip.sourceStart).toDouble();
          final speed = clip.resolvedPlaybackSpeed();
          final visibleEnd = math
              .min(cue.end, clip.sourceStart + clip.duration * speed)
              .toDouble();
          if (visibleEnd <= visibleStart) continue;
          result.add(
            TimelineCaptionCueData(
              id: _captionTimelineId(clip.mediaPath, index),
              timelineStart: clip.timelineStart +
                  (visibleStart - clip.sourceStart) / speed,
              duration: (visibleEnd - visibleStart) / speed,
              text: cue.text,
            ),
          );
        }
      }
    }
    result.sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
    return result;
  }

  Set<String> get _effectiveSelectedCaptionIds {
    final primary = _editorSelection.kind == EditorSelectionKind.captionCue
        ? _editorSelection.id
        : null;
    if (_selectedCaptionIds.isEmpty) {
      return primary == null ? const {} : {primary};
    }
    if (primary == null || _selectedCaptionIds.contains(primary)) {
      return Set.unmodifiable(_selectedCaptionIds);
    }
    return {primary};
  }

  Set<String> _captionSelectionFor(
    String id, {
    required bool toggle,
    required bool range,
  }) {
    final current = {..._effectiveSelectedCaptionIds};
    final anchor = _editorSelection.kind == EditorSelectionKind.captionCue
        ? _editorSelection.id
        : null;
    if (range && anchor != null) {
      final ordered = _dynamicTimelineCaptionCues();
      final first = ordered.indexWhere((cue) => cue.id == anchor);
      final last = ordered.indexWhere((cue) => cue.id == id);
      if (first >= 0 && last >= 0) {
        final low = math.min(first, last);
        final high = math.max(first, last);
        return {
          if (toggle) ...current,
          for (var index = low; index <= high; index++) ordered[index].id,
        };
      }
    }
    if (toggle) {
      if (!current.add(id)) current.remove(id);
      return current;
    }
    return {id};
  }
}
