import 'dart:math' as math;

enum TrackType { video, audio, text }

enum ClipEffectType {
  temperature,
  tint,
  exposure,
  brightness,
  contrast,
  highlights,
  shadows,
  whites,
  blacks,
  brilliance,
  saturation,
  gamma,
  clarity,
  fade,
  grayscale,
  sepia,
  blur,
  sharpen,
  vignette,
  invert,
  glitch,
  hueRotate,
}

extension ClipEffectTypeLabel on ClipEffectType {
  String get label => switch (this) {
        ClipEffectType.temperature => 'Temperature',
        ClipEffectType.tint => 'Tint',
        ClipEffectType.exposure => 'Exposure',
        ClipEffectType.brightness => 'Brightness',
        ClipEffectType.contrast => 'Contrast',
        ClipEffectType.highlights => 'Highlights',
        ClipEffectType.shadows => 'Shadows',
        ClipEffectType.whites => 'Whites',
        ClipEffectType.blacks => 'Blacks',
        ClipEffectType.brilliance => 'Brilliance',
        ClipEffectType.saturation => 'Saturation',
        ClipEffectType.gamma => 'Gamma',
        ClipEffectType.clarity => 'Clarity',
        ClipEffectType.fade => 'Fade',
        ClipEffectType.grayscale => 'Black & White',
        ClipEffectType.sepia => 'Sepia',
        ClipEffectType.blur => 'Gaussian Blur',
        ClipEffectType.sharpen => 'Sharpen',
        ClipEffectType.vignette => 'Vignette',
        ClipEffectType.invert => 'Invert Colors',
        ClipEffectType.glitch => 'RGB Glitch',
        ClipEffectType.hueRotate => 'Hue Rotate',
      };
}

class ClipEffect {
  const ClipEffect({
    required this.id,
    required this.type,
    this.amount = 1,
    this.enabled = true,
  });

  final String id;
  final ClipEffectType type;
  final double amount;
  final bool enabled;

  ClipEffect copyWith({double? amount, bool? enabled}) => ClipEffect(
        id: id,
        type: type,
        amount: amount ?? this.amount,
        enabled: enabled ?? this.enabled,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'enabled': enabled,
      };

  factory ClipEffect.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    final name = '${json['type'] ?? ''}';
    return ClipEffect(
      id: '${json['id'] ?? 'effect-$name'}',
      type: ClipEffectType.values.firstWhere(
        (item) => item.name == name,
        orElse: () => ClipEffectType.brightness,
      ),
      amount: (double.tryParse('${json['amount'] ?? 1}') ?? 1)
          .clamp(-1, 3)
          .toDouble(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

enum ClipTransitionType {
  dissolve,
  fadeBlack,
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
}

extension ClipTransitionTypeLabel on ClipTransitionType {
  String get label => switch (this) {
        ClipTransitionType.dissolve => 'Cross Dissolve',
        ClipTransitionType.fadeBlack => 'Fade Through Black',
        ClipTransitionType.slideLeft => 'Slide Left',
        ClipTransitionType.slideRight => 'Slide Right',
        ClipTransitionType.slideUp => 'Slide Up',
        ClipTransitionType.slideDown => 'Slide Down',
      };
}

class ClipTransition {
  const ClipTransition({required this.type, this.duration = 0.5});

  final ClipTransitionType type;
  final double duration;

  Map<String, Object?> toJson() => {
        'type': type.name,
        'duration': duration,
      };

  factory ClipTransition.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    final name = '${json['type'] ?? ''}';
    return ClipTransition(
      type: ClipTransitionType.values.firstWhere(
        (item) => item.name == name,
        orElse: () => ClipTransitionType.dissolve,
      ),
      duration: (double.tryParse('${json['duration'] ?? 0.5}') ?? 0.5)
          .clamp(0.05, 5)
          .toDouble(),
    );
  }
}

class ClipTransform {
  const ClipTransform({
    this.opacity = 1,
    this.scaleX = 1,
    this.scaleY = 1,
    this.positionX = 0.5,
    this.positionY = 0.5,
    this.rotationDegrees = 0,
    this.blendMode = 'normal',
    this.canvasMode = 'none',
    this.canvasColor = '#F4C70F',
    this.canvasPattern = 'grid',
    this.canvasBlur = 24,
  });

  final double opacity;
  final double scaleX;
  final double scaleY;
  final double positionX;
  final double positionY;
  final double rotationDegrees;
  final String blendMode;
  final String canvasMode;
  final String canvasColor;
  final String canvasPattern;
  final double canvasBlur;

  ClipTransform copyWith({
    double? opacity,
    double? scaleX,
    double? scaleY,
    double? positionX,
    double? positionY,
    double? rotationDegrees,
    String? blendMode,
    String? canvasMode,
    String? canvasColor,
    String? canvasPattern,
    double? canvasBlur,
  }) {
    return ClipTransform(
      opacity: opacity ?? this.opacity,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      blendMode: blendMode ?? this.blendMode,
      canvasMode: canvasMode ?? this.canvasMode,
      canvasColor: canvasColor ?? this.canvasColor,
      canvasPattern: canvasPattern ?? this.canvasPattern,
      canvasBlur: canvasBlur ?? this.canvasBlur,
    );
  }

  Map<String, Object?> toJson() => {
        'opacity': opacity,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'positionX': positionX,
        'positionY': positionY,
        'rotationDegrees': rotationDegrees,
        'blendMode': blendMode,
        'canvasMode': canvasMode,
        'canvasColor': canvasColor,
        'canvasPattern': canvasPattern,
        'canvasBlur': canvasBlur,
      };

  factory ClipTransform.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    double number(String key, double fallback) =>
        double.tryParse('${json[key] ?? fallback}') ?? fallback;
    const canvasModes = {'none', 'blur', 'color', 'pattern'};
    const canvasPatterns = {'grid', 'stripes', 'checker', 'dots'};
    final rawCanvasMode = '${json['canvasMode'] ?? 'none'}'.toLowerCase();
    final rawCanvasPattern = '${json['canvasPattern'] ?? 'grid'}'.toLowerCase();
    final rawCanvasColor = '${json['canvasColor'] ?? '#F4C70F'}'.toUpperCase();
    final validCanvasColor = RegExp(r'^#[0-9A-F]{6}$').hasMatch(rawCanvasColor)
        ? rawCanvasColor
        : '#F4C70F';
    return ClipTransform(
      opacity: number('opacity', 1).clamp(0, 1).toDouble(),
      scaleX: number('scaleX', 1).clamp(0.01, 20).toDouble(),
      scaleY: number('scaleY', 1).clamp(0.01, 20).toDouble(),
      positionX: number('positionX', 0.5).clamp(0, 1).toDouble(),
      positionY: number('positionY', 0.5).clamp(0, 1).toDouble(),
      rotationDegrees: number('rotationDegrees', 0),
      blendMode: '${json['blendMode'] ?? 'normal'}',
      canvasMode: canvasModes.contains(rawCanvasMode) ? rawCanvasMode : 'none',
      canvasColor: validCanvasColor,
      canvasPattern:
          canvasPatterns.contains(rawCanvasPattern) ? rawCanvasPattern : 'grid',
      canvasBlur: number('canvasBlur', 24).clamp(4, 80).toDouble(),
    );
  }
}

class ClipKeyframe {
  const ClipKeyframe({required this.offset, required this.transform});

  final double offset;
  final ClipTransform transform;

  Map<String, Object?> toJson() => {
        'offset': offset,
        'transform': transform.toJson(),
      };

  factory ClipKeyframe.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return ClipKeyframe(
      offset: math
          .max(
            0,
            double.tryParse('${json['offset'] ?? 0}') ?? 0,
          )
          .toDouble(),
      transform: ClipTransform.fromJson(json['transform']),
    );
  }
}

class ClipModel {
  const ClipModel({
    required this.id,
    required this.mediaPath,
    required this.timelineStart,
    required this.duration,
    required this.sourceStart,
    required this.zIndex,
    this.transform = const ClipTransform(),
    this.volume = 1,
    this.isMuted = false,
    this.isLinkedAudio = false,
    this.linkedClipId,
    this.replacesClipId,
    this.effects = const [],
    this.transitionIn,
    this.keyframes = const [],
  });

  final String id;
  final String mediaPath;
  final double timelineStart;
  final double duration;
  final double sourceStart;
  final int zIndex;
  final ClipTransform transform;
  final double volume;
  final bool isMuted;

  /// Linked source audio is rendered inside its video clip in the timeline.
  /// Extract Audio clears this link and turns the audio into an independent
  /// clip that can be moved, split, trimmed, locked, or deleted separately.
  final bool isLinkedAudio;
  final String? linkedClipId;

  /// The original V1/A1 clip replaced by this clip after it was split on a
  /// higher track. Keeping this lineage prevents legacy edit synchronization
  /// from recreating the original clip underneath the edited pieces.
  final String? replacesClipId;
  final List<ClipEffect> effects;
  final ClipTransition? transitionIn;
  final List<ClipKeyframe> keyframes;

  double get timelineEnd => timelineStart + duration;
  double get sourceEnd => sourceStart + duration;

  bool get hasProfessionalEdits =>
      effects.any((effect) => effect.enabled) ||
      transitionIn != null ||
      keyframes.isNotEmpty;

  ClipTransform transformAt(double offset) {
    if (keyframes.isEmpty) return transform;
    final ordered = [...keyframes]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    if (offset <= ordered.first.offset) return ordered.first.transform;
    if (offset >= ordered.last.offset) return ordered.last.transform;
    for (var index = 1; index < ordered.length; index++) {
      final right = ordered[index];
      final left = ordered[index - 1];
      if (offset > right.offset) continue;
      final span = math.max(0.001, right.offset - left.offset);
      final t = ((offset - left.offset) / span).clamp(0, 1).toDouble();
      return ClipTransform(
        opacity: _lerp(left.transform.opacity, right.transform.opacity, t),
        scaleX: _lerp(left.transform.scaleX, right.transform.scaleX, t),
        scaleY: _lerp(left.transform.scaleY, right.transform.scaleY, t),
        positionX:
            _lerp(left.transform.positionX, right.transform.positionX, t),
        positionY:
            _lerp(left.transform.positionY, right.transform.positionY, t),
        rotationDegrees: _lerp(
          left.transform.rotationDegrees,
          right.transform.rotationDegrees,
          t,
        ),
        blendMode:
            t < 0.5 ? left.transform.blendMode : right.transform.blendMode,
        canvasMode:
            t < 0.5 ? left.transform.canvasMode : right.transform.canvasMode,
        canvasColor:
            t < 0.5 ? left.transform.canvasColor : right.transform.canvasColor,
        canvasPattern: t < 0.5
            ? left.transform.canvasPattern
            : right.transform.canvasPattern,
        canvasBlur:
            _lerp(left.transform.canvasBlur, right.transform.canvasBlur, t),
      );
    }
    return transform;
  }

  ClipModel copyWith({
    String? id,
    String? mediaPath,
    double? timelineStart,
    double? duration,
    double? sourceStart,
    int? zIndex,
    ClipTransform? transform,
    double? volume,
    bool? isMuted,
    bool? isLinkedAudio,
    String? linkedClipId,
    bool clearLinkedClipId = false,
    String? replacesClipId,
    bool clearReplacesClipId = false,
    List<ClipEffect>? effects,
    ClipTransition? transitionIn,
    bool clearTransitionIn = false,
    List<ClipKeyframe>? keyframes,
  }) {
    return ClipModel(
      id: id ?? this.id,
      mediaPath: mediaPath ?? this.mediaPath,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      sourceStart: sourceStart ?? this.sourceStart,
      zIndex: zIndex ?? this.zIndex,
      transform: transform ?? this.transform,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isLinkedAudio: isLinkedAudio ?? this.isLinkedAudio,
      linkedClipId:
          clearLinkedClipId ? null : (linkedClipId ?? this.linkedClipId),
      replacesClipId:
          clearReplacesClipId ? null : (replacesClipId ?? this.replacesClipId),
      effects: effects ?? this.effects,
      transitionIn:
          clearTransitionIn ? null : (transitionIn ?? this.transitionIn),
      keyframes: keyframes ?? this.keyframes,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'mediaPath': mediaPath,
        'timelineStart': timelineStart,
        'duration': duration,
        'sourceStart': sourceStart,
        'zIndex': zIndex,
        'transform': transform.toJson(),
        'volume': volume,
        'isMuted': isMuted,
        'isLinkedAudio': isLinkedAudio,
        if (linkedClipId != null) 'linkedClipId': linkedClipId,
        if (replacesClipId != null) 'replacesClipId': replacesClipId,
        'effects': [for (final effect in effects) effect.toJson()],
        if (transitionIn != null) 'transitionIn': transitionIn!.toJson(),
        'keyframes': [for (final keyframe in keyframes) keyframe.toJson()],
      };

  factory ClipModel.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    double number(String key, double fallback) =>
        double.tryParse('${json[key] ?? fallback}') ?? fallback;
    return ClipModel(
      id: '${json['id'] ?? ''}',
      mediaPath: '${json['mediaPath'] ?? ''}',
      timelineStart: math.max(0, number('timelineStart', 0)).toDouble(),
      duration: math.max(0.001, number('duration', 0.001)).toDouble(),
      sourceStart: math.max(0, number('sourceStart', 0)).toDouble(),
      zIndex: int.tryParse('${json['zIndex'] ?? 0}') ?? 0,
      transform: ClipTransform.fromJson(json['transform']),
      volume: number('volume', 1).clamp(0, 10).toDouble(),
      isMuted: json['isMuted'] as bool? ?? false,
      isLinkedAudio: json['isLinkedAudio'] as bool? ?? false,
      linkedClipId: '${json['linkedClipId'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['linkedClipId']}',
      replacesClipId: '${json['replacesClipId'] ?? ''}'.trim().isEmpty
          ? null
          : '${json['replacesClipId']}',
      effects: [
        for (final item in json['effects'] as List? ?? const [])
          ClipEffect.fromJson(item),
      ],
      transitionIn: json['transitionIn'] == null
          ? null
          : ClipTransition.fromJson(json['transitionIn']),
      keyframes: [
        for (final item in json['keyframes'] as List? ?? const [])
          ClipKeyframe.fromJson(item),
      ],
    );
  }
}

class TrackModel {
  const TrackModel({
    required this.id,
    required this.type,
    required this.index,
    this.isMuted = false,
    this.isLocked = false,
    this.clips = const [],
  });

  final String id;
  final TrackType type;
  final int index;
  final bool isMuted;
  final bool isLocked;
  final List<ClipModel> clips;

  String get label => '${switch (type) {
        TrackType.video => 'V',
        TrackType.audio => 'A',
        TrackType.text => 'T',
      }}$index';

  TrackModel copyWith({
    String? id,
    TrackType? type,
    int? index,
    bool? isMuted,
    bool? isLocked,
    List<ClipModel>? clips,
  }) {
    return TrackModel(
      id: id ?? this.id,
      type: type ?? this.type,
      index: index ?? this.index,
      isMuted: isMuted ?? this.isMuted,
      isLocked: isLocked ?? this.isLocked,
      clips: clips ?? this.clips,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'index': index,
        'isMuted': isMuted,
        'isLocked': isLocked,
        'clips': [for (final clip in clips) clip.toJson()],
      };

  factory TrackModel.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    final typeName = '${json['type'] ?? 'video'}';
    final type = TrackType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => TrackType.video,
    );
    final index = math.max(1, int.tryParse('${json['index'] ?? 1}') ?? 1);
    final clips = <ClipModel>[];
    for (final item in json['clips'] as List? ?? const []) {
      var clip = ClipModel.fromJson(item);
      final itemJson = item is Map ? item : const {};
      // Before linked-audio metadata existed, A1 held invisible mirror clips
      // named audio-<video id>. Preserve that behavior during project load.
      if (type == TrackType.audio &&
          index == 1 &&
          !itemJson.containsKey('isLinkedAudio') &&
          clip.id.startsWith('audio-')) {
        clip = clip.copyWith(
          isLinkedAudio: true,
          linkedClipId: clip.id.substring('audio-'.length),
        );
      }
      clips.add(clip);
    }
    return TrackModel(
      id: '${json['id'] ?? ''}',
      type: type,
      index: index,
      isMuted: json['isMuted'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      clips: clips,
    );
  }
}

class TimelineModel {
  const TimelineModel({required this.tracks, required this.duration});

  factory TimelineModel.empty() => const TimelineModel(
        tracks: [
          TrackModel(id: 'video-1', type: TrackType.video, index: 1),
          TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
        ],
        duration: 0,
      );

  final List<TrackModel> tracks;
  final double duration;

  List<TrackModel> get videoTracks => _tracksOf(TrackType.video);
  List<TrackModel> get audioTracks => _tracksOf(TrackType.audio);
  List<TrackModel> get textTracks => _tracksOf(TrackType.text);

  List<TrackModel> _tracksOf(TrackType type) {
    final result = tracks.where((track) => track.type == type).toList();
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  List<TrackModel> get displayTracks => [
        ...textTracks
            .where((track) => track.clips.isNotEmpty)
            .toList()
            .reversed,
        ...videoTracks.reversed,
        ...audioTracks.where(
          (track) =>
              track.index > 1 || track.clips.any((clip) => !clip.isLinkedAudio),
        ),
      ];

  ClipModel? linkedAudioForVideo(String videoClipId) {
    for (final track in audioTracks) {
      for (final clip in track.clips) {
        if (clip.isLinkedAudio && clip.linkedClipId == videoClipId) return clip;
        // Repair early multi-track projects that used the audio-<video-id>
        // naming convention before linkedClipId was persisted.
        if (clip.id == 'audio-$videoClipId' &&
            !clip.id.startsWith('extracted-audio-')) {
          return clip;
        }
      }
    }
    return null;
  }

  bool get hasLayeredVideo => videoTracks
      .where((track) => track.index > 1)
      .any((track) => track.clips.isNotEmpty);

  bool get hasMultiTrackContent =>
      hasLayeredVideo ||
      tracks.any(
        (track) => track.clips.any((clip) => clip.hasProfessionalEdits),
      ) ||
      audioTracks
          .where((track) => track.index > 1)
          .any((track) => track.clips.isNotEmpty);

  TrackModel? trackById(String id) {
    for (final track in tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  ({TrackModel track, ClipModel clip})? clipById(String id) {
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.id == id) return (track: track, clip: clip);
      }
    }
    return null;
  }

  List<ClipModel> activeClips(double playhead, TrackType type) {
    final active = <ClipModel>[];
    for (final track in tracks.where((track) => track.type == type)) {
      if (track.isMuted) continue;
      active.addAll(
        track.clips.where(
          (clip) =>
              !clip.isMuted &&
              playhead >= clip.timelineStart &&
              playhead < clip.timelineEnd,
        ),
      );
    }
    active.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return active;
  }

  TimelineModel copyWith({List<TrackModel>? tracks, double? duration}) {
    final nextTracks = tracks ?? this.tracks;
    return TimelineModel(
      tracks: nextTracks,
      duration: duration ?? calculateDuration(nextTracks),
    );
  }

  TimelineModel normalized() {
    final next = <TrackModel>[];
    for (final type in TrackType.values) {
      final typed = _tracksOf(type);
      for (var i = 0; i < typed.length; i++) {
        final track = typed[i];
        next.add(
          track.copyWith(
            id: '${type.name}-${i + 1}',
            index: i + 1,
            clips: [
              for (final clip in track.clips)
                clip.copyWith(zIndex: type == TrackType.video ? i : 0),
            ],
          ),
        );
      }
    }
    return TimelineModel(tracks: next, duration: calculateDuration(next));
  }

  static double calculateDuration(List<TrackModel> tracks) {
    var result = 0.0;
    for (final track in tracks) {
      for (final clip in track.clips) {
        result = math.max(result, clip.timelineEnd);
      }
    }
    return result;
  }

  Map<String, Object?> toJson() => {
        'duration': duration,
        'tracks': [for (final track in tracks) track.toJson()],
      };

  factory TimelineModel.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    final tracks = [
      for (final item in json['tracks'] as List? ?? const [])
        TrackModel.fromJson(item),
    ];
    if (!tracks.any((track) => track.type == TrackType.video)) {
      tracks.add(
        const TrackModel(id: 'video-1', type: TrackType.video, index: 1),
      );
    }
    if (!tracks.any((track) => track.type == TrackType.audio)) {
      tracks.add(
        const TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
      );
    }
    return TimelineModel(
      tracks: tracks,
      duration: calculateDuration(tracks),
    ).normalized();
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
