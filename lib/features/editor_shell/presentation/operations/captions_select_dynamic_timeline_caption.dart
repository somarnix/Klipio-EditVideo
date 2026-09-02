part of '../editor_application.dart';

// captions operations owned by the editor state; extracted without changing timing.
extension _CaptionsSelectDynamicTimelineCaption on _EditorScreenState {
  Future<void> _selectDynamicTimelineCaption(
    String id, {
    bool toggle = false,
    bool range = false,
  }) async {
    if (!id.startsWith('caption:')) return;
    final separator = id.lastIndexOf(':');
    if (separator <= 'caption:'.length) return;
    final path =
        Uri.decodeComponent(id.substring('caption:'.length, separator));
    final index = int.tryParse(id.substring(separator + 1));
    final videoIndex = _videos.indexWhere((video) => video.path == path);
    final cues = _captionCuesByVideo[path] ?? const <_CaptionCue>[];
    if (index == null || videoIndex < 0 || index < 0 || index >= cues.length) {
      return;
    }
    if (videoIndex != _selectedVideoIndex) {
      await _selectVideo(videoIndex, saveCurrentEdit: false);
      if (!mounted) return;
    }
    final nextSelection = _captionSelectionFor(
      id,
      toggle: toggle,
      range: range,
    );
    final primaryCaptionId = nextSelection.contains(id)
        ? id
        : (nextSelection.isEmpty ? null : nextSelection.last);
    final primaryCaption = primaryCaptionId == null
        ? null
        : _dynamicTimelineCaptionCues()
            .where((cue) => cue.id == primaryCaptionId)
            .firstOrNull;
    _updateEditor(() {
      _selectedCaptionIds
        ..clear()
        ..addAll(nextSelection);
      if (!toggle && !range) {
        _selectedTimelineClipIds.clear();
        _musicTimelineSelected = false;
      }
      _selectedCaptionCueIndex = index;
      _selectedTimelineClipId = null;
      _editorSelection = nextSelection.isEmpty
          ? const EditorSelection.none()
          : EditorSelection.caption(
              primaryCaptionId!,
              label: primaryCaption?.text ?? cues[index].text,
            );
      _visibleWorkspacePanels.add('inspector');
      _status = nextSelection.length > 1
          ? '${nextSelection.length} caption clips selected'
          : 'Caption selected';
    });
  }

  Future<void> _deleteCaptionTimelineTrack() async {
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before deleting captions.');
      return;
    }
    final paths = {
      for (final track in _multiTrackTimeline.videoTracks)
        for (final clip in track.clips) clip.mediaPath,
    };
    if (!paths.any((path) => _captionCuesByVideo[path]?.isNotEmpty == true)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const KText('Delete caption track?'),
        content: const KText(
          'All caption blocks in this timeline will be removed. The source video is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const KText('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const KText('Delete captions'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _recordEditorHistory('caption-track-delete');
    _updateEditor(() {
      for (final path in paths) {
        _captionCuesByVideo.remove(path);
      }
      _selectedCaptionIds.clear();
      _selectedCaptionCueIndex = 0;
      _editorSelection = _videos.isEmpty
          ? const EditorSelection.none()
          : EditorSelection.video(_videos[_selectedVideoIndex].path);
      _status = 'Caption track deleted';
    });
    unawaited(_autosaveProject());
  }

  Widget _timelineCaptionClips() {
    return _timelineClipStrip(
      children: [
        for (final entry in _visibleTimelineVideos())
          ..._timelineCaptionParts(entry.video),
      ],
    );
  }

  List<Widget> _timelineCaptionParts(PickedVideo video) {
    final parts = _clipTimelineEditFor(video.path).timelineParts(
      video.durationSeconds,
    );
    final cues = _captionCuesByVideo[video.path] ?? const <_CaptionCue>[];
    return [
      for (final part in parts)
        Builder(
          builder: (context) {
            final width = _timelinePartWidth(part);
            final duration = math.max(0.001, part.end - part.start);
            final visibleCues = cues
                .where((cue) => cue.end > part.start && cue.start < part.end)
                .toList();
            return SizedBox(
              width: width,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (visibleCues.isEmpty && _isGeneratingCaptions)
                    const Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  for (final cue in visibleCues)
                    Positioned(
                      left: ((math.max(cue.start, part.start) - part.start) /
                              duration *
                              width)
                          .clamp(0.0, width)
                          .toDouble(),
                      width: (((math.min(cue.end, part.end) -
                                      math.max(cue.start, part.start)) /
                                  duration *
                                  width)
                              .clamp(8.0, width))
                          .toDouble(),
                      top: 3,
                      bottom: 5,
                      child: GestureDetector(
                        onTap: () => unawaited(_focusCaptionCue(video, cue)),
                        onDoubleTap: () => unawaited(
                          _focusCaptionCue(video, cue, edit: true),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xffc2410c),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: video.path ==
                                          _videos[_selectedVideoIndex].path &&
                                      cues.indexOf(cue) ==
                                          _selectedCaptionCueIndex
                                  ? Colors.white
                                  : const Color(0xfffb923c),
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: KText(
                            cue.text,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
    ];
  }

  Future<void> _focusCaptionCue(
    PickedVideo video,
    _CaptionCue cue, {
    bool edit = false,
  }) async {
    final videoIndex = _videos.indexWhere((item) => item.path == video.path);
    if (videoIndex < 0) return;
    if (_selectedVideoIndex != videoIndex) {
      await _selectVideo(videoIndex);
      if (!mounted) return;
    }
    final cues = _captionCuesByVideo[video.path] ?? const <_CaptionCue>[];
    final cueIndex = cues.indexOf(cue);
    if (cueIndex < 0) return;
    _updateEditor(() {
      _selectedCaptionCueIndex = cueIndex;
      _editorSelection = EditorSelection.caption(
        _captionTimelineId(video.path, cueIndex),
        label: cue.text,
      );
      _visibleWorkspacePanels.add('inspector');
    });
    if (edit) await _showCaptionCueEditor(index: cueIndex);
  }

  List<Widget> _captionInspectorControls() {
    return [
      if (_selectedCaptionCues.isEmpty)
        Padding(
          padding: const EdgeInsets.all(12),
          child: KText(
            'Select or generate a caption cue to edit its transcript and word timing.',
            style: TextStyle(color: _mutedTextColor),
          ),
        )
      else
        _captionInlineInspectorEditor(),
      if (_selectedCaptionCues.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionTitle('Position'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _selectAllCaptionsForCurrentVideo,
                icon: const Icon(Icons.select_all, size: 16),
                label: const KText('Select all captions'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _setSelectedCaptionPosition(x: 0.5, y: 0.78),
              child: const KText('Reset'),
            ),
          ],
        ),
        _slider(
          'Position X',
          _selectedCaptionCues[_selectedCaptionCueIndex.clamp(
                  0, _selectedCaptionCues.length - 1)]
              .x,
          0.02,
          0.98,
          (value) => _setSelectedCaptionPosition(x: value),
        ),
        _slider(
          'Position Y',
          _selectedCaptionCues[_selectedCaptionCueIndex.clamp(
                  0, _selectedCaptionCues.length - 1)]
              .y,
          0.02,
          0.98,
          (value) => _setSelectedCaptionPosition(y: value),
        ),
      ],
      const SizedBox(height: 12),
      _sectionTitle('Global Style Overrides'),
      _fontDropdown(
        'Caption font',
        _captionFont,
        (value) => _updateEditor(() => _captionFont = value),
      ),
      _slider(
        'Font size',
        _captionFontSize,
        6,
        36,
        (value) => _updateEditor(() => _captionFontSize = value),
        divisions: 30,
      ),
      _captionTypographyControls(
        bold: _captionBold,
        underline: _captionUnderline,
        italic: _captionItalic,
        letterCase: _captionCase,
        color: _captionColor,
        characterSpacing: _captionCharacterSpacing,
        wordSpacing: _captionWordSpacing,
        lineSpacing: _captionLineSpacing,
        onBold: (value) => _updateEditor(() => _captionBold = value),
        onUnderline: (value) => _updateEditor(() => _captionUnderline = value),
        onItalic: (value) => _updateEditor(() => _captionItalic = value),
        onCase: (value) => _updateEditor(() => _captionCase = value),
        onColor: (value) => _updateEditor(() => _captionColor = value),
        onCharacterSpacing: (value) =>
            _updateEditor(() => _captionCharacterSpacing = value),
        onWordSpacing: (value) =>
            _updateEditor(() => _captionWordSpacing = value),
        onLineSpacing: (value) =>
            _updateEditor(() => _captionLineSpacing = value),
      ),
      _captionEffectsControls(),
    ];
  }

  Widget _captionInlineInspectorEditor() {
    final cues = _selectedCaptionCues;
    final index = _selectedCaptionCueIndex.clamp(0, cues.length - 1);
    final cue = cues[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey(
            'caption-${_videos[_selectedVideoIndex].path}-$index-${cue.start}',
          ),
          initialValue: cue.text,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Transcript text',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _updateSelectedCaptionTranscript(value),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: KText(
                'WORD TIMING',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showCaptionCueEditor(index: index),
              icon: const Icon(Icons.schedule_outlined, size: 16),
              label: const KText('Edit timing'),
            ),
          ],
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: _controlSurfaceColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _panelBorderColor),
          ),
          child: cue.words.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: KText(
                    '${_subtitleTime(cue.start, comma: false)} - ${_subtitleTime(cue.end, comma: false)}',
                    style: TextStyle(color: _mutedTextColor, fontSize: 11),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: cue.words.length,
                  itemBuilder: (context, wordIndex) {
                    final word = cue.words[wordIndex];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: KText(word.text),
                      trailing: KText(
                        '${word.start.toStringAsFixed(2)} - ${word.end.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 9, color: _mutedTextColor),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _updateSelectedCaptionTranscript(String value) {
    if (_videos.isEmpty || _selectedCaptionCues.isEmpty) return;
    if (_captionTrackLocked) return;
    _recordEditorHistory('caption-text');
    final path = _videos[_selectedVideoIndex].path;
    final updated = [..._selectedCaptionCues];
    final index = _selectedCaptionCueIndex.clamp(0, updated.length - 1);
    final cue = updated[index];
    updated[index] = cue.copyWith(text: value);
    _updateEditor(() {
      _captionCuesByVideo[path] = updated;
      _editorSelection = EditorSelection.caption(
        _captionTimelineId(path, index),
        label: value,
      );
    });
  }

  void _applyCaptionPreset(String value) {
    final preset = _captionPreset(value);
    _updateEditor(() {
      _captionStyle = value;
      _captionColor = preset.accentColor;
      _captionBold = preset.bold;
      _captionItalic = preset.italic;
      _captionCase = preset.uppercase ? 'upper' : 'original';
      _captionStrokeEnabled = preset.outline > 0;
      _captionStrokeColor = preset.outlineColor;
      _captionStrokeWidth = preset.outline;
      _captionBackgroundEnabled =
          preset.backgroundColor != Colors.transparent ||
              preset.activeBoxColor != Colors.transparent;
      final background = preset.activeBoxColor != Colors.transparent
          ? preset.activeBoxColor
          : preset.backgroundColor;
      _captionBackgroundColor = background.withAlpha(255);
      _captionBackgroundOpacity = background.opacity;
      _captionGlowEnabled = preset.motion == 'glow';
      _captionGlowColor = preset.accentColor;
      _captionGlowStrength = math.max(6, preset.shadow);
      _captionShadowEnabled = preset.shadow > 0;
      _captionShadowColor = preset.outlineColor;
      _captionShadowStrength = preset.shadow;
      _captionCurve = 0;
    });
  }

  List<Widget> _captionControlSection() {
    return [
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: _automaticCaptions,
        onChanged: (value) => _updateEditor(() => _automaticCaptions = value),
        title: const KText(
          'Automatic captions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const KText(
          'Faster-Whisper word timing + one-pass ASS burn-in',
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _videos.isEmpty ? null : _importSubtitleFile,
            icon: const Icon(Icons.file_open_outlined),
            label: const KText('Import SRT/VTT/ASS'),
          ),
          OutlinedButton.icon(
            onPressed:
                _selectedCaptionCues.isEmpty ? null : _exportSubtitleFile,
            icon: const Icon(Icons.save_alt_outlined),
            label: const KText('Export subtitles'),
          ),
          FilledButton.tonalIcon(
            onPressed: _videos.isEmpty ? null : () => _showCaptionCueEditor(),
            icon: const Icon(Icons.add_comment_outlined),
            label: const KText('Add caption'),
          ),
        ],
      ),
      if (_selectedCaptionCues.isNotEmpty) ...[
        const SizedBox(height: 12),
        _manualCaptionEditorControls(),
      ],
      if (_automaticCaptions) ...[
        const SizedBox(height: 8),
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
                ? 'Generating captions...'
                : 'Generate captions on T1',
          ),
        ),
        const SizedBox(height: 12),
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
            'medium',
          ],
          (value) => _updateEditor(() {
            _captionModel = value;
            if (value.endsWith('.en')) _captionLanguage = 'en';
          }),
        ),
        _dropdown(
          'Language (en / auto / km)',
          _captionLanguage,
          const ['en', 'auto', 'km'],
          (value) => _updateEditor(() {
            _captionLanguage = value;
            if (value != 'en' && _captionModel.endsWith('.en')) {
              _captionModel = _captionModel.substring(
                0,
                _captionModel.length - 3,
              );
            }
          }),
        ),
        _dropdown(
          'Processing device',
          _captionDevice,
          const ['auto', 'cuda', 'cpu'],
          (value) => _updateEditor(() => _captionDevice = value),
        ),
        _captionPresetPicker(
          selected: _captionStyle,
          onChanged: (value) {
            final preset = _captionPreset(value);
            _updateEditor(() {
              _captionStyle = value;
              _captionColor = preset.accentColor;
              _captionBold = preset.bold;
              _captionItalic = preset.italic;
              _captionCase = preset.uppercase ? 'upper' : 'original';
              _captionStrokeEnabled = preset.outline > 0;
              _captionStrokeColor = preset.outlineColor;
              _captionStrokeWidth = preset.outline;
              _captionBackgroundEnabled =
                  preset.backgroundColor != Colors.transparent ||
                      preset.activeBoxColor != Colors.transparent;
              final presetBackground =
                  preset.activeBoxColor != Colors.transparent
                      ? preset.activeBoxColor
                      : preset.backgroundColor;
              _captionBackgroundColor = presetBackground.withAlpha(255);
              _captionBackgroundOpacity = presetBackground.opacity;
              _captionGlowEnabled = preset.motion == 'glow';
              _captionGlowColor = preset.accentColor;
              _captionGlowStrength = math.max(6, preset.shadow);
              _captionShadowEnabled = preset.shadow > 0;
              _captionShadowColor = preset.outlineColor;
              _captionShadowStrength = preset.shadow;
              _captionCurve = 0;
            });
          },
        ),
        _captionTypographyControls(
          bold: _captionBold,
          underline: _captionUnderline,
          italic: _captionItalic,
          letterCase: _captionCase,
          color: _captionColor,
          characterSpacing: _captionCharacterSpacing,
          wordSpacing: _captionWordSpacing,
          lineSpacing: _captionLineSpacing,
          onBold: (value) => _updateEditor(() => _captionBold = value),
          onUnderline: (value) =>
              _updateEditor(() => _captionUnderline = value),
          onItalic: (value) => _updateEditor(() => _captionItalic = value),
          onCase: (value) => _updateEditor(() => _captionCase = value),
          onColor: (value) => _updateEditor(() => _captionColor = value),
          onCharacterSpacing: (value) =>
              _updateEditor(() => _captionCharacterSpacing = value),
          onWordSpacing: (value) =>
              _updateEditor(() => _captionWordSpacing = value),
          onLineSpacing: (value) =>
              _updateEditor(() => _captionLineSpacing = value),
        ),
        _captionEffectsControls(),
        _fontDropdown(
          'Caption font',
          _captionFont,
          (value) => _updateEditor(() => _captionFont = value),
        ),
        _slider(
          'Font size',
          _captionFontSize,
          6,
          36,
          (value) => _updateEditor(() => _captionFontSize = value),
          divisions: 30,
        ),
        _slider(
          'Words per line',
          _captionWordsPerLine.toDouble(),
          1,
          8,
          (value) => _updateEditor(() => _captionWordsPerLine = value.round()),
          divisions: 7,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: KText(
            'Auto uses NVIDIA CUDA float16 when available, then falls back to CPU int8. '
            'The first run downloads the selected model; later exports reuse the transcript cache.',
            style: TextStyle(color: _mutedTextColor, fontSize: 12),
          ),
        ),
      ],
    ];
  }
}
