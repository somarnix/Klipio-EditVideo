import 'dart:math' as math;

import '../domain/export_models.dart';
import '../../timeline/domain/timeline_models.dart';
import '../../composition/domain/video_geometry.dart';
import '../../composition/domain/text_geometry.dart';
import '../../composition/domain/effect_render_state.dart';
import '../../timeline/domain/keyframe_curve.dart';
import '../../timeline/domain/transition_boundary.dart';

class MultiTrackFilterPlan {
  const MultiTrackFilterPlan({
    required this.arguments,
    required this.filterGraph,
    required this.duration,
    required this.videoInputCount,
    required this.audioInputCount,
    required this.filterCount,
  });

  final List<String> arguments;
  final String filterGraph;
  final double duration;
  final int videoInputCount;
  final int audioInputCount;
  final int filterCount;
}

class MultiTrackFilterBuilder {
  const MultiTrackFilterBuilder();

  MultiTrackFilterPlan build(
    MultiTrackExportJob job, {
    required String encoder,
    Set<String>? audioClipIdsWithStreams,
    String? captionAssPath,
    bool? hardwareDecoding,
    Map<String, ({double width, double height})> sourceDimensions = const {},
    Map<int, String> textRasterPaths = const {},
    bool titlesStreamed = false,
    Map<int, String> captionRasterPaths = const {},
    String? captionStreamUrl,
  }) {
    if (titlesStreamed && captionStreamUrl == null) {
      throw StateError('Modern titles require their job-owned visual stream');
    }
    final timeline = job.timeline;
    final duration = timeline.duration <= 0 ? 0.001 : timeline.duration;
    final videoLayers = <({TrackModel track, ClipModel clip})>[];
    final audioLayers = <({TrackModel track, ClipModel clip})>[];
    for (final track in timeline.videoTracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        if (!clip.isMuted) videoLayers.add((track: track, clip: clip));
      }
    }
    for (final track in timeline.audioTracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        if (!clip.isMuted &&
            (audioClipIdsWithStreams == null ||
                audioClipIdsWithStreams.contains(clip.id))) {
          audioLayers.add((track: track, clip: clip));
        }
      }
    }
    videoLayers.sort((a, b) {
      final z = a.clip.zIndex.compareTo(b.clip.zIndex);
      return z != 0 ? z : a.clip.timelineStart.compareTo(b.clip.timelineStart);
    });
    final outgoingVideoTransitions = _outgoingTransitions(
      timeline.videoTracks,
    );
    final outgoingAudioTransitions = _outgoingTransitions(
      timeline.audioTracks,
    );

    final sequentialPlan = _buildSequentialPlan(
      job,
      encoder: encoder,
      videoLayers: videoLayers,
      audioLayers: audioLayers,
      captionAssPath: captionAssPath,
      hardwareDecoding: hardwareDecoding ?? job.hardwareDecoding,
    );
    if (sequentialPlan != null &&
        textRasterPaths.isEmpty &&
        captionRasterPaths.isEmpty &&
        captionStreamUrl == null) {
      return sequentialPlan;
    }

    final args = <String>[
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=c=${job.backgroundColor}:s=${job.width}x${job.height}:r=${_n(job.frameRate)}:d=${_n(duration)}',
    ];
    final videoInputs = <String, int>{};
    final audioInputs = <String, int>{};
    final mediaInputs = <String, int>{};
    var inputIndex = 1;

    int addMediaInput(ClipModel clip) {
      final sourceDuration = _sourceDuration(job, clip);
      final key =
          '${clip.mediaPath}\u0000${_n(clip.sourceStart)}\u0000${_n(sourceDuration)}';
      final existing = mediaInputs[key];
      if (existing != null) return existing;
      if (hardwareDecoding ?? job.hardwareDecoding) {
        // `auto` lets FFmpeg select D3D11VA/CUDA/QSV/VideoToolbox while still
        // downloading frames for the software filter graph when required.
        args.addAll(['-hwaccel', 'auto']);
      }
      // Seeking before each input prevents a four-cut timeline from decoding
      // the complete source four (or eight) separate times.
      args.addAll([
        '-ss',
        _n(clip.sourceStart),
        '-t',
        _n(sourceDuration),
        '-i',
        clip.mediaPath,
      ]);
      final added = inputIndex++;
      mediaInputs[key] = added;
      return added;
    }

    for (final layer in videoLayers) {
      videoInputs[layer.clip.id] = addMediaInput(layer.clip);
    }
    for (final layer in audioLayers) {
      audioInputs[layer.clip.id] = addMediaInput(layer.clip);
    }

    final filters = <String>['[0:v]setpts=PTS-STARTPTS[canvas0]'];
    var composite = 'canvas0';
    for (var index = 0; index < videoLayers.length; index++) {
      final layer = videoLayers[index];
      final clip = layer.clip;
      final transform = clip.transform;
      final speed = _playbackSpeed(job, clip);
      final sourceDuration = _sourceDuration(job, clip);
      final input = videoInputs[clip.id]!;
      final prepared = 'video$index';
      final next = 'composite${index + 1}';
      final enable =
          "gte(t,${_n(clip.timelineStart)})*lt(t,${_n(clip.timelineEnd)})";
      var foregroundInput = '$input:v';
      if (transform.canvasMode == 'blur') {
        final foregroundSource = 'video${index}ForegroundSource';
        final backgroundSource = 'video${index}BackgroundSource';
        final background = 'video${index}CanvasBackground';
        final backgroundComposite = 'video${index}CanvasComposite';
        filters.add(
          '[$input:v]split=2[$foregroundSource][$backgroundSource]',
        );
        foregroundInput = foregroundSource;
        filters.add(
          '[$backgroundSource]trim=start=0:'
          'duration=${_n(sourceDuration)},'
          'setpts=(PTS-STARTPTS)/${_n(speed)},'
          'fps=${_n(job.frameRate)},'
          'scale=${_blurWidth(job)}:${_blurHeight(job)}:'
          'force_original_aspect_ratio=increase,'
          'crop=${_blurWidth(job)}:${_blurHeight(job)},'
          'gblur=sigma=${_n((transform.canvasBlur * 0.5).clamp(3, 24))}:steps=1,'
          'scale=${job.width}:${job.height},'
          'format=yuv420p,setpts=PTS+${_n(clip.timelineStart)}/TB[$background]',
        );
        filters.add(
          '[$composite][$background]overlay=x=0:y=0:enable=\'$enable\':'
          'eof_action=pass:shortest=0:format=auto[$backgroundComposite]',
        );
        composite = backgroundComposite;
      } else if (transform.canvasMode == 'color' ||
          transform.canvasMode == 'pattern') {
        final backgroundComposite = 'video${index}CanvasComposite';
        final base = _color(transform.canvasColor);
        final patternFilter = transform.canvasMode == 'pattern'
            ? _canvasPatternFilter(transform.canvasPattern, enable)
            : '';
        filters.add(
          '[$composite]drawbox=x=0:y=0:w=iw:h=ih:color=$base:'
          't=fill:enable=\'$enable\'$patternFilter[$backgroundComposite]',
        );
        composite = backgroundComposite;
      }
      final rotationDegrees = _keyframeExpression(
        clip,
        (value) => value.rotationDegrees,
      );
      final rotation = rotationDegrees == '0'
          ? ''
          : clip.keyframes.isEmpty
              ? ",rotate='$rotationDegrees*PI/180':ow='ceil(rotw($rotationDegrees*PI/180)/2)*2':oh='ceil(roth($rotationDegrees*PI/180)/2)*2':c=black@0"
              : ",rotate='$rotationDegrees*PI/180':ow='ceil(hypot(iw,ih)/2)*2':oh=ow:c=black@0";
      final effects = _clipEffectFilters(clip.effects);
      final flip = _flipFilters(transform.flip);
      final incomingFade = clip.transitionIn == null
          ? ''
          : ',fade=t=in:st=0:d=${_n(clip.transitionIn!.duration)}:alpha=1';
      final outgoing = outgoingVideoTransitions[clip.id];
      final outgoingFade = outgoing?.type == ClipTransitionType.fadeBlack
          ? ',fade=t=out:st=${_n(math.max(0, clip.duration - outgoing!.duration))}:'
              'd=${_n(outgoing.duration)}:alpha=1'
          : '';
      final needsAlpha = transform.opacity < 0.999 ||
          clip.keyframes.isNotEmpty ||
          incomingFade.isNotEmpty ||
          outgoingFade.isNotEmpty ||
          rotation.isNotEmpty;
      final animatedSize = sourceDimensions[clip.mediaPath];
      var animationPad = '';
      if (clip.keyframes.isNotEmpty && animatedSize != null) {
        final base = VideoGeometry.resolve(
            canvasWidth: job.width.toDouble(),
            canvasHeight: job.height.toDouble(),
            sourceWidth: animatedSize.width,
            sourceHeight: animatedSize.height,
            scaleX: 1,
            scaleY: 1,
            positionX: 0.5,
            positionY: 0.5);
        final maxX = clip.keyframes
            .map((frame) => frame.transform.scaleX)
            .reduce(math.max);
        final maxY = clip.keyframes
            .map((frame) => frame.transform.scaleY)
            .reduce(math.max);
        final width = math.max(2, (base.width * maxX / 2).ceil() * 2);
        final height = math.max(2, (base.height * maxY / 2).ceil() * 2);
        // Fixed transparent bounds prevent downstream filters retaining stale
        // configured dimensions when animated scale changes the input size.
        animationPad =
            ',pad=$width:$height:(ow-iw)/2:(oh-ih)/2:color=black@0:eval=frame';
      }
      final alphaFilters = clip.keyframes.isNotEmpty
          ? ",format=rgba$animationPad,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a='alpha(X,Y)*(${_keyframeExpression(clip, (value) => value.opacity, clock: 'T')})'"
          : needsAlpha
              ? ',format=rgba,colorchannelmixer=aa=${_n(transform.opacity)}'
              : '';
      final scaleFilter = ',${_foregroundScaleFilter(job, clip)}';
      filters.add(
        '[$foregroundInput]trim=start=0:duration=${_n(sourceDuration)},'
        'setpts=(PTS-STARTPTS)/${_n(speed)},'
        'fps=${_n(job.frameRate)}$flip$effects$scaleFilter$alphaFilters$rotation'
        '$incomingFade$outgoingFade,'
        'setpts=PTS+${_n(clip.timelineStart)}/TB[$prepared]',
      );
      final positionX = _keyframeExpression(
        clip,
        (value) => value.positionX,
        timelineOffset: clip.timelineStart,
      );
      final positionY = _keyframeExpression(
        clip,
        (value) => value.positionY,
        timelineOffset: clip.timelineStart,
      );
      // Program Monitor positions a clip by its center and fits the source
      // inside a canvas-relative transform box. Export must use the same
      // geometry or Scale X/Y crops a different picture than the preview.
      // Program Monitor stores position as pan across the free space around
      // the fitted/scaled source. Using W*position here moves the center
      // across the entire canvas and produces a different crop on export.
      var x = VideoGeometry.offsetExpression('W', 'w', positionX);
      var y = VideoGeometry.offsetExpression('H', 'h', positionY);
      final sourceSize = sourceDimensions[clip.mediaPath];
      if ((rotation.isNotEmpty || animationPad.isNotEmpty) &&
          sourceSize != null) {
        final base = VideoGeometry.resolve(
            canvasWidth: job.width.toDouble(),
            canvasHeight: job.height.toDouble(),
            sourceWidth: sourceSize.width,
            sourceHeight: sourceSize.height,
            scaleX: 1,
            scaleY: 1,
            positionX: 0.5,
            positionY: 0.5);
        // Match the two even-dimension scale stages used by the raster adapter.
        final width =
            ((base.width / 2).floor() * 2 * transform.scaleX / 2).floor() * 2;
        final height =
            ((base.height / 2).floor() * 2 * transform.scaleY / 2).floor() * 2;
        final animatedWidth = clip.keyframes.isEmpty
            ? '$width'
            : 'max(2\\,trunc(${(base.width / 2).floor() * 2}*(${_keyframeExpression(clip, (value) => value.scaleX, timelineOffset: clip.timelineStart)})/2)*2)';
        final animatedHeight = clip.keyframes.isEmpty
            ? '$height'
            : 'max(2\\,trunc(${(base.height / 2).floor() * 2}*(${_keyframeExpression(clip, (value) => value.scaleY, timelineOffset: clip.timelineStart)})/2)*2)';
        x = VideoGeometry.rotatedOffsetExpression(
            'W', 'w', animatedWidth, positionX);
        y = VideoGeometry.rotatedOffsetExpression(
            'H', 'h', animatedHeight, positionY);
      }
      final transition = clip.transitionIn;
      if (transition != null &&
          (transition.type == ClipTransitionType.slideLeft ||
              transition.type == ClipTransitionType.slideRight)) {
        final progress =
            'min(max((t-${_n(clip.timelineStart)})/${_n(transition.duration)}\\,0)\\,1)';
        final origin =
            transition.type == ClipTransitionType.slideLeft ? 'W' : '-w';
        x = '$origin+(($x)-$origin)*$progress';
      } else if (transition != null &&
          (transition.type == ClipTransitionType.slideUp ||
              transition.type == ClipTransitionType.slideDown)) {
        final progress =
            'min(max((t-${_n(clip.timelineStart)})/${_n(transition.duration)}\\,0)\\,1)';
        final origin =
            transition.type == ClipTransitionType.slideUp ? 'H' : '-h';
        y = '$origin+(($y)-$origin)*$progress';
      }
      final blend = _ffmpegBlendMode(transform.blendMode);
      if (blend == null) {
        filters.add(
          '[$composite][$prepared]overlay=x=$x:y=$y:enable=\'$enable\':'
          'eof_action=pass:shortest=0:format=auto[$next]',
        );
      } else {
        final padded = 'padded$index';
        final padX = '(ow-iw)*${_n(transform.positionX)}';
        final padY = '(oh-ih)*${_n(transform.positionY)}';
        filters.add(
          '[$prepared]pad=${job.width}:${job.height}:x=$padX:y=$padY:'
          'color=black@0[$padded]',
        );
        filters.add(
          '[$composite][$padded]blend=all_mode=$blend:'
          'all_opacity=${_n(transform.opacity)}:enable=\'$enable\'[$next]',
        );
      }
      composite = next;
    }
    for (var index = 0; index < job.textOverlays.length; index++) {
      if (titlesStreamed) break;
      final overlay = job.textOverlays[index];
      if (!overlay.visible || overlay.text.trim().isEmpty) continue;
      final next = 'text${index + 1}';
      final start = overlay.timelineStart.clamp(0, duration).toDouble();
      final end = overlay.timelineEnd > start
          ? overlay.timelineEnd.clamp(start, duration).toDouble()
          : duration;
      final raster = textRasterPaths[index];
      if (raster != null) {
        final input = inputIndex++;
        args.addAll(
            ['-loop', '1', '-framerate', _n(job.frameRate), '-i', raster]);
        filters.add('[$composite][$input:v]overlay=x=0:y=0:'
            "enable='gte(t,${_n(start)})*lt(t,${_n(end)})':"
            'eof_action=pass:shortest=0:format=auto[$next]');
        composite = next;
        continue;
      }
      filters.add(
        '[$composite]${_textFilter(overlay, start, end, job.height.toDouble())}[$next]',
      );
      composite = next;
    }
    if (captionStreamUrl != null) {
      final input = inputIndex++;
      args.addAll([
        '-f',
        'rawvideo',
        '-pixel_format',
        'rgba',
        '-video_size',
        '${job.width}x${job.height}',
        '-framerate',
        _n(job.frameRate),
        '-i',
        captionStreamUrl
      ]);
      const next = 'captionStream';
      filters.add(
          '[$composite][$input:v]overlay=x=0:y=0:eof_action=pass:shortest=0:format=auto[$next]');
      composite = next;
    }
    for (final entry in captionRasterPaths.entries) {
      final cue = job.captionSettings!.captionCues[entry.key];
      final input = inputIndex++;
      args.addAll(
          ['-loop', '1', '-framerate', _n(job.frameRate), '-i', entry.value]);
      final next = 'captionRaster${entry.key}';
      filters.add('[$composite][$input:v]overlay=x=0:y=0:'
          "enable='gte(t,${_n(cue.start)})*lt(t,${_n(cue.end)})':"
          'eof_action=pass:shortest=0:format=auto[$next]');
      composite = next;
    }
    if (captionAssPath != null && captionAssPath.trim().isNotEmpty) {
      const next = 'captioned';
      filters.add(
        '[$composite]${_assSubtitleFilter(captionAssPath)}[$next]',
      );
      composite = next;
    }
    filters.add(
      '[$composite]trim=duration=${_n(duration)},setsar=1,format=yuv420p[outv]',
    );

    final audioLabels = <String>[];
    for (var index = 0; index < audioLayers.length; index++) {
      final layer = audioLayers[index];
      final clip = layer.clip;
      final input = audioInputs[clip.id]!;
      final speed = _playbackSpeed(job, clip);
      final sourceDuration = _sourceDuration(job, clip);
      final label = 'audio$index';
      final delay = (clip.timelineStart * 1000).round();
      final incomingFade = clip.transitionIn == null
          ? ''
          : ',afade=t=in:st=0:d=${_n(clip.transitionIn!.duration)}';
      final outgoing = outgoingAudioTransitions[clip.id];
      final outgoingFade = outgoing == null
          ? ''
          : ',afade=t=out:st=${_n(math.max(0, clip.duration - outgoing.duration))}:'
              'd=${_n(outgoing.duration)}';
      filters.add(
        '[$input:a]atrim=start=0:'
        'duration=${_n(sourceDuration)},asetpts=PTS-STARTPTS,'
        '${_tempoFilter(speed)},atrim=duration=${_n(clip.duration)},'
        'volume=${_n(clip.volume)}$incomingFade$outgoingFade,'
        // adelay may emit leading silence with AV_NOPTS_VALUE when every
        // mixer input starts after zero (observed with FFmpeg 8.1.2). Those
        // samples already encode placement; timestamp them from the sample
        // clock before amix/atrim so the entire mix is not truncated.
        'adelay=$delay|$delay,asetpts=N/SR/TB[$label]',
      );
      audioLabels.add(label);
    }
    if (audioLabels.isNotEmpty) {
      filters.add(
        '${audioLabels.map((label) => '[$label]').join()}'
        'amix=inputs=${audioLabels.length}:normalize=0:dropout_transition=0,'
        // Audio must span the captured canvas, including trailing silence.
        'apad=whole_dur=${_n(duration)},'
        'atrim=duration=${_n(duration)}[outa]',
      );
    }

    final graph = filters.join(';');
    args.addAll([
      '-filter_complex',
      graph,
      '-map',
      '[outv]',
      if (audioLabels.isNotEmpty) ...['-map', '[outa]'],
      ..._videoEncoderArguments(encoder, job.videoBitrateKbps),
      '-r',
      _n(job.frameRate),
      '-pix_fmt',
      'yuv420p',
      if (audioLabels.isNotEmpty) ...[
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-ac',
        '2',
      ] else
        '-an',
      '-t',
      _n(duration),
      '-movflags',
      '+faststart',
      job.outputPath,
    ]);
    return MultiTrackFilterPlan(
      arguments: args,
      filterGraph: graph,
      duration: duration,
      videoInputCount: videoLayers.length,
      audioInputCount: audioLayers.length,
      filterCount: filters.length,
    );
  }

  MultiTrackFilterPlan? _buildSequentialPlan(
    MultiTrackExportJob job, {
    required String encoder,
    required List<({TrackModel track, ClipModel clip})> videoLayers,
    required List<({TrackModel track, ClipModel clip})> audioLayers,
    required String? captionAssPath,
    required bool hardwareDecoding,
  }) {
    if (videoLayers.isEmpty ||
        videoLayers.map((layer) => layer.track.id).toSet().length != 1) {
      return null;
    }
    final clips = [
      for (final layer in videoLayers) layer.clip
    ]..sort((left, right) => left.timelineStart.compareTo(right.timelineStart));
    var cursor = 0.0;
    for (final clip in clips) {
      final transform = clip.transform;
      // This is only an optimization. Any gap/overlap, however small, must
      // retain its timeline placement through the general composition path.
      if (clip.timelineStart != cursor ||
          clip.transitionIn != null ||
          clip.effects.isNotEmpty ||
          clip.keyframes.isNotEmpty ||
          transform.rotationDegrees != 0 ||
          transform.opacity != 1 ||
          transform.blendMode.toLowerCase() != 'normal' ||
          !const {'none', 'blur'}.contains(transform.canvasMode)) {
        return null;
      }
      cursor = clip.timelineEnd;
    }
    if (cursor != job.timeline.duration) return null;

    final matchingAudio = <ClipModel?>[];
    final unusedAudio = <ClipModel>{
      for (final layer in audioLayers) layer.clip
    };
    for (final clip in clips) {
      ClipModel? match;
      for (final audio in unusedAudio) {
        if (audio.mediaPath == clip.mediaPath &&
            audio.timelineStart == clip.timelineStart &&
            audio.sourceStart == clip.sourceStart &&
            audio.duration == clip.duration) {
          match = audio;
          break;
        }
      }
      matchingAudio.add(match);
      if (match != null) unusedAudio.remove(match);
    }
    if (unusedAudio.isNotEmpty ||
        (matchingAudio.any((audio) => audio != null) &&
            matchingAudio.any((audio) => audio == null))) {
      return null;
    }
    final includeAudio =
        matchingAudio.isNotEmpty && matchingAudio.first != null;
    final args = <String>['-y'];
    for (final clip in clips) {
      final sourceDuration = _sourceDuration(job, clip);
      if (hardwareDecoding) args.addAll(['-hwaccel', 'auto']);
      args.addAll([
        '-ss',
        _n(clip.sourceStart),
        '-t',
        _n(sourceDuration),
        '-i',
        clip.mediaPath,
      ]);
    }

    final filters = <String>[];
    final videoLabels = <String>[];
    final audioLabels = <String>[];
    for (var index = 0; index < clips.length; index++) {
      final clip = clips[index];
      final transform = clip.transform;
      final speed = _playbackSpeed(job, clip);
      final sourceDuration = _sourceDuration(job, clip);
      final output = 'seqVideo$index';
      final foregroundScale = _foregroundScaleFilter(job, clip);
      final overlayX = VideoGeometry.offsetExpression(
          'W', 'w', _n(transform.positionX.clamp(0, 1)));
      final overlayY = VideoGeometry.offsetExpression(
          'H', 'h', _n(transform.positionY.clamp(0, 1)));
      final flip = _flipFilters(transform.flip);
      if (transform.canvasMode == 'blur') {
        final foreground = 'seqForeground$index';
        final background = 'seqBackground$index';
        filters.add(
          '[$index:v]trim=duration=${_n(sourceDuration)},'
          'setpts=(PTS-STARTPTS)/${_n(speed)},'
          'fps=${_n(job.frameRate)}$flip,trim=duration=${_n(clip.duration)},'
          'split=2[$foreground][$background]',
        );
        filters.add(
          '[$background]scale=${_blurWidth(job)}:${_blurHeight(job)}:'
          'force_original_aspect_ratio=increase,'
          'crop=${_blurWidth(job)}:${_blurHeight(job)},'
          'gblur=sigma=${_n((transform.canvasBlur * 0.5).clamp(3, 24))}:steps=1,'
          'scale=${job.width}:${job.height},setsar=1[seqBlur$index]',
        );
        filters.add(
          '[$foreground]$foregroundScale[seqScaled$index]',
        );
        filters.add(
          '[seqBlur$index][seqScaled$index]overlay='
          'x=$overlayX:y=$overlayY:'
          'shortest=1:eof_action=endall,setsar=1,format=yuv420p[$output]',
        );
      } else {
        filters.add(
          'color=c=black:s=${job.width}x${job.height}:'
          'r=${_n(job.frameRate)}:d=${_n(clip.duration)}[seqCanvas$index]',
        );
        filters.add(
          '[$index:v]trim=duration=${_n(sourceDuration)},'
          'setpts=(PTS-STARTPTS)/${_n(speed)},'
          'fps=${_n(job.frameRate)}$flip,trim=duration=${_n(clip.duration)},'
          '$foregroundScale[seqScaled$index]',
        );
        filters.add(
          '[seqCanvas$index][seqScaled$index]overlay='
          'x=$overlayX:y=$overlayY:'
          'shortest=1:eof_action=endall,setsar=1,'
          'format=yuv420p[$output]',
        );
      }
      videoLabels.add(output);
      if (includeAudio) {
        final audio = matchingAudio[index]!;
        final audioSpeed = _playbackSpeed(job, audio);
        final audioSourceDuration = _sourceDuration(job, audio);
        final audioOutput = 'seqAudio$index';
        filters.add(
          '[$index:a]atrim=duration=${_n(audioSourceDuration)},'
          'asetpts=PTS-STARTPTS,${_tempoFilter(audioSpeed)},'
          // A finite WSOLA input can end short. Keep its declared slot before
          // concat so the next clip is not advanced by the missing tail. This
          // restores placement, not lost source sound; no repeat/extra media.
          'apad=whole_dur=${_n(audio.duration)},'
          'atrim=duration=${_n(audio.duration)},asetpts=N/SR/TB,'
          'volume=${_n(audio.volume)}[$audioOutput]',
        );
        audioLabels.add(audioOutput);
      }
    }
    const concatVideo = 'seqVideo';
    filters.add(
      '${videoLabels.map((label) => '[$label]').join()}'
      'concat=n=${videoLabels.length}:v=1:a=0[$concatVideo]',
    );
    var composite = concatVideo;
    for (var index = 0; index < job.textOverlays.length; index++) {
      final overlay = job.textOverlays[index];
      if (!overlay.visible || overlay.text.trim().isEmpty) continue;
      final next = 'seqText$index';
      final start = overlay.timelineStart.clamp(0, job.timeline.duration);
      final end = overlay.timelineEnd > start
          ? overlay.timelineEnd.clamp(start, job.timeline.duration)
          : job.timeline.duration;
      filters.add(
        '[$composite]${_textFilter(overlay, start.toDouble(), end.toDouble(), job.height.toDouble())}[$next]',
      );
      composite = next;
    }
    if (captionAssPath != null && captionAssPath.trim().isNotEmpty) {
      filters
          .add('[$composite]${_assSubtitleFilter(captionAssPath)}[seqCaption]');
      composite = 'seqCaption';
    }
    filters.add(
      '[$composite]trim=duration=${_n(job.timeline.duration)},'
      'setsar=1,format=yuv420p[outv]',
    );
    if (includeAudio) {
      filters.add(
        '${audioLabels.map((label) => '[$label]').join()}'
        'concat=n=${audioLabels.length}:v=0:a=1,'
        'atrim=duration=${_n(job.timeline.duration)}[outa]',
      );
    }
    final graph = filters.join(';');
    args.addAll([
      '-filter_complex',
      graph,
      '-map',
      '[outv]',
      if (includeAudio) ...['-map', '[outa]'],
      ..._videoEncoderArguments(encoder, job.videoBitrateKbps),
      '-r',
      _n(job.frameRate),
      '-pix_fmt',
      'yuv420p',
      if (includeAudio) ...[
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-ac',
        '2',
      ] else
        '-an',
      '-t',
      _n(job.timeline.duration),
      '-movflags',
      '+faststart',
      job.outputPath,
    ]);
    return MultiTrackFilterPlan(
      arguments: args,
      filterGraph: graph,
      duration: job.timeline.duration,
      videoInputCount: clips.length,
      audioInputCount: includeAudio ? clips.length : 0,
      filterCount: filters.length,
    );
  }

  int _blurWidth(MultiTrackExportJob job) {
    if (job.width >= job.height) return 480;
    return math.max(2, ((480 * job.width / job.height) / 2).round() * 2);
  }

  String _textFilter(TextOverlaySettings overlay, double start, double end,
      double canvasHeight) {
    final scale = TextGeometry.scale(canvasHeight);
    final enable = 'gte(t\\,${_n(start)})*lt(t\\,${_n(end)})';
    final x = '(w-text_w)*${_n(overlay.x.clamp(0, 1))}';
    final y = '(h-text_h)*${_n(overlay.y.clamp(0, 1))}';
    final shadow = overlay.shadow
        ? ':shadowx=${_n(3 * scale)}:shadowy=${_n(3 * scale)}:shadowcolor=${_color(overlay.shadowColor)}@${_n(overlay.shadowOpacity.clamp(0, 1))}'
        : '';
    return 'drawtext=text=\'${_text(overlay.text)}\':'
        'font=\'${_text(overlay.font)}\':fontsize=${_n(TextGeometry.fontSize(overlay.size, canvasHeight))}:'
        'fontcolor=${_color(overlay.color)}@${_n(overlay.opacity.clamp(0, 1))}:'
        'borderw=${_n(overlay.stroke.clamp(0, 20) * scale)}:'
        'bordercolor=${_color(overlay.strokeColor)}@${_n(overlay.strokeOpacity.clamp(0, 1))}'
        '$shadow:x=\'$x\':y=\'$y\':enable=\'$enable\'';
  }

  int _blurHeight(MultiTrackExportJob job) {
    if (job.height >= job.width) return 480;
    return math.max(2, ((480 * job.height / job.width) / 2).round() * 2);
  }

  String _foregroundScaleFilter(
    MultiTrackExportJob job,
    ClipModel clip,
  ) {
    final transform = clip.transform;
    if (clip.keyframes.isNotEmpty) {
      final x = _keyframeExpression(clip, (value) => value.scaleX);
      final y = _keyframeExpression(clip, (value) => value.scaleY);
      return 'scale=${job.width}:${job.height}:'
          'force_original_aspect_ratio=decrease:force_divisible_by=2:reset_sar=1,'
          "scale=w='max(2,trunc(iw*($x)/2)*2)':h='max(2,trunc(ih*($y)/2)*2)':eval=frame:reset_sar=1";
    }
    // Match _videoTransformRect in Program Monitor exactly: first contain the
    // source in the output frame, then apply independent X/Y scaling. Scaling
    // directly into a composition-relative box loses Scale Y whenever Scale X
    // becomes the aspect-ratio constraint (and vice versa).
    return 'scale=${job.width}:${job.height}:'
        'force_original_aspect_ratio=decrease:force_divisible_by=2:'
        'reset_sar=1,'
        'scale=trunc(iw*${_n(transform.scaleX)}/2)*2:'
        'trunc(ih*${_n(transform.scaleY)}/2)*2:reset_sar=1';
  }

  String _flipFilters(String flip) => switch (flip.toLowerCase()) {
        'left' || 'right' => ',hflip',
        'up' => ',hflip,vflip',
        'down' => ',vflip',
        _ => '',
      };

  double _playbackSpeed(MultiTrackExportJob job, ClipModel clip) {
    final requested = clip.resolvedPlaybackSpeed(
        job.playbackSpeedsByMediaPath[clip.mediaPath] ?? 1);
    if (!requested.isFinite) return 1;
    return requested.clamp(0.25, 4).toDouble();
  }

  double _sourceDuration(MultiTrackExportJob job, ClipModel clip) =>
      clip.duration * _playbackSpeed(job, clip);

  String _assSubtitleFilter(String path) {
    final escaped = path
        .replaceAll(r'\', '/')
        .replaceAll(':', r'\:')
        .replaceAll("'", r"\'")
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]');
    return "ass=filename='$escaped'";
  }

  List<String> _videoEncoderArguments(String encoder, int bitrateKbps) {
    final bitrate = '${bitrateKbps}k';
    final maxrate = '${(bitrateKbps * 1.5).round()}k';
    final buffer = '${bitrateKbps * 2}k';
    return switch (encoder) {
      'h264_nvenc' || 'hevc_nvenc' => [
          '-c:v',
          encoder,
          '-preset',
          'p1',
          '-tune',
          'll',
          '-rc',
          'vbr',
          '-b:v',
          bitrate,
          '-maxrate',
          maxrate,
          '-bufsize',
          buffer,
        ],
      'h264_qsv' || 'hevc_qsv' => [
          '-c:v',
          encoder,
          '-preset',
          'veryfast',
          '-b:v',
          bitrate,
          '-maxrate',
          maxrate,
          '-bufsize',
          buffer,
        ],
      'h264_amf' || 'hevc_amf' => [
          '-c:v',
          encoder,
          '-quality',
          'speed',
          '-b:v',
          bitrate,
          '-maxrate',
          maxrate,
          '-bufsize',
          buffer,
        ],
      'h264_videotoolbox' || 'hevc_videotoolbox' => [
          '-c:v',
          encoder,
          '-b:v',
          bitrate,
          '-maxrate',
          maxrate,
          '-bufsize',
          buffer,
        ],
      _ => [
          '-c:v',
          encoder,
          '-preset',
          'ultrafast',
          '-threads',
          '4',
          '-b:v',
          bitrate,
          '-maxrate',
          maxrate,
          '-bufsize',
          buffer,
        ],
    };
  }

  String _canvasPatternFilter(String pattern, String enable) {
    return switch (pattern) {
      'stripes' =>
        ',drawgrid=w=240:h=48:t=18:c=black@0.24:replace=0:enable=\'$enable\'',
      'checker' =>
        ',drawgrid=w=96:h=96:t=44:c=black@0.22:replace=0:enable=\'$enable\'',
      'dots' =>
        ',drawgrid=w=72:h=72:t=5:c=white@0.55:replace=0:enable=\'$enable\'',
      _ => ',drawgrid=w=84:h=84:t=3:c=black@0.32:replace=0:enable=\'$enable\'',
    };
  }

  String? _ffmpegBlendMode(String value) {
    return switch (value.toLowerCase()) {
      'multiply' => 'multiply',
      'screen' => 'screen',
      'overlay' => 'overlay',
      'darken' => 'darken',
      'lighten' => 'lighten',
      'difference' => 'difference',
      'addition' || 'add' => 'addition',
      _ => null,
    };
  }

  Map<String, ClipTransition> _outgoingTransitions(
    List<TrackModel> tracks,
  ) {
    final result = <String, ClipTransition>{};
    for (final track in tracks) {
      final clips = [...track.clips]
        ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
      for (var index = 1; index < clips.length; index++) {
        final transition = clips[index].transitionIn;
        if (transition != null &&
            TransitionBoundary.joins(clips[index - 1], clips[index])) {
          result[clips[index - 1].id] = transition;
        }
      }
    }
    return result;
  }

  String _clipEffectFilters(List<ClipEffect> effects) {
    final result = StringBuffer();
    for (final effect in effects.where((item) => item.enabled)) {
      final supportsSignedAmount = {
        ClipEffectType.temperature,
        ClipEffectType.tint,
        ClipEffectType.exposure,
        ClipEffectType.brightness,
        ClipEffectType.contrast,
        ClipEffectType.highlights,
        ClipEffectType.shadows,
        ClipEffectType.whites,
        ClipEffectType.blacks,
        ClipEffectType.brilliance,
        ClipEffectType.saturation,
        ClipEffectType.gamma,
      }.contains(effect.type);
      final amount =
          effect.amount.clamp(supportsSignedAmount ? -1 : 0, 3).toDouble();
      switch (effect.type) {
        case ClipEffectType.temperature:
          result.write(
            ',colorbalance=rs=${_n(amount * 0.16)}:bs=${_n(-amount * 0.16)}',
          );
        case ClipEffectType.tint:
          result.write(
            ',colorbalance=gs=${_n(-amount * 0.13)}:rm=${_n(amount * 0.05)}:bm=${_n(amount * 0.05)}',
          );
        case ClipEffectType.exposure:
          result.write(',eq=brightness=${_n(amount * 0.28)}');
        case ClipEffectType.brightness:
          result.write(',eq=brightness=${_n(amount * 0.25)}');
        case ClipEffectType.contrast:
          result.write(',eq=contrast=${_n(1 + amount * 0.5)}');
        case ClipEffectType.highlights:
          result.write(',eq=gamma=${_n((1 - amount * 0.2).clamp(0.45, 2))}');
        case ClipEffectType.shadows:
          result.write(',eq=gamma=${_n((1 + amount * 0.24).clamp(0.45, 2))}');
        case ClipEffectType.whites:
          result.write(',eq=brightness=${_n(amount * 0.12)}');
        case ClipEffectType.blacks:
          result.write(',eq=contrast=${_n(1 + amount * 0.22)}');
        case ClipEffectType.brilliance:
          result.write(
            ',eq=brightness=${_n(amount * 0.08)}:contrast=${_n(1 + amount * 0.18)}:saturation=${_n(1 + amount * 0.12)}',
          );
        case ClipEffectType.saturation:
          result.write(',eq=saturation=${_n(1 + amount * 0.75)}');
        case ClipEffectType.gamma:
          result.write(',eq=gamma=${_n(1 + amount * 0.35)}');
        case ClipEffectType.clarity:
          result.write(',unsharp=5:5:${_n(amount * 0.75)}:5:5:0');
        case ClipEffectType.fade:
          result.write(
            ',eq=contrast=${_n((1 - amount * 0.28).clamp(0.25, 1))}:brightness=${_n(amount * 0.06)}',
          );
        case ClipEffectType.grayscale:
          result.write(',hue=s=0');
        case ClipEffectType.sepia:
          result.write(
            ',colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131',
          );
        case ClipEffectType.blur:
          result.write(',gblur=sigma=${_n(amount * 6)}');
        case ClipEffectType.sharpen:
          result.write(',unsharp=5:5:${_n(amount * 1.2)}:5:5:0');
        case ClipEffectType.vignette:
          result.write(',vignette=PI/${_n(12 - amount * 2)}');
        case ClipEffectType.invert:
          result.write(',${EffectRenderState.invertFilter}');
        case ClipEffectType.glitch:
          result
              .write(',rgbashift=rh=${_n(amount * 10)}:bh=${_n(-amount * 10)}');
        case ClipEffectType.hueRotate:
          result.write(',hue=h=${_n(amount * 120)}');
      }
    }
    return result.toString();
  }

  String _keyframeExpression(
    ClipModel clip,
    double Function(ClipTransform transform) value, {
    double timelineOffset = 0,
    String clock = 't',
  }) {
    if (clip.keyframes.isEmpty) return _n(value(clip.transform));
    return KeyframeCurve.ffmpeg([
      for (final frame in clip.keyframes)
        (time: frame.offset, value: value(frame.transform))
    ], timelineOffset: timelineOffset, clock: clock);
  }

  // atempo is not sample-transparent even at 1x: its finite-input tail can
  // lose samples and turn a split/adjacent boundary into audible silence.
  // Preserve unchanged-speed PCM in both layered and sequential exports.
  String _tempoFilter(double speed) =>
      speed == 1 ? 'anull' : 'atempo=${_n(speed)}';

  String _n(num value) => value.toStringAsFixed(6).replaceFirst(
        RegExp(r'\.?0+$'),
        '',
      );

  String _color(String value) {
    final clean = value.trim().replaceFirst('#', '');
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)
        ? '0x${clean.toUpperCase()}'
        : 'white';
  }

  String _text(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(':', r'\:')
      .replaceAll('%', r'\%')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n');
}
