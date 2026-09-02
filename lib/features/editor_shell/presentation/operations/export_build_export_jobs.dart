part of '../editor_application.dart';

// export operations owned by the editor state; extracted without changing timing.
extension _ExportBuildExportJobs on _EditorScreenState {
  List<_QueuedExport> _buildExportJobs(
    String folder, {
    bool applyNumberRange = true,
  }) {
    _saveSelectedClipTimelineEdit();
    if (!_batchSplitLongVideos) {
      final timelineJobs = _buildTimelineClipExportJobs(
        folder,
        applyNumberRange: applyNumberRange,
      );
      if (timelineJobs.isNotEmpty) return timelineJobs;
    }
    final jobs = <_QueuedExport>[];
    final range = _selectedExportRange();
    for (var videoIndex = 0; videoIndex < _videos.length; videoIndex++) {
      if (applyNumberRange &&
          _useNumberRange &&
          (videoIndex < range.startIndex || videoIndex > range.endIndex)) {
        continue;
      }
      final video = _videos[videoIndex];
      final clipEdit = _clipTimelineEditFor(video.path);
      final batchSplitSeconds = _batchSplitSeconds;
      final applyBatchSplit = _batchSplitLongVideos &&
          batchSplitSeconds > 0 &&
          (!_batchSplitSelectedVideoOnly || videoIndex == _selectedVideoIndex);
      final effectiveEdit = applyBatchSplit
          ? clipEdit.copyWith(splitEverySeconds: batchSplitSeconds)
          : clipEdit;
      final clipSettings = _settingsForClip(effectiveEdit).copyWith(
        captionCues: _captionSettingsForVideo(video.path),
      );
      final parts = effectiveEdit.timelineParts(video.durationSeconds);
      final separatePartFiles = _exportsSeparatePartFiles;
      final splitSectionCount = applyBatchSplit
          ? math.max(
              1,
              ((video.durationSeconds ?? 0) / batchSplitSeconds).ceil(),
            )
          : parts.length;
      for (var partIndex = 0; partIndex < parts.length; partIndex++) {
        final part = parts[partIndex];
        final exportPartIndex = separatePartFiles && parts.length > 1
            ? applyBatchSplit
                ? math.max(1, (part.start / batchSplitSeconds).floor() + 1)
                : partIndex + 1
            : null;
        jobs.add(
          _QueuedExport(
            video: video,
            outputPath: _outputPath(
              folder,
              videoIndex,
              video,
              segmentIndex: exportPartIndex,
              segmentCount: splitSectionCount,
            ),
            settings: clipSettings.copyWith(
              trimStartSeconds: part.start,
              trimEndSeconds: part.end,
            ),
            partIndex: exportPartIndex,
            partCount: exportPartIndex == null ? null : splitSectionCount,
          ),
        );
      }
    }
    return jobs;
  }

  List<_QueuedExport> _buildTimelineClipExportJobs(
    String folder, {
    required bool applyNumberRange,
  }) {
    _storeActiveCompositionTimeline();
    final clips = <({int videoIndex, ClipModel clip})>[];
    final range = _selectedExportRange();
    for (var videoIndex = 0; videoIndex < _videos.length; videoIndex++) {
      if (applyNumberRange &&
          _useNumberRange &&
          (videoIndex < range.startIndex || videoIndex > range.endIndex)) {
        continue;
      }
      final video = _videos[videoIndex];
      final timeline = _selectedCompositionPath == video.path
          ? _multiTrackTimeline
          : _timelinesByComposition[video.path];
      if (timeline == null) continue;
      for (final track in timeline.videoTracks) {
        if (track.isMuted) continue;
        for (final clip in track.clips) {
          if (clip.isMuted ||
              clip.duration <= 0.001 ||
              clip.mediaPath != video.path) {
            continue;
          }
          clips.add((videoIndex: videoIndex, clip: clip));
        }
      }
    }
    clips.sort((a, b) {
      final video = a.videoIndex.compareTo(b.videoIndex);
      if (video != 0) return video;
      final start = a.clip.timelineStart.compareTo(b.clip.timelineStart);
      if (start != 0) return start;
      final track = a.clip.zIndex.compareTo(b.clip.zIndex);
      if (track != 0) return track;
      return a.videoIndex.compareTo(b.videoIndex);
    });
    if (clips.isEmpty) return const [];

    final perVideoClipCounts = <String, int>{};
    for (final item in clips) {
      perVideoClipCounts[item.clip.mediaPath] =
          (perVideoClipCounts[item.clip.mediaPath] ?? 0) + 1;
    }
    final perVideoSeen = <String, int>{};
    return [
      for (final item in clips)
        _timelineClipExportJob(
          folder: folder,
          videoIndex: item.videoIndex,
          clip: item.clip,
          occurrence: perVideoSeen[item.clip.mediaPath] =
              (perVideoSeen[item.clip.mediaPath] ?? 0) + 1,
          occurrenceCount: perVideoClipCounts[item.clip.mediaPath] ?? 1,
        ),
    ];
  }

  _QueuedExport _timelineClipExportJob({
    required String folder,
    required int videoIndex,
    required ClipModel clip,
    required int occurrence,
    required int occurrenceCount,
  }) {
    final video = _videos[videoIndex];
    final edit = _clipTimelineEditFor(video.path);
    final transform = clip.transform;
    final segmentIndex = _exportsSeparatePartFiles ? occurrence : null;
    final clipSettings = _settingsForClip(edit).copyWith(
      trimStartSeconds: clip.sourceStart,
      trimEndSeconds: clip.sourceEnd,
      scaleX: transform.scaleX,
      scaleY: transform.scaleY,
      zoom: 1,
      panX: ((transform.positionX - 0.5) * 2).clamp(-1.0, 1.0).toDouble(),
      panY: ((transform.positionY - 0.5) * 2).clamp(-1.0, 1.0).toDouble(),
      canvasMode: transform.canvasMode,
      canvasColor: transform.canvasColor,
      canvasPattern: transform.canvasPattern,
      canvasBlur: transform.canvasBlur,
      captionCues: _captionSettingsForVideo(video.path),
    );
    return _QueuedExport(
      video: video,
      outputPath: _outputPath(
        folder,
        videoIndex,
        video,
        segmentIndex: segmentIndex,
        segmentCount: segmentIndex == null ? null : occurrenceCount,
      ),
      settings: clipSettings,
      partIndex: segmentIndex,
      partCount: segmentIndex == null ? null : occurrenceCount,
    );
  }

  List<_QueuedExportGroup> _groupQueuedExports(List<_QueuedExport> jobs) {
    final groups = <_QueuedExportGroup>[];
    for (final job in jobs) {
      final existingIndex = groups.indexWhere(
        (group) =>
            group.video.path == job.video.path &&
            group.outputPath == job.outputPath,
      );
      if (existingIndex >= 0) {
        final existing = groups[existingIndex];
        groups[existingIndex] = _QueuedExportGroup(
          video: existing.video,
          outputPath: existing.outputPath,
          parts: [...existing.parts, job],
        );
      } else {
        groups.add(
          _QueuedExportGroup(
            video: job.video,
            outputPath: job.outputPath,
            parts: [job],
          ),
        );
      }
    }
    return groups;
  }

  void _playExportCompleteSound() {
    if (!widget.settings.exportCompleteSound) return;
    unawaited(SystemSound.play(SystemSoundType.alert));
  }

  String _partExportBaseName(int index, PickedVideo video, int partIndex) {
    final number = _useNumberRange ? _exportNumberForVideo(video) : index + 1;
    final label = _safeName(_partLabel.trim()).isEmpty
        ? 'part'
        : _safeName(_partLabel.trim());
    final typed = _safeName(_nameController.text);
    final title = typed.isEmpty ? _videoTitle(video) : typed;
    return _safeName('$number.$label$partIndex.$title');
  }

  String _exportBaseName(PickedVideo video) {
    final patterned = _patternedExportBaseName(video);
    if (patterned.isNotEmpty) return patterned;
    final typed = _safeName(_nameController.text);
    if (typed.isEmpty) return _videoBaseName(video);
    return numberedExportBaseName(
      typed,
      number: _exportNumberForVideo(video),
      enabled: _useNumberRange,
    );
  }

  String _patternedExportBaseName(PickedVideo video) {
    final pattern = _batchRenamePattern.trim();
    if (pattern.isEmpty) return '';
    final number = _exportNumberForVideo(video);
    final sourceTitle = _withoutExtension(video.name);
    final title = _safeName(sourceTitle);
    final typed = _safeName(_nameController.text);
    final value = pattern
        .replaceAll('{n}', '$number')
        .replaceAll('{index}', '$number')
        .replaceAll('{title}', title)
        .replaceAll('{name}', typed.isEmpty ? title : typed);
    final safeValue = _safeName(value);
    if (safeValue.isEmpty) return '';
    return numberedExportBaseName(
      safeValue,
      number: number,
      enabled: _useNumberRange,
      patternIncludesNumber:
          pattern.contains('{n}') || pattern.contains('{index}'),
    );
  }

  int _exportNumberForVideo(PickedVideo video) {
    final index = _videos.indexWhere((item) => item.path == video.path);
    if (index < 0) return 1;
    return _exportRangeStart() + index - _selectedExportRange().startIndex;
  }

  ({int startIndex, int endIndex}) _selectedExportRange() {
    final count = _videos.length;
    if (count <= 0) return (startIndex: 0, endIndex: -1);
    final selectedCount = _selectedExportVideoCount().clamp(0, count);
    if (selectedCount <= 0) return (startIndex: 0, endIndex: -1);
    return (startIndex: 0, endIndex: selectedCount - 1);
  }

  int _exportRangeStart() {
    return _numberRangeStartValue(_numberStartController.text);
  }

  int _exportRangeEnd() {
    return _numberRangeEndValue(
      _numberStartController.text,
      _numberEndController.text,
    );
  }

  int _selectedExportVideoCount() {
    if (!_useNumberRange) return _videos.length;
    return _numberRangeVideoCount(
      _numberStartController.text,
      _numberEndController.text,
    );
  }

  String _assExportTime(double seconds) {
    final safe = math.max(0.0, seconds);
    final hours = safe ~/ 3600;
    final minutes = (safe ~/ 60) % 60;
    final secs = safe - hours * 3600 - minutes * 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  List<Widget> _exportControlSection() {
    return [
      ..._fileControlSection(),
      const SizedBox(height: 18),
      _sectionTitle('AI Hook Video'),
      _hookVideoButton(),
      const SizedBox(height: 18),
      _sectionTitle('CapCut Draft'),
      _capCutDraftButton(),
      const SizedBox(height: 8),
      _capCutPrepareButton(),
      const SizedBox(height: 18),
      _sectionTitle('Render Settings'),
      _exportModeControl(),
      _batchSplitExportControl(),
      const SizedBox(height: 10),
      _dropdown('Format', 'MP4', const ['MP4'], (_) {}),
      _dropdown(
        'Quality',
        _qualityPreset,
        const ['4K', '1080p', '720p', '480p', 'Low', 'Custom'],
        (value) => _updateEditor(() => _qualityPreset = value),
      ),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Export preset',
                prefixIcon: Icon(Icons.bookmark_outline),
              ),
              items: [
                for (final preset in _exportPresets)
                  DropdownMenuItem(
                    value: preset.name,
                    child: KText(preset.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (name) {
                _ExportPreset? preset;
                for (final item in _exportPresets) {
                  if (item.name == name) {
                    preset = item;
                    break;
                  }
                }
                if (preset != null) _applyExportPreset(preset);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _saveCurrentExportPreset,
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save current export preset',
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _batchRenameController,
        decoration: const InputDecoration(
          labelText: 'Batch rename pattern',
          hintText: '{n}.{title}',
          helperText: 'Tokens: {n}, {index}, {title}, {name}',
          prefixIcon: Icon(Icons.drive_file_rename_outline),
        ),
        onChanged: (value) => _updateEditor(() => _batchRenamePattern = value),
      ),
      const SizedBox(height: 10),
      if (_qualityPreset == 'Custom')
        _slider(
          'Video bitrate',
          _customBitrateKbps,
          1000,
          50000,
          (value) => _updateEditor(() => _customBitrateKbps = value),
          divisions: 49,
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KText(
            'Video bitrate: $_exportBitrateKbps kbps',
            style: TextStyle(color: _mutedTextColor, fontSize: 12),
          ),
        ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _isExporting ? _cancelExport : _showExportHub,
        icon: Icon(
          _isExporting
              ? Icons.stop_circle_outlined
              : Icons.file_upload_outlined,
        ),
        label: KText(_isExporting ? 'Cancel Export' : 'Export Video'),
      ),
      if (_isExporting) ...[
        const SizedBox(height: 10),
        _renderQueueControlButton(),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
      ],
    ];
  }

  Widget _exportModeControl() {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: _exportsSeparatePartFiles ? false : _exportTimelineTogether,
      onChanged: _exportsSeparatePartFiles
          ? null
          : (value) => _updateEditor(() => _exportTimelineTogether = value),
      title: const KText(
        'One timeline video',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: KText(
        _exportsSeparatePartFiles
            ? 'Disabled while exporting split parts as separate files'
            : _exportTimelineTogether
                ? 'All imported clips export together as one MP4'
                : 'Export each imported clip as separate files',
      ),
    );
  }

  Widget _batchSplitExportControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _batchSplitLongVideos,
          onChanged: (value) => _updateEditor(() {
            _batchSplitLongVideos = value ?? false;
            if (_batchSplitLongVideos) {
              _exportTimelineTogether = false;
              _exportSplitPartsAsFiles = true;
            }
          }),
          title: const KText(
            'Cut long videos into parts',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const KText(
            'Example: 18 min with 15m max exports part1 15 min and part2 3 min',
          ),
        ),
        if (_batchSplitLongVideos) ...[
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _batchSplitSelectedVideoOnly,
            onChanged: (value) => _updateEditor(
              () => _batchSplitSelectedVideoOnly = value ?? false,
            ),
            title: const KText(
              'Only split selected video',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: KText(
              _batchSplitSelectedVideoOnly
                  ? 'Only the highlighted imported video is split; other videos stay full length'
                  : 'All videos in the export range can be split',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _batchSplitMinutesController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Max duration',
                    hintText: '15m, 900s, 1:00:00',
                    helperText: 'Plain 15 = 15 min',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  onChanged: (_) => _updateEditor(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _partLabelController,
                  decoration: const InputDecoration(
                    labelText: 'Part label',
                    hintText: 'part',
                    helperText: 'part, Part, Video...',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  onChanged: (value) => _updateEditor(() => _partLabel = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _exportSplitPartsAsFiles,
          onChanged: (value) => _updateEditor(() {
            _exportSplitPartsAsFiles = value ?? false;
            if (_exportSplitPartsAsFiles) {
              _exportTimelineTogether = false;
            }
          }),
          title: const KText(
            'Export split parts as files',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: KText(
            _exportSplitPartsAsFiles
                ? 'Each split part becomes its own file or its own CapCut draft folder'
                : 'Split parts stay together in one video or one CapCut draft timeline',
          ),
        ),
      ],
    );
  }

  List<TextOverlaySettings> _exportManualTextOverlays() => TitleProject.decode([
        for (final title in _previewTextOverlays())
          if (title.isVisible && title.text.trim().isNotEmpty)
            title.toJson(_colorToHex)
      ]);
}
