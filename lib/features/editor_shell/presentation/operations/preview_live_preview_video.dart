part of '../editor_application.dart';

// preview operations owned by the editor state; extracted without changing timing.
extension _PreviewLivePreviewVideo on _EditorScreenState {
  Widget _livePreviewVideo(VideoPlayerController controller) {
    final size = controller.value.size;
    final videoWidth = size.width <= 0 ? 16.0 : size.width;
    final videoHeight = size.height <= 0 ? 9.0 : size.height;
    final textOverlays = _previewTextOverlays();
    final previewTimeline = _programPreviewTimeline;
    final previewSeconds = ProgramTimelineMapper.monitorFrameTime(
        previewTimeline, _currentProgramSeconds(),
        frameRate: _projectFrameRate);
    final professionalClip = _activeBaseVideoClip(previewSeconds);
    final canvasTransform = professionalClip?.transformAt(
      previewSeconds - professionalClip.timelineStart,
    );
    final resolvedTransform = canvasTransform ??
        ClipTransform(
          scaleX: _scaleX * _zoom,
          scaleY: _scaleY * _zoom,
          positionX: (0.5 + _panX * 0.5).clamp(0, 1).toDouble(),
          positionY: (0.5 + _panY * 0.5).clamp(0, 1).toDouble(),
          flip: _flip,
        );
    final hFlip = resolvedTransform.flip == 'left' ||
        resolvedTransform.flip == 'right' ||
        resolvedTransform.flip == 'up';
    final vFlip =
        resolvedTransform.flip == 'up' || resolvedTransform.flip == 'down';
    final xScale = resolvedTransform.scaleX.abs();
    final yScale = resolvedTransform.scaleY.abs();
    final hasLayeredVideo = _multiTrackTimeline.hasLayeredVideo ||
        previewTimeline.activeClips(previewSeconds, TrackType.video).length > 1;
    final activeVideoLayers = hasLayeredVideo
        ? MultiTrackPreview.activeVideoLayers(
            model: previewTimeline,
            playheadSeconds: previewSeconds,
            includeBaseTrack: true,
          )
        : const <({TrackModel track, ClipModel clip})>[];
    final directTextureLayer = hasLayeredVideo
        ? MultiTrackPreview.directTextureLayer(
            model: previewTimeline,
            playheadSeconds: previewSeconds,
            preferredMediaPath: _videos[_selectedVideoIndex].path,
          )
        : null;
    final useTrueMultiTrackPreview = hasLayeredVideo &&
        activeVideoLayers.isNotEmpty &&
        directTextureLayer == null;
    final hideLegacyTexture =
        hasLayeredVideo ? directTextureLayer == null : _videoTrackHidden;
    // video_player_win textures can turn into a gray surface when wrapped in
    // ColorFiltered/ImageFiltered. Keep the decoded texture direct on Windows;
    // the complete effect stack is still rendered by FFmpeg during export.
    final showPreviewEffects = !Platform.isWindows &&
        !_projectProxyEnabled &&
        widget.settings.previewQuality != PreviewQuality.low;
    final showTextOverlays =
        widget.settings.previewQuality != PreviewQuality.low;

    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AspectRatio(
            aspectRatio: _previewAspectRatio(controller),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _monitorCanvasColor,
                border: Border.all(color: const Color(0xff6b7280)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xaa000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: _canvasPreviewBackground(
                        controller: controller,
                        videoSize: Size(videoWidth, videoHeight),
                        transform: canvasTransform,
                      ),
                    ),
                  ),
                  if (hideLegacyTexture)
                    const SizedBox.shrink()
                  else
                    Positioned.fill(
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final rect = _videoTransformRect(
                              canvasSize: constraints.biggest,
                              videoSize: Size(videoWidth, videoHeight),
                              xScale: xScale.abs(),
                              yScale: yScale.abs(),
                              transform: resolvedTransform,
                            );
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: rect.left,
                                  top: rect.top,
                                  width: rect.width,
                                  height: rect.height,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _updateEditor(() =>
                                        _programTransformOverlayVisible = true),
                                    child: Opacity(
                                      opacity: resolvedTransform.opacity
                                          .clamp(0, 1)
                                          .toDouble(),
                                      child: Transform.rotate(
                                        angle:
                                            resolvedTransform.rotationDegrees *
                                                math.pi /
                                                180,
                                        child: Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.diagonal3Values(
                                            hFlip ? -1 : 1,
                                            vFlip ? -1 : 1,
                                            1,
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              Widget video = showPreviewEffects
                                                  ? ColorFiltered(
                                                      colorFilter:
                                                          ColorFilter.matrix(
                                                        _previewColorMatrix(),
                                                      ),
                                                      child: VideoPlayer(
                                                          controller),
                                                    )
                                                  : VideoPlayer(controller);
                                              if (!showPreviewEffects &&
                                                  professionalClip != null &&
                                                  (professionalClip.effects.any(
                                                          (e) => e.enabled) ||
                                                      professionalClip
                                                              .transitionIn !=
                                                          null)) {
                                                return SoftwareEffectFrame(
                                                    clip: professionalClip,
                                                    time: previewSeconds);
                                              }
                                              if (professionalClip != null &&
                                                  showPreviewEffects) {
                                                video = ProfessionalClipPreview(
                                                  clip: professionalClip,
                                                  playheadSeconds:
                                                      previewSeconds,
                                                  child: video,
                                                );
                                              }
                                              return video;
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  if (useTrueMultiTrackPreview)
                    Positioned.fill(
                      child: Builder(
                        builder: (context) {
                          Widget preview = MultiTrackPreview(
                            model: previewTimeline,
                            playheadSeconds: previewSeconds,
                            isPlaying: controller.value.isPlaying,
                            includeBaseTrack: true,
                            preferredController: controller,
                            preferredMediaPath:
                                _videos[_selectedVideoIndex].path,
                            previewMediaPaths: {
                              for (final video in _videos)
                                if (_shouldUseProxy(video) &&
                                    video.proxyPath != null &&
                                    File(video.proxyPath!).existsSync())
                                  video.path: video.proxyPath!,
                            },
                            playbackSpeedsByMediaPath: {
                              for (final video in _videos)
                                video.path:
                                    _clipTimelineEditFor(video.path).speed,
                            },
                            selectedClipId: _selectedTimelineClipId,
                            onTransformChanged: _programTransformOverlayVisible
                                ? _updateProgramMonitorTransform
                                : null,
                            onTransformEnd: _commitProgramTransform,
                            onTransformCancel: _cancelProgramTransform,
                            enableTextureEffects: !Platform.isWindows,
                            onClipSelected: (clipId) =>
                                unawaited(_selectMultiTrackClip(clipId)),
                          );
                          final hasColorAdjustment =
                              _brightness.abs() > 0.0001 ||
                                  (_contrast - 1).abs() > 0.0001 ||
                                  (_saturation - 1).abs() > 0.0001;
                          if (showPreviewEffects && hasColorAdjustment) {
                            preview = ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                _previewColorMatrix(),
                              ),
                              child: preview,
                            );
                          }
                          return preview;
                        },
                      ),
                    ),
                  if (_programTransformOverlayVisible &&
                      professionalClip?.id == _selectedTimelineClipId &&
                      _multiTrackTimeline
                              .clipById(_selectedTimelineClipId ?? '')
                              ?.track
                              .isLocked ==
                          false &&
                      !useTrueMultiTrackPreview)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              InteractiveTransformOverlay(
                                frame: _videoTransformRect(
                                  canvasSize: constraints.biggest,
                                  videoSize: Size(videoWidth, videoHeight),
                                  xScale: xScale,
                                  yScale: yScale,
                                  transform: resolvedTransform,
                                ),
                                transform: resolvedTransform,
                                onTransformChanged: (transform) =>
                                    _updateProgramMonitorTransform(
                                  professionalClip?.id,
                                  transform,
                                ),
                                onTransformEnd: _commitProgramTransform,
                                onTransformCancel: _cancelProgramTransform,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  for (final entry in textOverlays.indexed)
                    if (showTextOverlays &&
                        entry.$2.isVisible &&
                        entry.$2.text.trim().isNotEmpty)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final overlay = entry.$2;
                          final selected =
                              entry.$1 == _selectedTextOverlayIndex;
                          final child = GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _selectTextOverlay(entry.$1),
                            onPanStart: selected && !overlay.isLocked
                                ? (_) => _recordEditorHistory('text-position')
                                : null,
                            onPanUpdate: selected && !overlay.isLocked
                                ? (details) {
                                    final width = constraints.maxWidth <= 0
                                        ? 260.0
                                        : constraints.maxWidth;
                                    final height = constraints.maxHeight <= 0
                                        ? 260.0
                                        : constraints.maxHeight;
                                    _updateEditor(() {
                                      _overlayTextX = (_overlayTextX +
                                              details.delta.dx / width)
                                          .clamp(0.0, 1.0)
                                          .toDouble();
                                      _overlayTextY = (_overlayTextY +
                                              details.delta.dy / height)
                                          .clamp(0.0, 1.0)
                                          .toDouble();
                                      final next = _currentTextOverlayDraft();
                                      _textOverlays[_selectedTextOverlayIndex] =
                                          next;
                                      _insertTextTimelineClip(next);
                                    });
                                  }
                                : null,
                            child: ProjectTitleView(
                              title: TitleTimelineResolver.bind(
                                  overlay.toSettings(_colorToHex),
                                  _programPreviewTimeline),
                              time: previewSeconds,
                            ),
                          );
                          return child;
                        },
                      ),
                  if (_watermarkPath != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final previewHeight = constraints.maxHeight <= 0
                            ? videoHeight
                            : constraints.maxHeight;
                        return Align(
                          alignment: Alignment(
                            _watermarkX * 2 - 1,
                            _watermarkY * 2 - 1,
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (_) =>
                                _recordEditorHistory('watermark-position'),
                            onPanUpdate: (details) {
                              final width = constraints.maxWidth <= 0
                                  ? 260.0
                                  : constraints.maxWidth;
                              final height = constraints.maxHeight <= 0
                                  ? 260.0
                                  : constraints.maxHeight;
                              _updateEditor(() {
                                _watermarkX =
                                    (_watermarkX + details.delta.dx / width)
                                        .clamp(0.0, 1.0)
                                        .toDouble();
                                _watermarkY =
                                    (_watermarkY + details.delta.dy / height)
                                        .clamp(0.0, 1.0)
                                        .toDouble();
                              });
                            },
                            child: ClipRect(
                              child: Image.file(
                                File(_watermarkPath!),
                                height: (previewHeight * _watermarkSize)
                                    .clamp(24, 220),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  _captionPreviewLayer(
                    controller: controller,
                    videoHeight: videoHeight,
                  ),
                  if (_outputRatio != 'original' &&
                      _programTransformOverlayVisible)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xaa000000),
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          child: KText(
                            'Drag to reframe',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateProgramMonitorTransform(String? clipId, ClipTransform transform) {
    if (clipId == null || clipId != _selectedTimelineClipId) return;
    if (_transformPreview.update(_multiTrackTimeline, clipId, transform)) {
      _updateEditor(() {});
    }
  }

  void _cancelProgramTransform() {
    _transformPreview.discard();
    if (mounted) _updateEditor(() {});
  }

  void _commitProgramTransform() {
    final next =
        _transformPreview.accept(_multiTrackTimeline, _selectedTimelineClipId);
    if (next == null) {
      if (mounted) _updateEditor(() {});
      return;
    }
    _commitTimelineModelChange(next);
    final selected = _selectedTimelineClipId;
    final clip = selected == null ? null : next.clipById(selected)?.clip;
    if (clip != null) _loadTimelineClipTransformIntoInspector(clip);
  }

  Widget _canvasPreviewBackground({
    required VideoPlayerController controller,
    required Size videoSize,
    ClipTransform? transform,
  }) {
    final mode = transform?.canvasMode ?? _canvasMode;
    final color = _parseHexColor(transform?.canvasColor ?? '') ?? _canvasColor;
    final pattern = transform?.canvasPattern ?? _canvasPattern;
    final blur = transform?.canvasBlur ?? _canvasBlur;
    switch (mode) {
      case 'blur':
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: blur.clamp(4, 80).toDouble(),
                sigmaY: blur.clamp(4, 80).toDouble(),
                tileMode: TileMode.mirror,
              ),
              child: Transform.scale(
                scale: 1.12,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: videoSize.width,
                    height: videoSize.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
            const ColoredBox(color: Color(0x18000000)),
          ],
        );
      case 'color':
        return ColoredBox(color: color);
      case 'pattern':
        return CustomPaint(
          painter: _CanvasPatternPainter(
            pattern: pattern,
            color: color,
          ),
        );
      default:
        return ColoredBox(color: _monitorCanvasColor);
    }
  }

  Rect _videoTransformRect({
    required Size canvasSize,
    required Size videoSize,
    required double xScale,
    required double yScale,
    ClipTransform? transform,
  }) {
    final box = VideoGeometry.resolve(
      canvasWidth: canvasSize.width,
      canvasHeight: canvasSize.height,
      sourceWidth: videoSize.width,
      sourceHeight: videoSize.height,
      scaleX: xScale,
      scaleY: yScale,
      positionX: transform?.positionX ?? (1 + _panX) / 2,
      positionY: transform?.positionY ?? (1 + _panY) / 2,
    );
    return Rect.fromLTWH(box.left, box.top, box.width, box.height);
  }

  double _previewAspectRatio(VideoPlayerController controller) {
    return switch (_outputRatio) {
      '16:9' => 16 / 9,
      '9:16' => 9 / 16,
      '4:5' => 4 / 5,
      '1:1' => 1,
      '3:4' => 3 / 4,
      '4:3' => 4 / 3,
      _ => controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio,
    };
  }
}
