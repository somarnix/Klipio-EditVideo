part of '../editor_application.dart';

// export operations owned by the editor state; extracted without changing timing.
extension _ExportShowExportSettingsDialog on _EditorScreenState {
  Future<bool> _showExportSettingsDialog(
      String initialFolder, List<_QueuedExport> jobs,
      {bool prepareForCapCut = false}) async {
    var exportFolder = initialFolder;
    var quality = _qualityPreset;
    var name = _nameController.text;
    var batchRenamePattern = _batchRenamePattern;
    var exportTimelineTogether = prepareForCapCut
        ? _capCutOneFolder
        : (_exportsSeparatePartFiles ? false : _exportTimelineTogether);
    var renderCapCutEdits = _capCutRenderEdits;
    var useNumberRange = _useNumberRange;
    var rangeStart = _numberStartController.text.trim().isEmpty
        ? '1'
        : _numberStartController.text.trim();
    var rangeEnd = _automaticNumberRangeEndText(
      rangeStart,
      _numberEndController.text,
    );
    final details = _buildExportDialogDetails(exportFolder, jobs);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isExporting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bitrate = _bitrateForQuality(quality);
            final outputCount = prepareForCapCut
                ? jobs.length
                : exportTimelineTogether
                    ? 1
                    : _groupQueuedExports(jobs).length;
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
                          KText(
                            prepareForCapCut
                                ? 'Prepare for CapCut'
                                : exportTimelineTogether
                                    ? 'Export timeline'
                                    : 'Export videos',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          KText(
                            prepareForCapCut
                                ? '$outputCount CapCut clips'
                                : exportTimelineTogether
                                    ? '1 file'
                                    : outputCount == 1
                                        ? '1 file'
                                        : '$outputCount files',
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
                            TextFormField(
                              initialValue: batchRenamePattern,
                              decoration: _exportInputDecoration(
                                'Batch rename pattern',
                              ).copyWith(
                                hintText: 'Optional: {n}.{title}, Reel {index}',
                                helperText:
                                    'Tokens: {n}, {index}, {title}, {name}',
                              ),
                              onChanged: (value) => batchRenamePattern = value,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InputDecorator(
                                    decoration:
                                        _exportInputDecoration('Export to'),
                                    child: KText(
                                      exportFolder,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () async {
                                    final picked = await FilePicker.platform
                                        .getDirectoryPath();
                                    if (picked == null) return;
                                    setDialogState(() => exportFolder = picked);
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
                                    ? 'Number ${_numberRangeVideoCount(rangeStart, rangeEnd)} videos from ${_numberRangeStartValue(rangeStart)} to ${_numberRangeEndValue(rangeStart, rangeEnd)}'
                                    : 'Export all selected videos',
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
                              const SizedBox(height: 18),
                            ],
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: KText(
                                  'Render Settings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (prepareForCapCut)
                              Column(
                                children: [
                                  SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: exportTimelineTogether,
                                    onChanged: (value) => setDialogState(
                                      () => exportTimelineTogether = value,
                                    ),
                                    title: const KText(
                                      'One CapCut folder',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: KText(
                                      exportTimelineTogether
                                          ? 'Put all clips in one folder'
                                          : 'Create one folder for each imported video',
                                    ),
                                  ),
                                  SwitchListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: renderCapCutEdits,
                                    onChanged: (value) => setDialogState(
                                      () => renderCapCutEdits = value,
                                    ),
                                    title: const KText(
                                      'Render edits into clips',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: KText(
                                      renderCapCutEdits
                                          ? 'Keeps size, speed, text, music, color, and effects for CapCut'
                                          : 'Faster cuts only; edit size/speed/effects inside CapCut',
                                    ),
                                  ),
                                ],
                              )
                            else
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: exportTimelineTogether,
                                onChanged: _exportsSeparatePartFiles
                                    ? null
                                    : (value) => setDialogState(
                                          () => exportTimelineTogether = value,
                                        ),
                                title: const KText(
                                  'One timeline video',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: KText(
                                  _exportsSeparatePartFiles
                                      ? 'Disabled while exporting split parts as separate files'
                                      : exportTimelineTogether
                                          ? 'All imported clips export together as one MP4'
                                          : 'Export each imported clip as separate files',
                                ),
                              ),
                            if (prepareForCapCut)
                              const ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.movie_creation_outlined),
                                title: KText(
                                  'CapCut-ready clips',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: KText(
                                  'Drag the prepared folder or clips into CapCut',
                                ),
                              ),
                            const SizedBox(height: 8),
                            _exportDialogDropdown(
                              label: 'Format',
                              value: 'MP4',
                              items: const ['MP4'],
                              onChanged: (_) {},
                            ),
                            const SizedBox(height: 10),
                            _exportDialogDropdown(
                              label: 'Quality',
                              value: quality,
                              items: const [
                                '4K',
                                '1080p',
                                '720p',
                                '480p',
                                'Low',
                                'Custom',
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => quality = value),
                            ),
                            const SizedBox(height: 10),
                            _exportStaticRow(
                              'Bit rate',
                              quality == 'Custom' ? 'Custom' : 'Higher',
                            ),
                            _exportStaticRow('Codec', 'H.264 fast'),
                            _exportStaticRow('Format', 'mp4'),
                            _exportStaticRow('Frame rate', 'Source fps'),
                            const SizedBox(height: 10),
                            _exportStaticRow(
                              'Estimated size',
                              _estimatedExportSizeLabel(
                                details.durationSeconds,
                                bitrate,
                                jobs.length,
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
                            child: KText(
                              prepareForCapCut ? 'Prepare' : 'Export',
                            ),
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
    if (confirmed == true) {
      _confirmedExportFolder = exportFolder;
      _updateEditor(() {
        if (!prepareForCapCut) {
          _outputFolder = exportFolder;
        }
        _nameController.text = name.trim();
        _batchRenamePattern = batchRenamePattern.trim();
        _batchRenameController.text = _batchRenamePattern;
        _qualityPreset = quality;
        if (!prepareForCapCut) {
          _exportTimelineTogether = exportTimelineTogether;
        } else {
          _capCutOneFolder = exportTimelineTogether;
          _capCutRenderEdits = renderCapCutEdits;
        }
        _useNumberRange = useNumberRange;
        _numberStartController.text =
            rangeStart.trim().isEmpty ? '1' : rangeStart.trim();
        _numberEndController.text = _automaticNumberRangeEndText(
          _numberStartController.text,
          rangeEnd,
        );
      });
      return true;
    }
    return false;
  }

  void _showExportProgressDialog() {
    if (_exportProgressDialogOpen) return;
    _exportProgressDialogOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ValueListenableBuilder<KlipioExportProgressView>(
          valueListenable: _exportProgressView,
          builder: (context, view, _) => _exportProgressDialog(view),
        ),
      ).whenComplete(() => _exportProgressDialogOpen = false),
    );
  }

  Future<void> _recoverUnexpectedExportFailure(
    Object error,
    StackTrace stackTrace,
  ) async {
    final token = _exportCancelToken;
    try {
      await token?.cancelAndWait(timeout: const Duration(seconds: 5));
    } catch (_) {
      // The emergency worker sweep below is the final cleanup path.
    }
    try {
      await terminateAllKlipioWorkers().timeout(const Duration(seconds: 8));
    } catch (_) {
      // UI recovery must complete even when Windows is releasing a process.
    }
    try {
      final directory = Directory(
        ApplicationPaths.logs.path,
      );
      await directory.create(recursive: true);
      final stack = '$stackTrace';
      await File(
        '${directory.path}${Platform.pathSeparator}export-errors.log',
      ).writeAsString(
        '${DateTime.now().toIso8601String()} [export UI recovery]\r\n'
        'Error: $error\r\n'
        '${stack.length > 12000 ? stack.substring(0, 12000) : stack}\r\n\r\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging is diagnostic only.
    }
    if (!mounted) return;
    final rawMessage = '$error'.replaceFirst('Exception: ', '').trim();
    final message = rawMessage.isEmpty
        ? 'The export pipeline stopped unexpectedly.'
        : rawMessage.length > 360
            ? '${rawMessage.substring(0, 360)}...'
            : rawMessage;
    final details = _exportProgressView.value.details ??
        _buildExportDialogDetails(_outputFolder ?? '', const []);
    _updateEditor(() {
      _isExporting = false;
      _renderQueuePaused = false;
      _renderQueueStopRequested = false;
      _exportCancelToken = null;
      _progress = 0;
      _status = 'Export failed';
    });
    MediaJobManager.instance.resumeBackgroundWork();
    _updateExportProgressView(
      details: details,
      progress: 0,
      elapsed: _exportProgressView.value.elapsed,
      status: 'Export failed: $message',
    );
    _closeExportProgressDialog();
    _showMessage('Export failed safely: $message');
  }

  void _closeExportProgressDialog() {
    if (!mounted || !_exportProgressDialogOpen) return;
    _exportProgressDialogOpen = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _pausePlaybackForExport() async {
    await MediaJobManager.instance.pauseBackgroundWork();
    MediaJobManager.instance.resumeBackgroundWork(owner: 'playback');
    try {
      await _sourceController?.pause();
    } catch (_) {
      // Export must still open if a preview controller is being replaced.
    }
    try {
      await _previewController?.pause();
    } catch (_) {
      // Export must still open if a preview controller is being replaced.
    }
    try {
      await _stopMusicPreview();
    } catch (_) {
      // A stale music preview must not block the export workflow.
    }
  }

  Future<void> _confirmCancelExport() async {
    if (!_isExporting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const KText('Stop exporting your video?'),
        content: const KText(
          'The current export will stop. Your project and source media will stay safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const KText('Keep exporting'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const KText('Stop export'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final stopped = await _cancelExport();
      if (!mounted) return;
      if (stopped) _closeExportProgressDialog();
    }
  }

  Future<bool> _cancelExport() async {
    final token = _exportCancelToken;
    if (token == null) return true;
    _renderQueueStopRequested = true;
    _renderQueuePaused = false;
    if (mounted) _updateEditor(() => _status = 'Stopping encoder...');
    _updateExportProgressView(
      details: _exportProgressView.value.details ??
          _buildExportDialogDetails(_outputFolder ?? '', const []),
      progress: _progress,
      elapsed: _exportProgressView.value.elapsed,
      status: 'Stopping encoder...',
    );
    try {
      await token.cancelAndWait();
    } on TimeoutException {
      if (mounted) {
        _updateEditor(() => _status = 'Force-stopping encoder process tree...');
      }
      _updateExportProgressView(
        details: _exportProgressView.value.details ??
            _buildExportDialogDetails(_outputFolder ?? '', const []),
        progress: _progress,
        elapsed: _exportProgressView.value.elapsed,
        status: 'Force-stopping encoder process tree...',
      );
      await Future.wait<void>([
        terminateAllKlipioWorkers(),
        platform.cancelBackgroundMediaTasks(),
      ]);
      try {
        await token.waitForIdle().timeout(const Duration(seconds: 3));
      } on TimeoutException {
        if (mounted) _updateEditor(() => _status = 'Encoder is still stopping');
        return false;
      }
    }
    if (!mounted) return true;
    _updateEditor(() => _status = 'Export canceled');
    MediaJobManager.instance.resumeBackgroundWork();
    _updateExportProgressView(
      details: _exportProgressView.value.details ??
          _buildExportDialogDetails(_outputFolder ?? '', const []),
      progress: _progress,
      elapsed: _exportProgressView.value.elapsed,
      status: 'Export canceled',
    );
    return true;
  }

  void _updateExportProgressView({
    required KlipioExportDialogDetails details,
    required double progress,
    required Duration elapsed,
    required String status,
  }) {
    _exportProgressView.value = KlipioExportProgressView(
      details: details,
      progress: progress.clamp(0.0, 1.0).toDouble(),
      elapsed: elapsed,
      status: status,
    );
  }
}
