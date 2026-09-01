import 'dart:async';
import 'dart:io';

import '../process/windows_process_job.dart';

final Map<int, Process> _backgroundMediaProcesses = <int, Process>{};
int _backgroundMediaGeneration = 0;

bool get isAndroid => Platform.isAndroid;
bool get isIos => Platform.isIOS;
String get pathSeparator => Platform.pathSeparator;
String basename(String path) => path.split(Platform.pathSeparator).last;
bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

String _bundledToolPath(String executableName) {
  if (!Platform.isWindows) return executableName;

  final appFolder = File(Platform.resolvedExecutable).parent.path;
  final bundledPath = '$appFolder${Platform.pathSeparator}$executableName.exe';
  if (File(bundledPath).existsSync()) {
    return bundledPath;
  }
  return executableName;
}

String get _ffmpegExecutable => _bundledToolPath('ffmpeg');
String get _ffprobeExecutable => _bundledToolPath('ffprobe');

Future<void> cancelBackgroundMediaTasks() async {
  _backgroundMediaGeneration++;
  final processes = List<Process>.of(_backgroundMediaProcesses.values);
  await Future.wait<void>([
    for (final process in processes) _terminateBackgroundProcessTree(process),
  ]);
}

Future<ProcessResult> _runBackgroundMediaProcess(
  String executable,
  List<String> arguments, {
  bool binaryStdout = false,
  void Function(List<int> chunk)? onBinaryStdoutChunk,
  Duration idleTimeout = const Duration(minutes: 2),
}) async {
  final generation = _backgroundMediaGeneration;
  final process = await Process.start(executable, arguments);
  await registerKlipioWorker(process);
  _backgroundMediaProcesses[process.pid] = process;
  var lastActivity = DateTime.now();
  if (generation != _backgroundMediaGeneration) {
    await _terminateBackgroundProcessTree(process);
  }
  final stdoutText = _BoundedBackgroundTextBuffer();
  final stderrText = _BoundedBackgroundTextBuffer();
  final binaryBytes = <int>[];
  final stdoutFuture = process.stdout.listen((chunk) {
    lastActivity = DateTime.now();
    if (binaryStdout) {
      if (onBinaryStdoutChunk != null) {
        onBinaryStdoutChunk(chunk);
      } else if (binaryBytes.length < 8 * 1024 * 1024) {
        final remaining = 8 * 1024 * 1024 - binaryBytes.length;
        binaryBytes.addAll(chunk.take(remaining));
      }
    } else {
      stdoutText.add(systemEncoding.decode(chunk));
    }
  }).asFuture<void>();
  final stderrFuture = process.stderr.listen((chunk) {
    lastActivity = DateTime.now();
    stderrText.add(systemEncoding.decode(chunk));
  }).asFuture<void>();
  final stalled = Completer<int>();
  final stallTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    if (DateTime.now().difference(lastActivity) <= idleTimeout ||
        stalled.isCompleted) {
      return;
    }
    stalled.complete(-2);
    unawaited(_terminateBackgroundProcessTree(process));
  });
  try {
    final exitCode = await Future.any<int>([process.exitCode, stalled.future]);
    await Future.wait<void>([stdoutFuture, stderrFuture])
        .timeout(const Duration(seconds: 3), onTimeout: () => const <void>[]);
    final stderr = exitCode == -2
        ? 'Media worker stopped after ${idleTimeout.inSeconds} seconds with no activity.\n$stderrText'
        : '$stderrText';
    return ProcessResult(
      process.pid,
      exitCode,
      binaryStdout ? binaryBytes : '$stdoutText',
      stderr,
    );
  } finally {
    stallTimer.cancel();
    _backgroundMediaProcesses.remove(process.pid);
  }
}

Future<void> _terminateBackgroundProcessTree(Process process) async {
  await terminateKlipioWorker(process);
}

class _BoundedBackgroundTextBuffer {
  static const int _limit = 64 * 1024;
  final StringBuffer _buffer = StringBuffer();
  int _length = 0;

  void add(String value) {
    if (_length >= _limit || value.isEmpty) return;
    final remaining = _limit - _length;
    final accepted =
        value.length <= remaining ? value : value.substring(0, remaining);
    _buffer.write(accepted);
    _length += accepted.length;
  }

  @override
  String toString() => _buffer.toString();
}

Future<List<String>> videoFilesInFolder(String folderPath) async {
  final directory = Directory(folderPath);
  if (!await directory.exists()) {
    return const [];
  }

  final files = await directory
      .list()
      .where((entity) => entity is File && _isVideoPath(entity.path))
      .map((entity) => entity.path)
      .toList();
  files.sort(
      (a, b) => basename(a).toLowerCase().compareTo(basename(b).toLowerCase()));
  return files;
}

bool _isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.wmv') ||
      lower.endsWith('.flv') ||
      lower.endsWith('.mpeg') ||
      lower.endsWith('.mpg') ||
      lower.endsWith('.mts') ||
      lower.endsWith('.m2ts') ||
      lower.endsWith('.3gp');
}

Future<double?> videoDurationSeconds(String path) async {
  if (!isDesktop) {
    return null;
  }

  final result = await _runBackgroundMediaProcess(_ffprobeExecutable, [
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'default=noprint_wrappers=1:nokey=1',
    path,
  ]);
  if (result.exitCode != 0) {
    return null;
  }
  return double.tryParse('${result.stdout}'.trim());
}

Future<bool> videoHasAudio(String path) async {
  if (!isDesktop) return true;
  try {
    final result = await _runBackgroundMediaProcess(_ffprobeExecutable, [
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
    return result.exitCode == 0 && '${result.stdout}'.trim().isNotEmpty;
  } catch (_) {
    // Keep source audio enabled when probing is unavailable. FFmpeg handles
    // silent inputs safely, while hiding real audio would lose user controls.
    return true;
  }
}

/// Decodes the first audio stream and returns real peak amplitudes at 50 Hz.
///
/// The compact byte cache is invalidated when the source size or modified time
/// changes. Timeline clips can therefore crop this shared source envelope with
/// their own sourceStart/duration without decoding again after every edit.
Future<List<double>> audioWaveformPeaks(
  String path,
  String cacheFolder,
) async {
  if (!isDesktop) return const [];
  try {
    final source = File(path);
    if (!await source.exists()) return const [];
    final stat = await source.stat();
    final cacheDirectory = Directory(cacheFolder);
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    final safeName = path.hashCode.toString().replaceAll('-', 'n');
    final cachePath =
        '${cacheDirectory.path}${Platform.pathSeparator}${safeName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}.waveform';
    final cache = File(cachePath);
    if (await cache.exists()) {
      final bytes = await cache.readAsBytes();
      if (bytes.isNotEmpty) {
        return [for (final value in bytes) value / 255.0];
      }
    }

    const decodeRate = 4000;
    const peaksPerSecond = 50;
    const samplesPerPeak = decodeRate ~/ peaksPerSecond;
    final peaks = <int>[];
    int? lowByte;
    var samplesInPeak = 0;
    var maximum = 0;
    void consumePcm(List<int> chunk) {
      for (final byte in chunk) {
        if (lowByte == null) {
          lowByte = byte;
          continue;
        }
        var signed = lowByte! | (byte << 8);
        lowByte = null;
        if (signed >= 0x8000) signed -= 0x10000;
        final amplitude = signed == -32768 ? 32768 : signed.abs();
        if (amplitude > maximum) maximum = amplitude;
        samplesInPeak++;
        if (samplesInPeak == samplesPerPeak) {
          peaks.add(((maximum / 32768) * 255).round().clamp(0, 255));
          samplesInPeak = 0;
          maximum = 0;
        }
      }
    }

    final result = await _runBackgroundMediaProcess(
      _ffmpegExecutable,
      [
        '-nostdin',
        '-v',
        'error',
        '-threads',
        '2',
        '-i',
        path,
        '-map',
        '0:a:0',
        '-vn',
        '-ac',
        '1',
        '-ar',
        '$decodeRate',
        '-f',
        's16le',
        'pipe:1',
      ],
      binaryStdout: true,
      onBinaryStdoutChunk: consumePcm,
    );
    if (result.exitCode != 0) return const [];
    if (samplesInPeak > 0) {
      peaks.add(((maximum / 32768) * 255).round().clamp(0, 255));
    }
    if (peaks.isNotEmpty) await cache.writeAsBytes(peaks, flush: true);
    return [for (final value in peaks) value / 255.0];
  } catch (_) {
    return const [];
  }
}

Future<double?> audioWindowLevelScore(String path, double start) async {
  if (!isDesktop) return null;
  try {
    final result = await _runBackgroundMediaProcess(
      _ffmpegExecutable,
      [
        '-hide_banner',
        '-nostdin',
        '-ss',
        start.toStringAsFixed(3),
        '-t',
        '5',
        '-threads',
        '2',
        '-i',
        path,
        '-vn',
        '-af',
        'volumedetect',
        '-f',
        'null',
        '-',
      ],
      idleTimeout: const Duration(seconds: 15),
    );
    final output = '${result.stdout}\n${result.stderr}';
    final maxMatch =
        RegExp(r'max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB').firstMatch(output);
    final meanMatch =
        RegExp(r'mean_volume:\s*(-?\d+(?:\.\d+)?)\s*dB').firstMatch(output);
    final maxVolume = double.tryParse(maxMatch?.group(1) ?? '');
    final meanVolume = double.tryParse(meanMatch?.group(1) ?? '');
    if (maxVolume == null && meanVolume == null) return null;
    return (maxVolume ?? -90) * 0.7 + (meanVolume ?? -90) * 0.3;
  } catch (_) {
    return null;
  }
}

Future<String?> thumbnailForVideo(String path, String cacheFolder) async {
  if (!isDesktop) {
    return null;
  }

  final cacheDirectory = Directory(cacheFolder);
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }

  final safeName = path.hashCode.toString().replaceAll('-', 'n');
  final outputPath =
      '${cacheDirectory.path}${Platform.pathSeparator}$safeName.jpg';
  final output = File(outputPath);
  if (await output.exists() && await output.length() > 0) {
    return outputPath;
  }

  final result = await _runBackgroundMediaProcess(_ffmpegExecutable, [
    '-nostdin',
    '-y',
    '-ss',
    '00:00:01',
    '-threads',
    '2',
    '-i',
    path,
    '-frames:v',
    '1',
    '-vf',
    'scale=320:-1',
    outputPath,
  ]);

  if (result.exitCode == 0 &&
      await output.exists() &&
      await output.length() > 0) {
    return outputPath;
  }
  return null;
}

Future<List<String>> timelineThumbnailsForVideo(
  String path,
  String cacheFolder,
  double? durationSeconds,
) async {
  if (!isDesktop || durationSeconds == null || durationSeconds <= 0) {
    return const [];
  }

  final cacheDirectory = Directory(cacheFolder);
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  final safeName = path.hashCode.toString().replaceAll('-', 'n');
  final frameCount = (durationSeconds / 8).ceil().clamp(8, 24);
  final paths = [
    for (var index = 0; index < frameCount; index++)
      '${cacheDirectory.path}${Platform.pathSeparator}${safeName}_timeline_${index.toString().padLeft(2, '0')}.jpg',
  ];
  final missing = <int>[];
  for (var index = 0; index < paths.length; index++) {
    final file = File(paths[index]);
    if (!await file.exists() || await file.length() == 0) missing.add(index);
  }
  if (missing.isEmpty) return paths;

  // Fast input seeking avoids decoding the full video for every timeline frame.
  // Two small workers keep imports responsive without saturating the machine
  // while waveform decoding and video preview are also active.
  for (var offset = 0; offset < missing.length; offset += 2) {
    final batch = missing.skip(offset).take(2);
    await Future.wait([
      for (final index in batch)
        _writeTimelineThumbnail(
          path,
          paths[index],
          durationSeconds * (index + 0.5) / frameCount,
        ),
    ]);
  }
  return [
    for (final outputPath in paths)
      if (await File(outputPath).exists() &&
          await File(outputPath).length() > 0)
        outputPath,
  ];
}

Future<void> _writeTimelineThumbnail(
  String inputPath,
  String outputPath,
  double seconds,
) async {
  await _runBackgroundMediaProcess(_ffmpegExecutable, [
    '-nostdin',
    '-y',
    '-loglevel',
    'error',
    '-ss',
    seconds.toStringAsFixed(3),
    '-threads',
    '2',
    '-i',
    inputPath,
    '-frames:v',
    '1',
    '-vf',
    'scale=160:90:force_original_aspect_ratio=increase,crop=160:90',
    '-q:v',
    '5',
    outputPath,
  ]);
}
