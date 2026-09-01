import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../export/domain/export_models.dart';
import '../../../services/process/windows_process_job.dart';

class CaptionGenerationException implements Exception {
  const CaptionGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PythonCommand {
  const _PythonCommand(this.executable, this.prefixArguments);

  final String executable;
  final List<String> prefixArguments;
}

class _CaptionErrorBuffer {
  static const int _maximumCharacters = 65536;
  final StringBuffer _buffer = StringBuffer();

  void write(Object? value) {
    if (_buffer.length >= _maximumCharacters) return;
    final text = '$value';
    final remaining = _maximumCharacters - _buffer.length;
    _buffer
        .write(text.length <= remaining ? text : text.substring(0, remaining));
  }

  @override
  String toString() => _buffer.toString();
}

Future<String> generateAutomaticCaptionAss(
  ExportJob job, {
  void Function(String status)? onStatus,
  void Function(double progress, String status)? onProgress,
}) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    throw const CaptionGenerationException(
      'Automatic captions currently require the desktop app.',
    );
  }

  final script = await _captionScriptPath();
  final python = await _pythonCommand(cancelToken: job.cancelToken);
  final cacheDirectory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}klipio_whisper_cache',
  );
  await cacheDirectory.create(recursive: true);

  final input = File(job.inputPath);
  final stat = await input.stat();
  final settings = job.settings;
  final identity = Object.hashAll([
    input.absolute.path.toLowerCase(),
    stat.size,
    stat.modified.millisecondsSinceEpoch,
    settings.captionModel,
    settings.captionLanguage,
    settings.captionStyle,
    settings.captionWordsPerLine,
    settings.captionFont,
    settings.captionFontSize,
    settings.captionBold,
    settings.captionUnderline,
    settings.captionItalic,
    settings.captionCase,
    settings.captionColor,
    settings.captionCharacterSpacing,
    settings.captionLineSpacing,
    settings.captionOpacity,
    settings.captionStrokeEnabled,
    settings.captionStrokeColor,
    settings.captionStrokeWidth,
    settings.captionBackgroundEnabled,
    settings.captionBackgroundColor,
    settings.captionBackgroundOpacity,
    settings.captionBackgroundPadding,
    settings.captionGlowEnabled,
    settings.captionGlowColor,
    settings.captionGlowStrength,
    settings.captionShadowEnabled,
    settings.captionShadowColor,
    settings.captionShadowStrength,
    settings.captionCurve,
    settings.speed,
    settings.trimStartSeconds,
    settings.trimEndSeconds,
  ]).abs();
  final output = File(
    '${cacheDirectory.path}${Platform.pathSeparator}caption_$identity.ass',
  );

  final arguments = <String>[
    ...python.prefixArguments,
    script,
    job.inputPath,
    output.path,
    '--cache-dir',
    cacheDirectory.path,
    '--model',
    settings.captionModel,
    '--language',
    settings.captionLanguage,
    '--device',
    settings.captionDevice,
    '--start',
    settings.trimStartSeconds.toStringAsFixed(3),
    '--end',
    settings.trimEndSeconds.toStringAsFixed(3),
    '--words-per-line',
    settings.captionWordsPerLine.toString(),
    '--font',
    settings.captionFont,
    '--font-size',
    settings.captionFontSize.round().toString(),
    '--style',
    settings.captionStyle,
    '--bold',
    settings.captionBold ? '1' : '0',
    '--underline',
    settings.captionUnderline ? '1' : '0',
    '--italic',
    settings.captionItalic ? '1' : '0',
    '--case',
    settings.captionCase,
    '--color',
    settings.captionColor,
    '--character-spacing',
    settings.captionCharacterSpacing.toStringAsFixed(2),
    '--word-spacing',
    settings.captionWordSpacing.toStringAsFixed(2),
    '--line-spacing',
    settings.captionLineSpacing.toStringAsFixed(2),
    '--opacity',
    settings.captionOpacity.toStringAsFixed(3),
    '--stroke-enabled',
    settings.captionStrokeEnabled ? '1' : '0',
    '--stroke-color',
    settings.captionStrokeColor,
    '--stroke-width',
    settings.captionStrokeWidth.toStringAsFixed(2),
    '--background-enabled',
    settings.captionBackgroundEnabled ? '1' : '0',
    '--background-color',
    settings.captionBackgroundColor,
    '--background-opacity',
    settings.captionBackgroundOpacity.toStringAsFixed(3),
    '--background-padding',
    settings.captionBackgroundPadding.toStringAsFixed(2),
    '--glow-enabled',
    settings.captionGlowEnabled ? '1' : '0',
    '--glow-color',
    settings.captionGlowColor,
    '--glow-strength',
    settings.captionGlowStrength.toStringAsFixed(2),
    '--shadow-enabled',
    settings.captionShadowEnabled ? '1' : '0',
    '--shadow-color',
    settings.captionShadowColor,
    '--shadow-strength',
    settings.captionShadowStrength.toStringAsFixed(2),
    '--curve',
    settings.captionCurve.toStringAsFixed(2),
    '--speed',
    settings.speed.toStringAsFixed(4),
  ];

  onStatus?.call('Starting Faster-Whisper captions...');
  var result = await _runCaptionProcess(
    python.executable,
    arguments,
    cancelToken: job.cancelToken,
    onStatus: onStatus,
    onProgress: onProgress,
  );
  if (job.cancelToken?.isCanceled == true) {
    throw const CaptionGenerationException('Export canceled.');
  }
  if (result.exitCode != 0 && settings.captionDevice == 'auto') {
    onStatus
        ?.call('CUDA runtime unavailable. Retrying captions on CPU int8...');
    if (await output.exists()) await output.delete();
    final cpuArguments = List<String>.from(arguments);
    cpuArguments[cpuArguments.indexOf('--device') + 1] = 'cpu';
    result = await _runCaptionProcess(
      python.executable,
      cpuArguments,
      cancelToken: job.cancelToken,
      onStatus: onStatus,
      onProgress: onProgress,
    );
  }

  if (job.cancelToken?.isCanceled == true) {
    throw const CaptionGenerationException('Export canceled.');
  }
  if (result.exitCode != 0 || !await output.exists()) {
    throw CaptionGenerationException(
      result.stderr.isEmpty
          ? 'Faster-Whisper caption generation failed.'
          : result.stderr,
    );
  }
  return output.path;
}

Future<String> generateManualCaptionAss(
  ExportJob job, {
  int playResWidth = 1920,
  int playResHeight = 1080,
}) async {
  final settings = job.settings;
  final safePlayResWidth = playResWidth.clamp(2, 8192);
  final safePlayResHeight = playResHeight.clamp(2, 8192);
  // Caption controls use a 1920x1080 logical design surface. Scale every ASS
  // metric into the actual export surface so portrait and square renders keep
  // the same visual size, outline and draggable center position as Preview.
  final metricScale = safePlayResHeight / 1080.0;
  final cacheDirectory = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}klipio_manual_captions',
  );
  await cacheDirectory.create(recursive: true);
  final identity = Object.hashAll([
    job.inputPath,
    settings.trimStartSeconds,
    settings.trimEndSeconds,
    settings.speed,
    settings.captionFont,
    settings.captionFontSize,
    settings.captionColor,
    settings.captionOpacity,
    settings.captionStrokeColor,
    settings.captionStrokeWidth,
    settings.captionBackgroundEnabled,
    settings.captionBackgroundColor,
    settings.captionBackgroundOpacity,
    settings.captionShadowStrength,
    safePlayResWidth,
    safePlayResHeight,
    for (final cue in settings.captionCues) ...[
      cue.start,
      cue.end,
      cue.text,
      cue.x,
      cue.y,
      for (final word in cue.words) ...[
        word.start,
        word.end,
        word.text,
      ],
    ],
  ]).abs();
  final output = File(
    '${cacheDirectory.path}${Platform.pathSeparator}manual_$identity.ass',
  );
  final speed = settings.speed.clamp(0.25, 4.0).toDouble();
  final trimStart = settings.trimStartSeconds.clamp(0.0, double.infinity);
  final trimEnd = settings.trimEndSeconds > trimStart
      ? settings.trimEndSeconds
      : double.infinity;
  final primary = _manualAssColor(
    settings.captionColor,
    opacity: settings.captionOpacity,
  );
  final outline = _manualAssColor(settings.captionStrokeColor);
  final background = _manualAssColor(
    settings.captionBackgroundColor,
    opacity: settings.captionBackgroundOpacity,
  );
  final borderStyle = settings.captionBackgroundEnabled ? 3 : 1;
  final outlineWidth = settings.captionBackgroundEnabled
      ? settings.captionBackgroundPadding.clamp(0.0, 60.0) * metricScale
      : settings.captionStrokeEnabled
          ? settings.captionStrokeWidth.clamp(0.0, 30.0) * metricScale
          : 0.0;
  final shadow = settings.captionShadowEnabled
      ? settings.captionShadowStrength.clamp(0.0, 30.0) * metricScale
      : 0.0;
  final font = settings.captionFont.replaceAll(',', ' ').trim();
  final fontSize = (settings.captionFontSize * metricScale).clamp(1.0, 1000.0);
  final spacing = settings.captionCharacterSpacing * metricScale;
  final style = 'Style: Manual,${font.isEmpty ? 'Arial' : font},'
      '${fontSize.round()},$primary,$primary,$outline,$background,'
      '${settings.captionBold ? -1 : 0},${settings.captionItalic ? -1 : 0},'
      '${settings.captionUnderline ? -1 : 0},0,100,100,'
      '${spacing.toStringAsFixed(2)},0,$borderStyle,'
      // Alignment 5 anchors \\pos at the caption's center. Flutter Preview
      // also centers the caption widget on cue.x/cue.y; alignment 2 anchored
      // the exported text by its bottom edge and pushed it visibly too low.
      '${outlineWidth.toStringAsFixed(2)},${shadow.toStringAsFixed(2)},5,30,30,80,1';
  final events = <String>[];
  for (final cue in settings.captionCues) {
    final sourceStart = cue.start.clamp(trimStart, trimEnd).toDouble();
    final sourceEnd = cue.end.clamp(trimStart, trimEnd).toDouble();
    if (sourceEnd <= sourceStart || cue.text.trim().isEmpty) continue;
    final start = (sourceStart - trimStart) / speed;
    final end = (sourceEnd - trimStart) / speed;
    final text = _manualCaptionText(settings.captionCase, cue.text);
    final karaokeWords = cue.words
        .where((word) => word.end > sourceStart && word.start < sourceEnd)
        .toList();
    final renderedText = karaokeWords.isEmpty
        ? _manualAssText(text)
        : karaokeWords.map((word) {
            final wordStart = word.start.clamp(sourceStart, sourceEnd);
            final wordEnd = word.end.clamp(sourceStart, sourceEnd);
            final centiseconds =
                (((wordEnd - wordStart) / speed) * 100).round().clamp(1, 9999);
            return '{\\k$centiseconds}'
                '${_manualAssText(_manualCaptionText(settings.captionCase, word.text))}';
          }).join(r'\h');
    final position =
        '{\\pos(${(cue.x.clamp(0.0, 1.0) * safePlayResWidth).round()},'
        '${(cue.y.clamp(0.0, 1.0) * safePlayResHeight).round()})}';
    events.add(
      'Dialogue: 0,${_manualAssTime(start)},${_manualAssTime(end)},Manual,,0,0,0,,$position$renderedText',
    );
  }
  final contents = '[Script Info]\n'
      'ScriptType: v4.00+\n'
      'PlayResX: $safePlayResWidth\n'
      'PlayResY: $safePlayResHeight\n'
      'WrapStyle: 0\n'
      'ScaledBorderAndShadow: yes\n\n'
      '[V4+ Styles]\n'
      'Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding\n'
      '$style\n\n'
      '[Events]\n'
      'Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text\n'
      '${events.join('\n')}\n';
  await output.writeAsString(contents, flush: true);
  return output.path;
}

String _manualAssTime(double seconds) {
  final safe = seconds.clamp(0.0, 359999.0).toDouble();
  final hours = safe ~/ 3600;
  final minutes = (safe ~/ 60) % 60;
  final remaining = safe - hours * 3600 - minutes * 60;
  return '$hours:${minutes.toString().padLeft(2, '0')}:'
      '${remaining.toStringAsFixed(2).padLeft(5, '0')}';
}

String _manualAssText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('{', r'\{')
    .replaceAll('}', r'\}')
    .replaceAll('\r\n', r'\N')
    .replaceAll('\n', r'\N');

String _manualCaptionText(String letterCase, String text) {
  return switch (letterCase) {
    'upper' => text.toUpperCase(),
    'lower' => text.toLowerCase(),
    'title' => text.splitMapJoin(
        RegExp(r'\S+'),
        onMatch: (match) {
          final part = match.group(0)!;
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        },
      ),
    _ => text,
  };
}

String _manualAssColor(String input, {double opacity = 1}) {
  var hex = input.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((value) => '$value$value').join();
  }
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) hex = 'FFFFFF';
  final red = hex.substring(0, 2);
  final green = hex.substring(2, 4);
  final blue = hex.substring(4, 6);
  final alpha = ((1 - opacity.clamp(0.0, 1.0)) * 255)
      .round()
      .toRadixString(16)
      .padLeft(2, '0');
  return '&H${alpha.toUpperCase()}${blue.toUpperCase()}${green.toUpperCase()}${red.toUpperCase()}';
}

Future<_CaptionProcessResult> _runCaptionProcess(
  String executable,
  List<String> arguments, {
  ExportCancelToken? cancelToken,
  void Function(String status)? onStatus,
  void Function(double progress, String status)? onProgress,
}) async {
  if (cancelToken?.isCanceled == true) {
    return const _CaptionProcessResult(-1, 'Export canceled.');
  }
  Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      runInShell: false,
      environment: const <String, String>{
        'OMP_NUM_THREADS': '4',
        'MKL_NUM_THREADS': '4',
        'OPENBLAS_NUM_THREADS': '4',
        'NUMEXPR_NUM_THREADS': '4',
      },
    );
  } on ProcessException catch (error) {
    throw CaptionGenerationException(
      'Could not start Faster-Whisper: ${error.message}',
    );
  }
  await registerKlipioWorker(process);
  final stderr = _CaptionErrorBuffer();
  var lastWorkerActivity = DateTime.now();
  final stdoutDone = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .listen((line) {
    lastWorkerActivity = DateTime.now();
    if (line.startsWith('PROGRESS:')) {
      final fields = line.split(':');
      if (fields.length >= 3) {
        final status = fields.sublist(2).join(':');
        final percent = double.tryParse(fields[1]);
        onStatus?.call(status);
        if (percent != null) {
          onProgress?.call((percent / 100).clamp(0, 1), status);
        }
      }
    }
  }).asFuture<void>();
  final stderrDone = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen((chunk) {
    lastWorkerActivity = DateTime.now();
    stderr.write(chunk);
  }).asFuture<void>();

  final processExit = process.exitCode;
  cancelToken?.trackOperation(processExit.then<void>((_) {}));
  final stalled = Completer<void>();
  final stallTimer = Timer.periodic(const Duration(seconds: 20), (_) {
    if (DateTime.now().difference(lastWorkerActivity) >=
            const Duration(minutes: 10) &&
        !stalled.isCompleted) {
      stalled.complete();
    }
  });
  final outcome = await Future.any<int>([
    processExit,
    if (cancelToken != null) cancelToken.whenCanceled.then<int>((_) => -1),
    stalled.future.then<int>((_) => -3),
  ]);
  var exitCode = outcome;
  if (outcome < 0) {
    await _terminateCaptionProcessTree(process);
    exitCode = await processExit.timeout(
      const Duration(seconds: 3),
      onTimeout: () => outcome,
    );
  }
  stallTimer.cancel();
  try {
    await Future.wait([stdoutDone, stderrDone])
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // A force-terminated Python tree can release its pipes slightly later.
  }

  if (outcome == -3) {
    return const _CaptionProcessResult(
      -3,
      'Caption analysis made no progress for 10 minutes and was stopped to keep Windows responsive. Try the tiny model or a shorter edited range.',
    );
  }

  return _CaptionProcessResult(exitCode, stderr.toString().trim());
}

Future<void> _terminateCaptionProcessTree(Process process) async {
  await terminateKlipioWorker(process);
}

class _CaptionProcessResult {
  const _CaptionProcessResult(this.exitCode, this.stderr);

  final int exitCode;
  final String stderr;
}

Future<String> _captionScriptPath() async {
  final separator = Platform.pathSeparator;
  final executableFolder = File(Platform.resolvedExecutable).parent.path;
  final candidates = <String>[
    '${Directory.current.path}${separator}assets${separator}scripts${separator}ultra_fast_captions.py',
    '$executableFolder${separator}data${separator}flutter_assets${separator}assets${separator}scripts${separator}ultra_fast_captions.py',
    '$executableFolder${separator}assets${separator}scripts${separator}ultra_fast_captions.py',
  ];
  for (final candidate in candidates) {
    if (await File(candidate).exists()) return File(candidate).absolute.path;
  }
  throw const CaptionGenerationException(
    'The automatic-caption helper was not found in the app bundle.',
  );
}

Future<_PythonCommand> _pythonCommand({
  ExportCancelToken? cancelToken,
}) async {
  final configured = Platform.environment['KLIPIO_PYTHON']?.trim();
  final executableFolder = File(Platform.resolvedExecutable).parent.path;
  final candidates = <_PythonCommand>[
    if (configured != null && configured.isNotEmpty)
      _PythonCommand(configured, const []),
    if (Platform.isWindows)
      _PythonCommand(
        '$executableFolder${Platform.pathSeparator}python${Platform.pathSeparator}python.exe',
        const [],
      ),
    if (Platform.isWindows) const _PythonCommand('py', ['-3']),
    const _PythonCommand('python', []),
    if (!Platform.isWindows) const _PythonCommand('python3', []),
  ];

  for (final candidate in candidates) {
    if (cancelToken?.isCanceled == true) {
      throw const CaptionGenerationException('Export canceled.');
    }
    try {
      final result = await _runCaptionProcess(
        candidate.executable,
        [...candidate.prefixArguments, '--version'],
        cancelToken: cancelToken,
      );
      if (result.exitCode == 0) return candidate;
    } on CaptionGenerationException {
      if (cancelToken?.isCanceled == true) rethrow;
      // Try the next conventional Python location.
    }
  }
  throw const CaptionGenerationException(
    'Python 3 was not found. Install Python 3, then run: '
    'python -m pip install -r tool/requirements-captions.txt',
  );
}
