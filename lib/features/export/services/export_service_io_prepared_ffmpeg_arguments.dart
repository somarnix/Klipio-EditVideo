part of 'export_service_io.dart';

Future<_FfmpegRunResult> _runFfmpeg(
  List<String> args, {
  double? durationSeconds,
  void Function(double progress, String status)? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  if (cancelToken?.isCanceled == true) {
    return const _FfmpegRunResult(success: false, message: 'Export canceled.');
  }
  if (cancelToken?.isPaused == true) {
    onProgress?.call(0, 'Export paused...');
    final canResume = await cancelToken!.waitUntilResumed();
    if (!canResume) {
      return const _FfmpegRunResult(
        success: false,
        message: 'Export canceled.',
      );
    }
  }

  if (Platform.isAndroid || Platform.isIOS) {
    final completedSession = Completer<dynamic>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) {
        if (!completedSession.isCompleted) {
          completedSession.complete(session);
        }
      },
    );
    cancelToken?.trackOperation(completedSession.future.then<void>((_) {}));
    Timer? cancelTimer;
    var cancellationRequested = false;
    if (cancelToken != null) {
      cancelTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if ((cancelToken.isCanceled || cancelToken.isPaused) &&
            !cancellationRequested) {
          cancellationRequested = true;
          unawaited(session.cancel());
        }
      });
    }
    final finishedSession = await completedSession.future;
    cancelTimer?.cancel();
    if (cancelToken?.isPaused == true && cancelToken?.isCanceled != true) {
      onProgress?.call(0, 'Export paused...');
      final canResume = await cancelToken!.waitUntilResumed();
      if (!canResume) {
        return const _FfmpegRunResult(
          success: false,
          message: 'Export canceled.',
        );
      }
      onProgress?.call(0, 'Resuming current export item...');
      return _runFfmpeg(
        args,
        durationSeconds: durationSeconds,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
    if (cancelToken?.isCanceled == true) {
      return const _FfmpegRunResult(
          success: false, message: 'Export canceled.');
    }
    final returnCode = await finishedSession.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return const _FfmpegRunResult(success: true, message: '');
    }

    if (ReturnCode.isCancel(returnCode)) {
      return const _FfmpegRunResult(
          success: false, message: 'Export canceled.');
    }

    final output = await finishedSession.getOutput();
    final failStackTrace = await finishedSession.getFailStackTrace();
    return _FfmpegRunResult(
      success: false,
      message: (output?.trim().isNotEmpty ?? false)
          ? output!.trim()
          : (failStackTrace ?? 'FFmpeg export failed.'),
    );
  }

  final preparedArguments = await _prepareDesktopFfmpegArguments(args);
  late final Process process;
  try {
    process = await Process.start(
      _ffmpegExecutable,
      [
        '-hide_banner',
        '-loglevel',
        'warning',
        '-nostdin',
        '-threads',
        '4',
        '-filter_threads',
        '2',
        '-filter_complex_threads',
        '2',
        '-nostats',
        '-progress',
        'pipe:1',
        ...preparedArguments.arguments,
      ],
    );
  } on ProcessException catch (error) {
    await preparedArguments.cleanUp();
    return _FfmpegRunResult(
      success: false,
      message: 'FFmpeg could not start: ${error.message}',
    );
  }
  await registerKlipioWorker(process);
  final processExit = process.exitCode;
  cancelToken?.trackOperation(processExit.then<void>((_) {}));
  final stderr = _BoundedTextBuffer();
  final stdout = _BoundedTextBuffer();
  var lastProgress = 0.0;
  String? processingFps;
  String? processingSpeed;
  var terminationRequested = false;
  Timer? cancelTimer;
  Timer? stallTimer;
  final stalled = Completer<void>();
  var lastWorkerActivity = DateTime.now();
  if (cancelToken != null) {
    cancelTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if ((cancelToken.isCanceled || cancelToken.isPaused) &&
          !terminationRequested) {
        terminationRequested = true;
        unawaited(_terminateProcessTree(process));
      }
    });
  }

  final stderrDone =
      process.stderr.transform(systemEncoding.decoder).listen((chunk) {
    lastWorkerActivity = DateTime.now();
    stderr.write(chunk);
  }).asFuture<void>();
  final stdoutDone = process.stdout
      .transform(systemEncoding.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    lastWorkerActivity = DateTime.now();
    stdout.writeln(line);
    if (line.startsWith('fps=')) {
      final value = line.substring('fps='.length).trim();
      if (value.isNotEmpty && value != '0.00') processingFps = value;
    } else if (line.startsWith('speed=')) {
      final value = line.substring('speed='.length).trim();
      if (value.isNotEmpty && value != 'N/A') processingSpeed = value;
    } else if (line.startsWith('out_time_us=') ||
        line.startsWith('out_time_ms=')) {
      final separator = line.indexOf('=');
      final value = double.tryParse(line.substring(separator + 1));
      if (value != null) {
        final seconds = value / 1000000;
        if (durationSeconds != null && durationSeconds > 0) {
          lastProgress =
              (seconds / durationSeconds).clamp(0.0, 0.999).toDouble();
          onProgress?.call(
            lastProgress,
            _renderingStatus(processingFps, processingSpeed),
          );
        }
      }
    } else if (line.startsWith('out_time=')) {
      final seconds = _parseFfmpegTimestamp(line.substring('out_time='.length));
      if (seconds != null) {
        if (durationSeconds != null && durationSeconds > 0) {
          lastProgress =
              (seconds / durationSeconds).clamp(0.0, 0.999).toDouble();
          onProgress?.call(
            lastProgress,
            _renderingStatus(processingFps, processingSpeed),
          );
        }
      }
    } else if (line == 'progress=end') {
      onProgress?.call(1, 'Finishing...');
    }
  }).asFuture<void>();
  stallTimer = Timer.periodic(const Duration(seconds: 15), (_) {
    if (DateTime.now().difference(lastWorkerActivity) >=
            const Duration(seconds: 90) &&
        !stalled.isCompleted) {
      stalled.complete();
    }
  });
  final outcome = await Future.any<int>([
    processExit,
    if (cancelToken != null) cancelToken.whenCanceled.then<int>((_) => -2),
    stalled.future.then<int>((_) => -3),
  ]);
  var exitCode = outcome;
  if (outcome < 0) {
    terminationRequested = true;
    await _terminateProcessTree(process);
    exitCode = await processExit.timeout(
      const Duration(seconds: 3),
      onTimeout: () => outcome,
    );
  }
  cancelTimer?.cancel();
  stallTimer.cancel();
  try {
    await Future.wait([stdoutDone, stderrDone])
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // A force-terminated worker can close its pipes asynchronously.
  }
  await preparedArguments.cleanUp();
  if (cancelToken?.isPaused == true && cancelToken?.isCanceled != true) {
    onProgress?.call(lastProgress, 'Export paused...');
    final canResume = await cancelToken!.waitUntilResumed();
    if (!canResume) {
      return const _FfmpegRunResult(
        success: false,
        message: 'Export canceled.',
      );
    }
    onProgress?.call(0, 'Resuming current export item...');
    return _runFfmpeg(
      args,
      durationSeconds: durationSeconds,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
  if (cancelToken?.isCanceled == true) {
    return const _FfmpegRunResult(success: false, message: 'Export canceled.');
  }
  if (outcome == -3) {
    return const _FfmpegRunResult(
      success: false,
      message:
          'The media worker stopped making progress for 90 seconds and was terminated to keep Windows responsive.',
    );
  }
  final message = stderr.toString().trim();
  return _FfmpegRunResult(
    success: exitCode == 0,
    message: message.isEmpty ? stdout.toString().trim() : message,
  );
}

class _PreparedFfmpegArguments {
  const _PreparedFfmpegArguments(this.arguments, this.scriptFiles);

  final List<String> arguments;
  final List<File> scriptFiles;

  Future<void> cleanUp() async {
    for (final file in scriptFiles) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {
        // A stale temporary script is harmless and can be cleared with cache.
      }
    }
  }
}

Future<_PreparedFfmpegArguments> _prepareDesktopFfmpegArguments(
  List<String> arguments,
) async {
  // CreateProcess has a finite command-line length on Windows. Filter graphs
  // can grow beyond it when a project has many text layers or timeline clips.
  // FFmpeg supports reading those graphs from a file, keeping the launch
  // command short without changing the rendered result.
  if (!Platform.isWindows) {
    return _PreparedFfmpegArguments(List<String>.from(arguments), const []);
  }
  final prepared = List<String>.from(arguments);
  final scripts = <File>[];
  final scriptDirectory = Directory(
    '${ApplicationPaths.temporary.path}${Platform.pathSeparator}klipio_ffmpeg_scripts',
  );
  for (var index = 0; index + 1 < prepared.length; index++) {
    final option = prepared[index];
    final isComplex = option == '-filter_complex';
    final isVideoFilter = option == '-vf' || option == '-filter:v';
    final graph = prepared[index + 1];
    if ((!isComplex && !isVideoFilter) || graph.length < 4096) continue;
    await scriptDirectory.create(recursive: true);
    final script = File(
      '${scriptDirectory.path}${Platform.pathSeparator}'
      'graph_${DateTime.now().microsecondsSinceEpoch}_${scripts.length}.txt',
    );
    await script.writeAsString(graph, flush: true);
    scripts.add(script);
    prepared[index] = isComplex ? '-filter_complex_script' : '-filter_script:v';
    prepared[index + 1] = script.path;
    index++;
  }
  return _PreparedFfmpegArguments(prepared, scripts);
}

Future<_FfmpegRunResult> _runFfmpegWithEncoderFallback({
  required List<String> args,
  required String encoder,
  required Future<List<String>> Function() fallbackArgs,
  double? durationSeconds,
  void Function(double progress, String status)? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final result = await _runFfmpeg(
    args,
    durationSeconds: durationSeconds,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );
  if (result.success ||
      _isSoftwareEncoder(encoder) ||
      cancelToken?.isCanceled == true ||
      !_looksLikeHardwareEncoderFailure(result.message)) {
    return result;
  }

  onProgress?.call(0, 'Hardware encoder failed. Retrying CPU export...');
  return _runFfmpeg(
    await fallbackArgs(),
    durationSeconds: durationSeconds,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );
}

bool _looksLikeHardwareEncoderFailure(String message) {
  final lower = message.toLowerCase();
  return lower.contains('h264_nvenc') ||
      lower.contains('hevc_nvenc') ||
      lower.contains('h264_qsv') ||
      lower.contains('hevc_qsv') ||
      lower.contains('h264_amf') ||
      lower.contains('hevc_amf') ||
      lower.contains('h264_videotoolbox') ||
      lower.contains('hevc_videotoolbox') ||
      lower.contains('hardware acceleration') ||
      lower.contains('hwaccel') ||
      lower.contains('encoder') && lower.contains('failed') ||
      lower.contains('no capable devices') ||
      lower.contains('device creation failed') ||
      lower.contains('initializing an internal mfx session') ||
      lower.contains('cannot load nvcuda') ||
      lower.contains('openencode sessionex failed');
}

class _FfmpegRunResult {
  const _FfmpegRunResult({required this.success, required this.message});

  final bool success;
  final String message;
}

Future<List<String>> _buildFfmpegArgs(
  ExportJob job, {
  required bool inputHasAudio,
  required bool musicHasAudio,
  required String encoder,
  String? captionAssPath,
  bool canCopyInputAudio = false,
}) async {
  final settings = job.settings;
  if (_canStreamCopyExport(settings, inputHasAudio, musicHasAudio)) {
    return _buildStreamCopyArgs(job);
  }

  final speed = _safeSpeed(settings.speed);
  final args = <String>['-y'];
  if (!_isSoftwareEncoder(encoder) && settings.hardwareDecoding) {
    args.addAll(['-hwaccel', 'auto']);
  }
  final trimStart =
      settings.trimStartSeconds < 0 ? 0.0 : settings.trimStartSeconds;
  final trimEnd = settings.trimEndSeconds < 0 ? 0.0 : settings.trimEndSeconds;
  if (trimStart > 0) {
    args.addAll(['-ss', _seconds(trimStart)]);
  }
  if (trimEnd > trimStart) {
    args.addAll(['-t', _seconds(trimEnd - trimStart)]);
  }
  args.addAll(['-i', job.inputPath]);
  final hasWatermark =
      settings.watermarkPath != null && settings.watermarkPath!.isNotEmpty;
  final hasMusic = settings.musicPath != null &&
      settings.musicPath!.isNotEmpty &&
      musicHasAudio;

  var nextInputIndex = 1;
  int? watermarkInputIndex;
  int? musicInputIndex;
  if (hasWatermark) {
    args.addAll(['-i', settings.watermarkPath!]);
    watermarkInputIndex = nextInputIndex;
    nextInputIndex++;
  }
  if (hasMusic) {
    args.addAll(['-i', settings.musicPath!]);
    musicInputIndex = nextInputIndex;
    nextInputIndex++;
  }

  final videoFilters = <String>[];
  if (speed != 1.0) {
    videoFilters.add('setpts=${_num(1 / speed)}*PTS');
  }
  switch (settings.flip) {
    case 'left':
    case 'right':
      videoFilters.add('hflip');
      break;
    case 'up':
      videoFilters.add('hflip');
      videoFilters.add('vflip');
      break;
    case 'down':
      videoFilters.add('vflip');
      break;
  }
  if (settings.scaleX != 1.0 || settings.scaleY != 1.0) {
    videoFilters.add(
      'scale=trunc(iw*${_num(settings.scaleX)}/2)*2:trunc(ih*${_num(settings.scaleY)}/2)*2',
    );
  }
  if (settings.zoom > 1.0) {
    final zoom = _num(settings.zoom);
    final xPos = _num(((settings.panX.clamp(-1.0, 1.0) + 1) / 2).toDouble());
    final yPos = _num(((settings.panY.clamp(-1.0, 1.0) + 1) / 2).toDouble());
    videoFilters.add(
      'crop=iw/$zoom:ih/$zoom:(iw-iw/$zoom)*$xPos:(ih-ih/$zoom)*$yPos,scale=trunc(iw*$zoom/2)*2:trunc(ih*$zoom/2)*2',
    );
  }
  final ratioFilter = _ratioPadFilter(
    settings.outputRatio,
    panX: settings.panX,
    panY: settings.panY,
    backgroundColor:
        settings.canvasMode == 'color' || settings.canvasMode == 'pattern'
            ? settings.canvasColor
            : 'black',
  );
  if (ratioFilter != null) {
    videoFilters.add(ratioFilter);
  }
  final colorFilter = _colorCorrectionFilter(settings);
  if (colorFilter != null) {
    videoFilters.add(colorFilter);
  }
  final textOverlays = _effectiveTextOverlays(settings);
  for (final overlay in textOverlays) {
    if (overlay.text.trim().isNotEmpty) {
      videoFilters.add(_drawTextFilter(overlay));
    }
  }
  videoFilters.add('scale=trunc(iw/2)*2:trunc(ih/2)*2');
  if (captionAssPath != null && captionAssPath.isNotEmpty) {
    videoFilters.add(_assSubtitleFilter(captionAssPath));
  }

  final needsAudioFilter =
      inputHasAudio && (speed != 1.0 || settings.originalVolume != 1.0);
  final needsComplexVideoFilter = textOverlays.any(
    (overlay) => _normalizedAnimation(overlay.animation) == 'text typing',
  );

  if (hasWatermark ||
      hasMusic ||
      needsComplexVideoFilter ||
      (needsAudioFilter && videoFilters.isNotEmpty)) {
    final filterParts = <String>[];
    var videoMap = '0:v';
    if (videoFilters.isNotEmpty) {
      filterParts.add('[0:v]${videoFilters.join(',')}[vbase]');
      videoMap = '[vbase]';
    }
    if (hasWatermark) {
      if (videoMap == '0:v') {
        filterParts.add('[0:v]null[vbase]');
        videoMap = '[vbase]';
      }
      filterParts.add(
        '[$watermarkInputIndex:v]$videoMap'
        'scale2ref=w=oh*mdar:h=ih*${_num(settings.watermarkSize)}[wm][vref]',
      );
      filterParts.add(
          '[vref][wm]overlay=${_overlayXY(settings.watermarkX, settings.watermarkY)}[vout]');
      videoMap = '[vout]';
    }

    String? audioMap = inputHasAudio ? '0:a?' : null;
    if (hasMusic) {
      if (inputHasAudio) {
        filterParts
            .add('[0:a]${_audioFilters(speed, settings.originalVolume)}[a0]');
        filterParts.add(
          '[$musicInputIndex:a]volume=${_num(settings.musicVolume)}[a1]',
        );
        filterParts.add(
          '[a0][a1]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[aout]',
        );
      } else {
        filterParts.add(
          '[$musicInputIndex:a]volume=${_num(settings.musicVolume)}[aout]',
        );
      }
      audioMap = '[aout]';
    } else if (needsAudioFilter) {
      filterParts.add(
        '[0:a]${_audioFilters(speed, settings.originalVolume)}[aout]',
      );
      audioMap = '[aout]';
    }

    args.addAll([
      '-filter_complex',
      filterParts.join(';'),
      '-map',
      videoMap,
    ]);
    if (audioMap != null) {
      args.addAll(['-map', audioMap]);
    }
  } else {
    if (videoFilters.isNotEmpty) {
      args.addAll(['-vf', videoFilters.join(',')]);
    }
    if (needsAudioFilter) {
      args.addAll(['-af', _audioFilters(speed, settings.originalVolume)]);
    }
  }

  if (hasMusic) {
    args.addAll(['-shortest']);
  }

  args.addAll([
    ..._videoEncoderArgs(settings, encoder: encoder),
    ..._audioOutputArgs(
      copy: canCopyInputAudio &&
          !hasMusic &&
          speed == 1.0 &&
          settings.originalVolume == 1.0,
    ),
    ..._cleanMp4OutputArgs(),
    job.outputPath,
  ]);
  return args;
}

List<String> _buildStreamCopyArgs(ExportJob job) {
  final settings = job.settings;
  final args = <String>['-y'];
  final trimStart =
      settings.trimStartSeconds < 0 ? 0.0 : settings.trimStartSeconds;
  final trimEnd = settings.trimEndSeconds < 0 ? 0.0 : settings.trimEndSeconds;
  if (trimStart > 0) {
    args.addAll(['-ss', _seconds(trimStart)]);
  }
  if (trimEnd > trimStart) {
    args.addAll(['-t', _seconds(trimEnd - trimStart)]);
  }
  args.addAll([
    '-i',
    job.inputPath,
    '-map',
    '0:v:0',
    '-map',
    '0:a?',
    '-c:v',
    'copy',
    ..._captionFriendlyAudioArgs(),
    '-avoid_negative_ts',
    'make_zero',
    ..._cleanMp4OutputArgs(),
    job.outputPath,
  ]);
  return args;
}

bool _canStreamCopyExport(
  VideoEditSettings settings,
  bool inputHasAudio,
  bool musicHasAudio,
) {
  final hasWatermark =
      settings.watermarkPath != null && settings.watermarkPath!.isNotEmpty;
  final hasMusic = settings.musicPath != null &&
      settings.musicPath!.isNotEmpty &&
      musicHasAudio;
  final hasText = _effectiveTextOverlays(settings).any(
    (overlay) => overlay.text.trim().isNotEmpty,
  );
  return !hasWatermark &&
      !hasMusic &&
      !hasText &&
      _normalizedExportCodec(settings.exportCodec) == 'h264' &&
      !settings.automaticCaptions &&
      settings.captionCues.isEmpty &&
      _safeSpeed(settings.speed) == 1.0 &&
      settings.flip == 'none' &&
      settings.scaleX == 1.0 &&
      settings.scaleY == 1.0 &&
      settings.zoom == 1.0 &&
      settings.canvasMode == 'none' &&
      settings.outputRatio == 'original' &&
      settings.brightness == 0.0 &&
      settings.contrast == 1.0 &&
      settings.saturation == 1.0 &&
      settings.gamma == 1.0 &&
      (!inputHasAudio || settings.originalVolume == 1.0);
}

double _exportDurationSeconds(ExportJob job) {
  final start =
      job.settings.trimStartSeconds < 0 ? 0.0 : job.settings.trimStartSeconds;
  final end =
      job.settings.trimEndSeconds < 0 ? 0.0 : job.settings.trimEndSeconds;
  if (end > start) {
    return (end - start) / _safeSpeed(job.settings.speed);
  }
  return 0;
}

String _normalizedExportCodec(String codec) =>
    codec.trim().toLowerCase() == 'hevc' ? 'hevc' : 'h264';

String _softwareEncoderForCodec(String codec) =>
    _normalizedExportCodec(codec) == 'hevc'
        ? _softwareHevcEncoder
        : _softwareH264Encoder;

bool _isSoftwareEncoder(String encoder) =>
    encoder == _softwareH264Encoder || encoder == _softwareHevcEncoder;

Future<String> _preferredVideoEncoder(
  String codec, {
  ExportCancelToken? cancelToken,
}) async {
  final normalized = _normalizedExportCodec(codec);
  final cached = _preferredVideoEncoders[normalized];
  if (cached != null) return cached;
  final detected = await _detectPreferredVideoEncoder(
    normalized,
    cancelToken: cancelToken,
  );
  if (cancelToken?.isCanceled != true) {
    _preferredVideoEncoders[normalized] = detected;
  }
  return detected;
}

Future<String> _detectPreferredVideoEncoder(
  String codec, {
  ExportCancelToken? cancelToken,
}) async {
  final softwareEncoder = _softwareEncoderForCodec(codec);
  if (Platform.isAndroid || Platform.isIOS) {
    return softwareEncoder;
  }

  final result = await _runProbe(
    _ffmpegExecutable,
    const ['-hide_banner', '-encoders'],
    timeout: const Duration(seconds: 10),
    cancelToken: cancelToken,
  );
  if (result?.exitCode != 0 || cancelToken?.isCanceled == true) {
    return softwareEncoder;
  }
  final encoders = '${result!.stdout}\n${result.stderr}'.toLowerCase();
  for (final encoder in _hardwareEncoderPreference(codec)) {
    if (cancelToken?.isCanceled == true) return softwareEncoder;
    if (encoders.contains(encoder) &&
        await _videoEncoderWorks(encoder, cancelToken: cancelToken)) {
      return encoder;
    }
  }
  return softwareEncoder;
}
