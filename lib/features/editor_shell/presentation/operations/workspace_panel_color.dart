part of '../editor_application.dart';

// workspace operations owned by the editor state; extracted without changing timing.
extension _WorkspacePanelColor on _EditorScreenState {
  Color get _panelColor =>
      _isLightUi ? const Color(0xffffffff) : const Color(0xff181a20);

  Color get _panelHeaderColor =>
      _isLightUi ? const Color(0xfff4f5fa) : const Color(0xff20232b);

  Color get _panelBorderColor =>
      _isLightUi ? const Color(0xffd6d9e4) : const Color(0xff30343f);

  Color get _controlSurfaceColor =>
      _isLightUi ? const Color(0xffeef1f5) : const Color(0xff242428);

  Color get _controlSelectedColor =>
      _isLightUi ? const Color(0xffede9fe) : const Color(0xff3b2f5f);

  Color get _controlBorderColor =>
      _isLightUi ? const Color(0xffc4b5fd) : const Color(0xff51436f);

  Map<ShortcutActivator, VoidCallback> get _shortcutBindings => {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _cancelProgramTransform();
          _discardEffectPreview();
          _discardTransitionPreview();
        },
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
            _runEditorShortcut(_EditorShortcut.export),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _runEditorShortcut(_EditorShortcut.saveProject),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            _runEditorShortcut(_EditorShortcut.openProject),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _runEditorShortcut(_EditorShortcut.split),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true):
            () => _runEditorShortcut(_EditorShortcut.cutStart),
        const SingleActivator(LogicalKeyboardKey.bracketRight, control: true):
            () => _runEditorShortcut(_EditorShortcut.cutEnd),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            _runEditorShortcut(_EditorShortcut.undo),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
            _runEditorShortcut(_EditorShortcut.redo),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () => _runEditorShortcut(_EditorShortcut.redo),
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () =>
            _runEditorShortcut(_EditorShortcut.copy),
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): () =>
            _runEditorShortcut(_EditorShortcut.cut),
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
            _runEditorShortcut(_EditorShortcut.paste),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () =>
            _runEditorShortcut(_EditorShortcut.duplicate),
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _runEditorShortcut(_EditorShortcut.playPause),
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            _runEditorShortcut(_EditorShortcut.deletePart),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            unawaited(_nudgePlayhead(-1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            unawaited(_nudgePlayhead(1)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            unawaited(_nudgePlayhead(-5)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            unawaited(_nudgePlayhead(5)),
      };

  Future<void> _loadWorkspaceMemory() async {
    try {
      final prefs = await loadSharedPreferencesRecovering();
      final presetJson =
          prefs.getStringList(_EditorScreenState._exportPresetsKey) ?? const [];
      final presets = <_ExportPreset>[];
      for (final raw in presetJson) {
        final data = jsonDecode(raw);
        if (data is Map<String, Object?>) {
          presets.add(_ExportPreset.fromJson(data));
        }
      }
      if (!mounted) return;
      _updateEditor(() {
        _recentProjectPaths
          ..clear()
          ..addAll(prefs.getStringList(_EditorScreenState._recentProjectsKey) ??
              const []);
        _recentFolders
          ..clear()
          ..addAll(prefs.getStringList(_EditorScreenState._recentFoldersKey) ??
              const []);
        _exportPresets
          ..clear()
          ..addAll(presets);
        final savedOrder =
            prefs.getStringList(_EditorScreenState._workspaceDockOrderKey);
        if (savedOrder != null &&
            savedOrder.toSet().containsAll(_workspaceDockOrder)) {
          _workspaceDockOrder
            ..clear()
            ..addAll(savedOrder.where(_workspaceDockWidths.containsKey));
        }
        final savedWidths =
            prefs.getString(_EditorScreenState._workspaceDockWidthsKey);
        if (savedWidths != null) {
          final decoded = jsonDecode(savedWidths);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final width = double.tryParse('${entry.value}');
              if (_workspaceDockWidths.containsKey('${entry.key}') &&
                  width != null) {
                _workspaceDockWidths['${entry.key}'] = width;
              }
            }
          }
        }
        final visible =
            prefs.getStringList(_EditorScreenState._workspaceVisiblePanelsKey);
        if (visible != null && visible.isNotEmpty) {
          _visibleWorkspacePanels
            ..clear()
            ..addAll(visible);
        }
        _timelineWorkspaceHeight =
            prefs.getDouble(_EditorScreenState._workspaceTimelineHeightKey) ??
                _timelineWorkspaceHeight;
        final savedTrackHeights =
            prefs.getString(_EditorScreenState._workspaceTrackHeightsKey);
        if (savedTrackHeights != null) {
          final decoded = jsonDecode(savedTrackHeights);
          if (decoded is Map) {
            _timelineTrackHeights
              ..clear()
              ..addEntries(decoded.entries.map((entry) => MapEntry(
                    '${entry.key}',
                    (double.tryParse('${entry.value}') ?? 64)
                        .clamp(34, 150)
                        .toDouble(),
                  )));
          }
        }
      });
    } catch (_) {
      // Recent lists are convenience state only.
    }
  }

  Future<void> _saveWorkspaceMemory() async {
    try {
      final prefs = await loadSharedPreferencesRecovering();
      await prefs.setStringList(
          _EditorScreenState._recentProjectsKey, _recentProjectPaths);
      await prefs.setStringList(
          _EditorScreenState._recentFoldersKey, _recentFolders);
      await prefs.setStringList(
        _EditorScreenState._exportPresetsKey,
        [for (final preset in _exportPresets) jsonEncode(preset.toJson())],
      );
      await prefs.setStringList(
          _EditorScreenState._workspaceDockOrderKey, _workspaceDockOrder);
      await prefs.setString(
        _EditorScreenState._workspaceDockWidthsKey,
        jsonEncode(_workspaceDockWidths),
      );
      await prefs.setStringList(
        _EditorScreenState._workspaceVisiblePanelsKey,
        _visibleWorkspacePanels.toList(),
      );
      await prefs.setDouble(
        _EditorScreenState._workspaceTimelineHeightKey,
        _timelineWorkspaceHeight,
      );
      await prefs.setString(
        _EditorScreenState._workspaceTrackHeightsKey,
        jsonEncode(_timelineTrackHeights),
      );
    } catch (_) {
      // Recent lists are convenience state only.
    }
  }

  void _scheduleWorkspaceMemorySave() {
    _workspaceMemorySaveTimer?.cancel();
    _workspaceMemorySaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_saveWorkspaceMemory()),
    );
  }

  void _runEditorShortcut(_EditorShortcut shortcut) {
    switch (shortcut) {
      case _EditorShortcut.export:
        if (!_isExporting) unawaited(_showExportHub());
      case _EditorShortcut.saveProject:
        unawaited(_saveProjectAs());
      case _EditorShortcut.openProject:
        unawaited(_openProjectDialog());
      case _EditorShortcut.split:
        _splitClipAtPlayhead();
      case _EditorShortcut.cutStart:
        _cutClipStartAtPlayhead();
      case _EditorShortcut.cutEnd:
        _cutClipEndAtPlayhead();
      case _EditorShortcut.undo:
        _undoEditor();
      case _EditorShortcut.redo:
        _redoEditor();
      case _EditorShortcut.playPause:
        unawaited(_togglePreview());
      case _EditorShortcut.deletePart:
        _deleteClipPartAtPlayhead();
      case _EditorShortcut.copy:
        _copySelectedTimelineClip();
      case _EditorShortcut.cut:
        _cutSelectedTimelineClip();
      case _EditorShortcut.paste:
        _pasteTimelineClip();
      case _EditorShortcut.duplicate:
        _duplicateSelectedTimelineClip();
    }
  }

  Widget _workspaceActionDeck() {
    final hasVideo = _videos.isNotEmpty;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _panelColor,
        border: Border(bottom: BorderSide(color: _panelBorderColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_motion,
                    color: Theme.of(context).colorScheme.primary, size: 17),
                const SizedBox(width: 6),
                const KText('TOOLS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ],
            ),
          ),
          VerticalDivider(color: _panelBorderColor, indent: 7, endIndent: 7),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _deckAction(
                  icon: Icons.video_library_outlined,
                  label: 'Project media',
                  shortcut: 'Library',
                  onPressed: () =>
                      _openLeftWorkspaceTab(LeftWorkspaceTab.media),
                  primary: true,
                ),
                _deckAction(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Effects',
                  shortcut: 'Library',
                  onPressed: () => _openEffectsWorkspace(
                    _EffectsWorkspaceCategory.effects,
                  ),
                ),
                _deckAction(
                  icon: Icons.compare_arrows,
                  label: 'Transitions',
                  shortcut: 'Between clips',
                  onPressed: () => _openEffectsWorkspace(
                    _EffectsWorkspaceCategory.transitions,
                  ),
                ),
                _deckAction(
                  icon: Icons.tune,
                  label: 'Adjustment',
                  shortcut: 'Filters & color',
                  onPressed: () => _openEffectsWorkspace(
                    _EffectsWorkspaceCategory.adjustments,
                  ),
                ),
                _deckAction(
                  icon: Icons.music_note_outlined,
                  label: 'Music',
                  shortcut: 'Audio',
                  onPressed: _pickMusic,
                ),
                _deckAction(
                  icon: Icons.title_outlined,
                  label: 'Text layer',
                  shortcut: 'Overlay',
                  onPressed: () => _openLeftWorkspaceTab(LeftWorkspaceTab.text),
                ),
                _deckAction(
                  icon: Icons.subtitles_outlined,
                  label: 'AI Captions',
                  shortcut: _automaticCaptions ? 'ON' : 'Whisper',
                  onPressed: _showCaptionSettingsDialog,
                  primary: _automaticCaptions,
                ),
                _deckAction(
                  icon: Icons.fact_check_outlined,
                  label: 'Call Check',
                  shortcut: 'Verify',
                  onPressed: hasVideo ? _showTitleCheckDialog : null,
                ),
                _deckAction(
                  icon: Icons.save_outlined,
                  label: 'Save',
                  shortcut: 'Ctrl+S',
                  onPressed: hasVideo ? _saveProjectAs : null,
                ),
                _windowMenuAction(),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: hasVideo
                  ? const Color(0xff22c55e).withOpacity(0.10)
                  : _softBarColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Icon(
                  hasVideo ? Icons.history : Icons.check_circle_outline,
                  size: 17,
                  color: hasVideo ? const Color(0xff22c55e) : _mutedTextColor,
                ),
                const SizedBox(width: 7),
                KText(
                  hasVideo ? 'Autosave enabled' : 'Ready',
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dividerSize = 4.0;
        final topPanels = _workspaceDockOrder
            .where(_visibleWorkspacePanels.contains)
            .toList();
        final showTimeline = _visibleWorkspacePanels.contains('timeline');
        final timelineHeight = _timelineWorkspaceHeight
            .clamp(
                math.min(190.0, constraints.maxHeight * 0.45),
                math.max(
                    constraints.maxHeight * 0.45, constraints.maxHeight - 230))
            .toDouble();
        return Column(
          children: [
            if (topPanels.isNotEmpty)
              Expanded(
                child: constraints.maxWidth < 1100 &&
                        topPanels.contains('program')
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            if (topPanels.length > 1)
                              SizedBox(
                                width: math.min(
                                    340.0, constraints.maxWidth * 0.46),
                                child: WorkspacePanelTabs(
                                  selectedPanel: _compactWorkspacePanel,
                                  onPanelChanged: (panel) => _updateEditor(() {
                                    _compactWorkspacePanel = panel;
                                    _effectPreview.discard();
                                    _transitionPreview.discard();
                                  }),
                                  labels: const {
                                    'project': 'Assets',
                                    'source': 'Source',
                                    'inspector': 'Inspector'
                                  },
                                  panels: {
                                    for (final panel in topPanels
                                        .where((id) => id != 'program'))
                                      panel: _dockableWorkspacePanel(panel)
                                  },
                                ),
                              ),
                            Expanded(child: _programMonitorPanel()),
                          ])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final entry in topPanels.indexed) ...[
                            Expanded(
                              flex: math.max(
                                1,
                                (_workspaceDockWidths[entry.$2] ?? 300).round(),
                              ),
                              child: _dockableWorkspacePanel(entry.$2),
                            ),
                            if (entry.$1 < topPanels.length - 1)
                              _workspaceResizeHandle(
                                axis: Axis.vertical,
                                onDrag: (delta) {
                                  final left = entry.$2;
                                  final right = topPanels[entry.$1 + 1];
                                  _updateEditor(() {
                                    _workspaceDockWidths[left] =
                                        ((_workspaceDockWidths[left] ?? 300) +
                                                delta)
                                            .clamp(140.0, 900.0)
                                            .toDouble();
                                    _workspaceDockWidths[right] =
                                        ((_workspaceDockWidths[right] ?? 300) -
                                                delta)
                                            .clamp(140.0, 900.0)
                                            .toDouble();
                                  });
                                },
                                onDragEnd: () =>
                                    unawaited(_saveWorkspaceMemory()),
                              ),
                          ],
                        ],
                      ),
              ),
            if (topPanels.isNotEmpty && showTimeline)
              _workspaceResizeHandle(
                axis: Axis.horizontal,
                onDrag: (delta) => _updateEditor(() {
                  _timelineWorkspaceHeight = (_timelineWorkspaceHeight - delta)
                      .clamp(
                        190.0,
                        math.max(190.0, constraints.maxHeight - 230),
                      )
                      .toDouble();
                }),
                onDragEnd: () => unawaited(_saveWorkspaceMemory()),
              ),
            if (showTimeline)
              SizedBox(
                height: topPanels.isEmpty
                    ? constraints.maxHeight
                    : math.max(0, timelineHeight - dividerSize),
                child: _timelinePanel(compact: false),
              ),
            if (topPanels.isEmpty && !showTimeline)
              Expanded(
                child: _emptyWorkspaceMessage(),
              ),
          ],
        );
      },
    );
  }

  Widget _workspacePanelContent(String panel) {
    return switch (panel) {
      'project' => _projectImportTabsPanel(),
      'source' => _sourceMonitorPanel(),
      'program' => _programMonitorPanel(),
      'inspector' => _toolTabsPanel(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _dockableWorkspacePanel(String panel) {
    return _workspacePanelContent(panel);
  }

  Widget _emptyWorkspaceMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.window_outlined, size: 48),
          const SizedBox(height: 12),
          const KText(
            'All panels are closed',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              _updateEditor(() => _visibleWorkspacePanels.addAll([
                    'project',
                    'source',
                    'program',
                    'inspector',
                    'timeline',
                  ]));
              unawaited(_saveWorkspaceMemory());
            },
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const KText('Show all panels'),
          ),
        ],
      ),
    );
  }

  Widget _workspaceResizeHandle({
    required Axis axis,
    required ValueChanged<double> onDrag,
    VoidCallback? onDragEnd,
  }) {
    final vertical = axis == Axis.vertical;
    return MouseRegion(
      cursor: vertical
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate:
            vertical ? (details) => onDrag(details.delta.dx) : null,
        onVerticalDragUpdate:
            vertical ? null : (details) => onDrag(details.delta.dy),
        onHorizontalDragEnd: vertical ? (_) => onDragEnd?.call() : null,
        onVerticalDragEnd: vertical ? null : (_) => onDragEnd?.call(),
        child: SizedBox(
          width: vertical ? 4 : double.infinity,
          height: vertical ? double.infinity : 4,
          child: Center(
            child: Container(
              width: vertical ? 1 : 36,
              height: vertical ? 36 : 1,
              decoration: BoxDecoration(
                color: _panelBorderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneWorkspace() {
    return LayoutBuilder(builder: (context, constraints) {
      final landscape = constraints.maxWidth > constraints.maxHeight;
      final monitor = _programMonitorPanel(phoneMode: true);
      final tools = Column(
        children: [
          _phoneQuickActions(),
          Expanded(child: _phoneTabPanel()),
        ],
      );
      if (landscape) {
        return Row(
          children: [
            if (_phonePreviewExpanded) ...[
              Expanded(flex: 5, child: monitor),
              SizedBox(
                width: 1,
                child: ColoredBox(color: _panelBorderColor),
              ),
            ],
            Expanded(flex: 6, child: tools),
          ],
        );
      }
      final previewHeight = math.min(
        360.0,
        math.max(190.0, constraints.maxHeight * 0.44),
      );
      return Column(
        children: [
          if (_phonePreviewExpanded) ...[
            SizedBox(height: previewHeight, child: monitor),
          ],
          Expanded(child: tools),
        ],
      );
    });
  }

  Widget _phoneTabPanel() {
    final child = switch (_phoneTabIndex) {
      0 => _mediaLibraryPanel(),
      1 => _phoneEditPanel(),
      2 => _focusedControlsPanel('Captions', _captionControlSection()),
      3 => _timelinePanel(compact: true),
      4 => _focusedControlsPanel('Audio', _audioControlSection()),
      5 => _focusedControlsPanel('Export', _exportControlSection()),
      _ => _timelinePanel(compact: true),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 190),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_phoneTabIndex), child: child),
    );
  }

  Widget _phoneEditPanel() {
    const labels = ['Transform', 'Speed', 'Color', 'Text', 'Watermark'];
    final sections = <List<Widget>>[
      [
        ..._transformControlSection(includeSpeed: false),
        const SizedBox(height: 14),
        ..._canvasControlSection(),
      ],
      [
        _slider(
          'Speed',
          _speed,
          _EditorScreenState._minVideoSpeed,
          _EditorScreenState._maxVideoSpeed,
          _setPreviewSpeed,
          divisions: 30,
        ),
        _speedPresets(),
        ..._cutControlSection(),
      ],
      _colorControlSection(),
      _textControlSection(),
      _watermarkControlSection(),
    ];
    return Card(
      margin: EdgeInsets.zero,
      color: _panelColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) => ChoiceChip(
                label: KText(labels[index]),
                selected: _phoneEditToolIndex == index,
                onSelected: (_) =>
                    _updateEditor(() => _phoneEditToolIndex = index),
              ),
            ),
          ),
          Divider(height: 1, color: _panelBorderColor),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 16),
              children: [
                KText(labels[_phoneEditToolIndex],
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...sections[_phoneEditToolIndex],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
