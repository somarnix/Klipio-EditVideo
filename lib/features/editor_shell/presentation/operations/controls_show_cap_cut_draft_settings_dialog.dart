part of '../editor_application.dart';

// controls operations owned by the editor state; extracted without changing timing.
extension _ControlsShowCapCutDraftSettingsDialog on _EditorScreenState {
  Future<String?> _showCapCutDraftSettingsDialog(String initialFolder) async {
    var draftFolder = initialFolder;
    var name = _nameController.text;
    var oneDraft = _exportTimelineTogether;
    var useNumberRange = _useNumberRange;
    var rangeStart = _numberStartController.text.trim().isEmpty
        ? '1'
        : _numberStartController.text.trim();
    var rangeEnd = _automaticNumberRangeEndText(
      rangeStart,
      _numberEndController.text,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isExporting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCount = useNumberRange
                ? _numberRangeVideoCount(rangeStart, rangeEnd)
                : _selectedExportVideoCount();
            return Dialog(
              backgroundColor: _panelColor,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _panelBorderColor),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.sizeOf(context).height - 48,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Row(
                        children: [
                          const KText(
                            'Create CapCut draft',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          KText(
                            oneDraft ? '1 draft' : '$selectedCount drafts',
                            style: const TextStyle(
                              color: Color(0xffa3a3a3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _panelBorderColor),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              initialValue: name,
                              decoration:
                                  _exportInputDecoration('Name').copyWith(
                                hintText: 'Blank = original video name',
                              ),
                              onChanged: (value) => name = value,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InputDecorator(
                                    decoration:
                                        _exportInputDecoration('Export to'),
                                    child: KText(
                                      draftFolder,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () async {
                                    final picked = await FilePicker.platform
                                        .getDirectoryPath(
                                      dialogTitle:
                                          'Choose where to save CapCut draft',
                                      initialDirectory: draftFolder,
                                    );
                                    if (picked == null ||
                                        picked.trim().isEmpty) {
                                      return;
                                    }
                                    setDialogState(() {
                                      draftFolder = picked;
                                    });
                                  },
                                  icon: const Icon(Icons.folder_open),
                                  tooltip: 'Choose output folder',
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: useNumberRange,
                              onChanged: (value) => setDialogState(() {
                                useNumberRange = value ?? false;
                              }),
                              title: const KText('Output numbering'),
                              subtitle: KText(
                                useNumberRange
                                    ? 'Name ${_numberRangeVideoCount(rangeStart, rangeEnd)} videos ${_numberRangeStartValue(rangeStart)}.title to ${_numberRangeStartValue(rangeStart) + _numberRangeVideoCount(rangeStart, rangeEnd) - 1}.title'
                                    : 'Keep normal video names',
                              ),
                            ),
                            if (useNumberRange) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: rangeStart,
                                      keyboardType: TextInputType.number,
                                      decoration:
                                          _exportInputDecoration('Start'),
                                      onChanged: (value) => rangeStart = value,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: rangeEnd,
                                      keyboardType: TextInputType.number,
                                      decoration: _exportInputDecoration('End')
                                          .copyWith(
                                        hintText: 'Blank = all videos',
                                      ),
                                      onChanged: (value) => rangeEnd = value,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                            SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: oneDraft,
                              onChanged: (value) => setDialogState(() {
                                oneDraft = value;
                              }),
                              title: const KText(
                                'One CapCut draft',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: KText(
                                oneDraft
                                    ? 'Put selected clips into one editable CapCut draft'
                                    : 'Create one draft for each selected video',
                              ),
                            ),
                            const ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.bolt_outlined),
                              title: KText(
                                'Fast draft mode',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: KText(
                                'No local render. Video cuts and text layers stay editable. Captions are exported to a Caption folder as SRT for manual import.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: _panelBorderColor),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const KText('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const KText('Create draft'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed != true) return null;
    final cleanFolder = draftFolder.trim();
    if (cleanFolder.isEmpty) return null;
    _updateEditor(() {
      _outputFolder = cleanFolder;
      _nameController.text = name.trim();
      _exportTimelineTogether = oneDraft;
      _useNumberRange = useNumberRange;
      _numberStartController.text =
          rangeStart.trim().isEmpty ? '1' : rangeStart.trim();
      _numberEndController.text = _automaticNumberRangeEndText(
        _numberStartController.text,
        rangeEnd,
      );
    });
    return cleanFolder;
  }

  List<List<_QueuedExport>> _capCutDraftGroups(List<_QueuedExport> jobs) {
    if (_exportSplitPartsAsFiles) {
      return [
        for (final job in jobs) [job],
      ];
    }
    if (_exportTimelineTogether) return [jobs];
    final groups = <List<_QueuedExport>>[];
    for (final job in jobs) {
      final existingIndex = groups.indexWhere(
        (group) => group.first.video.path == job.video.path,
      );
      if (existingIndex >= 0) {
        groups[existingIndex].add(job);
      } else {
        groups.add([job]);
      }
    }
    return groups;
  }

  String _extensionOrDefault(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.mp4';
    final extension = name.substring(dot);
    return extension.length > 8 ? '.mp4' : extension;
  }

  Future<void> _returnToHome({bool closeDialog = false}) async {
    await _autosaveProject();
    await _sourceController?.pause();
    await _previewController?.pause();
    await _stopMusicPreview();
    if (!mounted) return;
    if (closeDialog) _closeExportProgressDialog();
    widget.onBackHome();
  }

  void _resumeRenderQueue() {
    if (!_isExporting) return;
    _exportCancelToken?.resume();
    _updateEditor(() {
      _renderQueuePaused = false;
      _status = 'Resuming render queue...';
    });
    final view = _exportProgressView.value;
    final details = view.details;
    if (details != null) {
      _updateExportProgressView(
        details: details,
        progress: _progress,
        elapsed: view.elapsed,
        status: 'Resuming render queue...',
      );
    }
  }

  Future<bool> _waitForRenderQueueResume({
    required KlipioExportDialogDetails details,
    required DateTime exportStartedAt,
  }) async {
    while (mounted &&
        _renderQueuePaused &&
        !_renderQueueStopRequested &&
        _exportCancelToken?.isCanceled != true) {
      _updateExportProgressView(
        details: details,
        progress: _progress,
        elapsed: DateTime.now().difference(exportStartedAt),
        status: 'Render queue paused...',
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return mounted &&
        !_renderQueueStopRequested &&
        _exportCancelToken?.isCanceled != true;
  }

  int _bitrateForQuality(String quality) {
    return switch (quality) {
      '4K' => 35000,
      '1080p' => 8000,
      '720p' => 5000,
      '480p' => 2500,
      'Low' => 1200,
      'Custom' => _customBitrateKbps.round(),
      _ => 8000,
    };
  }

  String _formatClock(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTimecode(double seconds) {
    final safe = seconds.isFinite ? math.max(0.0, seconds) : 0.0;
    final wholeSeconds = safe.floor();
    final frameRate = _projectFrameRate.clamp(1.0, 120.0);
    final frames = ((safe - wholeSeconds) * frameRate).floor();
    final hours = wholeSeconds ~/ 3600;
    final minutes = (wholeSeconds ~/ 60) % 60;
    final secs = wholeSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}:'
        '${frames.toString().padLeft(2, '0')}';
  }

  VideoEditSettings get _settings {
    _saveSelectedTextOverlay();
    final caption = _resolvedCaptionStyle;
    return VideoEditSettings(
      speed: _speed,
      flip: _flip,
      scaleX: _scaleX,
      scaleY: _scaleY,
      zoom: _zoom,
      watermarkPath: _watermarkPath,
      watermarkPosition: 'custom',
      watermarkSize: _watermarkSize,
      musicPath: _musicPath,
      originalVolume: _originalAudioMuted ? 0 : _originalVolume,
      musicVolume: _musicTrackMuted ? 0 : _musicVolume,
      outputRatio: _outputRatio,
      canvasMode: _canvasMode,
      canvasColor: _colorToHex(_canvasColor),
      canvasPattern: _canvasPattern,
      canvasBlur: _canvasBlur,
      panX: _panX,
      panY: _panY,
      overlayText: _overlayTextController.text,
      overlayTextX: _overlayTextX,
      overlayTextY: _overlayTextY,
      overlayTextSize: _overlayTextSize,
      overlayFont: _overlayFont,
      overlayTextColor: _colorToHex(_overlayTextColor),
      overlayTextOpacity: _overlayTextOpacity,
      overlayTextStroke: _overlayTextStroke,
      overlayTextStrokeColor: _colorToHex(_overlayTextStrokeColor),
      overlayTextStrokeOpacity: _overlayTextStrokeOpacity,
      overlayTextShadow: true,
      overlayTextShadowColor: _colorToHex(_overlayTextShadowColor),
      overlayTextShadowOpacity: _overlayTextShadowOpacity,
      overlayTextAnimation: _overlayTextAnimation,
      overlayTextAnimationDuration: _overlayTextAnimationDuration,
      overlayTextStartX: _overlayTextStartX,
      overlayTextStartY: _overlayTextStartY,
      // Captions are exported through the generated ASS file. Adding them to
      // textOverlays as well duplicates every cue into FFmpeg's command line
      // and can exceed Windows' CreateProcess limit on long videos.
      textOverlays: _exportManualTextOverlays(),
      watermarkX: _watermarkX,
      watermarkY: _watermarkY,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      gamma: _gamma,
      trimStartSeconds: _trimStartSeconds,
      trimEndSeconds: _trimEndSeconds,
      videoBitrateKbps: _exportBitrateKbps,
      exportCodec: _exportCodec,
      exportFrameRate: _exportFrameRate,
      automaticCaptions: _automaticCaptions && !_captionTrackHidden,
      captionModel: _captionModel,
      captionLanguage: _captionLanguage,
      captionDevice: _captionDevice,
      captionStyle: _captionStyle,
      captionWordsPerLine: caption.wordsPerLine,
      captionFont: caption.fontFamily,
      captionFontSize: caption.fontSize,
      captionBold: caption.bold,
      captionUnderline: caption.underline,
      captionItalic: caption.italic,
      captionCase: _captionCase,
      captionColor: _colorToHex(caption.color),
      captionCharacterSpacing: caption.letterSpacing,
      captionWordSpacing: caption.wordSpacing,
      captionLineSpacing: caption.lineSpacing,
      captionOpacity: caption.opacity,
      captionStrokeEnabled: caption.strokeWidth > 0,
      captionStrokeColor: _colorToHex(caption.strokeColor),
      captionStrokeWidth: caption.strokeWidth,
      captionBackgroundEnabled: caption.backgroundOpacity > 0,
      captionBackgroundColor: _colorToHex(caption.backgroundColor),
      captionBackgroundOpacity: caption.backgroundOpacity,
      captionBackgroundPadding: caption.padding,
      captionGlowEnabled: _captionGlowEnabled,
      captionGlowColor: _colorToHex(_captionGlowColor),
      captionGlowStrength: _captionGlowStrength,
      captionShadowEnabled: caption.shadowBlur > 0,
      captionShadowColor: _colorToHex(caption.shadowColor),
      captionShadowStrength: caption.shadowBlur,
      captionCurve: _captionCurve,
      hardwareEncoding: widget.settings.hardwareEncoding,
      hardwareDecoding: widget.settings.hardwareDecoding,
    );
  }

  double _parseDurationSeconds(
    String input, {
    double plainNumberSeconds = 1,
  }) {
    final raw = input.trim().toLowerCase();
    if (raw.isEmpty) return 0;

    if (raw.contains(':')) {
      final parts = raw.split(':');
      if (parts.length < 2 || parts.length > 3) return 0;
      final values = parts.map((part) => double.tryParse(part.trim())).toList();
      if (values.any((value) => value == null || value < 0)) return 0;
      if (values.length == 2) {
        return values[0]! * 60 + values[1]!;
      }
      return values[0]! * 3600 + values[1]! * 60 + values[2]!;
    }

    final unitPattern = RegExp(
      r'(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\b',
    );
    final matches = unitPattern.allMatches(raw).toList();
    if (matches.isNotEmpty) {
      var seconds = 0.0;
      for (final match in matches) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value == null || value < 0) return 0;
        final unit = match.group(2) ?? '';
        if (unit.startsWith('h')) {
          seconds += value * 3600;
        } else if (unit.startsWith('m')) {
          seconds += value * 60;
        } else {
          seconds += value;
        }
      }
      return seconds;
    }

    final plain = double.tryParse(raw);
    if (plain == null || plain <= 0) return 0;
    return plain * plainNumberSeconds;
  }

  List<_QueuedExport> _capCutJobs(
    List<_QueuedExport> jobs, {
    required String rootFolder,
    required bool oneFolder,
    required bool renderEdits,
  }) {
    final clipCounters = <String, int>{};
    return [
      for (var index = 0; index < jobs.length; index++)
        _QueuedExport(
          video: jobs[index].video,
          outputPath: _capCutClipOutputPath(
            jobs[index],
            rootFolder,
            index,
            (clipCounters[jobs[index].video.path] =
                (clipCounters[jobs[index].video.path] ?? 0) + 1),
            oneFolder: oneFolder,
          ),
          settings: renderEdits
              ? jobs[index].settings
              : _capCutFastSettings(jobs[index].settings),
          partIndex: jobs[index].partIndex,
          partCount: jobs[index].partCount,
        ),
    ];
  }

  VideoEditSettings _capCutFastSettings(VideoEditSettings source) {
    return VideoEditSettings(
      speed: 1,
      flip: 'none',
      scaleX: 1,
      scaleY: 1,
      zoom: 1,
      watermarkPath: null,
      watermarkPosition: 'custom',
      watermarkSize: _watermarkSize,
      musicPath: null,
      originalVolume: 1,
      musicVolume: 0,
      outputRatio: 'original',
      panX: 0,
      panY: 0,
      overlayText: '',
      textOverlays: const [],
      brightness: 0,
      contrast: 1,
      saturation: 1,
      gamma: 1,
      trimStartSeconds: source.trimStartSeconds,
      trimEndSeconds: source.trimEndSeconds,
      videoBitrateKbps: source.videoBitrateKbps,
      exportCodec: source.exportCodec,
      exportFrameRate: source.exportFrameRate,
      hardwareEncoding: source.hardwareEncoding,
      hardwareDecoding: source.hardwareDecoding,
    );
  }

  void _syncCutFields() {
    final start = _parseDurationSeconds(_trimStartController.text);
    final end = _parseDurationSeconds(_trimEndController.text);
    _trimStartSeconds = start < 0 ? 0 : start;
    _trimEndSeconds = end < 0 ? 0 : end;
    _saveSelectedClipTimelineEdit();
  }

  String _fieldNumber(double value) {
    return value
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _outputPath(
    String folder,
    int index,
    PickedVideo video, {
    int? segmentIndex,
    int? segmentCount,
  }) {
    if (segmentIndex != null && (segmentCount ?? 0) > 1) {
      final base = _partExportBaseName(index, video, segmentIndex);
      return '$folder${platform.pathSeparator}$base.mp4';
    }
    final base = _exportBaseName(video);
    final videoSuffix =
        _useNumberRange ? '' : (_videos.length > 1 ? '_${index + 1}' : '');
    final suffix = videoSuffix;
    return '$folder${platform.pathSeparator}$base$suffix.mp4';
  }

  int _numberRangeStartValue(String startText) {
    final value = int.tryParse(startText.trim()) ?? 1;
    return value < 1 ? 1 : value;
  }

  int _numberRangeEndValue(String startText, String endText) {
    final start = _numberRangeStartValue(startText);
    return int.tryParse(endText.trim()) ??
        (_videos.isEmpty ? start : start + _videos.length - 1);
  }

  String _safeName(String input) {
    final cleaned =
        input.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]+'), '_');
    final normalized = cleaned.replaceAll(RegExp(r'^[ .]+|[ .]+$'), '');
    return normalized;
  }

  double _hookEditTargetSeconds(double duration) {
    final raw = _hookDurationController.text.trim().toLowerCase();
    final parsed = raw.isEmpty || raw == 'auto'
        ? _autoHookEditSeconds(duration)
        : _parseDurationSeconds(raw, plainNumberSeconds: 60);
    final fallback = _autoHookEditSeconds(duration);
    final requested = parsed <= 0 ? fallback : parsed;
    return requested.clamp(8.0, duration).toDouble();
  }

  double? _manualHookEditSeconds() {
    final raw = _hookDurationController.text.trim().toLowerCase();
    if (raw.isEmpty || raw == 'auto') return null;
    final parsed = _parseDurationSeconds(raw, plainNumberSeconds: 60);
    return parsed <= 0 ? null : parsed;
  }

  double _autoHookEditSeconds(double duration) {
    if (_hookEditMode == _HookEditMode.bestMoments) {
      return _autoHookBestMomentsSeconds(duration);
    }
    if (duration <= 0) return 0;
    if (duration <= 60) return duration;
    if (duration <= 10 * 60) {
      final target = duration * 0.9;
      return target.clamp(math.min(duration, 45.0), duration).toDouble();
    }
    if (duration <= 20 * 60) {
      final target = duration * 0.8;
      return target.clamp(8 * 60, math.min(duration, 10 * 60)).toDouble();
    }
    if (duration <= 30 * 60) {
      final target = duration * 0.75;
      return target.clamp(8 * 60, math.min(duration, 20 * 60)).toDouble();
    }
    final target = duration * 0.65;
    return target.clamp(10 * 60, math.min(duration, 30 * 60)).toDouble();
  }
}
