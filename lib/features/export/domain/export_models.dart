import 'dart:async';

import '../../timeline/domain/timeline_models.dart';

class TextOverlaySettings {
  const TextOverlaySettings({
    this.text = '',
    this.x = 0.5,
    this.y = 0.75,
    this.size = 44,
    this.font = 'Arial',
    this.color = '#FFFFFF',
    this.opacity = 1,
    this.stroke = 3,
    this.strokeColor = '#000000',
    this.strokeOpacity = 0.9,
    this.shadow = true,
    this.shadowColor = '#000000',
    this.shadowOpacity = 0.65,
    this.animation = 'none',
    this.animationDuration = 1,
    this.startX = 0.5,
    this.startY = 1,
    this.timelineStart = 0,
    this.timelineEnd = 0,
    this.visible = true,
    this.tracking = 0,
    this.curve = 0,
  });

  final String text;
  final double x;
  final double y;
  final double size;
  final String font;
  final String color;
  final double opacity;
  final double stroke;
  final String strokeColor;
  final double strokeOpacity;
  final bool shadow;
  final String shadowColor;
  final double shadowOpacity;
  final String animation;
  final double animationDuration;
  final double startX;
  final double startY;
  final double timelineStart;
  final double timelineEnd;
  final bool visible;
  final double tracking;
  final double curve;
}

class CaptionWordSettings {
  const CaptionWordSettings({
    required this.start,
    required this.end,
    required this.text,
  });

  final double start;
  final double end;
  final String text;
}

class CaptionCueSettings {
  const CaptionCueSettings({
    required this.start,
    required this.end,
    required this.text,
    this.words = const [],
    this.x = 0.5,
    this.y = 0.78,
  });

  final double start;
  final double end;
  final String text;
  final List<CaptionWordSettings> words;
  final double x;
  final double y;
}

class VideoEditSettings {
  const VideoEditSettings({
    required this.speed,
    required this.flip,
    required this.scaleX,
    required this.scaleY,
    required this.zoom,
    required this.watermarkPath,
    required this.watermarkPosition,
    required this.watermarkSize,
    required this.musicPath,
    required this.originalVolume,
    required this.musicVolume,
    this.outputRatio = 'original',
    this.canvasMode = 'none',
    this.canvasColor = '#F4C70F',
    this.canvasPattern = 'grid',
    this.canvasBlur = 24,
    this.panX = 0,
    this.panY = 0,
    this.overlayText = '',
    this.overlayTextX = 0,
    this.overlayTextY = 0.75,
    this.overlayTextSize = 44,
    this.overlayFont = 'Arial',
    this.overlayTextColor = '#FFFFFF',
    this.overlayTextOpacity = 1,
    this.overlayTextStroke = 3,
    this.overlayTextStrokeColor = '#000000',
    this.overlayTextStrokeOpacity = 0.9,
    this.overlayTextShadow = true,
    this.overlayTextShadowColor = '#000000',
    this.overlayTextShadowOpacity = 0.65,
    this.overlayTextAnimation = 'none',
    this.overlayTextAnimationDuration = 1,
    this.overlayTextStartX = 0.5,
    this.overlayTextStartY = 1,
    this.textOverlays = const [],
    this.watermarkX = 0.82,
    this.watermarkY = 0.82,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.gamma = 1,
    this.trimStartSeconds = 0,
    this.trimEndSeconds = 0,
    this.videoBitrateKbps = 8000,
    this.exportCodec = 'h264',
    this.exportFrameRate = 0,
    this.automaticCaptions = false,
    this.captionModel = 'base.en',
    this.captionLanguage = 'en',
    this.captionDevice = 'auto',
    this.captionStyle = 'capcut',
    this.captionWordsPerLine = 4,
    this.captionFont = 'Arial Black',
    this.captionFontSize = 72,
    this.captionBold = true,
    this.captionUnderline = false,
    this.captionItalic = false,
    this.captionCase = 'upper',
    this.captionColor = '#FFF000',
    this.captionCharacterSpacing = 0,
    this.captionWordSpacing = 4,
    this.captionLineSpacing = 0,
    this.captionOpacity = 1,
    this.captionStrokeEnabled = true,
    this.captionStrokeColor = '#000000',
    this.captionStrokeWidth = 6,
    this.captionBackgroundEnabled = false,
    this.captionBackgroundColor = '#000000',
    this.captionBackgroundOpacity = 0.75,
    this.captionBackgroundPadding = 10,
    this.captionGlowEnabled = false,
    this.captionGlowColor = '#FFF000',
    this.captionGlowStrength = 8,
    this.captionShadowEnabled = true,
    this.captionShadowColor = '#000000',
    this.captionShadowStrength = 3,
    this.captionCurve = 0,
    this.captionCues = const [],
    this.hardwareEncoding = false,
    this.hardwareDecoding = false,
  });

  final double speed;
  final String flip;
  final double scaleX;
  final double scaleY;
  final double zoom;
  final String? watermarkPath;
  final String watermarkPosition;
  final double watermarkSize;
  final String? musicPath;
  final double originalVolume;
  final double musicVolume;
  final String outputRatio;
  final String canvasMode;
  final String canvasColor;
  final String canvasPattern;
  final double canvasBlur;
  final double panX;
  final double panY;
  final String overlayText;
  final double overlayTextX;
  final double overlayTextY;
  final double overlayTextSize;
  final String overlayFont;
  final String overlayTextColor;
  final double overlayTextOpacity;
  final double overlayTextStroke;
  final String overlayTextStrokeColor;
  final double overlayTextStrokeOpacity;
  final bool overlayTextShadow;
  final String overlayTextShadowColor;
  final double overlayTextShadowOpacity;
  final String overlayTextAnimation;
  final double overlayTextAnimationDuration;
  final double overlayTextStartX;
  final double overlayTextStartY;
  final List<TextOverlaySettings> textOverlays;
  final double watermarkX;
  final double watermarkY;
  final double brightness;
  final double contrast;
  final double saturation;
  final double gamma;
  final double trimStartSeconds;
  final double trimEndSeconds;
  final int videoBitrateKbps;
  final String exportCodec;
  final double exportFrameRate;
  final bool automaticCaptions;
  final String captionModel;
  final String captionLanguage;
  final String captionDevice;
  final String captionStyle;
  final int captionWordsPerLine;
  final String captionFont;
  final double captionFontSize;
  final bool captionBold;
  final bool captionUnderline;
  final bool captionItalic;
  final String captionCase;
  final String captionColor;
  final double captionCharacterSpacing;
  final double captionWordSpacing;
  final double captionLineSpacing;
  final double captionOpacity;
  final bool captionStrokeEnabled;
  final String captionStrokeColor;
  final double captionStrokeWidth;
  final bool captionBackgroundEnabled;
  final String captionBackgroundColor;
  final double captionBackgroundOpacity;
  final double captionBackgroundPadding;
  final bool captionGlowEnabled;
  final String captionGlowColor;
  final double captionGlowStrength;
  final bool captionShadowEnabled;
  final String captionShadowColor;
  final double captionShadowStrength;
  final double captionCurve;
  final List<CaptionCueSettings> captionCues;
  final bool hardwareEncoding;
  final bool hardwareDecoding;

  VideoEditSettings copyWith({
    double? speed,
    String? flip,
    double? scaleX,
    double? scaleY,
    double? zoom,
    String? watermarkPath,
    String? watermarkPosition,
    double? watermarkSize,
    String? musicPath,
    double? originalVolume,
    double? musicVolume,
    String? outputRatio,
    String? canvasMode,
    String? canvasColor,
    String? canvasPattern,
    double? canvasBlur,
    double? panX,
    double? panY,
    String? overlayText,
    double? overlayTextX,
    double? overlayTextY,
    double? overlayTextSize,
    String? overlayFont,
    String? overlayTextColor,
    double? overlayTextOpacity,
    double? overlayTextStroke,
    String? overlayTextStrokeColor,
    double? overlayTextStrokeOpacity,
    bool? overlayTextShadow,
    String? overlayTextShadowColor,
    double? overlayTextShadowOpacity,
    String? overlayTextAnimation,
    double? overlayTextAnimationDuration,
    double? overlayTextStartX,
    double? overlayTextStartY,
    List<TextOverlaySettings>? textOverlays,
    double? watermarkX,
    double? watermarkY,
    double? brightness,
    double? contrast,
    double? saturation,
    double? gamma,
    double? trimStartSeconds,
    double? trimEndSeconds,
    int? videoBitrateKbps,
    String? exportCodec,
    double? exportFrameRate,
    bool? automaticCaptions,
    String? captionModel,
    String? captionLanguage,
    String? captionDevice,
    String? captionStyle,
    int? captionWordsPerLine,
    String? captionFont,
    double? captionFontSize,
    bool? captionBold,
    bool? captionUnderline,
    bool? captionItalic,
    String? captionCase,
    String? captionColor,
    double? captionCharacterSpacing,
    double? captionWordSpacing,
    double? captionLineSpacing,
    double? captionOpacity,
    bool? captionStrokeEnabled,
    String? captionStrokeColor,
    double? captionStrokeWidth,
    bool? captionBackgroundEnabled,
    String? captionBackgroundColor,
    double? captionBackgroundOpacity,
    double? captionBackgroundPadding,
    bool? captionGlowEnabled,
    String? captionGlowColor,
    double? captionGlowStrength,
    bool? captionShadowEnabled,
    String? captionShadowColor,
    double? captionShadowStrength,
    double? captionCurve,
    List<CaptionCueSettings>? captionCues,
    bool? hardwareEncoding,
    bool? hardwareDecoding,
  }) {
    return VideoEditSettings(
      speed: speed ?? this.speed,
      flip: flip ?? this.flip,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      zoom: zoom ?? this.zoom,
      watermarkPath: watermarkPath ?? this.watermarkPath,
      watermarkPosition: watermarkPosition ?? this.watermarkPosition,
      watermarkSize: watermarkSize ?? this.watermarkSize,
      musicPath: musicPath ?? this.musicPath,
      originalVolume: originalVolume ?? this.originalVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      outputRatio: outputRatio ?? this.outputRatio,
      canvasMode: canvasMode ?? this.canvasMode,
      canvasColor: canvasColor ?? this.canvasColor,
      canvasPattern: canvasPattern ?? this.canvasPattern,
      canvasBlur: canvasBlur ?? this.canvasBlur,
      panX: panX ?? this.panX,
      panY: panY ?? this.panY,
      overlayText: overlayText ?? this.overlayText,
      overlayTextX: overlayTextX ?? this.overlayTextX,
      overlayTextY: overlayTextY ?? this.overlayTextY,
      overlayTextSize: overlayTextSize ?? this.overlayTextSize,
      overlayFont: overlayFont ?? this.overlayFont,
      overlayTextColor: overlayTextColor ?? this.overlayTextColor,
      overlayTextOpacity: overlayTextOpacity ?? this.overlayTextOpacity,
      overlayTextStroke: overlayTextStroke ?? this.overlayTextStroke,
      overlayTextStrokeColor:
          overlayTextStrokeColor ?? this.overlayTextStrokeColor,
      overlayTextStrokeOpacity:
          overlayTextStrokeOpacity ?? this.overlayTextStrokeOpacity,
      overlayTextShadow: overlayTextShadow ?? this.overlayTextShadow,
      overlayTextShadowColor:
          overlayTextShadowColor ?? this.overlayTextShadowColor,
      overlayTextShadowOpacity:
          overlayTextShadowOpacity ?? this.overlayTextShadowOpacity,
      overlayTextAnimation: overlayTextAnimation ?? this.overlayTextAnimation,
      overlayTextAnimationDuration:
          overlayTextAnimationDuration ?? this.overlayTextAnimationDuration,
      overlayTextStartX: overlayTextStartX ?? this.overlayTextStartX,
      overlayTextStartY: overlayTextStartY ?? this.overlayTextStartY,
      textOverlays: textOverlays ?? this.textOverlays,
      watermarkX: watermarkX ?? this.watermarkX,
      watermarkY: watermarkY ?? this.watermarkY,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      gamma: gamma ?? this.gamma,
      trimStartSeconds: trimStartSeconds ?? this.trimStartSeconds,
      trimEndSeconds: trimEndSeconds ?? this.trimEndSeconds,
      videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
      exportCodec: exportCodec ?? this.exportCodec,
      exportFrameRate: exportFrameRate ?? this.exportFrameRate,
      automaticCaptions: automaticCaptions ?? this.automaticCaptions,
      captionModel: captionModel ?? this.captionModel,
      captionLanguage: captionLanguage ?? this.captionLanguage,
      captionDevice: captionDevice ?? this.captionDevice,
      captionStyle: captionStyle ?? this.captionStyle,
      captionWordsPerLine: captionWordsPerLine ?? this.captionWordsPerLine,
      captionFont: captionFont ?? this.captionFont,
      captionFontSize: captionFontSize ?? this.captionFontSize,
      captionBold: captionBold ?? this.captionBold,
      captionUnderline: captionUnderline ?? this.captionUnderline,
      captionItalic: captionItalic ?? this.captionItalic,
      captionCase: captionCase ?? this.captionCase,
      captionColor: captionColor ?? this.captionColor,
      captionCharacterSpacing:
          captionCharacterSpacing ?? this.captionCharacterSpacing,
      captionWordSpacing: captionWordSpacing ?? this.captionWordSpacing,
      captionLineSpacing: captionLineSpacing ?? this.captionLineSpacing,
      captionOpacity: captionOpacity ?? this.captionOpacity,
      captionStrokeEnabled: captionStrokeEnabled ?? this.captionStrokeEnabled,
      captionStrokeColor: captionStrokeColor ?? this.captionStrokeColor,
      captionStrokeWidth: captionStrokeWidth ?? this.captionStrokeWidth,
      captionBackgroundEnabled:
          captionBackgroundEnabled ?? this.captionBackgroundEnabled,
      captionBackgroundColor:
          captionBackgroundColor ?? this.captionBackgroundColor,
      captionBackgroundOpacity:
          captionBackgroundOpacity ?? this.captionBackgroundOpacity,
      captionBackgroundPadding:
          captionBackgroundPadding ?? this.captionBackgroundPadding,
      captionGlowEnabled: captionGlowEnabled ?? this.captionGlowEnabled,
      captionGlowColor: captionGlowColor ?? this.captionGlowColor,
      captionGlowStrength: captionGlowStrength ?? this.captionGlowStrength,
      captionShadowEnabled: captionShadowEnabled ?? this.captionShadowEnabled,
      captionShadowColor: captionShadowColor ?? this.captionShadowColor,
      captionShadowStrength:
          captionShadowStrength ?? this.captionShadowStrength,
      captionCurve: captionCurve ?? this.captionCurve,
      captionCues: captionCues ?? this.captionCues,
      hardwareEncoding: hardwareEncoding ?? this.hardwareEncoding,
      hardwareDecoding: hardwareDecoding ?? this.hardwareDecoding,
    );
  }
}

class ExportJob {
  const ExportJob({
    required this.inputPath,
    required this.outputPath,
    required this.settings,
    this.onProgress,
    this.cancelToken,
  });

  final String inputPath;
  final String outputPath;
  final VideoEditSettings settings;
  final void Function(double progress, String status)? onProgress;
  final ExportCancelToken? cancelToken;
}

class SequenceExportJob {
  const SequenceExportJob({
    required this.jobs,
    required this.outputPath,
    required this.settings,
    this.onProgress,
    this.cancelToken,
  });

  final List<ExportJob> jobs;
  final String outputPath;
  final VideoEditSettings settings;
  final void Function(double progress, String status)? onProgress;
  final ExportCancelToken? cancelToken;
}

/// One edited source section used to build the lightweight speech-analysis
/// track. Captions need timing and audio only; decoding or encoding video here
/// wastes GPU memory and can make the desktop unresponsive.
class CaptionAudioSegment {
  const CaptionAudioSegment({
    required this.inputPath,
    required this.sourceStart,
    required this.duration,
    required this.speed,
  });

  final String inputPath;
  final double sourceStart;
  final double duration;
  final double speed;

  double get outputDuration => duration / speed;
}

class MultiTrackExportJob {
  const MultiTrackExportJob({
    required this.timeline,
    required this.outputPath,
    this.width = 1920,
    this.height = 1080,
    this.frameRate = 30,
    this.videoBitrateKbps = 8000,
    this.exportCodec = 'h264',
    this.backgroundColor = 'black',
    this.hardwareEncoding = false,
    this.hardwareDecoding = false,
    this.playbackSpeedsByMediaPath = const {},
    this.textOverlays = const [],
    this.captionSettings,
    this.onProgress,
    this.cancelToken,
  });

  final TimelineModel timeline;
  final String outputPath;
  final int width;
  final int height;
  final double frameRate;
  final int videoBitrateKbps;
  final String exportCodec;
  final String backgroundColor;
  final bool hardwareEncoding;
  final bool hardwareDecoding;
  final Map<String, double> playbackSpeedsByMediaPath;
  final List<TextOverlaySettings> textOverlays;
  final VideoEditSettings? captionSettings;
  final void Function(double progress, String status)? onProgress;
  final ExportCancelToken? cancelToken;
}

class ExportCancelToken {
  bool _isCanceled = false;
  bool _isPaused = false;
  Completer<void>? _resumeCompleter;
  final Completer<void> _cancelCompleter = Completer<void>();
  final Set<Future<void>> _activeOperations = <Future<void>>{};

  bool get isCanceled => _isCanceled;
  bool get isPaused => _isPaused;
  Future<void> get whenCanceled => _cancelCompleter.future;
  int get activeOperationCount => _activeOperations.length;

  void trackOperation(Future<void> operation) {
    late final Future<void> guarded;
    guarded = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _activeOperations.add(guarded);
    unawaited(guarded.whenComplete(() => _activeOperations.remove(guarded)));
  }

  Future<void> waitForIdle() async {
    while (_activeOperations.isNotEmpty) {
      await Future.wait<void>(List<Future<void>>.of(_activeOperations));
    }
  }

  Future<void> cancelAndWait({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    cancel();
    await waitForIdle().timeout(timeout);
  }

  void pause() {
    if (_isCanceled || _isPaused) return;
    _isPaused = true;
    _resumeCompleter = Completer<void>();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  Future<bool> waitUntilResumed() async {
    while (_isPaused && !_isCanceled) {
      final completer = _resumeCompleter;
      if (completer == null) break;
      await completer.future;
    }
    return !_isCanceled;
  }

  void cancel() {
    _isCanceled = true;
    _isPaused = false;
    if (!_cancelCompleter.isCompleted) _cancelCompleter.complete();
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}

class ExportResult {
  const ExportResult({
    required this.success,
    required this.message,
    this.outputPath,
  });

  final bool success;
  final String message;
  final String? outputPath;
}
