part of 'export_service_io.dart';

Future<bool> _videoEncoderWorks(
  String encoder, {
  ExportCancelToken? cancelToken,
}) async {
  if (cancelToken?.isCanceled == true) return false;
  try {
    final process = await Process.start(_ffmpegExecutable, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=size=64x64:rate=1:duration=0.05',
      '-frames:v',
      '1',
      '-an',
      '-c:v',
      encoder,
      '-f',
      'null',
      '-',
    ]);
    await registerKlipioWorker(process);
    final processExit = process.exitCode;
    cancelToken?.trackOperation(processExit.then<void>((_) {}));
    final outputDone = process.stdout.drain<void>();
    final errorDone = process.stderr.drain<void>();
    final outcome = await Future.any<int>([
      processExit,
      Future<int>.delayed(const Duration(seconds: 8), () => -1),
      if (cancelToken != null) cancelToken.whenCanceled.then<int>((_) => -2),
    ]);
    var exitCode = outcome;
    if (outcome < 0) {
      await _terminateProcessTree(process);
      exitCode = await processExit.timeout(
        const Duration(seconds: 3),
        onTimeout: () => outcome,
      );
    }
    await Future.wait([outputDone, errorDone]);
    return exitCode == 0 && cancelToken?.isCanceled != true;
  } on ProcessException {
    return false;
  }
}

List<String> _hardwareEncoderPreference(String codec) {
  final prefix = _normalizedExportCodec(codec) == 'hevc' ? 'hevc' : 'h264';
  if (Platform.isWindows) {
    return ['${prefix}_nvenc', '${prefix}_qsv', '${prefix}_amf'];
  }
  if (Platform.isMacOS) {
    return ['${prefix}_videotoolbox'];
  }
  if (Platform.isLinux) {
    return ['${prefix}_nvenc', '${prefix}_qsv'];
  }
  return const [];
}

List<String> _cleanMp4OutputArgs() {
  return const [
    '-map_metadata',
    '-1',
    '-map_chapters',
    '-1',
    '-movflags',
    '+faststart',
  ];
}

List<String> _captionFriendlyAudioArgs() {
  return const [
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-ar',
    '48000',
    '-ac',
    '2',
    '-fflags',
    '+genpts',
  ];
}

List<String> _audioOutputArgs({required bool copy}) {
  if (copy) {
    return const ['-c:a', 'copy', '-fflags', '+genpts'];
  }
  return _captionFriendlyAudioArgs();
}

String _assSubtitleFilter(String path) {
  final escaped = path
      .replaceAll(r'\', '/')
      .replaceAll(':', r'\:')
      .replaceAll("'", r"\'")
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]');
  return "ass=filename='$escaped'";
}

List<String> _videoEncoderArgs(
  VideoEditSettings settings, {
  required String encoder,
}) {
  final bitrate = '${settings.videoBitrateKbps}k';
  final maxrate = '${(settings.videoBitrateKbps * 1.5).round()}k';
  final bufsize = '${settings.videoBitrateKbps * 2}k';
  switch (encoder) {
    case 'h264_nvenc':
    case 'hevc_nvenc':
      return [
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
        bufsize,
        '-pix_fmt',
        'yuv420p',
      ];
    case 'h264_qsv':
    case 'hevc_qsv':
      return [
        '-c:v',
        encoder,
        '-preset',
        'veryfast',
        '-b:v',
        bitrate,
        '-maxrate',
        maxrate,
        '-bufsize',
        bufsize,
        '-pix_fmt',
        'yuv420p',
      ];
    case 'h264_amf':
    case 'hevc_amf':
      return [
        '-c:v',
        encoder,
        '-quality',
        'speed',
        '-b:v',
        bitrate,
        '-maxrate',
        maxrate,
        '-bufsize',
        bufsize,
        '-pix_fmt',
        'yuv420p',
      ];
    case 'h264_videotoolbox':
    case 'hevc_videotoolbox':
      return [
        '-c:v',
        encoder,
        '-b:v',
        bitrate,
        '-maxrate',
        maxrate,
        '-bufsize',
        bufsize,
        '-pix_fmt',
        'yuv420p',
      ];
    default:
      return [
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
        bufsize,
        '-pix_fmt',
        'yuv420p',
      ];
  }
}

double? _parseFfmpegTimestamp(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 3) return null;
  final hours = double.tryParse(parts[0]);
  final minutes = double.tryParse(parts[1]);
  final seconds = double.tryParse(parts[2]);
  if (hours == null || minutes == null || seconds == null) return null;
  return hours * 3600 + minutes * 60 + seconds;
}

String _renderingStatus(String? fps, String? speed) {
  final details = <String>[
    if (fps != null) '$fps fps',
    if (speed != null) speed,
  ];
  return details.isEmpty
      ? 'Exporting...'
      : 'Exporting... ${details.join(' • ')}';
}

String _audioFilters(double speed, double volume) {
  final filters = <String>[];
  if (speed != 1.0) {
    filters.addAll(_tempoFilters(speed));
  }
  if (volume != 1.0) {
    filters.add('volume=${_num(volume)}');
  }
  if (filters.isEmpty) {
    return 'anull';
  }
  return filters.join(',');
}

String _overlayXY(double x, double y) {
  final safeX = _num(x.clamp(0.0, 1.0).toDouble());
  final safeY = _num(y.clamp(0.0, 1.0).toDouble());
  return '(main_w-overlay_w)*$safeX:(main_h-overlay_h)*$safeY';
}

String? _ratioPadFilter(String ratio,
    {required double panX,
    required double panY,
    String backgroundColor = 'black'}) {
  final target = switch (ratio) {
    '16:9' => 16 / 9,
    '9:16' => 9 / 16,
    '4:5' => 4 / 5,
    '1:1' => 1.0,
    '3:4' => 3 / 4,
    '4:3' => 4 / 3,
    _ => null,
  };
  if (target == null) {
    return null;
  }

  final value = _num(target);
  final xPos = _num(((panX.clamp(-1.0, 1.0) + 1) / 2).toDouble());
  final yPos = _num(((panY.clamp(-1.0, 1.0) + 1) / 2).toDouble());
  final cleanColor = backgroundColor.trim().replaceFirst('#', '');
  final color = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleanColor)
      ? '0x${cleanColor.toUpperCase()}'
      : 'black';
  return "pad='if(gt(a,$value),iw,ceil(ih*$value/2)*2)':'if(gt(a,$value),ceil(iw/$value/2)*2,ih)':'(ow-iw)*$xPos':'(oh-ih)*$yPos':$color";
}

String? _colorCorrectionFilter(VideoEditSettings settings) {
  final brightness = settings.brightness.clamp(-1.0, 1.0).toDouble();
  final contrast = settings.contrast.clamp(0.0, 3.0).toDouble();
  final saturation = settings.saturation.clamp(0.0, 3.0).toDouble();
  final gamma = settings.gamma.clamp(0.1, 3.0).toDouble();
  if (brightness == 0 && contrast == 1 && saturation == 1 && gamma == 1) {
    return null;
  }
  return 'eq=brightness=${_num(brightness)}:contrast=${_num(contrast)}:saturation=${_num(saturation)}:gamma=${_num(gamma)}';
}

List<TextOverlaySettings> _effectiveTextOverlays(VideoEditSettings settings) {
  if (settings.textOverlays.isNotEmpty) {
    return settings.textOverlays.where((overlay) => overlay.visible).toList();
  }
  if (settings.overlayText.trim().isEmpty) {
    return const [];
  }
  return [
    TextOverlaySettings(
      text: settings.overlayText,
      x: settings.overlayTextX,
      y: settings.overlayTextY,
      size: settings.overlayTextSize,
      font: settings.overlayFont,
      color: settings.overlayTextColor,
      opacity: settings.overlayTextOpacity,
      stroke: settings.overlayTextStroke,
      strokeColor: settings.overlayTextStrokeColor,
      strokeOpacity: settings.overlayTextStrokeOpacity,
      shadow: settings.overlayTextShadow,
      shadowColor: settings.overlayTextShadowColor,
      shadowOpacity: settings.overlayTextShadowOpacity,
      animation: settings.overlayTextAnimation,
      animationDuration: settings.overlayTextAnimationDuration,
      startX: settings.overlayTextStartX,
      startY: settings.overlayTextStartY,
    ),
  ];
}

String _drawTextFilter(TextOverlaySettings overlay) {
  if (_normalizedAnimation(overlay.animation) == 'text typing') {
    return _typingDrawTextFilters(overlay);
  }

  final text = _escapeDrawText(overlay.text.trim());
  final position = _textPosition(overlay);
  final alpha = _textAlpha(overlay);
  final boxColor = _ffmpegColor(overlay.shadowColor, '#000000');
  final extraOptions = _normalizedAnimation(overlay.animation) == 'pop up line'
      ? ':box=1:boxcolor=$boxColor@0.42:boxborderw=10'
      : '';
  return _singleDrawTextFilter(
    overlay,
    text: text,
    x: position.x,
    y: position.y,
    alpha: alpha,
    extraOptions: extraOptions,
  );
}

String _singleDrawTextFilter(
  TextOverlaySettings overlay, {
  required String text,
  required String x,
  required String y,
  String? alpha,
  String? enable,
  String extraOptions = '',
}) {
  final size = overlay.size.clamp(16, 120).round();
  final fillOpacity = _num(overlay.opacity.clamp(0.0, 1.0).toDouble());
  final strokeOpacity = _num(overlay.strokeOpacity.clamp(0.0, 1.0).toDouble());
  final shadowOpacity = _num(overlay.shadowOpacity.clamp(0.0, 1.0).toDouble());
  final textColor = _ffmpegColor(overlay.color, '#FFFFFF');
  final strokeColor = _ffmpegColor(overlay.strokeColor, '#000000');
  final shadowColor = _ffmpegColor(overlay.shadowColor, '#000000');
  final stroke = overlay.stroke.clamp(0, 12).round();
  final fontOption = _fontOption(overlay.font);
  final alphaOption = alpha == null ? '' : ":alpha='$alpha'";
  final timelineEnable = _textTimelineEnable(overlay);
  final combinedEnable = enable == null
      ? timelineEnable
      : timelineEnable == null
          ? enable
          : '($timelineEnable)*($enable)';
  final enableOption =
      combinedEnable == null ? '' : ":enable='$combinedEnable'";
  final shadow = overlay.shadow
      ? ':shadowx=3:shadowy=3:shadowcolor=$shadowColor@$shadowOpacity'
      : '';
  return "drawtext=text='$text'$fontOption:fontcolor=$textColor@$fillOpacity$alphaOption:fontsize=$size:borderw=$stroke:bordercolor=$strokeColor@$strokeOpacity$shadow$extraOptions:x='$x':y='$y'$enableOption";
}

({String x, String y}) _textPosition(TextOverlaySettings overlay) {
  final x = _num(overlay.x.clamp(0.0, 1.0).toDouble());
  final y = _num(overlay.y.clamp(0.0, 1.0).toDouble());
  final startX = _num(overlay.startX.clamp(0.0, 1.0).toDouble());
  final startY = _num(overlay.startY.clamp(0.0, 1.0).toDouble());
  final duration = _num(
    overlay.animationDuration.clamp(0.2, 5.0).toDouble(),
  );
  final finalX = '(w-text_w)*$x';
  final finalY = '(h-text_h)*$y';
  final initialX = '(w-text_w)*$startX';
  final initialY = '(h-text_h)*$startY';
  final localTime = overlay.timelineEnd > overlay.timelineStart
      ? '(t-${_num(overlay.timelineStart)})'
      : 't';
  final progress = 'min(max($localTime/$duration\\,0)\\,1)';
  return switch (_normalizedAnimation(overlay.animation)) {
    'flow up' => (
        x: '$initialX+($finalX-($initialX))*$progress',
        y: '$initialY+($finalY-($initialY))*$progress',
      ),
    'flow down' => (
        x: '$initialX+($finalX-($initialX))*$progress',
        y: '$initialY+($finalY-($initialY))*$progress',
      ),
    'flow left' => (
        x: '$initialX+($finalX-($initialX))*$progress',
        y: '$initialY+($finalY-($initialY))*$progress',
      ),
    'flow right' => (
        x: '$initialX+($finalX-($initialX))*$progress',
        y: '$initialY+($finalY-($initialY))*$progress',
      ),
    'pop up line' => (
        x: finalX,
        y: '$finalY+20*(1-$progress)',
      ),
    _ => (x: finalX, y: finalY),
  };
}

String? _textAlpha(TextOverlaySettings overlay) {
  final duration = _num(
    overlay.animationDuration.clamp(0.2, 5.0).toDouble(),
  );
  final localTime = overlay.timelineEnd > overlay.timelineStart
      ? '(t-${_num(overlay.timelineStart)})'
      : 't';
  return switch (_normalizedAnimation(overlay.animation)) {
    'fade in' => 'min(max($localTime/$duration\\,0)\\,1)',
    'fade out' => 'max(1-$localTime/$duration\\,0)',
    'pop up line' => 'min(max($localTime/$duration\\,0)\\,1)',
    'pulse' => '0.65+0.35*sin(2*PI*$localTime/$duration)',
    _ => null,
  };
}

String _typingDrawTextFilters(TextOverlaySettings overlay) {
  final runes = overlay.text.trim().runes.toList();
  if (runes.isEmpty) {
    return 'null';
  }

  final position = _textPosition(overlay);
  final steps = runes.length.clamp(1, 64);
  final duration = overlay.animationDuration.clamp(0.2, 5.0).toDouble();
  final filters = <String>[];
  for (var index = 1; index <= steps; index++) {
    final chars =
        index == steps ? runes.length : (runes.length * index / steps).ceil();
    final prefix = _escapeDrawText(String.fromCharCodes(runes.take(chars)));
    final base = overlay.timelineEnd > overlay.timelineStart
        ? overlay.timelineStart
        : 0.0;
    final start = _num(base + (index - 1) * duration / steps);
    final end = _num(base + index * duration / steps);
    final enable =
        index == steps ? 'gte(t\\,$start)' : 'between(t\\,$start\\,$end)';
    filters.add(
      _singleDrawTextFilter(
        overlay,
        text: prefix,
        x: position.x,
        y: position.y,
        alpha: enable,
      ),
    );
  }
  return filters.join(',');
}

String? _textTimelineEnable(TextOverlaySettings overlay) {
  if (!overlay.visible) return '0';
  if (overlay.timelineEnd <= overlay.timelineStart) return null;
  return 'between(t\\,${_num(overlay.timelineStart)}\\,${_num(overlay.timelineEnd)})';
}

String _normalizedAnimation(String animation) =>
    animation.trim().toLowerCase().replaceAll('-', ' ');

String _ffmpegColor(String input, String fallback) {
  final fallbackHex = fallback.replaceFirst('#', '');
  var hex = input.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((char) => '$char$char').join();
  }
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
    hex = fallbackHex;
  }
  return '0x${hex.toUpperCase()}';
}

String _fontOption(String family) {
  final trimmed = family.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  if (Platform.isWindows) {
    final fontFile = _windowsFontFile(trimmed);
    if (fontFile != null) {
      return ":fontfile='${_escapeDrawText(fontFile)}'";
    }
  }

  return ":font='${_escapeDrawText(trimmed)}'";
}

String? _windowsFontFile(String family) {
  final normalized = family.toLowerCase();
  final candidates = switch (normalized) {
    'arial' => ['arial.ttf', 'arialbd.ttf'],
    'segoe ui' => ['segoeui.ttf', 'segoeuib.ttf'],
    'tahoma' => ['tahoma.ttf', 'tahomabd.ttf'],
    'verdana' => ['verdana.ttf', 'verdanab.ttf'],
    'calibri' => ['calibri.ttf', 'calibrib.ttf'],
    'georgia' => ['georgia.ttf', 'georgiab.ttf'],
    'impact' => ['impact.ttf'],
    'times new roman' => ['times.ttf', 'timesbd.ttf'],
    'khmer ui' => ['khmerui.ttf', 'khmeruib.ttf'],
    'daunpenh' => ['daunpenh.ttf'],
    'noto sans khmer' => ['NotoSansKhmer-Regular.ttf'],
    'noto serif khmer' => ['NotoSerifKhmer-Regular.ttf'],
    'khmer os' => ['KhmerOS.ttf', 'Khmer OS.ttf'],
    'khmer os battambang' => ['KhmerOSbattambang.ttf'],
    'khmer os muol light' => ['KhmerOSmuollight.ttf'],
    _ => <String>[],
  };

  for (final fileName in candidates) {
    final path = 'C:/Windows/Fonts/$fileName';
    if (File(path).existsSync()) {
      return path;
    }
  }
  return null;
}

String _escapeDrawText(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(':', r'\:')
      .replaceAll(',', r'\,')
      .replaceAll('%', r'\%');
}

String _tempo(double speed) {
  final clamped = speed.clamp(0.5, 2.0).toDouble();
  return _num(clamped);
}

List<String> _tempoFilters(double speed) {
  // The caption-analysis audio path also requires sample-transparent 1x.
  if (speed == 1) return ['anull'];
  var remaining = speed;
  final filters = <String>[];

  while (remaining > 2.0) {
    filters.add('atempo=2');
    remaining /= 2.0;
  }

  while (remaining < 0.5) {
    filters.add('atempo=0.5');
    remaining /= 0.5;
  }

  filters.add('atempo=${_tempo(remaining)}');
  return filters;
}

String _num(double value) => value
    .toStringAsFixed(3)
    .replaceAll(RegExp(r'0+$'), '')
    .replaceAll(RegExp(r'\.$'), '');

String _seconds(double value) => value.toStringAsFixed(3);

double _safeSpeed(double value) => value.clamp(0.25, 4.0).toDouble();
