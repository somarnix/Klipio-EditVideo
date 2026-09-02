part of '../editor_application.dart';

// export operations owned by the editor state; extracted without changing timing.
extension _ExportLoadExportAvailability on _EditorScreenState {
  Future<void> _loadExportAvailability() async {
    final available = await isExportAvailable();
    if (!mounted) return;
    _updateEditor(() => _exportAvailable = available);
  }

  Future<void> _saveCurrentExportPreset() async {
    final controller = TextEditingController(
      text: 'Preset ${_exportPresets.length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const KText('Save Export Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const KText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const KText('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    final preset = _ExportPreset(
      name: trimmed,
      outputName: _nameController.text,
      batchRenamePattern: _batchRenamePattern,
      qualityPreset: _qualityPreset,
      customBitrateKbps: _customBitrateKbps,
      exportTimelineTogether: _exportTimelineTogether,
      useNumberRange: _useNumberRange,
      rangeStart: _numberStartController.text,
      rangeEnd: _numberEndController.text,
    );
    _updateEditor(() {
      _exportPresets.removeWhere((item) => item.name == trimmed);
      _exportPresets.insert(0, preset);
      if (_exportPresets.length > 12) {
        _exportPresets.removeRange(12, _exportPresets.length);
      }
      _status = 'Saved export preset: $trimmed';
    });
    unawaited(_saveWorkspaceMemory());
  }

  void _applyExportPreset(_ExportPreset preset) {
    _updateEditor(() {
      _nameController.text = preset.outputName;
      _batchRenamePattern = preset.batchRenamePattern;
      _qualityPreset = preset.qualityPreset;
      _customBitrateKbps = preset.customBitrateKbps;
      _batchRenameController.text = preset.batchRenamePattern;
      _exportTimelineTogether = preset.exportTimelineTogether;
      _useNumberRange = preset.useNumberRange;
      _numberStartController.text = preset.rangeStart;
      _numberEndController.text = preset.rangeEnd;
      _status = 'Applied export preset: ${preset.name}';
    });
  }

  Future<void> _showExportHub() async {
    if (_videos.isEmpty) {
      _showMessage('Select one or more videos first.');
      return;
    }
    await _pausePlaybackForExport();
    var destination = 'video';
    var oneDraft = _exportTimelineTogether;
    var useNumberRange = _useNumberRange;
    final initialFolder = _outputFolder ?? await _defaultOutputFolder();
    if (initialFolder == null) return;
    if (!mounted) return;
    var localExportFolder = initialFolder;
    var localName = _nameController.text;
    var localBatchRenamePattern = _batchRenamePattern;
    var localQuality = _qualityPreset;
    var localTimelineTogether =
        _exportsSeparatePartFiles ? false : _exportTimelineTogether;
    var localUseNumberRange = _useNumberRange;
    var localRangeStart = _numberStartController.text.trim().isEmpty
        ? '1'
        : _numberStartController.text.trim();
    var localRangeEnd = _automaticNumberRangeEndText(
      localRangeStart,
      _numberEndController.text,
    );
    var capCutDraftFolder = initialFolder;
    final capCutNameController = TextEditingController(
      text: _nameController.text,
    );
    final capCutNumberStartController = TextEditingController(
      text: _numberStartController.text,
    );
    final capCutNumberEndController = TextEditingController(
      text: _automaticNumberRangeEndText(
        capCutNumberStartController.text,
        _numberEndController.text,
      ),
    );
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isWindows = platform.isDesktop && Platform.isWindows;
          return Dialog(
            backgroundColor: _panelColor,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: _panelBorderColor),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 650),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 17, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: KText(
                            'Export',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        const ButtonSegment(
                          value: 'video',
                          icon: Icon(Icons.video_file_outlined, size: 18),
                          label: KText('Local video'),
                        ),
                        ButtonSegment(
                          value: 'draft',
                          enabled: isWindows,
                          icon: const Icon(Icons.movie_creation_outlined,
                              size: 18),
                          label: const KText('CapCut draft'),
                        ),
                      ],
                      selected: {destination},
                      onSelectionChanged: (value) => setDialogState(
                        () => destination = value.first,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: destination == 'video'
                            ? Column(
                                key: const ValueKey('video-export'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    initialValue: localName,
                                    decoration:
                                        _exportInputDecoration('Name').copyWith(
                                      hintText: 'Blank = original video name',
                                    ),
                                    onChanged: (value) => localName = value,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    initialValue: localBatchRenamePattern,
                                    decoration: _exportInputDecoration(
                                      'Batch rename pattern',
                                    ).copyWith(
                                      hintText:
                                          'Optional: {n}.{title}, Reel {index}',
                                      helperText:
                                          'Tokens: {n}, {index}, {title}, {name}',
                                    ),
                                    onChanged: (value) =>
                                        localBatchRenamePattern = value,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InputDecorator(
                                          decoration: _exportInputDecoration(
                                            'Export to',
                                          ),
                                          child: KText(
                                            localExportFolder,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        onPressed: () async {
                                          final picked = await FilePicker
                                              .platform
                                              .getDirectoryPath(
                                            dialogTitle: 'Choose export folder',
                                            initialDirectory: localExportFolder,
                                          );
                                          if (picked == null ||
                                              picked.trim().isEmpty) {
                                            return;
                                          }
                                          setDialogState(() {
                                            localExportFolder = picked;
                                          });
                                        },
                                        icon: const Icon(Icons.folder_open),
                                        tooltip: 'Choose output folder',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: localUseNumberRange,
                                    onChanged: (value) => setDialogState(() {
                                      localUseNumberRange = value ?? false;
                                    }),
                                    title: const KText('Output numbering'),
                                    subtitle: KText(
                                      localUseNumberRange
                                          ? 'Name ${_numberRangeVideoCount(localRangeStart, localRangeEnd)} videos ${_numberRangeStartValue(localRangeStart)}.title to ${_numberRangeStartValue(localRangeStart) + _numberRangeVideoCount(localRangeStart, localRangeEnd) - 1}.title'
                                          : 'Keep normal video names',
                                    ),
                                  ),
                                  if (localUseNumberRange) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: localRangeStart,
                                            keyboardType: TextInputType.number,
                                            decoration:
                                                _exportInputDecoration('Start'),
                                            onChanged: (value) =>
                                                localRangeStart = value,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: localRangeEnd,
                                            keyboardType: TextInputType.number,
                                            decoration:
                                                _exportInputDecoration('End')
                                                    .copyWith(
                                              hintText: 'Blank = all videos',
                                            ),
                                            onChanged: (value) =>
                                                localRangeEnd = value,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: localTimelineTogether,
                                    onChanged: _exportsSeparatePartFiles
                                        ? null
                                        : (value) => setDialogState(() {
                                              localTimelineTogether = value;
                                            }),
                                    title: const KText(
                                      'One timeline video',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: KText(
                                      localTimelineTogether
                                          ? 'Export the edited timeline as one MP4'
                                          : 'Export selected videos separately',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _exportDialogDropdown(
                                    label: 'Quality',
                                    value: localQuality,
                                    items: const [
                                      '4K',
                                      '1080p',
                                      '720p',
                                      '480p',
                                      'Low',
                                      'Custom',
                                    ],
                                    onChanged: (value) => setDialogState(
                                      () => localQuality = value,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _exportStaticRow(
                                    'Codec',
                                    'H.264 fast',
                                  ),
                                  _exportStaticRow('Format', 'mp4'),
                                  _exportStaticRow(
                                    'Frame rate',
                                    'Source fps',
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('draft-export'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: capCutNameController,
                                    decoration:
                                        _exportInputDecoration('Name').copyWith(
                                      hintText: 'Blank = original video name',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InputDecorator(
                                          decoration: _exportInputDecoration(
                                            'Export to',
                                          ),
                                          child: KText(
                                            capCutDraftFolder,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        onPressed: () async {
                                          final picked = await FilePicker
                                              .platform
                                              .getDirectoryPath(
                                            dialogTitle:
                                                'Choose where to save CapCut draft',
                                            initialDirectory: capCutDraftFolder,
                                          );
                                          if (picked == null ||
                                              picked.trim().isEmpty) {
                                            return;
                                          }
                                          setDialogState(() {
                                            capCutDraftFolder = picked;
                                          });
                                        },
                                        icon: const Icon(Icons.folder_open),
                                        tooltip: 'Choose output folder',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: oneDraft,
                                    onChanged: (value) => setDialogState(
                                      () => oneDraft = value,
                                    ),
                                    title: const KText('One CapCut draft'),
                                    subtitle: const KText(
                                      'Keep all selected clips together',
                                    ),
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: useNumberRange,
                                    onChanged: (value) => setDialogState(
                                      () => useNumberRange = value,
                                    ),
                                    title: const KText(
                                      'Number CapCut outputs',
                                    ),
                                    subtitle: const KText(
                                      'Choose the first and last output number',
                                    ),
                                  ),
                                  if (useNumberRange)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                capCutNumberStartController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Start number',
                                              hintText: '1',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller:
                                                capCutNumberEndController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'End number',
                                              hintText: '5',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  const ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.bolt_outlined),
                                    title: KText(
                                      'Fast draft mode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: KText(
                                      'No local render. Video cuts and text layers stay editable. Captions are saved separately in a Caption folder as SRT.',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: _panelBorderColor),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const KText('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            destination,
                          ),
                          icon: Icon(destination == 'video'
                              ? Icons.arrow_forward
                              : Icons.movie_creation_outlined),
                          label: KText(destination == 'video'
                              ? 'Export'
                              : 'Create draft'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    final capCutName = capCutNameController.text;
    final capCutNumberStart = capCutNumberStartController.text;
    final capCutNumberEnd = capCutNumberEndController.text;
    capCutNameController.dispose();
    capCutNumberStartController.dispose();
    capCutNumberEndController.dispose();
    if (choice == null || !mounted) return;
    _updateEditor(() {
      if (choice == 'video') {
        _outputFolder = localExportFolder.trim();
        _nameController.text = localName.trim();
        _batchRenamePattern = localBatchRenamePattern.trim();
        _batchRenameController.text = _batchRenamePattern;
        _qualityPreset = localQuality;
        _exportTimelineTogether = localTimelineTogether;
        _useNumberRange = localUseNumberRange;
        _numberStartController.text =
            localRangeStart.trim().isEmpty ? '1' : localRangeStart.trim();
        _numberEndController.text = _automaticNumberRangeEndText(
          _numberStartController.text,
          localRangeEnd,
        );
      } else {
        _exportTimelineTogether = oneDraft;
        _capCutOneFolder = oneDraft;
        _capCutRenderEdits = false;
        _nameController.text = capCutName.trim();
        _outputFolder = capCutDraftFolder.trim();
        _useNumberRange = useNumberRange;
        _numberStartController.text = capCutNumberStart;
        _numberEndController.text = _automaticNumberRangeEndText(
          _numberStartController.text,
          capCutNumberEnd,
        );
      }
    });
    if (choice == 'draft') {
      await _createCapCutDraft(showSettingsDialog: false);
    } else {
      await _exportVideos(showSettingsDialog: false);
    }
  }

  Future<void> _exportVideos({
    bool prepareForCapCut = false,
    bool showSettingsDialog = true,
  }) async {
    try {
      await _exportVideosImpl(
        prepareForCapCut: prepareForCapCut,
        showSettingsDialog: showSettingsDialog,
      );
    } catch (error, stackTrace) {
      await _recoverUnexpectedExportFailure(error, stackTrace);
    }
  }
}
