part of '../editor_application.dart';

// workspace operations owned by the editor state; extracted without changing timing.
extension _WorkspacePanelShell on _EditorScreenState {
  Widget _panelShell({
    required String title,
    Widget? trailing,
    required Widget child,
    String? workspacePanelId,
    bool showHeader = true,
    bool darkChrome = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: darkChrome ? _monitorCanvasColor : _panelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: darkChrome ? _monitorChromeBorderColor : _panelBorderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              height: widget.settings.compactWorkspace ? 28 : 30,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: darkChrome ? _monitorChromeColor : _panelHeaderColor,
                border: Border(
                  bottom: BorderSide(
                    color: darkChrome
                        ? _monitorChromeBorderColor
                        : _panelBorderColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (title.isNotEmpty)
                    Expanded(
                      child: KText(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.35,
                          color: darkChrome ? _monitorChromeTextColor : null,
                        ),
                      ),
                    ),
                  if (trailing != null)
                    title.isEmpty
                        ? Expanded(
                            child: ClipRect(
                              child: DefaultTextStyle.merge(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                child: trailing,
                              ),
                            ),
                          )
                        : Flexible(
                            flex: 2,
                            child: ClipRect(
                              child: DefaultTextStyle.merge(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                child: trailing,
                              ),
                            ),
                          ),
                  const SizedBox(width: 4),
                  if (workspacePanelId == null)
                    Icon(
                      Icons.menu,
                      size: 14,
                      color: darkChrome
                          ? _monitorChromeTextColor
                          : _mutedTextColor,
                    ),
                  if (workspacePanelId != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 24, height: 24),
                      onPressed: () {
                        _updateEditor(
                          () =>
                              _visibleWorkspacePanels.remove(workspacePanelId),
                        );
                        unawaited(_saveWorkspaceMemory());
                      },
                      icon: Icon(
                        Icons.close,
                        size: 15,
                        color: darkChrome ? _monitorChromeTextColor : null,
                      ),
                      tooltip: 'Close panel',
                    ),
                  ],
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _toolTabsPanel() {
    return _panelShell(
      title: 'INSPECTOR',
      workspacePanelId: 'inspector',
      trailing: Tooltip(
        message: 'Choose video numbers and the settings to copy',
        child: TextButton.icon(
          key: const ValueKey('inspector-apply-video-settings'),
          onPressed: _videos.isEmpty ||
                  _selectedVideoIndex < 0 ||
                  _selectedVideoIndex >= _videos.length
              ? null
              : _applyCurrentTransformToAllVideos,
          icon: const Icon(Icons.copy_all_outlined, size: 15),
          label: const KText('Apply settings…'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 26),
            textStyle: const TextStyle(fontSize: 11),
          ),
        ),
      ),
      child: ContextAwareInspector(
        selection: _editorSelection,
        projectDetails: _projectDetailsInspector(),
        videoProperties: _focusedControlsPanel(
          'Video',
          [
            _inspectorSection(
              title: 'Transform',
              icon: Icons.video_settings_outlined,
              initiallyExpanded: true,
              children: _clipCompositionControls(),
            ),
            _inspectorSection(
                title: 'Speed',
                icon: Icons.speed,
                initiallyExpanded: true,
                children: [
                  _slider(
                      'Clip speed',
                      _speed,
                      _EditorScreenState._minVideoSpeed,
                      _EditorScreenState._maxVideoSpeed,
                      (value) => _setPreviewSpeed(value),
                      divisions: 100),
                  _speedPresets()
                ]),
            _inspectorSection(
                title: 'Animation / Keyframes',
                icon: Icons.diamond_outlined,
                children: _clipMotionControls()),
            _inspectorSection(
                title: 'Transition',
                icon: Icons.blur_on,
                initiallyExpanded:
                    _professionalTargetClip()?.clip.transitionIn != null,
                children: _transitionInspectorControls()),
            _inspectorSection(
              title: 'Canvas',
              icon: Icons.crop_square_outlined,
              initiallyExpanded: true,
              children: _canvasControlSection(),
            ),
            _inspectorSection(
              title: 'Cut & Hook',
              icon: Icons.content_cut_outlined,
              children: [
                _hookVideoButton(),
                const SizedBox(height: 12),
                ..._cutControlSection(),
              ],
            ),
            _inspectorSection(
              title: 'Audio',
              icon: Icons.volume_up_outlined,
              children: _clipSourceAudioControls(),
            ),
            _inspectorSection(
              title: 'Effects',
              icon: Icons.auto_awesome_outlined,
              initiallyExpanded: true,
              children: [
                if (_professionalTargetClip()?.clip.effects.isEmpty ?? true)
                  const Text(
                      'No effects on this clip. Choose a style from the Effects browser.'),
                for (final effect in _professionalTargetClip()?.clip.effects ??
                    const <ClipEffect>[])
                  _activeClipEffectTile(effect),
                TextButton.icon(
                    onPressed: () => _openEffectsWorkspace(
                        _EffectsWorkspaceCategory.effects),
                    icon: const Icon(Icons.add),
                    label: const Text('Browse effects')),
              ],
            ),
            _inspectorSection(
              title: 'Watermark',
              icon: Icons.branding_watermark_outlined,
              children: _watermarkControlSection(),
            ),
          ],
        ),
        audioProperties: _focusedControlsPanel(
          'Audio Properties',
          _selectedTimelineAudioControls(),
        ),
        textProperties: _focusedControlsPanel(
          'Text Properties',
          [
            _inspectorSection(
                title: 'Text / Typography',
                icon: Icons.text_fields,
                initiallyExpanded: true,
                children: _textControlSection(includeLayerPicker: false)),
            _inspectorSection(
                title: 'Composition Transform',
                icon: Icons.transform,
                initiallyExpanded: true,
                children: _clipCompositionControls()),
            _inspectorSection(
                title: 'Composition Keyframes',
                icon: Icons.diamond_outlined,
                children: _clipMotionControls()),
          ],
        ),
        transitionProperties:
            _focusedControlsPanel('Transition', _transitionInspectorControls()),
        captionProperties: _focusedControlsPanel(
          'Caption Properties',
          _captionInspectorControls(),
        ),
      ),
    );
  }

  void _openLeftWorkspaceTab(LeftWorkspaceTab tab) {
    _effectPreview.discard();
    _transitionPreview.discard();
    _updateEditor(() {
      _leftWorkspaceTab = tab;
      _compactWorkspacePanel = 'project';
      if (tab == LeftWorkspaceTab.effects) {
        _effectsWorkspaceCategory = _EffectsWorkspaceCategory.effects;
      }
      _visibleWorkspacePanels.add('project');
    });
    unawaited(_saveWorkspaceMemory());
  }

  void _openEffectsWorkspace(_EffectsWorkspaceCategory category) {
    _effectPreview.discard();
    _transitionPreview.discard();
    _updateEditor(() {
      _effectsWorkspaceCategory = category;
      _compactWorkspacePanel = 'project';
      _leftWorkspaceTab = LeftWorkspaceTab.effects;
      _visibleWorkspacePanels.add('project');
    });
    unawaited(_saveWorkspaceMemory());
  }

  Widget _effectsWorkspacePanel() {
    return switch (_effectsWorkspaceCategory) {
      _EffectsWorkspaceCategory.effects => _clipEffectsLibrary(),
      _EffectsWorkspaceCategory.adjustments => _clipAdjustmentLibrary(),
      _EffectsWorkspaceCategory.transitions => _transitionPresetLibrary(),
    };
  }

  Widget _textWorkspacePanel() {
    final presets = _visibleTextStylePresets();
    const categories = ['Trending', 'Classic', 'Neon', 'Box', 'Social', 'All'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 9, 6),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _videos.isEmpty ? null : _addTextOverlay,
                  icon: const Icon(Icons.add, size: 17),
                  label: const KText('Add text'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                tooltip: 'Add lower third',
                onPressed: _videos.isEmpty
                    ? null
                    : () => _addTextOverlay(template: 'lower_third'),
                icon: const Icon(Icons.space_dashboard_outlined, size: 18),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: TextField(
            controller: _textStyleSearchController,
            onChanged: (_) => _updateEditor(() {}),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search text effects and styles',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _textStyleSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _textStyleSearchController.clear();
                        _updateEditor(() {});
                      },
                      icon: const Icon(Icons.close, size: 17),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 43,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 5),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                label: KText(category),
                selected: _selectedTextStyleCategory == category,
                onSelected: (_) => _updateEditor(
                  () => _selectedTextStyleCategory = category,
                ),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(9, 2, 9, 18),
            children: [
              Row(
                children: [
                  Expanded(
                    child: KText(
                      _selectedTextStyleCategory.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  KText(
                    '${presets.length} styles',
                    style: TextStyle(fontSize: 10, color: _mutedTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              if (presets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: KText(
                      'No matching text styles',
                      style: TextStyle(color: _mutedTextColor),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.18,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (context, index) =>
                      _textStylePresetCard(presets[index]),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: KText(
                      'TEXT LAYERS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  KText(
                    '${_textOverlays.where((item) => item.text.trim().isNotEmpty).length}',
                    style: TextStyle(fontSize: 10, color: _mutedTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final entry in _textOverlays.indexed)
                if (entry.$2.text.trim().isNotEmpty)
                  _textLayerManagerTile(entry.$1, entry.$2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _focusedControlsPanel(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      color: _panelColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 14),
        children: [
          if (title.trim().isNotEmpty) ...[
            _sectionTitle(title),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }

  List<Widget> _fileControlSection() {
    return [
      _statusRow(),
      const SizedBox(height: 16),
      _actionTile(
        icon: Icons.video_library_outlined,
        title: 'Video files',
        subtitle: _videos.isEmpty
            ? 'No videos selected'
            : '${_videos.length} selected',
        onPressed: _pickVideos,
      ),
      _actionTile(
        icon: Icons.folder_copy_outlined,
        title: 'Video folder',
        subtitle: 'Open 1 folder and load all videos',
        onPressed: _pickVideoFolder,
      ),
      _actionTile(
        icon: Icons.folder_outlined,
        title: 'Output folder',
        subtitle: _outputFolder ?? 'Default documents folder',
        onPressed: _pickOutputFolder,
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveProjectAs,
              icon: const Icon(Icons.save_outlined),
              label: const KText('Save project'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openProjectDialog,
              icon: const Icon(Icons.folder_open),
              label: const KText('Open project'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => unawaited(_openAutosaveProject()),
              icon: const Icon(Icons.restore_page_outlined),
              label: const KText('Open autosave'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _recentProjectMenu()),
        ],
      ),
      const SizedBox(height: 8),
      _recentFolderMenu(),
      const SizedBox(height: 10),
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Output name',
          hintText: 'Blank = original video name',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.drive_file_rename_outline),
        ),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: _useNumberRange,
        onChanged: (value) => _updateEditor(() {
          _useNumberRange = value ?? false;
        }),
        title: const KText(
          'Output numbering',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: KText(
          _useNumberRange
              ? 'Number ${_selectedExportVideoCount()} videos from ${_exportRangeStart()} to ${_exportRangeEnd()} as ${_exportRangeStart()}.name, ${_exportRangeStart() + 1}.name...'
              : 'Off: export all videos with normal names',
        ),
      ),
      if (_useNumberRange)
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _numberStartController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Start',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateEditor(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _numberEndController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'End',
                  hintText: 'Blank = all videos',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _updateEditor(() {}),
              ),
            ),
          ],
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _videos.isEmpty ? null : _clearProject,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const KText('Clear project'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _videos.isEmpty ? null : _showTitleCheckDialog,
              icon: const Icon(Icons.fact_check_outlined),
              label: const KText('Call Check'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _cutControlSection() {
    final selectedVideo = _videos.isEmpty
        ? null
        : _videos[_selectedVideoIndex.clamp(0, _videos.length - 1)];
    return [
      Row(
        children: [
          Expanded(
            child: KText(
              selectedVideo == null
                  ? 'No clip selected'
                  : 'Selected clip: ${selectedVideo.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _mutedTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: selectedVideo == null ? null : _resetSelectedClipCut,
            icon: const Icon(Icons.restart_alt),
            label: const KText('Reset clip'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _trimStartController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Start time',
                hintText: '90s, 1:30, 15m',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                _syncCutFields();
                _updateEditor(() {});
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _trimEndController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'End time',
                hintText: '90s, 1:30, 15m',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                _syncCutFields();
                _updateEditor(() {});
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _splitEveryController,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(
          labelText: 'Split every',
          helperText: 'Examples: 30s, 15m, 1h, 1:00:00',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.call_split_outlined),
        ),
        onChanged: (_) {
          _syncCutFields();
          _updateEditor(() {});
        },
      ),
    ];
  }

  List<Widget> _watermarkControlSection() {
    return [
      _actionTile(
        icon: Icons.branding_watermark_outlined,
        title: 'Watermark image',
        subtitle: _watermarkPath == null
            ? 'Optional'
            : platform.basename(_watermarkPath!),
        onPressed: _pickWatermark,
      ),
      _slider(
        'Size',
        _watermarkSize,
        0.05,
        0.5,
        (value) {
          _recordEditorHistory('watermark-size');
          _updateEditor(() => _watermarkSize = value);
        },
      ),
    ];
  }

  void _updateTextControl(String key, VoidCallback update) {
    if (_selectedTextOverlayIndex >= 0 &&
        _selectedTextOverlayIndex < _textOverlays.length &&
        _textOverlays[_selectedTextOverlayIndex].isLocked) {
      _showMessage(
        'Unlock T${_textOverlays[_selectedTextOverlayIndex].trackIndex} before editing text.',
      );
      return;
    }
    _recordEditorHistory(key);
    _updateEditor(() {
      update();
      if (_selectedTextOverlayIndex >= 0 &&
          _selectedTextOverlayIndex < _textOverlays.length) {
        final next = _currentTextOverlayDraft();
        _textOverlays[_selectedTextOverlayIndex] = next;
        _insertTextTimelineClip(next);
      }
    });
    unawaited(_autosaveProject());
  }
}
