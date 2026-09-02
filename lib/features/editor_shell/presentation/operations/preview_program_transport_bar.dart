part of '../editor_application.dart';

// preview operations owned by the editor state; extracted without changing timing.
extension _PreviewProgramTransportBar on _EditorScreenState {
  Widget _programTransportBar(VideoPlayerController? controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _monitorChromeColor,
        border: Border(top: BorderSide(color: _monitorChromeBorderColor)),
      ),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller ?? _emptyVideoValueListenable,
        builder: (context, value, child) {
          final initialized = controller != null && value.isInitialized;
          final duration =
              initialized ? _programPlaybackDurationSeconds() : 0.0;
          final position = initialized ? _currentProgramSeconds() : 0.0;
          return LayoutBuilder(builder: (context, constraints) {
            final roomy = constraints.maxWidth >= 470;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Program scrub slider — shows the FULL timeline duration
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 2,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                    ),
                    child: Slider(
                      value: duration <= 0 ? 0 : position.clamp(0.0, duration),
                      min: 0,
                      max: duration <= 0 ? 1 : duration,
                      onChanged: initialized
                          ? (value) => _requestMultiTrackTimelineSeek(value)
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: initialized
                                  ? _formatTimecode(position)
                                  : '00:00:00:00',
                              style: const TextStyle(color: Color(0xff22d3ee)),
                            ),
                            const TextSpan(
                              text: '  /  ',
                              style: TextStyle(color: Color(0xff64748b)),
                            ),
                            TextSpan(
                              text: initialized
                                  ? _formatTimecode(duration)
                                  : '00:00:00:00',
                              style: TextStyle(color: _monitorChromeTextColor),
                            ),
                          ]),
                          style: TextStyle(fontSize: roomy ? 10.5 : 9),
                          maxLines: 1,
                        ),
                      ),
                      _monitorIconButton(
                        onPressed: initialized ? _togglePreview : null,
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 21,
                          color: _monitorChromeTextColor,
                        ),
                        tooltip: 'Play / pause',
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (roomy)
                              _monitorIconButton(
                                onPressed: _videos.length < 2
                                    ? null
                                    : _selectPreviousVideo,
                                icon: const Icon(Icons.skip_previous, size: 18),
                                tooltip: 'Previous clip',
                              ),
                            if (roomy)
                              _monitorIconButton(
                                onPressed: _videos.length < 2
                                    ? null
                                    : _selectNextVideo,
                                icon: const Icon(Icons.skip_next, size: 18),
                                tooltip: 'Next clip',
                              ),
                            if (roomy)
                              _monitorIconButton(
                                onPressed: initialized
                                    ? () => _showMonitorVolumeDialog(
                                          title: 'Program volume',
                                          value: _originalVolume,
                                          onChanged: _setOriginalVolume,
                                        )
                                    : null,
                                icon: Icon(
                                  _effectiveOriginalVolume <= 0
                                      ? Icons.volume_off_outlined
                                      : Icons.volume_up_outlined,
                                  size: 18,
                                ),
                                tooltip: 'Program volume',
                              ),
                            if (roomy)
                              _monitorLabelButton(
                                  'Full',
                                  initialized
                                      ? () =>
                                          _showMonitorFullscreen(source: false)
                                      : null),
                            _monitorIconButton(
                              onPressed: initialized
                                  ? () => _updateEditor(() =>
                                      _programTransformOverlayVisible =
                                          !_programTransformOverlayVisible)
                                  : null,
                              icon: Icon(
                                _programTransformOverlayVisible
                                    ? Icons.center_focus_strong
                                    : Icons.center_focus_weak,
                                size: 20,
                                color: _programTransformOverlayVisible
                                    ? const Color(0xff22d3ee)
                                    : _monitorChromeTextColor,
                              ),
                              tooltip: _programTransformOverlayVisible
                                  ? 'Hide transform handles'
                                  : 'Show transform handles',
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Canvas ratio',
                              enabled: initialized,
                              onSelected: (ratio) {
                                _recordEditorHistory('output-ratio');
                                _updateEditor(() => _outputRatio = ratio);
                              },
                              itemBuilder: (context) => [
                                for (final ratio in const [
                                  'original',
                                  '16:9',
                                  '9:16',
                                  '4:5',
                                  '1:1',
                                  '3:4',
                                  '4:3'
                                ])
                                  PopupMenuItem(
                                    value: ratio,
                                    child: Row(children: [
                                      Icon(
                                          ratio == _outputRatio
                                              ? Icons.check
                                              : Icons.crop_free,
                                          size: 18),
                                      const SizedBox(width: 10),
                                      KText(ratio == 'original'
                                          ? 'Original'
                                          : ratio),
                                    ]),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 8),
                                child: KText(roomy ? 'Ratio' : _outputRatio,
                                    style: TextStyle(
                                        color: _monitorChromeTextColor,
                                        fontSize: 10,
                                        decoration: TextDecoration.underline)),
                              ),
                            ),
                            _monitorIconButton(
                              onPressed: initialized
                                  ? () => _showMonitorFullscreen(source: false)
                                  : null,
                              icon: const Icon(Icons.fullscreen, size: 21),
                              tooltip: 'Fullscreen program',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          });
        },
      ),
    );
  }

  Widget _monitorLabelButton(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(34, 30),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: KText(label,
          style: TextStyle(
              color: _monitorChromeTextColor,
              fontSize: 10,
              decoration: TextDecoration.underline)),
    );
  }

  Widget _monitorIconButton({
    required Widget icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      onPressed: onPressed,
      color: _monitorChromeTextColor,
      disabledColor: const Color(0xff6b7280),
      icon: icon,
      tooltip: tooltip,
    );
  }

  Future<void> _showMonitorFullscreen({required bool source}) async {
    final controller = source ? _sourceController : _previewController;
    if (controller == null || !controller.value.isInitialized) return;
    await showDialog<void>(
      context: context,
      barrierColor: _monitorCanvasColor,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: _monitorCanvasColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: source
                    ? _liveSourceVideo(controller)
                    : _livePreviewVideo(controller),
              ),
              Positioned(
                left: 16,
                top: 12,
                right: 16,
                child: Row(
                  children: [
                    KText(
                      source ? 'SOURCE MONITOR' : 'PROGRAM MONITOR',
                      style: TextStyle(
                        color: _monitorChromeTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close fullscreen',
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: _fullscreenTransportBar(
                  source: source,
                  controller: controller,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMonitorVolumeDialog({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) async {
    var draft = value;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _panelColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(color: _panelBorderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            draft <= 0
                                ? Icons.volume_off_outlined
                                : Icons.volume_up_outlined,
                            color: _monitorChromeTextColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Slider(
                              value: draft.clamp(
                                  0.0, _EditorScreenState._maxAudioBoost),
                              min: 0,
                              max: _EditorScreenState._maxAudioBoost,
                              divisions: 60,
                              label: _EditorScreenState._volumeDbText(draft),
                              onChanged: (next) {
                                setDialogState(() => draft = next);
                                onChanged(next);
                              },
                            ),
                          ),
                        ],
                      ),
                      KText(
                        title,
                        style: TextStyle(
                          color: _mutedTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _fullscreenTransportBar({
    required bool source,
    required VideoPlayerController controller,
  }) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final initialized = value.isInitialized;
        final duration = initialized
            ? source
                ? value.duration.inMilliseconds / 1000
                : _programPlaybackDurationSeconds()
            : 0.0;
        final position = initialized
            ? source
                ? value.position.inMilliseconds / 1000
                : _currentProgramSeconds()
            : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _monitorChromeColor.withOpacity(0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _monitorChromeBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: KText(
                    initialized ? _formatDuration(position) : '00:00',
                    style: const TextStyle(
                      color: Color(0xff60a5fa),
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: duration <= 0 ? 0 : position.clamp(0.0, duration),
                    min: 0,
                    max: duration <= 0 ? 1 : duration,
                    onChanged: initialized
                        ? (next) => unawaited(
                              source
                                  ? _seekSourcePreview(next)
                                  : _seekProgramPreview(next),
                            )
                        : null,
                  ),
                ),
                _monitorIconButton(
                  onPressed: _videos.length < 2 ? null : _selectPreviousVideo,
                  icon: const Icon(Icons.skip_previous, size: 18),
                  tooltip: 'Previous clip',
                ),
                _monitorIconButton(
                  onPressed: initialized
                      ? (source ? _toggleSourcePreview : _togglePreview)
                      : null,
                  icon: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  tooltip: 'Play',
                ),
                _monitorIconButton(
                  onPressed: _videos.length < 2 ? null : _selectNextVideo,
                  icon: const Icon(Icons.skip_next, size: 18),
                  tooltip: 'Next clip',
                ),
                _monitorIconButton(
                  onPressed: () => _showMonitorVolumeDialog(
                    title: source ? 'Source volume' : 'Program volume',
                    value: source ? _sourceVolume : _originalVolume,
                    onChanged: source ? _setSourceVolume : _setOriginalVolume,
                  ),
                  icon: Icon(
                    (source ? _sourceVolume : _effectiveOriginalVolume) <= 0
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                    size: 18,
                  ),
                  tooltip: source ? 'Source volume' : 'Program volume',
                ),
                _monitorIconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.fullscreen_exit, size: 20),
                  tooltip: 'Back to small screen',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
