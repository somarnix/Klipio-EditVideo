part of '../editor_application.dart';

// preview operations owned by the editor state; extracted without changing timing.
extension _PreviewSourceMonitorPanel on _EditorScreenState {
  Widget _sourceMonitorPanel() {
    final currentVideo = _videos.isEmpty
        ? null
        : _videos[_selectedVideoIndex.clamp(0, _videos.length - 1)];
    final controller = _sourceController;
    return _panelShell(
      title: 'SOURCE MONITOR',
      workspacePanelId: 'source',
      darkChrome: true,
      trailing: currentVideo == null
          ? null
          : Tooltip(
              message: currentVideo.name,
              child: KText(
                currentVideo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: _monitorChromeTextColor,
                ),
              ),
            ),
      child: Column(
        children: [
          Expanded(
            child: ColoredBox(
              key: const Key('source-monitor-canvas'),
              color: _monitorCanvasColor,
              child: controller == null || !controller.value.isInitialized
                  ? Center(
                      child: KText(
                        _sourceError ?? 'Select media',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _mutedTextColor),
                      ),
                    )
                  : _liveSourceVideo(controller),
            ),
          ),
          _sourceTransportBar(controller),
        ],
      ),
    );
  }

  Widget _programMonitorPanel({bool phoneMode = false}) {
    return _panelShell(
      title: 'Player-Timeline 01',
      workspacePanelId: phoneMode ? null : 'program',
      darkChrome: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xff22d3ee),
              shape: BoxShape.circle,
            ),
          ),
          if (!phoneMode) ...[
            const SizedBox(width: 8),
            KText(
              'Program',
              style: TextStyle(fontSize: 11, color: _monitorChromeTextColor),
            ),
          ],
        ],
      ),
      child: _previewPanel(phoneMode),
    );
  }

  Widget _sourceTransportBar(VideoPlayerController? controller) {
    final source = controller;
    final sourceValue = source?.value;
    final initialized = sourceValue?.isInitialized == true;
    final duration =
        initialized ? sourceValue!.duration.inMilliseconds / 1000 : 0.0;
    final position =
        initialized ? sourceValue!.position.inMilliseconds / 1000 : 0.0;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _monitorChromeColor,
        border: Border(top: BorderSide(color: _monitorChromeBorderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showClipNavigation = constraints.maxWidth >= 300;
          return Row(
            children: [
              SizedBox(
                width: 42,
                child: KText(
                  initialized ? _formatDuration(position) : '00:00',
                  style:
                      const TextStyle(color: Color(0xff60a5fa), fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                      trackHeight: 2,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5)),
                  child: Slider(
                    value: duration <= 0 ? 0 : position.clamp(0.0, duration),
                    min: 0,
                    max: duration <= 0 ? 1 : duration,
                    onChanged: initialized
                        ? (value) {
                            _sourceInPoint = value;
                            unawaited(_seekSourcePreview(value));
                          }
                        : null,
                  ),
                ),
              ),
              if (showClipNavigation)
                _monitorIconButton(
                  onPressed: _videos.length < 2 ? null : _selectPreviousVideo,
                  icon: const Icon(Icons.skip_previous, size: 18),
                  tooltip: 'Previous clip',
                ),
              _monitorIconButton(
                onPressed: initialized ? _toggleSourcePreview : null,
                icon: Icon(
                  controller?.value.isPlaying == true
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 18,
                ),
                tooltip: 'Play',
              ),
              if (showClipNavigation)
                _monitorIconButton(
                  onPressed: _videos.length < 2 ? null : _selectNextVideo,
                  icon: const Icon(Icons.skip_next, size: 18),
                  tooltip: 'Next clip',
                ),
              _monitorIconButton(
                onPressed: initialized
                    ? () => _showMonitorVolumeDialog(
                          title: 'Source volume',
                          value: _sourceVolume,
                          onChanged: _setSourceVolume,
                        )
                    : null,
                icon: Icon(
                  _sourceVolume <= 0
                      ? Icons.volume_off_outlined
                      : Icons.volume_up_outlined,
                  size: 18,
                ),
                tooltip: 'Source volume',
              ),
              _monitorIconButton(
                onPressed: initialized
                    ? () => _showMonitorFullscreen(source: true)
                    : null,
                icon: const Icon(Icons.fullscreen, size: 20),
                tooltip: 'Fullscreen source',
              ),
            ],
          );
        },
      ),
    );
  }

  void _addTransformKeyframe() {
    final target = _professionalTargetClip();
    if (target == null) return;
    if (!_ensureTimelineClipUnlocked(
      target.clip.id,
      action: 'adding a keyframe',
    )) {
      return;
    }
    final offset = (_currentProgramSeconds() - target.clip.timelineStart)
        .clamp(0, target.clip.duration)
        .toDouble();
    _updateEditor(() {
      _multiTrackTimeline = _timelineEditor.setClipKeyframe(
        _multiTrackTimeline,
        target.clip.id,
        ClipKeyframe(offset: offset, transform: target.clip.transform),
      );
      _status = 'Motion keyframe added at ${_formatDuration(offset)}';
    });
    unawaited(_autosaveProject());
  }

  void _removeNearestTransformKeyframe() {
    final target = _professionalTargetClip();
    if (target == null || target.clip.keyframes.isEmpty) return;
    if (!_ensureTimelineClipUnlocked(
      target.clip.id,
      action: 'removing a keyframe',
    )) {
      return;
    }
    final offset = (_currentProgramSeconds() - target.clip.timelineStart)
        .clamp(0, target.clip.duration)
        .toDouble();
    final nearest = [...target.clip.keyframes]..sort((a, b) =>
        (a.offset - offset).abs().compareTo((b.offset - offset).abs()));
    _updateEditor(() {
      _multiTrackTimeline = _timelineEditor.removeClipKeyframe(
        _multiTrackTimeline,
        target.clip.id,
        nearest.first.offset,
      );
      _status = 'Nearest motion keyframe removed';
    });
    unawaited(_autosaveProject());
  }

  List<Widget> _transformControlSection({bool includeSpeed = true}) {
    return [
      if (includeSpeed) ...[
        _slider(
          'Speed',
          _speed,
          _EditorScreenState._minVideoSpeed,
          _EditorScreenState._maxVideoSpeed,
          (value) => _setPreviewSpeed(value),
          divisions: 30,
        ),
        _speedPresets(),
      ],
      _dropdown(
        'Flip',
        _flip,
        const ['none', 'left', 'right', 'up', 'down'],
        (value) => _setSelectedTransformEdit(
          (edit) => edit.copyWith(flip: value),
        ),
      ),
      _slider(
        'Scale X',
        _scaleX,
        0.1,
        _EditorScreenState._maxTransformScale,
        (value) => _setSelectedTransformEdit(
          (edit) => edit.copyWith(scaleX: value),
        ),
        valueFormatter: _EditorScreenState._percentText,
        valueParser: _EditorScreenState._parsePercent,
      ),
      _slider(
        'Scale Y',
        _scaleY,
        0.1,
        _EditorScreenState._maxTransformScale,
        (value) => _setSelectedTransformEdit(
          (edit) => edit.copyWith(scaleY: value),
        ),
        valueFormatter: _EditorScreenState._percentText,
        valueParser: _EditorScreenState._parsePercent,
      ),
      _slider(
        'Zoom',
        _zoom,
        1.0,
        _EditorScreenState._maxTransformScale,
        (value) => _setSelectedTransformEdit(
          (edit) => edit.copyWith(zoom: value),
        ),
        valueFormatter: _EditorScreenState._percentText,
        valueParser: _EditorScreenState._parsePercent,
      ),
      _slider(
        'Position X',
        _panX,
        -1,
        1,
        (value) => _setSelectedTransformEdit(
          (edit) => edit.copyWith(panX: value),
        ),
        divisions: 200,
        valueFormatter: (value) => value.toStringAsFixed(2),
      ),
      _slider(
        'Position Y',
        _panY,
        -1,
        1,
        (value) => _setSelectedTransformEdit(
          (edit) => edit.copyWith(panY: value),
        ),
        divisions: 200,
        valueFormatter: (value) => value.toStringAsFixed(2),
      ),
      const SizedBox(height: 8),
      _ratioSelector(),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: KText(
              'Position X ${_panX.toStringAsFixed(2)} / Y ${_panY.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xffb7b7b7)),
            ),
          ),
          TextButton.icon(
            onPressed: () => _setSelectedTransformEdit(
              (edit) => edit.copyWith(panX: 0, panY: 0),
            ),
            icon: const Icon(Icons.center_focus_strong),
            label: const KText('Center'),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _videos.isEmpty ? null : _applyCurrentTransformToAllVideos,
              icon: const Icon(Icons.select_all),
              label: const KText('Apply selected to all'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _videos.isEmpty
                  ? null
                  : () => _setSelectedTransformEdit(
                        (edit) => edit.copyWith(
                          speed: 1,
                          flip: 'none',
                          scaleX: 1,
                          scaleY: 1,
                          zoom: 1,
                          panX: 0,
                          panY: 0,
                        ),
                      ),
              icon: const Icon(Icons.restart_alt),
              label: const KText('Reset frame'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _canvasControlSection() {
    const modes = <String, String>{
      'none': 'None',
      'blur': 'Blur',
      'color': 'Color',
      'pattern': 'Pattern',
    };
    const patterns = <String, String>{
      'grid': 'Grid',
      'stripes': 'Stripes',
      'checker': 'Checker',
      'dots': 'Dots',
    };
    return [
      Row(
        children: [
          const Expanded(
            child: KText(
              'Canvas',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: _videos.isEmpty
                ? null
                : () => _updateCanvasSettings(applyToAll: true),
            child: const KText('Apply to all'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _canvasMode,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Canvas background'),
        items: [
          for (final entry in modes.entries)
            DropdownMenuItem(value: entry.key, child: KText(entry.value)),
        ],
        onChanged: _videos.isEmpty
            ? null
            : (value) {
                if (value != null) _updateCanvasSettings(mode: value);
              },
      ),
      const SizedBox(height: 12),
      if (_canvasMode == 'blur') ...[
        _slider(
          'Blur strength',
          _canvasBlur,
          4,
          80,
          (value) => _updateCanvasSettings(blur: value),
          divisions: 19,
          valueFormatter: (value) => value.round().toString(),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const [12.0, 24.0, 40.0, 64.0])
              ChoiceChip(
                label: KText(value.round().toString()),
                selected: (_canvasBlur - value).abs() < 1,
                onSelected: (_) => _updateCanvasSettings(blur: value),
              ),
          ],
        ),
      ],
      if (_canvasMode == 'color')
        _colorSelector(
          'Canvas color',
          _canvasColor,
          (value) => _updateCanvasSettings(color: value),
        ),
      if (_canvasMode == 'pattern') ...[
        _colorSelector(
          'Pattern color',
          _canvasColor,
          (value) => _updateCanvasSettings(color: value),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in patterns.entries)
              ChoiceChip(
                label: KText(entry.value),
                selected: _canvasPattern == entry.key,
                onSelected: (_) => _updateCanvasSettings(pattern: entry.key),
              ),
          ],
        ),
      ],
      if (_canvasMode != 'none') ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _updateCanvasSettings(mode: 'none'),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const KText('Remove canvas'),
          ),
        ),
      ],
    ];
  }

  Widget _previewPanel(bool phoneMode) {
    final controller = _previewController;
    return ColoredBox(
      color: _panelColor,
      child: Column(
        children: [
          Expanded(
            child: ColoredBox(
              key: const Key('program-monitor-canvas'),
              color: _monitorCanvasColor,
              child: controller == null || !controller.value.isInitialized
                  ? BrowserMessage(
                      icon: _previewError == null
                          ? Icons.movie_outlined
                          : Icons.error_outline,
                      title: _previewError != null
                          ? 'Preview unavailable'
                          : _videos.isEmpty
                              ? 'Add a clip to start editing'
                              : 'Preparing preview',
                      description: _previewError ??
                          (_videos.isEmpty
                              ? 'Import media, then add a clip to your timeline.'
                              : 'The native player is opening your selected media.'),
                      action: _videos.isEmpty
                          ? TextButton.icon(
                              onPressed: _pickVideos,
                              icon: const Icon(Icons.add),
                              label: const Text('Import video'))
                          : _previewError == null
                              ? null
                              : TextButton.icon(
                                  onPressed: () =>
                                      _requestMultiTrackTimelineSeek(
                                          _currentProgramSeconds()),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry preview')),
                    )
                  : _livePreviewVideo(controller),
            ),
          ),
          _programTransportBar(controller),
        ],
      ),
    );
  }
}
