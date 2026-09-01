import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'preview_controller.dart';
import 'professional_clip_preview.dart';
import '../../timeline/domain/timeline_models.dart';

class MultiTrackPreview extends StatefulWidget {
  const MultiTrackPreview({
    super.key,
    required this.model,
    required this.playheadSeconds,
    required this.isPlaying,
    this.includeBaseTrack = false,
    this.preferredController,
    this.preferredMediaPath,
    this.selectedClipId,
    this.onClipSelected,
    this.enableTextureEffects = true,
  });

  final TimelineModel model;
  final double playheadSeconds;
  final bool isPlaying;
  final bool includeBaseTrack;
  final VideoPlayerController? preferredController;
  final String? preferredMediaPath;
  final String? selectedClipId;
  final ValueChanged<String>? onClipSelected;
  final bool enableTextureEffects;

  static List<({TrackModel track, ClipModel clip})> activeVideoLayers({
    required TimelineModel model,
    required double playheadSeconds,
    bool includeBaseTrack = false,
  }) {
    final result = <({TrackModel track, ClipModel clip})>[];
    for (final track in model.videoTracks) {
      if ((!includeBaseTrack && track.index <= 1) || track.isMuted) continue;
      for (final clip in track.clips) {
        if (!clip.isMuted &&
            playheadSeconds >= clip.timelineStart &&
            playheadSeconds < clip.timelineEnd) {
          result.add((track: track, clip: clip));
        }
      }
    }
    result.sort((a, b) => a.clip.zIndex.compareTo(b.clip.zIndex));
    return result;
  }

  /// A normal full-frame top clip does not need GPU multi-texture
  /// composition. Rendering it through the persistent Program texture is
  /// both faster and more reliable with video_player_win.
  static ({TrackModel track, ClipModel clip})? directTextureLayer({
    required TimelineModel model,
    required double playheadSeconds,
    required String preferredMediaPath,
  }) {
    final layers = activeVideoLayers(
      model: model,
      playheadSeconds: playheadSeconds,
      includeBaseTrack: true,
    );
    if (layers.isEmpty) return null;
    final top = layers.last;
    final clip = top.clip;
    final transform = clip.transformAt(playheadSeconds - clip.timelineStart);
    final fullFrame = transform.scaleX >= 0.999 &&
        transform.scaleY >= 0.999 &&
        (transform.positionX - 0.5).abs() < 0.001 &&
        (transform.positionY - 0.5).abs() < 0.001 &&
        transform.opacity >= 0.999 &&
        transform.rotationDegrees.abs() < 0.001 &&
        transform.blendMode == 'normal';
    if (!fullFrame ||
        clip.mediaPath != preferredMediaPath ||
        clip.transitionIn != null ||
        clip.keyframes.isNotEmpty) {
      return null;
    }
    return top;
  }

  @override
  State<MultiTrackPreview> createState() => _MultiTrackPreviewState();
}

class _MultiTrackPreviewState extends State<MultiTrackPreview> {
  final Map<String, VideoPlayerController> _controllers = {};
  final Set<String> _readyClipIds = {};
  bool _synchronizing = false;
  bool _synchronizeAgain = false;
  double _lastSynchronizedPlayhead = -1;
  bool? _lastPlaying;
  String _lastLayerSignature = '';

  @override
  void initState() {
    super.initState();
    unawaited(_synchronizeControllers());
  }

  @override
  void didUpdateWidget(covariant MultiTrackPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _layerSignature(_activeLayers);
    final activeSetChanged = signature != _lastLayerSignature;
    final playbackChanged = widget.isPlaying != _lastPlaying;
    final drift = (widget.playheadSeconds - _lastSynchronizedPlayhead).abs();
    if (activeSetChanged ||
        playbackChanged ||
        !widget.isPlaying ||
        drift >= 0.18) {
      unawaited(_synchronizeControllers());
    }
  }

  List<({TrackModel track, ClipModel clip})> get _activeLayers {
    return MultiTrackPreview.activeVideoLayers(
      model: widget.model,
      playheadSeconds: widget.playheadSeconds,
      includeBaseTrack: widget.includeBaseTrack,
    );
  }

  String? get _preferredClipId {
    final controller = widget.preferredController;
    final path = widget.preferredMediaPath;
    if (controller == null || !controller.value.isInitialized || path == null) {
      return null;
    }
    for (final layer in _activeLayers.reversed) {
      if (layer.clip.mediaPath == path) return layer.clip.id;
    }
    return null;
  }

  VideoPlayerController? _controllerFor(ClipModel clip) {
    if (_preferredClipId == clip.id) return widget.preferredController;
    return _controllers[clip.id];
  }

  String _layerSignature(
    List<({TrackModel track, ClipModel clip})> layers,
  ) =>
      '${layers.map((item) => '${item.clip.id}:${item.clip.timelineStart}:${item.clip.duration}').join('|')}:preferred=${_preferredClipId ?? ''}';

  Future<void> _synchronizeControllers() async {
    if (_synchronizing) {
      _synchronizeAgain = true;
      return;
    }
    _synchronizing = true;
    final active = _activeLayers;
    _lastLayerSignature = _layerSignature(active);
    _lastPlaying = widget.isPlaying;
    _lastSynchronizedPlayhead = widget.playheadSeconds;
    final preferredClipId = _preferredClipId;
    final activeIds = active
        .map((item) => item.clip.id)
        .where((id) => id != preferredClipId)
        .toSet();
    final stale =
        _controllers.keys.where((id) => !activeIds.contains(id)).toList();
    var controllersChanged = stale.isNotEmpty;
    for (final id in stale) {
      await _controllers.remove(id)?.dispose();
      _readyClipIds.remove(id);
    }
    for (final layer in active) {
      if (layer.clip.id == preferredClipId) continue;
      var controller = _controllers[layer.clip.id];
      var created = false;
      if (controller == null) {
        try {
          controller = await createPreviewController(layer.clip.mediaPath);
          await controller.setVolume(0);
          if (!mounted ||
              !_activeLayers.any((item) => item.clip.id == layer.clip.id)) {
            await controller.dispose();
            continue;
          }
          _controllers[layer.clip.id] = controller;
          controllersChanged = true;
          created = true;
          // Mount the texture invisibly before asking video_player_win to
          // decode its first frame. Warming an unmounted texture leaves the
          // Windows plugin's gray placeholder visible indefinitely.
          if (mounted) {
            setState(() {});
            await WidgetsBinding.instance.endOfFrame;
          }
        } catch (_) {
          continue;
        }
      }
      final sourceSeconds = layer.clip.sourceStart +
          widget.playheadSeconds -
          layer.clip.timelineStart;
      final current = controller.value.position.inMilliseconds / 1000;
      if (!widget.isPlaying || (current - sourceSeconds).abs() > 0.2) {
        await controller.seekTo(
          Duration(milliseconds: (sourceSeconds * 1000).round()),
        );
      }
      if (widget.isPlaying && !controller.value.isPlaying) {
        await controller.play();
        if (created) {
          await Future<void>.delayed(const Duration(milliseconds: 90));
        }
      } else if (!widget.isPlaying && controller.value.isPlaying) {
        await controller.pause();
      } else if (created && !widget.isPlaying) {
        // Decode a real frame while the mounted texture is still hidden.
        await controller.play();
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await controller.pause();
      }
      if (created) {
        _readyClipIds.add(layer.clip.id);
        if (mounted) setState(() {});
      }
    }
    if (mounted && controllersChanged) {
      setState(() {});
    }
    _synchronizing = false;
    if (_synchronizeAgain && mounted) {
      _synchronizeAgain = false;
      unawaited(_synchronizeControllers());
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      unawaited(controller.dispose());
    }
    _controllers.clear();
    _readyClipIds.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = _activeLayers;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in layers)
          if (_controllerFor(layer.clip)?.value.isInitialized == true)
            _layer(
              layer.clip,
              _controllerFor(layer.clip)!,
              textureReady: layer.clip.id == _preferredClipId ||
                  _readyClipIds.contains(layer.clip.id),
            ),
      ],
    );
  }

  Widget _layer(
    ClipModel clip,
    VideoPlayerController controller, {
    required bool textureReady,
  }) {
    final transform =
        clip.transformAt(widget.playheadSeconds - clip.timelineStart);
    final selected = widget.selectedClipId == clip.id;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * transform.scaleX;
        final height = constraints.maxHeight * transform.scaleY;
        final left = transform.positionX * constraints.maxWidth - width / 2;
        final top = transform.positionY * constraints.maxHeight - height / 2;
        Widget video = VideoPlayer(controller);
        if (widget.enableTextureEffects &&
            (clip.effects.any((effect) => effect.enabled) ||
                clip.transitionIn != null)) {
          video = ProfessionalClipPreview(
            clip: clip,
            playheadSeconds: widget.playheadSeconds,
            child: video,
          );
        }
        Widget visual = video;
        if (!textureReady || transform.opacity < 0.999) {
          visual = Opacity(
            opacity: textureReady ? transform.opacity.clamp(0, 1) : 0,
            child: visual,
          );
        }
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Transform.rotate(
            angle: transform.rotationDegrees * 0.017453292519943295,
            child: GestureDetector(
              onTap: () => widget.onClipSelected?.call(clip.id),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: selected
                      ? Border.all(color: const Color(0xff22d3ee), width: 2)
                      : null,
                ),
                child: ClipRect(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio > 0
                          ? controller.value.aspectRatio
                          : 16 / 9,
                      child: visual,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
