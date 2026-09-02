part of '../editor_application.dart';

// timeline operations owned by the editor state; extracted without changing timing.
extension _TimelineTimelinePanel on _EditorScreenState {
  void _onTimelineNavigationSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    if (!keys.isControlPressed && !keys.isShiftPressed) return;
    final zoom = keys.isControlPressed;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (zoom) {
        _setTimelineZoom(
          _timelineZoom + (event.scrollDelta.dy < 0 ? 5 : -5),
          pointerViewportX: event.localPosition.dx,
        );
      } else if (_timelineScrollController.hasClients) {
        final position = _timelineScrollController.position;
        _timelineScrollController.jumpTo(
            (position.pixels + event.scrollDelta.dy + event.scrollDelta.dx)
                .clamp(0, position.maxScrollExtent)
                .toDouble());
      }
    });
  }

  Widget _timelinePanel({required bool compact}) {
    final totalDuration = _timelineSequenceDuration();
    final selectedVideo = _videos.isEmpty
        ? null
        : _videos[_selectedVideoIndex.clamp(0, _videos.length - 1)];
    return _panelShell(
      title: '',
      workspacePanelId: compact ? null : 'timeline',
      showHeader: false,
      child: Column(
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: _softBarColor,
              border: Border(bottom: BorderSide(color: _panelBorderColor)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 7),
                  child: KText(
                    'TIMELINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.65,
                    ),
                  ),
                ),
                if (!compact)
                  KText(
                    totalDuration <= 0
                        ? '00:00'
                        : _formatDuration(totalDuration),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(width: 3),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: _previewController == null ? null : _togglePreview,
                  icon: Icon(
                    _previewController?.value.isPlaying == true
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 18,
                  ),
                  tooltip: 'Play / pause (Space)',
                ),
                const SizedBox(width: 3),
                if (!compact)
                  KText(
                    _previewController?.value.isInitialized == true
                        ? _formatDuration(_currentProgramSeconds())
                        : '00:00',
                    style: const TextStyle(
                      color: Color(0xff60a5fa),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(width: 5),
                if (_timelineSelectionCount > 1) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: KText(
                      '$_timelineSelectionCount selected',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                VerticalDivider(
                    color: _panelBorderColor, indent: 8, endIndent: 8),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _timelineActionButton(
                        icon: Icons.content_cut,
                        label: 'Split',
                        tooltip: 'Split at playhead (Ctrl+K)',
                        primary: true,
                        iconOnly: true,
                        onPressed:
                            selectedVideo == null ? null : _splitClipAtPlayhead,
                      ),
                      _timelineActionButton(
                        icon: Icons.first_page,
                        label: 'Trim start',
                        tooltip: 'Keep video after playhead (Ctrl+[)',
                        iconOnly: true,
                        onPressed: selectedVideo == null
                            ? null
                            : _cutClipStartAtPlayhead,
                      ),
                      _timelineActionButton(
                        icon: Icons.last_page,
                        label: 'Trim end',
                        tooltip: 'Keep video before playhead (Ctrl+])',
                        iconOnly: true,
                        onPressed: selectedVideo == null
                            ? null
                            : _cutClipEndAtPlayhead,
                      ),
                      _timelineActionButton(
                        icon: Icons.delete_outline,
                        label: 'Delete part',
                        tooltip: 'Delete section under playhead (Delete)',
                        danger: true,
                        iconOnly: true,
                        onPressed: selectedVideo == null
                            ? null
                            : _deleteClipPartAtPlayhead,
                      ),
                      _timelineToolButton(
                        icon: Icons.undo,
                        tooltip: 'Undo (Ctrl+Z)',
                        onPressed: _canUndoEditor ? _undoEditor : null,
                      ),
                      _timelineToolButton(
                        icon: Icons.redo,
                        tooltip: 'Redo (Ctrl+Y)',
                        onPressed: _canRedoEditor ? _redoEditor : null,
                      ),
                      VerticalDivider(
                        color: _panelBorderColor,
                        indent: 8,
                        endIndent: 8,
                      ),
                      _timelineActionButton(
                        icon: Icons.layers_outlined,
                        label: 'Layer',
                        tooltip: 'Selected layer transform and blend mode',
                        iconOnly: true,
                        onPressed: _selectedTimelineClipId == null
                            ? null
                            : _showSelectedLayerDialog,
                      ),
                      _timelineToolButton(
                        icon: Icons.flag_outlined,
                        tooltip: 'Add marker at playhead',
                        onPressed:
                            selectedVideo == null ? null : _addTimelineMarker,
                      ),
                      _timelineSpeedMenu(
                        enabled: selectedVideo != null,
                        compact: true,
                      ),
                      _timelineToolButton(
                        icon: Icons.keyboard_double_arrow_left,
                        tooltip: 'Back 1 second (Left arrow)',
                        onPressed: selectedVideo == null
                            ? null
                            : () => unawaited(_nudgePlayhead(-1)),
                      ),
                      _timelineToolButton(
                        icon: Icons.keyboard_double_arrow_right,
                        tooltip: 'Forward 1 second (Right arrow)',
                        onPressed: selectedVideo == null
                            ? null
                            : () => unawaited(_nudgePlayhead(1)),
                      ),
                      VerticalDivider(
                        color: _panelBorderColor,
                        indent: 8,
                        endIndent: 8,
                      ),
                      _timelineToolButton(
                        icon: _clipEditMode
                            ? Icons.edit_note
                            : Icons.video_collection_outlined,
                        tooltip: _clipEditMode
                            ? 'Selected clip mode'
                            : 'Full timeline mode',
                        selected: _clipEditMode,
                        onPressed: selectedVideo == null
                            ? null
                            : () => _updateEditor(() {
                                  _clipEditMode = !_clipEditMode;
                                  if (_timelineScrollController.hasClients) {
                                    _timelineScrollController.jumpTo(0);
                                  }
                                }),
                      ),
                      _timelineAddTrackMenu(
                        enabled: selectedVideo != null,
                      ),
                      _timelineToolButton(
                        icon: Icons.restart_alt,
                        tooltip: 'Reset selected clip edits',
                        onPressed: selectedVideo == null
                            ? null
                            : _resetSelectedClipCut,
                      ),
                    ],
                  ),
                ),
                VerticalDivider(
                  color: _panelBorderColor,
                  indent: 8,
                  endIndent: 8,
                ),
                _timelineToolButton(
                  icon: Icons.fit_screen_outlined,
                  tooltip: 'Fit complete timeline',
                  onPressed: _fitTimelineZoom,
                ),
                _timelineToolButton(
                  icon: Icons.zoom_out,
                  tooltip: 'Zoom timeline out',
                  onPressed: _zoomTimelineOut,
                ),
                SizedBox(
                  width: compact ? 70 : 112,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: _timelineZoom.clamp(0, 100),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: _setTimelineZoom,
                    ),
                  ),
                ),
                if (!compact)
                  SizedBox(
                    width: 34,
                    child: KText(
                      '${_timelineZoom.round()}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                _timelineToolButton(
                  icon: Icons.zoom_in,
                  tooltip: 'Zoom timeline in',
                  onPressed: _zoomTimelineIn,
                ),
                const SizedBox(width: 3),
              ],
            ),
          ),
          if (_selectedVideoTimelineClipIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
              child: Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: TimelineQuickActions(
                    selectionCount: _selectedVideoTimelineClipIds.length,
                    onSplit: _splitClipAtPlayhead,
                    onSpeedChanged: _setSelectedTimelineClipsSpeed,
                    onDeleteRipple: _deleteClipPartAtPlayhead,
                    onSyncSettings: _syncSettingsToTimelineSelection,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _videos.isEmpty
                ? BrowserMessage(
                    icon: Icons.movie_creation_outlined,
                    title: 'Build your first timeline',
                    description: 'Add clips or open a complete video folder',
                    action: FilledButton.icon(
                      onPressed: _pickVideos,
                      icon: const Icon(Icons.add, size: 18),
                      label: const KText('Add clips'),
                    ),
                  )
                : ColoredBox(
                    color: _isLightUi
                        ? const Color(0xffeef1f5)
                        : const Color(0xff10141a),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final labelWidth = compact ? 124.0 : 132.0;
                        const horizontalTrackPadding = 16.0;
                        final visibleTimelineWidth = (constraints.maxWidth -
                                labelWidth -
                                horizontalTrackPadding)
                            .clamp(0.0, double.infinity)
                            .toDouble();
                        _timelineViewportWidth = visibleTimelineWidth;
                        final contentWidth = labelWidth +
                            horizontalTrackPadding +
                            _timelineContentWidth(
                              minimumWidth: visibleTimelineWidth,
                            );
                        return Listener(
                          onPointerSignal: _onTimelineNavigationSignal,
                          child: ClipRect(
                              child: Scrollbar(
                            controller: _timelineScrollController,
                            thumbVisibility: true,
                            thickness: 4,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              controller: _timelineScrollController,
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: contentWidth,
                                child: _timelineTracks(compact: compact),
                              ),
                            ),
                          )),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<({PickedVideo video, int index})> _visibleTimelineVideos() {
    if (_videos.isEmpty) return const [];
    if (!_clipEditMode) {
      return [
        for (final entry in _videos.indexed) (video: entry.$2, index: entry.$1),
      ];
    }
    final index = _selectedVideoIndex.clamp(0, _videos.length - 1);
    return [(video: _videos[index], index: index)];
  }
}
