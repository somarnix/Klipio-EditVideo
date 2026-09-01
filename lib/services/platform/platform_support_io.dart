import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../process/windows_process_job.dart';
import '../tasks/media_job_manager.dart';

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

typedef MediaProbeInfo = ({
  double? durationSeconds,
  int width,
  int height,
  double frameRate,
  String videoCodec,
  int bitrate,
  bool hasAudio,
});

typedef AudioWaveformLod = ({
  List<double> peaks,
  double peaksPerSecond,
});

Future<void> cancelBackgroundMediaTasks() async {
  _backgroundMediaGeneration++;
  final processes = List<Process>.of(_backgroundMediaProcesses.values);
  await Future.wait<void>([
    MediaJobManager.instance.cancelScope('project-media'),
    for (final process in processes) _terminateBackgroundProcessTree(process),
  ]);
}

Future<ProcessResult> _runBackgroundMediaProcess(
  String executable,
  List<String> arguments, {
  required MediaJobType jobType,
  MediaJobPriority priority = MediaJobPriority.normal,
  bool binaryStdout = false,
  void Function(List<int> chunk)? onBinaryStdoutChunk,
  Duration idleTimeout = const Duration(minutes: 2),
}) async {
  try {
    return await MediaJobManager.instance.schedule<ProcessResult>(
      type: jobType,
      priority: priority,
      scopeId: 'project-media',
      task: (cancellationToken) => _executeBackgroundMediaProcess(
        executable,
        arguments,
        cancellationToken: cancellationToken,
        binaryStdout: binaryStdout,
        onBinaryStdoutChunk: onBinaryStdoutChunk,
        idleTimeout: idleTimeout,
      ),
    );
  } on MediaJobCanceledException {
    return ProcessResult(-1, -3, binaryStdout ? <int>[] : '', 'Canceled');
  }
}

Future<ProcessResult> _executeBackgroundMediaProcess(
  String executable,
  List<String> arguments, {
  required MediaJobCancellationToken cancellationToken,
  bool binaryStdout = false,
  void Function(List<int> chunk)? onBinaryStdoutChunk,
  Duration idleTimeout = const Duration(minutes: 2),
}) async {
  final generation = _backgroundMediaGeneration;
  cancellationToken.throwIfCanceled();
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
    final exitCode = await Future.any<int>([
      process.exitCode,
      stalled.future,
      cancellationToken.whenCanceled.then((_) => -3),
    ]);
    if (exitCode == -3) {
      await _terminateBackgroundProcessTree(process);
    }
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

Future<MediaProbeInfo> probeMedia(String path) async {
  const fallback = (
    durationSeconds: null,
    width: 0,
    height: 0,
    frameRate: 0.0,
    videoCodec: 'unknown',
    bitrate: 0,
    hasAudio: true,
  );
  if (!isDesktop) return fallback;
  try {
    final result = await _runBackgroundMediaProcess(
      _ffprobeExecutable,
      [
        '-v',
        'error',
        '-show_entries',
        'format=duration,bit_rate:stream=codec_type,codec_name,width,height,avg_frame_rate,r_frame_rate',
        '-of',
        'json',
        path,
      ],
      jobType: MediaJobType.probe,
      priority: MediaJobPriority.high,
    );
    if (result.exitCode != 0) return fallback;
    final decoded = jsonDecode('${result.stdout}');
    if (decoded is! Map) return fallback;
    final streams = decoded['streams'] as List? ?? const [];
    Map? video;
    var hasAudio = false;
    for (final stream in streams) {
      if (stream is! Map) continue;
      if (stream['codec_type'] == 'video' && video == null) video = stream;
      if (stream['codec_type'] == 'audio') hasAudio = true;
    }
    final format = decoded['format'] is Map ? decoded['format'] as Map : null;
    return (
      durationSeconds: double.tryParse('${format?['duration'] ?? ''}'),
      width: int.tryParse('${video?['width'] ?? ''}') ?? 0,
      height: int.tryParse('${video?['height'] ?? ''}') ?? 0,
      frameRate: _parseFrameRate(
        '${video?['avg_frame_rate'] ?? video?['r_frame_rate'] ?? ''}',
      ),
      videoCodec: '${video?['codec_name'] ?? 'unknown'}'.toLowerCase(),
      bitrate: int.tryParse('${format?['bit_rate'] ?? ''}') ?? 0,
      hasAudio: hasAudio,
    );
  } catch (_) {
    return fallback;
  }
}

double _parseFrameRate(String value) {
  final parts = value.split('/');
  if (parts.length == 2) {
    final numerator = double.tryParse(parts[0]);
    final denominator = double.tryParse(parts[1]);
    if (numerator != null && denominator != null && denominator != 0) {
      return numerator / denominator;
    }
  }
  return double.tryParse(value) ?? 0;
}

Future<double?> videoDurationSeconds(String path) async {
  if (!isDesktop) {
    return null;
  }

  final result = await _runBackgroundMediaProcess(
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
      jobType: MediaJobType.probe,
      priority: MediaJobPriority.high);
  if (result.exitCode != 0) {
    return null;
  }
  return double.tryParse('${result.stdout}'.trim());
}

Future<bool> videoHasAudio(String path) async {
  if (!isDesktop) return true;
  try {
    final result = await _runBackgroundMediaProcess(
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
        jobType: MediaJobType.probe,
        priority: MediaJobPriority.high);
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
) async =>
    (await audioWaveformLod(path, cacheFolder)).peaks;

Future<AudioWaveformLod> audioWaveformLod(
  String path,
  String cacheFolder, {
  double? durationSeconds,
}) async {
  if (!isDesktop) {
    return (peaks: const <double>[], peaksPerSecond: 20.0);
  }
  try {
    final source = File(path);
    if (!await source.exists()) {
      return (peaks: const <double>[], peaksPerSecond: 20.0);
    }
    final stat = await source.stat();
    final cacheDirectory = Directory(cacheFolder);
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    final duration = durationSeconds ?? await videoDurationSeconds(path) ?? 0;
    final peaksPerSecond =
        duration <= 0 ? 20.0 : (60000 / duration).clamp(2.0, 50.0).toDouble();
    final roundedRate = peaksPerSecond.toStringAsFixed(3);
    final safeName = path.hashCode.toString().replaceAll('-', 'n');
    final cachePath =
        '${cacheDirectory.path}${Platform.pathSeparator}${safeName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_$roundedRate.waveform-v2';
    final cache = File(cachePath);
    if (await cache.exists()) {
      final bytes = await cache.readAsBytes();
      if (bytes.isNotEmpty) {
        return (
          peaks: [for (final value in bytes) value / 255.0],
          peaksPerSecond: peaksPerSecond,
        );
      }
    }

    final decodeRate = (peaksPerSecond * 80).round().clamp(400, 4000);
    final samplesPerPeak = math.max(1, (decodeRate / peaksPerSecond).round());
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
      jobType: MediaJobType.waveform,
      priority: MediaJobPriority.low,
    );
    if (result.exitCode != 0) {
      return (peaks: const <double>[], peaksPerSecond: peaksPerSecond);
    }
    if (samplesInPeak > 0) {
      peaks.add(((maximum / 32768) * 255).round().clamp(0, 255));
    }
    if (peaks.isNotEmpty) {
      await cache.writeAsBytes(peaks, flush: true);
      unawaited(
        _trimMediaCache(
          cacheDirectory,
          maximumFiles: 128,
          maximumBytes: 64 * 1024 * 1024,
        ),
      );
    }
    return (
      peaks: [for (final value in peaks) value / 255.0],
      peaksPerSecond: peaksPerSecond,
    );
  } catch (_) {
    return (peaks: const <double>[], peaksPerSecond: 20.0);
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
      jobType: MediaJobType.probe,
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

  final result = await _runBackgroundMediaProcess(
      _ffmpegExecutable,
      [
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
      ],
      jobType: MediaJobType.thumbnail);

  if (result.exitCode == 0 &&
      await output.exists() &&
      await output.length() > 0) {
    unawaited(
      _trimMediaCache(
        cacheDirectory,
        maximumFiles: 512,
        maximumBytes: 256 * 1024 * 1024,
      ),
    );
    return outputPath;
  }
  return null;
}

Future<List<String>> timelineThumbnailsForVideo(
  String path,
  String cacheFolder,
  double? durationSeconds, {
  double? visibleSourceStart,
  double? visibleSourceEnd,
}) async {
  if (!isDesktop || durationSeconds == null || durationSeconds <= 0) {
    return const [];
  }

  final cacheDirectory = Directory(cacheFolder);
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  final safeName = path.hashCode.toString().replaceAll('-', 'n');
  final frameCount = (durationSeconds / 5).ceil().clamp(8, 240);
  final paths = [
    for (var index = 0; index < frameCount; index++)
      '${cacheDirectory.path}${Platform.pathSeparator}${safeName}_timeline_${index.toString().padLeft(2, '0')}.jpg',
  ];
  final requestedStart = (visibleSourceStart ?? 0).clamp(0.0, durationSeconds);
  final requestedEnd = (visibleSourceEnd ?? math.min(durationSeconds, 45.0))
      .clamp(requestedStart, durationSeconds);
  final buffer = math.max(10.0, (requestedEnd - requestedStart) * 0.15);
  final rangeStart = math.max(0.0, requestedStart - buffer);
  final rangeEnd = math.min(durationSeconds, requestedEnd + buffer);
  var candidateIndices = <int>[
    for (var index = 0; index < paths.length; index++)
      if (durationSeconds * (index + 0.5) / frameCount >= rangeStart &&
          durationSeconds * (index + 0.5) / frameCount <= rangeEnd)
        index,
  ];
  if (candidateIndices.isEmpty) {
    candidateIndices = <int>[
      ((requestedStart / durationSeconds) * frameCount)
          .floor()
          .clamp(0, frameCount - 1),
    ];
  }
  if (candidateIndices.length > 32) {
    candidateIndices = <int>[
      for (var sample = 0; sample < 32; sample++)
        candidateIndices[(sample * (candidateIndices.length - 1) / 31).round()],
    ];
  }
  final missing = <int>[];
  for (final index in candidateIndices) {
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
  unawaited(
    _trimMediaCache(
      cacheDirectory,
      maximumFiles: 512,
      maximumBytes: 256 * 1024 * 1024,
    ),
  );
  // Preserve the complete time grid. Missing files remain lightweight blank
  // slots until their viewport is requested, so indices always map to the
  // correct source timestamp.
  return paths;
}

Future<void> _writeTimelineThumbnail(
  String inputPath,
  String outputPath,
  double seconds,
) async {
  await _runBackgroundMediaProcess(
      _ffmpegExecutable,
      [
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
      ],
      jobType: MediaJobType.thumbnail,
      priority: MediaJobPriority.low);
}

bool mediaNeedsProxy(MediaProbeInfo info) {
  final pixels = info.width * info.height;
  final codec = info.videoCodec.toLowerCase();
  return pixels >= 2560 * 1440 ||
      info.frameRate > 45 ||
      info.bitrate > 18 * 1000 * 1000 ||
      codec == 'hevc' ||
      codec == 'h265' ||
      codec == 'av1' ||
      (info.durationSeconds ?? 0) >= 20 * 60;
}

Future<String?> generateProxyMedia(
  String path,
  String cacheFolder, {
  String resolution = '720p',
}) async {
  if (!isDesktop) return null;
  try {
    final source = File(path);
    if (!await source.exists()) return null;
    final stat = await source.stat();
    final directory = Directory(cacheFolder);
    await directory.create(recursive: true);
    final safeName = path.hashCode.toString().replaceAll('-', 'n');
    final height = resolution == '540p' ? 540 : 720;
    final outputPath =
        '${directory.path}${Platform.pathSeparator}${safeName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_${height}p.mp4';
    final output = File(outputPath);
    if (await output.exists() && await output.length() > 0) return outputPath;
    final partial = File('$outputPath.partial.mp4');
    final result = await _runBackgroundMediaProcess(
      _ffmpegExecutable,
      [
        '-nostdin',
        '-y',
        '-v',
        'error',
        '-threads',
        '2',
        '-i',
        path,
        '-map',
        '0:v:0',
        '-map',
        '0:a:0?',
        '-vf',
        'scale=-2:$height:force_original_aspect_ratio=decrease,fps=30',
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-crf',
        '30',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '96k',
        '-movflags',
        '+faststart',
        partial.path,
      ],
      jobType: MediaJobType.proxy,
      priority: MediaJobPriority.low,
      idleTimeout: const Duration(minutes: 5),
    );
    if (result.exitCode != 0 || !await partial.exists()) {
      if (await partial.exists()) await partial.delete();
      return null;
    }
    if (await output.exists()) await output.delete();
    await partial.rename(outputPath);
    unawaited(
      _trimMediaCache(
        directory,
        maximumFiles: 24,
        maximumBytes: 12 * 1024 * 1024 * 1024,
        protectedPaths: <String>{outputPath},
      ),
    );
    return outputPath;
  } catch (_) {
    return null;
  }
}

Future<void> _trimMediaCache(
  Directory directory, {
  required int maximumFiles,
  required int maximumBytes,
  Set<String> protectedPaths = const <String>{},
}) async {
  try {
    if (!await directory.exists()) return;
    final files = <({File file, FileStat stat})>[];
    var totalBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || protectedPaths.contains(entity.path)) continue;
      final stat = await entity.stat();
      files.add((file: entity, stat: stat));
      totalBytes += stat.size;
    }
    files.sort((a, b) => a.stat.accessed.compareTo(b.stat.accessed));
    while (files.length > maximumFiles || totalBytes > maximumBytes) {
      final oldest = files.removeAt(0);
      totalBytes -= oldest.stat.size;
      try {
        await oldest.file.delete();
      } catch (_) {}
    }
  } catch (_) {
    // Cache pruning must never interrupt editing.
  }
}
