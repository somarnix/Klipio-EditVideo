part of 'export_service_io.dart';

Future<({double width, double height})?> _probeVideoDimensions(
    String path, ExportCancelToken? cancelToken) async {
  final args = [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=width,height,sample_aspect_ratio:stream_side_data=rotation',
    '-of',
    'json',
    path
  ];
  String? output;
  if (Platform.isAndroid || Platform.isIOS) {
    final session = await FFprobeKit.executeWithArguments(args);
    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      output = await session.getOutput();
    }
  } else {
    final result = await _runProbe(_ffprobeExecutable, args,
        timeout: const Duration(seconds: 10), cancelToken: cancelToken);
    if (result?.exitCode == 0) output = result!.stdout;
  }
  if (output == null) return null;
  try {
    final stream = (jsonDecode(output)['streams'] as List).first as Map;
    var width = (stream['width'] as num).toDouble();
    var height = (stream['height'] as num).toDouble();
    final sar = '${stream['sample_aspect_ratio']}'.split(':');
    if (sar.length == 2) {
      final numerator = double.tryParse(sar[0]) ?? 1;
      final denominator = double.tryParse(sar[1]) ?? 1;
      if (numerator > 0 && denominator > 0) width *= numerator / denominator;
    }
    for (final side in stream['side_data_list'] as List? ?? []) {
      final rotation = ((side as Map)['rotation'] as num?)?.toDouble() ?? 0;
      if (rotation.abs() % 180 == 90) {
        final previousWidth = width;
        width = height;
        height = previousWidth;
      }
    }
    return width > 0 && height > 0 ? (width: width, height: height) : null;
  } catch (_) {
    return null;
  }
}

Future<bool> _probeAudioStream(
  String path, {
  ExportCancelToken? cancelToken,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final session = await FFprobeKit.executeWithArguments([
      '-v',
      'error',
      '-select_streams',
      'a:0',
      '-show_entries',
      'stream=index',
      '-of',
      'csv=p=0',
      path,
    ]);
    final returnCode = await session.getReturnCode();
    final output = await session.getOutput();
    return ReturnCode.isSuccess(returnCode) && (output ?? '').trim().isNotEmpty;
  }

  final result = await _runProbe(
    _ffprobeExecutable,
    [
      '-v',
      'error',
      '-select_streams',
      'a:0',
      '-show_entries',
      'stream=index',
      '-of',
      'csv=p=0',
      path,
    ],
    timeout: const Duration(seconds: 10),
    cancelToken: cancelToken,
  );
  return result?.exitCode == 0 && result!.stdout.trim().isNotEmpty;
}

Future<String?> _videoCodec(
  String path, {
  ExportCancelToken? cancelToken,
}) {
  if (cancelToken != null) {
    return _probeVideoCodec(path, cancelToken: cancelToken);
  }
  final key = File(path).absolute.path.toLowerCase();
  return _videoCodecProbeFutures.putIfAbsent(
    key,
    () => _probeVideoCodec(path),
  );
}

Future<String?> _probeVideoCodec(
  String path, {
  ExportCancelToken? cancelToken,
}) async {
  if (Platform.isAndroid || Platform.isIOS) return null;
  final result = await _runProbe(
    _ffprobeExecutable,
    [
      '-v',
      'error',
      '-select_streams',
      'v:0',
      '-show_entries',
      'stream=codec_name',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ],
    timeout: const Duration(seconds: 10),
    cancelToken: cancelToken,
  );
  if (result?.exitCode != 0) return null;
  final codec = result!.stdout.trim().toLowerCase();
  return codec.isEmpty ? null : codec;
}

bool _safeAutomaticHardwareDecodeCodec(String codec) =>
    const {'h264', 'hevc', 'mpeg2video', 'vc1'}.contains(codec);

Future<bool> _canCopyAudioToMp4(
  String path, {
  ExportCancelToken? cancelToken,
}) async {
  String codec;
  if (Platform.isAndroid || Platform.isIOS) {
    final session = await FFprobeKit.executeWithArguments([
      '-v',
      'error',
      '-select_streams',
      'a:0',
      '-show_entries',
      'stream=codec_name',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) return false;
    codec = (await session.getOutput() ?? '').trim().toLowerCase();
  } else {
    final result = await _runProbe(
      _ffprobeExecutable,
      [
        '-v',
        'error',
        '-select_streams',
        'a:0',
        '-show_entries',
        'stream=codec_name',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        path,
      ],
      timeout: const Duration(seconds: 10),
      cancelToken: cancelToken,
    );
    if (result?.exitCode != 0) return false;
    codec = result!.stdout.trim().toLowerCase();
  }
  return const {'aac', 'mp3', 'ac3', 'eac3', 'alac'}.contains(codec);
}

Future<double> _mediaDuration(
  String path, {
  ExportCancelToken? cancelToken,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final session = await FFprobeKit.executeWithArguments([
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    final output = await session.getOutput();
    return double.tryParse((output ?? '').trim()) ?? 0;
  }

  final result = await _runProbe(
    _ffprobeExecutable,
    [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ],
    timeout: const Duration(seconds: 10),
    cancelToken: cancelToken,
  );
  if (result?.exitCode != 0) {
    return 0;
  }
  return double.tryParse(result!.stdout.trim()) ?? 0;
}

Future<bool> _canConcatWithCopy(
  List<String> clipPaths, {
  ExportCancelToken? cancelToken,
}) async {
  if (clipPaths.length < 2) return true;
  String? firstSignature;
  for (final path in clipPaths) {
    final signature = await _streamCopySignature(
      path,
      cancelToken: cancelToken,
    );
    if (signature == null || signature.isEmpty) {
      return false;
    }
    firstSignature ??= signature;
    if (signature != firstSignature) {
      return false;
    }
  }
  return true;
}

Future<String?> _streamCopySignature(
  String path, {
  ExportCancelToken? cancelToken,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return null;
  }

  final result = await _runProbe(
    _ffprobeExecutable,
    [
      '-v',
      'error',
      '-show_entries',
      'stream=codec_type,codec_name,width,height,r_frame_rate,sample_rate,channels',
      '-of',
      'csv=p=0',
      path,
    ],
    timeout: const Duration(seconds: 10),
    cancelToken: cancelToken,
  );
  if (result?.exitCode != 0) {
    return null;
  }
  final lines = result!.stdout
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList()
    ..sort();
  return lines.join('|');
}

Future<ExportResult> _concatRenderedClipsWithCopy(
  List<String> clipPaths,
  String outputPath, {
  required double durationSeconds,
  void Function(double progress, String status)? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final listFile = File(
    '${ApplicationPaths.temporary.path}${Platform.pathSeparator}klipio_concat_${DateTime.now().microsecondsSinceEpoch}.txt',
  );
  final contents = clipPaths.map((path) {
    final normalized = path.replaceAll(r'\', '/');
    final escaped = normalized.replaceAll("'", r"'\''");
    return "file '$escaped'";
  }).join('\n');
  await listFile.writeAsString(contents);
  try {
    final result = await _runFfmpeg(
      [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        listFile.path,
        '-c',
        'copy',
        ..._cleanMp4OutputArgs(),
        outputPath,
      ],
      durationSeconds: durationSeconds,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (result.success) {
      return ExportResult(
        success: true,
        message: 'Timeline export complete.',
        outputPath: outputPath,
      );
    }
    return ExportResult(success: false, message: result.message);
  } finally {
    if (await listFile.exists()) {
      await listFile.delete();
    }
  }
}

Future<ExportResult> _concatRenderedClips(
  List<String> clipPaths,
  String outputPath, {
  required VideoEditSettings settings,
  required bool musicHasAudio,
  void Function(double progress, String status)? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  final args = <String>['-y'];
  final clipHasAudio = <bool>[];
  final clipDurations = <double>[];
  for (final path in clipPaths) {
    args.addAll(['-i', path]);
    clipHasAudio.add(
      await _hasAudioStream(path, cancelToken: cancelToken),
    );
    clipDurations.add(
      await _mediaDuration(path, cancelToken: cancelToken),
    );
  }

  final hasMusic = settings.musicPath != null &&
      settings.musicPath!.isNotEmpty &&
      musicHasAudio;
  if (!hasMusic &&
      await _canConcatWithCopy(clipPaths, cancelToken: cancelToken)) {
    final copyResult = await _concatRenderedClipsWithCopy(
      clipPaths,
      outputPath,
      durationSeconds:
          clipDurations.fold<double>(0, (sum, value) => sum + value),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (copyResult.success) {
      return copyResult;
    }
  }

  int? musicInputIndex;
  if (hasMusic) {
    musicInputIndex = clipPaths.length;
    args.addAll(['-i', settings.musicPath!]);
  }

  final filterParts = <String>[];
  final concatInputs = <String>[];
  for (var index = 0; index < clipPaths.length; index++) {
    filterParts.add('[$index:v]setpts=PTS-STARTPTS[v$index]');
    concatInputs.add('[v$index]');
    if (clipHasAudio[index]) {
      filterParts.add('[$index:a]asetpts=PTS-STARTPTS[a$index]');
    } else {
      final duration = clipDurations[index] <= 0 ? 0.1 : clipDurations[index];
      filterParts.add(
        'anullsrc=channel_layout=stereo:sample_rate=44100,atrim=duration=${_num(duration)}[a$index]',
      );
    }
    concatInputs.add('[a$index]');
  }

  filterParts.add(
    '${concatInputs.join()}concat=n=${clipPaths.length}:v=1:a=1[vcat][acat]',
  );

  var audioMap = '[acat]';
  if (hasMusic) {
    filterParts.add(
      '[$musicInputIndex:a]volume=${_num(settings.musicVolume)}[music]',
    );
    filterParts.add(
      '[acat][music]amix=inputs=2:duration=first:dropout_transition=2:normalize=0[aout]',
    );
    audioMap = '[aout]';
  }

  final softwareEncoder = _softwareEncoderForCodec(settings.exportCodec);
  final encoder = settings.hardwareEncoding
      ? await _preferredVideoEncoder(
          settings.exportCodec,
          cancelToken: cancelToken,
        )
      : softwareEncoder;
  args.addAll([
    '-filter_complex',
    filterParts.join(';'),
    '-map',
    '[vcat]',
    '-map',
    audioMap,
    ..._videoEncoderArgs(settings, encoder: encoder),
    ..._captionFriendlyAudioArgs(),
    ..._cleanMp4OutputArgs(),
    outputPath,
  ]);
  if (hasMusic) {
    args.insert(args.length - 1, '-shortest');
  }

  final durationSeconds =
      clipDurations.fold<double>(0, (sum, value) => sum + value);
  final result = await _runFfmpegWithEncoderFallback(
    args: args,
    encoder: encoder,
    fallbackArgs: () async {
      final fallbackArgs = List<String>.from(args);
      final encoderStart = fallbackArgs.indexOf('-c:v');
      if (encoderStart >= 0) {
        final output = fallbackArgs.removeLast();
        fallbackArgs.removeRange(encoderStart, fallbackArgs.length);
        fallbackArgs.addAll([
          ..._videoEncoderArgs(settings, encoder: softwareEncoder),
          ..._captionFriendlyAudioArgs(),
          ..._cleanMp4OutputArgs(),
          output,
        ]);
      }
      return fallbackArgs;
    },
    durationSeconds: durationSeconds,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );
  if (result.success) {
    return ExportResult(
      success: true,
      message: 'Timeline export complete.',
      outputPath: outputPath,
    );
  }
  final error = result.message.trim();
  return ExportResult(
    success: false,
    message: error.isEmpty ? 'Timeline concat failed.' : error,
  );
}

bool get isDesktopExportPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class _ProbeResult {
  const _ProbeResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

class _BoundedTextBuffer {
  _BoundedTextBuffer();

  static const int maximumCharacters = 65536;
  final StringBuffer _buffer = StringBuffer();

  void write(Object? value) {
    if (_buffer.length >= maximumCharacters) return;
    final text = '$value';
    final remaining = maximumCharacters - _buffer.length;
    _buffer
        .write(text.length <= remaining ? text : text.substring(0, remaining));
  }

  void writeln(Object? value) => write('$value\n');

  @override
  String toString() => _buffer.toString();
}

Future<_ProbeResult?> _runProbe(
  String executable,
  List<String> arguments, {
  required Duration timeout,
  ExportCancelToken? cancelToken,
}) async {
  if (cancelToken?.isCanceled == true) {
    return const _ProbeResult(exitCode: -2, stdout: '', stderr: 'Canceled');
  }
  try {
    final process = await Process.start(executable, arguments);
    await registerKlipioWorker(process);
    final processExit = process.exitCode;
    cancelToken?.trackOperation(processExit.then<void>((_) {}));
    final stdoutFuture =
        process.stdout.transform(systemEncoding.decoder).join();
    final stderrFuture =
        process.stderr.transform(systemEncoding.decoder).join();
    final outcome = await Future.any<int>([
      processExit,
      Future<int>.delayed(timeout, () => -1),
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
    final output = await Future.wait([stdoutFuture, stderrFuture]);
    return _ProbeResult(
      exitCode: exitCode,
      stdout: output[0],
      stderr: output[1],
    );
  } on ProcessException {
    return null;
  }
}

Future<void> _deleteIncompleteExport(String outputPath) async {
  try {
    final output = File(outputPath);
    if (await output.exists()) await output.delete();
  } catch (_) {
    // A locked partial file can be cleaned up by the next export attempt.
  }
}

Future<void> _recordUnexpectedExportError({
  required String operation,
  required String? inputPath,
  required String outputPath,
  required Object error,
  required StackTrace stackTrace,
}) async {
  try {
    final directory = Directory(
      ApplicationPaths.logs.path,
    );
    await directory.create(recursive: true);
    final log = File(
      '${directory.path}${Platform.pathSeparator}export-errors.log',
    );
    final stack = '$stackTrace';
    await log.writeAsString(
      '${DateTime.now().toIso8601String()} [$operation]\r\n'
      'Input: ${inputPath ?? '(multiple timeline inputs)'}\r\n'
      'Output: $outputPath\r\n'
      'Error: $error\r\n'
      '${stack.length > 12000 ? stack.substring(0, 12000) : stack}\r\n\r\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Diagnostics must never become a second export failure.
  }
}

Future<void> _terminateProcessTree(Process process) async {
  await terminateKlipioWorker(process);
}
