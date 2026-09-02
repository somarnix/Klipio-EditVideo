part of '../editor_application.dart';

// captions operations owned by the editor state; extracted without changing timing.
extension _CaptionsCaptionCuesFromAss on _EditorScreenState {
  Future<List<_CaptionCue>> _captionCuesFromAss(
    String path, {
    bool capCutStyleOnly = true,
  }) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final pattern = RegExp(
      r'^Dialogue:\s*[^,]*,([^,]+),([^,]+),([^,]*),[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,(.*)$',
    );
    final cues = <_CaptionCue>[];
    for (final line in await file.readAsLines()) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      if (capCutStyleOnly && (match.group(3) ?? '').trim() != 'CapCutPro') {
        continue;
      }
      final start = _parseAssSeconds(match.group(1) ?? '');
      final end = _parseAssSeconds(match.group(2) ?? '');
      final rawText = match.group(4) ?? '';
      final text = normalizeAssDisplayText(rawText);
      if (start != null && end != null && end > start && text.isNotEmpty) {
        final words = <_CaptionWord>[];
        var cursor = start;
        final karaoke = RegExp(
          r'\{[^}]*\\(?:kf|ko|k)(\d+)[^}]*\}([^\{]*)',
          caseSensitive: false,
        );
        for (final wordMatch in karaoke.allMatches(rawText)) {
          final duration = (int.tryParse(wordMatch.group(1) ?? '') ?? 0) / 100;
          final word = normalizeAssDisplayText(wordMatch.group(2) ?? '');
          if (word.isNotEmpty) {
            words.add(
              _CaptionWord(
                start: cursor,
                end: math.min(end, cursor + math.max(0.01, duration)),
                text: word,
              ),
            );
          }
          cursor += duration;
        }
        cues.add(
          _CaptionCue(start: start, end: end, text: text, words: words),
        );
      }
    }
    return cues;
  }

  List<_CaptionCue> get _selectedCaptionCues {
    if (_videos.isEmpty) return const [];
    return _captionCuesByVideo[_videos[_selectedVideoIndex].path] ?? const [];
  }

  Future<void> _showCaptionCueEditor({int? index}) async {
    if (_videos.isEmpty) return;
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before editing captions.');
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    final cues = _captionCuesByVideo[path] ?? const <_CaptionCue>[];
    final existing =
        index != null && index >= 0 && index < cues.length ? cues[index] : null;
    final start = existing?.start ?? _currentPlayheadSeconds();
    final videoEnd = _videos[_selectedVideoIndex].durationSeconds;
    final end = existing?.end ??
        (videoEnd == null
            ? start + 2
            : math.min(videoEnd, math.max(start + 0.5, start + 2)));
    final textController = TextEditingController(text: existing?.text ?? '');
    final startController =
        TextEditingController(text: start.toStringAsFixed(3));
    final endController = TextEditingController(text: end.toStringAsFixed(3));
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: KText(existing == null ? 'Add caption' : 'Edit caption'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        decoration: const InputDecoration(
                          labelText: 'Start (seconds or timecode)',
                          hintText: '12.5 or 00:12.500',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        decoration: const InputDecoration(
                          labelText: 'End (seconds or timecode)',
                          hintText: '15.0 or 00:15.000',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Caption text',
                    hintText: 'Correct the transcript here',
                  ),
                ),
                const SizedBox(height: 10),
                KText(
                  'Editing text clears the original word-level alignment for this cue. The cue remains fully editable and exportable.',
                  style: TextStyle(fontSize: 12, color: _mutedTextColor),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const KText('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: const KText('Save caption'),
          ),
        ],
      ),
    );
    if (applied != true || !mounted) {
      textController.dispose();
      startController.dispose();
      endController.dispose();
      return;
    }
    final nextStart = _parseCaptionEditorTime(startController.text);
    final nextEnd = _parseCaptionEditorTime(endController.text);
    final nextText = textController.text.trim();
    textController.dispose();
    startController.dispose();
    endController.dispose();
    if (nextStart == null || nextEnd == null || nextEnd <= nextStart) {
      _showMessage('Caption end time must be after its start time.');
      return;
    }
    if (nextText.isEmpty) {
      _showMessage('Caption text cannot be empty.');
      return;
    }
    final next = existing?.copyWith(
          start: math.max(0, nextStart),
          end: math.max(0, nextEnd),
          text: nextText,
          words: const [],
        ) ??
        _CaptionCue(
          start: math.max(0, nextStart),
          end: math.max(0, nextEnd),
          text: nextText,
        );
    _recordEditorHistory(
      existing == null ? 'caption-add' : 'caption-edit',
    );
    _updateEditor(() {
      _session.putCaption(path, next);
      final updated = _captionCuesByVideo[path]!;
      _selectedCaptionCueIndex = updated.indexOf(next);
      _automaticCaptions = true;
      _status = existing == null ? 'Caption added to T1' : 'Caption updated';
    });
    unawaited(_autosaveProject());
  }

  double? _parseCaptionEditorTime(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll(',', '.');
    if (!normalized.contains(':')) return double.tryParse(normalized);
    final parts = normalized.split(':');
    if (parts.length == 2) {
      final minutes = double.tryParse(parts[0]);
      final seconds = double.tryParse(parts[1]);
      return minutes == null || seconds == null ? null : minutes * 60 + seconds;
    }
    if (parts.length == 3) {
      final hours = double.tryParse(parts[0]);
      final minutes = double.tryParse(parts[1]);
      final seconds = double.tryParse(parts[2]);
      return hours == null || minutes == null || seconds == null
          ? null
          : hours * 3600 + minutes * 60 + seconds;
    }
    return null;
  }

  void _deleteSelectedCaptionCue() {
    if (_videos.isEmpty || _selectedCaptionCues.isEmpty) return;
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before deleting captions.');
      return;
    }
    _recordEditorHistory('caption-delete');
    final path = _videos[_selectedVideoIndex].path;
    final updated = [..._selectedCaptionCues];
    final index = _selectedCaptionCueIndex.clamp(0, updated.length - 1);
    updated.removeAt(index);
    _updateEditor(() {
      _captionCuesByVideo[path] = updated;
      _selectedCaptionCueIndex =
          updated.isEmpty ? 0 : index.clamp(0, updated.length - 1);
      _status = 'Caption deleted';
    });
    unawaited(_autosaveProject());
  }

  void _splitSelectedCaptionCue() {
    if (_videos.isEmpty || _selectedCaptionCues.isEmpty) return;
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before splitting captions.');
      return;
    }
    final path = _videos[_selectedVideoIndex].path;
    final updated = [..._selectedCaptionCues];
    final index = _selectedCaptionCueIndex.clamp(0, updated.length - 1);
    final cue = updated[index];
    var split = _currentPlayheadSeconds();
    if (split <= cue.start + 0.05 || split >= cue.end - 0.05) {
      split = (cue.start + cue.end) / 2;
    }
    final words = cue.text.trim().split(RegExp(r'\s+'));
    final cut = math.max(1, (words.length / 2).ceil());
    final firstText = words.take(cut).join(' ');
    final secondText = words.skip(cut).join(' ');
    if (secondText.isEmpty) {
      _showMessage('Add more words before splitting this caption.');
      return;
    }
    _recordEditorHistory('caption-split');
    updated
      ..removeAt(index)
      ..insertAll(index, [
        cue.copyWith(end: split, text: firstText, words: const []),
        cue.copyWith(start: split, text: secondText, words: const []),
      ]);
    _updateEditor(() {
      _captionCuesByVideo[path] = updated;
      _selectedCaptionCueIndex = index;
      _status = 'Caption split at ${_formatDuration(split)}';
    });
    unawaited(_autosaveProject());
  }

  void _mergeSelectedCaptionCue() {
    if (_videos.isEmpty || _selectedCaptionCues.length < 2) return;
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before merging captions.');
      return;
    }
    _recordEditorHistory('caption-merge');
    final path = _videos[_selectedVideoIndex].path;
    final updated = [..._selectedCaptionCues];
    final index = _selectedCaptionCueIndex.clamp(0, updated.length - 1);
    final otherIndex = index < updated.length - 1 ? index + 1 : index - 1;
    final firstIndex = math.min(index, otherIndex);
    final first = updated[firstIndex];
    final second = updated[firstIndex + 1];
    final merged = _CaptionCue(
      start: math.min(first.start, second.start),
      end: math.max(first.end, second.end),
      text: '${first.text.trim()} ${second.text.trim()}'.trim(),
      x: first.x,
      y: first.y,
    );
    updated
      ..removeRange(firstIndex, firstIndex + 2)
      ..insert(firstIndex, merged);
    _updateEditor(() {
      _captionCuesByVideo[path] = updated;
      _selectedCaptionCueIndex = firstIndex;
      _status = 'Captions merged';
    });
    unawaited(_autosaveProject());
  }

  Future<void> _importSubtitleFile() async {
    if (_videos.isEmpty) return;
    if (_captionTrackLocked) {
      _showMessage('Unlock T1 before importing captions.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt', 'ass'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final extension = path.toLowerCase().split('.').last;
    List<_CaptionCue> cues;
    if (extension == 'ass') {
      cues = await _captionCuesFromAss(path, capCutStyleOnly: false);
    } else {
      cues = _captionCuesFromSrtOrVtt(await File(path).readAsString());
    }
    if (!mounted) return;
    if (cues.isEmpty) {
      _showMessage('No valid subtitle cues were found in this file.');
      return;
    }
    _recordEditorHistory('caption-import');
    _updateEditor(() {
      _captionCuesByVideo[_videos[_selectedVideoIndex].path] = cues;
      _selectedCaptionCueIndex = 0;
      _automaticCaptions = true;
      _status =
          'Imported ${cues.length} captions from ${platform.basename(path)}';
    });
    unawaited(_autosaveProject());
  }

  List<_CaptionCue> _captionCuesFromSrtOrVtt(String input) {
    final normalized = input
        .replaceFirst('\ufeff', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <_CaptionCue>[];
    final timing = RegExp(
      r'((?:\d+:)?\d{1,2}:\d{2}[\.,]\d{3})\s*-->\s*((?:\d+:)?\d{1,2}:\d{2}[\.,]\d{3})',
    );
    for (final block in blocks) {
      final lines =
          block.split('\n').where((line) => line.trim().isNotEmpty).toList();
      final timingIndex = lines.indexWhere((line) => timing.hasMatch(line));
      if (timingIndex < 0) continue;
      final match = timing.firstMatch(lines[timingIndex])!;
      final start = _parseCaptionEditorTime(match.group(1) ?? '');
      final end = _parseCaptionEditorTime(match.group(2) ?? '');
      final text = lines
          .skip(timingIndex + 1)
          .join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim();
      if (start != null && end != null && end > start && text.isNotEmpty) {
        cues.add(_CaptionCue(start: start, end: end, text: text));
      }
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  Future<void> _exportSubtitleFile() async {
    if (_videos.isEmpty || _selectedCaptionCues.isEmpty) {
      _showMessage('Generate or import captions before exporting subtitles.');
      return;
    }
    final format = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const KText('Export subtitle file'),
        children: [
          for (final item in const ['srt', 'vtt', 'ass'])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(item),
              child: KText(item.toUpperCase()),
            ),
        ],
      ),
    );
    if (format == null || !mounted) return;
    final videoName = _withoutExtension(_videos[_selectedVideoIndex].name);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export ${format.toUpperCase()} subtitles',
      fileName: '${_safeName(videoName)}.$format',
      type: FileType.custom,
      allowedExtensions: [format],
    );
    if (path == null) return;
    final target =
        path.toLowerCase().endsWith('.$format') ? path : '$path.$format';
    await File(target).writeAsString(
      _subtitleFileContents(format, _selectedCaptionCues),
      flush: true,
    );
    if (mounted) {
      _updateEditor(() =>
          _status = 'Subtitle file exported: ${platform.basename(target)}');
    }
  }

  String _subtitleFileContents(String format, List<_CaptionCue> cues) {
    if (format == 'ass') {
      final events = [
        for (final cue in cues)
          'Dialogue: 0,${_assExportTime(cue.start)},${_assExportTime(cue.end)},Default,,0,0,0,,${_subtitleAssText(cue.text)}',
      ];
      return '[Script Info]\nScriptType: v4.00+\nPlayResX: 1920\nPlayResY: 1080\n\n'
          '[V4+ Styles]\nFormat: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding\n'
          'Style: Default,${_safeCaptionFont(_captionFont).replaceAll(',', ' ')},${_captionAssFontSize(_captionFontSize).round()},&H00FFFFFF,&H0000FFFF,&H00000000,&H80000000,${_captionBold ? -1 : 0},${_captionItalic ? -1 : 0},${_captionUnderline ? -1 : 0},0,100,100,${_captionCharacterSpacing.toStringAsFixed(1)},0,1,4,2,2,30,30,70,1\n\n'
          '[Events]\nFormat: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text\n${events.join('\n')}\n';
    }
    final buffer = StringBuffer();
    if (format == 'vtt') buffer.writeln('WEBVTT\n');
    for (var index = 0; index < cues.length; index++) {
      final cue = cues[index];
      if (format == 'srt') buffer.writeln(index + 1);
      buffer.writeln(
        '${_subtitleTime(cue.start, comma: format == 'srt')} --> '
        '${_subtitleTime(cue.end, comma: format == 'srt')}',
      );
      buffer.writeln(cue.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _subtitleTime(double seconds, {required bool comma}) {
    final safe = math.max(0.0, seconds);
    final milliseconds = (safe * 1000).round();
    final hours = milliseconds ~/ 3600000;
    final minutes = (milliseconds ~/ 60000) % 60;
    final secs = (milliseconds ~/ 1000) % 60;
    final millis = milliseconds % 1000;
    final separator = comma ? ',' : '.';
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}$separator'
        '${millis.toString().padLeft(3, '0')}';
  }

  String _subtitleAssText(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}')
      .replaceAll('\r\n', r'\N')
      .replaceAll('\n', r'\N');

  _CaptionCue? _activeCaptionCue() {
    if (_videos.isEmpty || _captionTrackHidden) return null;
    // The preview controller position is source-media time. Program clips can
    // start hundreds of seconds into that source while appearing near the
    // beginning of the edited timeline, so it must never be used to choose an
    // active timeline clip. Resolve the program playhead first, then map that
    // active clip back to source time for its source-based caption cues.
    final timelineSeconds = _currentProgramSeconds();
    for (final track in _programPreviewTimeline.videoTracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips.reversed) {
        if (clip.isMuted ||
            timelineSeconds < clip.timelineStart ||
            timelineSeconds >= clip.timelineEnd) {
          continue;
        }
        final playbackSpeed = _clipTimelineEditFor(clip.mediaPath)
            .speed
            .clamp(_EditorScreenState._minVideoSpeed,
                _EditorScreenState._maxVideoSpeed)
            .toDouble();
        final sourceSeconds = clip.sourceStart +
            (timelineSeconds - clip.timelineStart) * playbackSpeed;
        for (final cue
            in _captionCuesByVideo[clip.mediaPath] ?? const <_CaptionCue>[]) {
          if (sourceSeconds >= cue.start && sourceSeconds < cue.end) return cue;
        }
      }
    }
    return null;
  }

  Widget _captionPreviewLayer({
    required VideoPlayerController controller,
    required double videoHeight,
  }) {
    return Positioned.fill(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final cue = _activeCaptionCue();
          if (cue == null) return const SizedBox.shrink();
          return LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = constraints.maxHeight <= 0
                  ? videoHeight
                  : constraints.maxHeight;
              final scale = previewHeight / videoHeight;
              final fontSize = _captionPreviewFontSize(
                scale: scale,
                previewHeight: previewHeight,
              );
              final preset = _captionPreset(_captionStyle);
              final style = _resolvedCaptionStyle;
              final currentSeconds = value.position.inMilliseconds / 1000;
              final sharedCaption =
                  cue.words.isEmpty || _captionParagraphSpec.timedHighlight;
              final visualState = EditorSession.captionResolver(cue,
                      motion: preset.motion, textCase: _captionCase)
                  .resolve(currentSeconds);
              final captionBackground = sharedCaption
                  ? Colors.transparent
                  : style.backgroundColor.withOpacity(
                      style.backgroundOpacity,
                    );
              final caption = sharedCaption
                  ? CaptionParagraphView(
                      spec: _captionParagraphSpec,
                      visualState: visualState,
                      highlights: cue.words.isEmpty ? null : visualState.ranges,
                      text: cue.text,
                      canvasHeight: previewHeight)
                  : _captionWordFlow(
                      cue: cue,
                      currentSeconds: currentSeconds,
                      preset: preset,
                      fontSize: fontSize,
                      scale: scale,
                    );
              return Align(
                alignment: Alignment(
                  cue.x.clamp(0.0, 1.0) * 2 - 1,
                  cue.y.clamp(0.0, 1.0) * 2 - 1,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _recordEditorHistory('caption-position'),
                  onPanUpdate: (details) => _dragSelectedCaptions(
                    cue,
                    Offset(
                      details.delta.dx / math.max(1, constraints.maxWidth),
                      details.delta.dy / math.max(1, previewHeight),
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: captionBackground,
                      borderRadius: BorderRadius.circular(
                        (style.borderRadius * scale)
                            .clamp(0.0, 24.0)
                            .toDouble(),
                      ),
                    ),
                    child: Padding(
                      padding: captionBackground == Colors.transparent
                          ? EdgeInsets.zero
                          : EdgeInsets.symmetric(
                              horizontal: (style.padding * scale)
                                  .clamp(2.0, 50.0)
                                  .toDouble(),
                              vertical: (style.padding * 0.5 * scale)
                                  .clamp(1.0, 30.0)
                                  .toDouble(),
                            ),
                      child: caption,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
