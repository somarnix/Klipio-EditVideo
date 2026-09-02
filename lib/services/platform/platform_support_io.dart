import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/storage/application_paths.dart';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import '../tasks/media_worker_policy.dart';

import '../process/windows_process_job.dart';
import '../tasks/media_job_manager.dart';

final Map<int, Process> _backgroundMediaProcesses = <int, Process>{};
final Map<String, Future<String?>> _proxyMediaJobs = {};
final Map<String, Future<void>> _thumbnailBatchJobs = {};
final Map<String, Future<AudioWaveformLod>> _waveformMediaJobs = {};
final Map<String, Future<MediaProbeInfo>> _probeJobs = {};
final Map<String, MediaProbeInfo> _probeCache = {};

Map<String, int> get mediaCacheDiagnostics => {
      'metadataEntries': _probeCache.length,
      'metadataJobs': _probeJobs.length,
      'proxyJobs': _proxyMediaJobs.length,
      'thumbnailSamplesInFlight': _thumbnailBatchJobs.length,
      'waveformJobs': _waveformMediaJobs.length,
      'backgroundProcesses': _backgroundMediaProcesses.length,
    };
int _backgroundMediaGeneration = 0;

bool get isAndroid => Platform.isAndroid;
bool get isIos => Platform.isIOS;
String get pathSeparator => Platform.pathSeparator;
String basename(String path) => path.split(Platform.pathSeparator).last;
bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

String _bundledToolPath(String executableName) {
  return ApplicationPaths.mediaTool(executableName);
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
  double? progressDuration,
}) async {
  try {
    return await MediaJobManager.instance.schedule<ProcessResult>(
      type: jobType,
      priority: priority,
      scopeId: 'project-media',
      asset: arguments.contains('-i')
          ? arguments[arguments.indexOf('-i') + 1]
          : null,
      interruptible: true,
      task: (cancellationToken) => _executeBackgroundMediaProcess(
        executable,
        arguments,
        cancellationToken: cancellationToken,
        binaryStdout: binaryStdout,
        onBinaryStdoutChunk: onBinaryStdoutChunk,
        idleTimeout: idleTimeout,
        progressDuration: progressDuration,
        jobType: jobType,
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
  double? progressDuration,
  required MediaJobType jobType,
}) async {
  final generation = _backgroundMediaGeneration;
  cancellationToken.throwIfCanceled();
  final process = await Process.start(executable, arguments);
  await registerKlipioWorker(process,
      jobType: jobType.name,
      executable: executable,
      asset: arguments.contains('-i')
          ? arguments[arguments.indexOf('-i') + 1]
          : null);
  _backgroundMediaProcesses[process.pid] = process;
  var lastActivity = DateTime.now();
  final progress =
      arguments.contains('-progress') ? MediaWorkerProgress() : null;
  if (generation != _backgroundMediaGeneration) {
    await _terminateBackgroundProcessTree(process);
  }
  final stdoutText = _BoundedBackgroundTextBuffer();
  final stderrText = _BoundedBackgroundTextBuffer();
  final binaryBytes = <int>[];
  final stdoutFuture = process.stdout.listen((chunk) {
    if (progress == null) {
      lastActivity = DateTime.now();
    } else if (progress.add(utf8.decode(chunk, allowMalformed: true))) {
      lastActivity = DateTime.now();
      if (progressDuration != null && progressDuration > 0) {
        cancellationToken.reportProgress(
            progress.outputMicroseconds / 1000000 / progressDuration);
      }
    }
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
    if (progress == null) lastActivity = DateTime.now();
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
    if (exitCode < 0) {
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
  final stat = await File(path).stat();
  final key =
      '${File(path).absolute.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
  final cached = _probeCache.remove(key);
  if (cached != null) {
    _probeCache[key] = cached;
    return cached;
  }
  final pending = _probeJobs[key];
  if (pending != null) return pending;
  final job = _probeMedia(path);
  _probeJobs[key] = job;
  try {
    final result = await job;
    if (result.durationSeconds != null) {
      _probeCache[key] = result;
      while (_probeCache.length > 128) {
        _probeCache.remove(_probeCache.keys.first);
      }
    }
    return result;
  } finally {
    if (identical(_probeJobs[key], job)) {
      _probeJobs.remove(key);
    }
  }
}

Future<MediaProbeInfo> _probeMedia(String path) async {
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

  return (await probeMedia(path)).durationSeconds;
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
  final key =
      '${File(path).absolute.path}|${Directory(cacheFolder).absolute.path}|$durationSeconds';
  final active = _waveformMediaJobs[key];
  if (active != null) return active;
  final job = _extractAudioWaveformLod(path, cacheFolder,
      durationSeconds: durationSeconds);
  _waveformMediaJobs[key] = job;
  try {
    return await job;
  } finally {
    if (identical(_waveformMediaJobs[key], job)) {
      _waveformMediaJobs.remove(key);
    }
  }
}

Future<AudioWaveformLod> _extractAudioWaveformLod(
    String path, String cacheFolder,
    {double? durationSeconds}) async {
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
    final requestedRate =
        duration <= 0 ? 20.0 : (60000 / duration).clamp(2.0, 50.0).toDouble();
    final decodeRate = (requestedRate * 80).round().clamp(400, 4000);
    final samplesPerPeak = math.max(1, (decodeRate / requestedRate).round());
    // The envelope clock is determined by integer PCM bins, not the desired
    // approximate LOD rate. Reporting the latter drifts on long media.
    final peaksPerSecond = decodeRate / samplesPerPeak;
    final roundedRate = peaksPerSecond.toStringAsFixed(3);
    final safeName = path.hashCode.toString().replaceAll('-', 'n');
    final cachePath =
        '${cacheDirectory.path}${Platform.pathSeparator}${safeName}_${stat.size}_${stat.modified.millisecondsSinceEpoch}_$roundedRate.waveform-v3';
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
        '-filter_threads',
        '1',
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
        '-threads',
        '1',
        'pipe:1',
      ],
      binaryStdout: true,
      onBinaryStdoutChunk: consumePcm,
      jobType: MediaJobType.waveform,
      priority: MediaJobPriority.low,
    );
    if (result.exitCode == -3) throw const MediaJobCanceledException();
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
  } on MediaJobCanceledException {
    rethrow;
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
  void Function(List<String> frames)? onFrames,
  bool Function()? isCanceled,
}) async {
  if (!isDesktop || durationSeconds == null || durationSeconds <= 0) {
    return const [];
  }

  final cacheDirectory = Directory(cacheFolder);
  final generation = _backgroundMediaGeneration;
  bool canceled() =>
      generation != _backgroundMediaGeneration || (isCanceled?.call() ?? false);
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  final sourceStat = await File(path).stat();
  if (canceled()) return const [];
  // Derived images belong to this source revision and sampling grid. Never
  // reuse an old grid after replacing media or correcting its duration.
  final safeName = '${path.hashCode}_${sourceStat.size}_'
          '${sourceStat.modified.millisecondsSinceEpoch}_$durationSeconds'
      .replaceAll('-', 'n');
  final frameCount = (durationSeconds / 5).ceil().clamp(8, 240);
  final paths = [
    for (var index = 0; index < frameCount; index++)
      '${cacheDirectory.path}${Platform.pathSeparator}${safeName}_timeline_${index.toString().padLeft(2, '0')}.jpg',
  ];
  final requestedStart = (visibleSourceStart ?? 0).clamp(0.0, durationSeconds);
  // First paint needs an overview of the entire source, not just its first
  // 45 seconds. Decoding remains capped below; zoomed views refine that grid.
  final requestedEnd = (visibleSourceEnd ?? durationSeconds)
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
  if (candidateIndices.length > 16) {
    candidateIndices = <int>[
      for (var sample = 0; sample < 16; sample++)
        candidateIndices[(sample * (candidateIndices.length - 1) / 15).round()],
    ];
  }
  final missing = <int>[];
  for (final index in candidateIndices) {
    final file = File(paths[index]);
    if (!await file.exists() || await file.length() == 0) missing.add(index);
  }
  List<String> currentFrames() =>
      _timelineThumbnailGridWithNearestFrames(paths, candidateIndices);
  void publish() {
    if (!canceled()) onFrames?.call(currentFrames());
  }

  publish();
  if (missing.isEmpty) return currentFrames();

  // Fast input seeking avoids decoding the full video. Four timestamp inputs
  // share one FFmpeg process, which cuts Windows process churn by up to 75%
  // compared with launching a new worker for every frame.
  for (var offset = 0; offset < missing.length; offset += 4) {
    if (canceled()) return const [];
    final batch = [
      for (final index in missing.skip(offset).take(4))
        (
          outputPath: paths[index],
          seconds: durationSeconds * (index + 0.5) / frameCount,
        ),
    ];
    await _writeTimelineThumbnailBatch(path, batch);
    if (canceled()) return const [];
    publish();
  }
  unawaited(
    _trimMediaCache(
      cacheDirectory,
      maximumFiles: 512,
      maximumBytes: 256 * 1024 * 1024,
    ),
  );
  return currentFrames();
}

List<String> _timelineThumbnailGridWithNearestFrames(
    List<String> paths, List<int> requested) {
  final available = <int>[
    for (var index = 0; index < paths.length; index++)
      if (File(paths[index]).existsSync() &&
          File(paths[index]).lengthSync() > 0)
        index,
  ];
  // Map each slot to its planned temporal sample BEFORE checking readiness.
  // Mapping to just the available frames repeats the first decoded image
  // across the whole clip and falsely presents it as other moments in time.
  final anchors = <int>{...available, ...requested};
  return List<String>.generate(paths.length, (index) {
    final nearest = anchors.reduce((nearest, candidate) =>
        (candidate - index).abs() < (nearest - index).abs()
            ? candidate
            : nearest);
    return available.contains(nearest) ? paths[nearest] : '';
  });
}

Future<void> _writeTimelineThumbnailBatch(
  String inputPath,
  List<({String outputPath, double seconds})> samples,
) async {
  if (samples.isEmpty) return;
  final existing = <Future<void>>{
    for (final sample in samples)
      if (_thumbnailBatchJobs[sample.outputPath] != null)
        _thumbnailBatchJobs[sample.outputPath]!,
  };
  final missing = samples
      .where((sample) => !_thumbnailBatchJobs.containsKey(sample.outputPath))
      .toList();
  final job = missing.isEmpty
      ? Future<void>.value()
      : _writeOwnedThumbnailBatch(inputPath, missing);
  for (final sample in missing) {
    _thumbnailBatchJobs[sample.outputPath] = job;
  }
  try {
    await Future.wait([...existing, job]);
  } finally {
    for (final sample in missing) {
      if (identical(_thumbnailBatchJobs[sample.outputPath], job)) {
        _thumbnailBatchJobs.remove(sample.outputPath);
      }
    }
  }
}

Future<void> _writeOwnedThumbnailBatch(String inputPath,
    List<({String outputPath, double seconds})> samples) async {
  final needed = <({String outputPath, double seconds})>[];
  for (final sample in samples) {
    final file = File(sample.outputPath);
    if (!await file.exists() || await file.length() == 0) needed.add(sample);
  }
  if (needed.isEmpty) return;
  samples = needed;
  final work =
      await File(samples.first.outputPath).parent.createTemp('thumbnail-work-');
  try {
    final arguments = <String>[
      '-nostdin',
      '-y',
      '-loglevel',
      'error',
      '-filter_threads',
      '1',
    ];
    for (final sample in samples) {
      arguments.addAll([
        '-ss',
        sample.seconds.toStringAsFixed(3),
        '-threads',
        '1',
        '-i',
        inputPath,
      ]);
    }
    for (var index = 0; index < samples.length; index++) {
      arguments.addAll([
        '-map',
        '$index:v:0',
        '-frames:v',
        '1',
        '-an',
        '-vf',
        'scale=160:90:force_original_aspect_ratio=increase,crop=160:90',
        '-q:v',
        '5',
        '-threads:v',
        '1',
        '${work.path}${Platform.pathSeparator}$index.jpg',
      ]);
    }
    final result = await _runBackgroundMediaProcess(
        _ffmpegExecutable, arguments,
        jobType: MediaJobType.thumbnail,
        priority: MediaJobPriority.interactive);
    if (result.exitCode != 0) return;
    for (var index = 0; index < samples.length; index++) {
      final image = File('${work.path}${Platform.pathSeparator}$index.jpg');
      final target = File(samples[index].outputPath);
      if (await image.exists() &&
          await image.length() > 0 &&
          (!await target.exists() || await target.length() == 0)) {
        await image.rename(target.path);
      }
    }
  } finally {
    if (await work.exists()) {
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }
  }
}

bool mediaNeedsProxy(MediaProbeInfo info) {
  final pixels = info.width * info.height;
  final codec = info.videoCodec.toLowerCase();
  return pixels >= 2560 * 1440 ||
      info.frameRate > 45 ||
      info.bitrate > 18 * 1000 * 1000 ||
      codec == 'hevc' ||
      codec == 'h265' ||
      codec == 'av1';
}

Future<String?> generateProxyMedia(
  String path,
  String cacheFolder, {
  String resolution = '720p',
  double? durationSeconds,
}) async {
  if (!isDesktop) return null;
  final source = File(path);
  if (!await source.exists()) return null;
  final stat = await source.stat();
  final height = resolution == '540p' ? 540 : 720;
  final identity = sha256
      .convert(utf8.encode(jsonEncode([
        Platform.isWindows
            ? source.absolute.path.toLowerCase()
            : source.absolute.path,
        stat.size,
        stat.modified.microsecondsSinceEpoch,
        MediaWorkerPolicy.proxyProfile,
        height,
      ])))
      .toString();
  final outputPath =
      '${Directory(cacheFolder).absolute.path}${Platform.pathSeparator}$identity.mp4';
  final active = _proxyMediaJobs[outputPath];
  if (active != null) return active;
  final job = _generateProxyMedia(path, outputPath, height, durationSeconds);
  _proxyMediaJobs[outputPath] = job;
  try {
    return await job;
  } finally {
    if (identical(_proxyMediaJobs[outputPath], job)) {
      _proxyMediaJobs.remove(outputPath);
    }
  }
}

Future<String?> _generateProxyMedia(
    String path, String outputPath, int height, double? durationSeconds) async {
  Directory? work;
  try {
    final output = File(outputPath);
    final directory = output.parent;
    await directory.create(recursive: true);
    if (await output.exists() && await output.length() > 0) return outputPath;
    work = await directory.createTemp('proxy-work-');
    final partial = File('${work.path}${Platform.pathSeparator}output.mp4');
    final result = await _runBackgroundMediaProcess(
      _ffmpegExecutable,
      [
        '-nostdin',
        '-y',
        '-v',
        'error',
        '-threads',
        '${MediaWorkerPolicy.decoderThreads}',
        '-filter_threads',
        '${MediaWorkerPolicy.filterThreads}',
        '-progress',
        'pipe:1',
        '-nostats',
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
        '-threads:v',
        '${MediaWorkerPolicy.encoderThreads}',
        '-x264-params',
        'threads=${MediaWorkerPolicy.encoderThreads}:lookahead_threads=1',
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
      progressDuration: durationSeconds,
    );
    if (result.exitCode != 0 || !await partial.exists()) {
      if (await partial.exists()) await partial.delete();
      return null;
    }
    // Another process may have published the same deterministic cache entry.
    if (await output.exists() && await output.length() > 0) return outputPath;
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
  } finally {
    // Only this invocation's unique work directory is ever removed.
    if (work != null && await work.exists()) {
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }
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
