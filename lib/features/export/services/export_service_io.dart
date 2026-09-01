import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../captions/services/caption_service_io.dart';
import '../../../services/process/windows_process_job.dart';
import '../domain/export_models.dart';
import 'multi_track_filter_builder.dart';

const _softwareH264Encoder = 'libx264';
const _softwareHevcEncoder = 'libx265';
Future<bool>? _exportAvailabilityFuture;
final Map<String, String> _preferredVideoEncoders = {};
final Map<String, Future<bool>> _audioStreamProbeFutures = {};
final Map<String, Future<String?>> _videoCodecProbeFutures = {};

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

Future<bool> isExportAvailable() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return true;
  }

  if (!isDesktopExportPlatform) {
    return false;
  }

  return _exportAvailabilityFuture ??= () async {
    final result = await _runProbe(
      _ffmpegExecutable,
      const ['-version'],
      timeout: const Duration(seconds: 8),
    );
    return result?.exitCode == 0;
  }();
}

Future<ExportResult> exportVideo(ExportJob job) async {
  try {
    return await _exportVideo(job);
  } catch (error, stackTrace) {
    await _recordUnexpectedExportError(
      operation: 'single video export',
      inputPath: job.inputPath,
      outputPath: job.outputPath,
      error: error,
      stackTrace: stackTrace,
    );
    await _deleteIncompleteExport(job.outputPath);
    return ExportResult(
      success: false,
      message: 'Export stopped safely: $error',
    );
  }
}

Future<ExportResult> _exportVideo(ExportJob job) async {
  if (!isDesktopExportPlatform && !Platform.isAndroid && !Platform.isIOS) {
    return const ExportResult(
      success: false,
      message: 'Export is not supported on this platform.',
    );
  }

  if (!await isExportAvailable()) {
    return const ExportResult(
      success: false,
      message: 'FFmpeg was not found. Install FFmpeg and add it to PATH.',
    );
  }

  final inputFile = File(job.inputPath);
  if (!await inputFile.exists()) {
    return ExportResult(
      success: false,
      message: 'Input video was not found: ${job.inputPath}',
    );
  }

  final outputDirectory = Directory(File(job.outputPath).parent.path);
  if (!await outputDirectory.exists()) {
    await outputDirectory.create(recursive: true);
  }

  final settings = job.settings;
  job.onProgress?.call(0.01, 'Inspecting source media...');
  final hasWatermark =
      settings.watermarkPath != null && settings.watermarkPath!.isNotEmpty;
  final hasMusic = settings.musicPath != null && settings.musicPath!.isNotEmpty;

  if (hasWatermark && !await File(settings.watermarkPath!).exists()) {
    return ExportResult(
      success: false,
      message: 'Watermark image was not found: ${settings.watermarkPath}',
    );
  }

  if (hasMusic && !await File(settings.musicPath!).exists()) {
    return ExportResult(
      success: false,
      message: 'Background music was not found: ${settings.musicPath}',
    );
  }

  final inputHasAudio = await _hasAudioStream(
    job.inputPath,
    cancelToken: job.cancelToken,
  );
  final canCopyInputAudio = inputHasAudio &&
      await _canCopyAudioToMp4(
        job.inputPath,
        cancelToken: job.cancelToken,
      );
  final musicHasAudio = hasMusic &&
      await _hasAudioStream(
        settings.musicPath!,
        cancelToken: job.cancelToken,
      );
  if (hasMusic && !musicHasAudio) {
    return const ExportResult(
      success: false,
      message: 'Background music file does not contain an audio stream.',
    );
  }

  String? captionAssPath;
  if (settings.automaticCaptions && settings.captionCues.isNotEmpty) {
    try {
      job.onProgress?.call(0.03, 'Preparing edited captions...');
      captionAssPath = await generateManualCaptionAss(job);
    } on FileSystemException catch (error) {
      return ExportResult(
        success: false,
        message: 'Could not prepare edited captions: ${error.message}',
      );
    }
  } else if (settings.automaticCaptions) {
    try {
      captionAssPath = await generateAutomaticCaptionAss(
        job,
        onProgress: job.onProgress,
      );
    } on CaptionGenerationException catch (error) {
      return ExportResult(success: false, message: error.message);
    }
  }

  final softwareEncoder = _softwareEncoderForCodec(settings.exportCodec);
  job.onProgress?.call(0.05, 'Selecting the video encoder...');
  final encoder = settings.hardwareEncoding
      ? await _preferredVideoEncoder(
          settings.exportCodec,
          cancelToken: job.cancelToken,
        )
      : softwareEncoder;
  final args = await _buildFfmpegArgs(
    job,
    inputHasAudio: inputHasAudio,
    musicHasAudio: musicHasAudio,
    encoder: encoder,
    captionAssPath: captionAssPath,
    canCopyInputAudio: canCopyInputAudio,
  );

  job.onProgress?.call(0.08, 'Starting the video encoder...');
  void renderProgress(double progress, String status) {
    job.onProgress?.call(
      0.08 + progress.clamp(0.0, 1.0).toDouble() * 0.92,
      status,
    );
  }

  final result = await _runFfmpegWithEncoderFallback(
    args: args,
    encoder: encoder,
    fallbackArgs: () => _buildFfmpegArgs(
      job,
      inputHasAudio: inputHasAudio,
      musicHasAudio: musicHasAudio,
      encoder: softwareEncoder,
      captionAssPath: captionAssPath,
      canCopyInputAudio: canCopyInputAudio,
    ),
    durationSeconds: _exportDurationSeconds(job),
    onProgress: renderProgress,
    cancelToken: job.cancelToken,
  );
  if (job.cancelToken?.isCanceled == true) {
    await _deleteIncompleteExport(job.outputPath);
  }
  if (result.success) {
    return ExportResult(
      success: true,
      message: 'Export complete.',
      outputPath: job.outputPath,
    );
  }

  final error = result.message.trim();
  return ExportResult(
    success: false,
    message: error.isEmpty ? 'FFmpeg export failed.' : error,
  );
}

Future<ExportResult> exportMultiTrackTimeline(MultiTrackExportJob job) async {
  try {
    return await _exportMultiTrackTimeline(job);
  } catch (error, stackTrace) {
    await _recordUnexpectedExportError(
      operation: 'multi-track export',
      inputPath: null,
      outputPath: job.outputPath,
      error: error,
      stackTrace: stackTrace,
    );
    await _deleteIncompleteExport(job.outputPath);
    return ExportResult(
      success: false,
      message: 'Timeline export stopped safely: $error',
    );
  }
}

Future<ExportResult> _exportMultiTrackTimeline(MultiTrackExportJob job) async {
  ExportResult canceled() => const ExportResult(
        success: false,
        message: 'Export canceled.',
      );

  if (!isDesktopExportPlatform && !Platform.isAndroid && !Platform.isIOS) {
    return const ExportResult(
      success: false,
      message: 'Multi-track export is not supported on this platform.',
    );
  }
  if (job.cancelToken?.isCanceled == true) return canceled();
  job.onProgress?.call(0.01, 'Checking the export engine...');
  if (!await isExportAvailable()) {
    return const ExportResult(
      success: false,
      message: 'FFmpeg was not found. Install FFmpeg and add it to PATH.',
    );
  }
  if (job.cancelToken?.isCanceled == true) return canceled();
  if (job.timeline.duration <= 0) {
    return const ExportResult(
      success: false,
      message: 'The multi-track timeline is empty.',
    );
  }
  final mediaPaths = {
    for (final track in job.timeline.tracks)
      for (final clip in track.clips) clip.mediaPath,
  };
  job.onProgress?.call(0.02, 'Verifying timeline media...');
  for (final path in mediaPaths) {
    if (job.cancelToken?.isCanceled == true) return canceled();
    if (!await File(path).exists()) {
      return ExportResult(
        success: false,
        message: 'Timeline media was not found: $path',
      );
    }
  }
  if (job.cancelToken?.isCanceled == true) return canceled();
  job.onProgress?.call(0.03, 'Inspecting timeline audio...');
  final audioPaths = {
    for (final track in job.timeline.audioTracks)
      if (!track.isMuted)
        for (final clip in track.clips)
          if (!clip.isMuted) clip.mediaPath,
  };
  final audioAvailability = <String, bool>{};
  for (final path in audioPaths) {
    if (job.cancelToken?.isCanceled == true) return canceled();
    audioAvailability[path] = await _hasAudioStream(
      path,
      cancelToken: job.cancelToken,
    );
  }
  final audioClipIds = <String>{};
  for (final track in job.timeline.audioTracks) {
    if (track.isMuted) continue;
    for (final clip in track.clips) {
      if (!clip.isMuted && audioAvailability[clip.mediaPath] == true) {
        audioClipIds.add(clip.id);
      }
    }
  }
  if (job.cancelToken?.isCanceled == true) return canceled();
  var hardwareDecodingActive = job.hardwareDecoding;
  final sourceCodecs = <String>{};
  if (hardwareDecodingActive) {
    job.onProgress?.call(0.04, 'Checking source decoder compatibility...');
    for (final path in mediaPaths) {
      if (job.cancelToken?.isCanceled == true) return canceled();
      final codec = await _videoCodec(path, cancelToken: job.cancelToken);
      if (codec != null) sourceCodecs.add(codec);
    }
    hardwareDecodingActive = sourceCodecs.isNotEmpty &&
        sourceCodecs.every(_safeAutomaticHardwareDecodeCodec);
  }
  final outputDirectory = Directory(File(job.outputPath).parent.path);
  if (!await outputDirectory.exists()) {
    await outputDirectory.create(recursive: true);
  }
  String? captionAssPath;
  final captionSettings = job.captionSettings;
  if (captionSettings != null && captionSettings.captionCues.isNotEmpty) {
    job.onProgress?.call(0.045, 'Preparing one optimized caption track...');
    captionAssPath = await generateManualCaptionAss(
      ExportJob(
        inputPath: mediaPaths.first,
        outputPath: job.outputPath,
        settings: captionSettings.copyWith(
          speed: 1,
          trimStartSeconds: 0,
          trimEndSeconds: job.timeline.duration,
        ),
        cancelToken: job.cancelToken,
      ),
      playResWidth: job.width,
      playResHeight: job.height,
    );
  }
  if (job.cancelToken?.isCanceled == true) return canceled();
  job.onProgress?.call(0.06, 'Selecting the fastest available encoder...');
  final softwareEncoder = _softwareEncoderForCodec(job.exportCodec);
  final encoder = job.hardwareEncoding
      ? await _preferredVideoEncoder(
          job.exportCodec,
          cancelToken: job.cancelToken,
        )
      : softwareEncoder;
  if (job.cancelToken?.isCanceled == true) return canceled();
  const builder = MultiTrackFilterBuilder();
  final plan = builder.build(
    job,
    encoder: encoder,
    audioClipIdsWithStreams: audioClipIds,
    captionAssPath: captionAssPath,
    hardwareDecoding: hardwareDecodingActive,
  );
  final gpuActive = !_isSoftwareEncoder(encoder);
  final decodeLabel = hardwareDecodingActive
      ? 'GPU decode'
      : sourceCodecs.isEmpty
          ? 'CPU decode'
          : 'CPU ${sourceCodecs.join('/').toUpperCase()} decode';
  job.onProgress?.call(
    0.08,
    'Rendering with $encoder • ${job.frameRate.toStringAsFixed(2)} fps '
    '• ${plan.filterCount} filters • $decodeLabel '
    '• GPU encode ${gpuActive ? 'on' : 'off'}',
  );
  void renderProgress(double progress, String status) {
    job.onProgress?.call(
      0.08 + progress.clamp(0.0, 1.0).toDouble() * 0.92,
      status,
    );
  }

  final result = await _runFfmpegWithEncoderFallback(
    args: plan.arguments,
    encoder: encoder,
    fallbackArgs: () async => builder
        .build(
          job,
          encoder: softwareEncoder,
          audioClipIdsWithStreams: audioClipIds,
          captionAssPath: captionAssPath,
          hardwareDecoding: false,
        )
        .arguments,
    durationSeconds: plan.duration,
    onProgress: renderProgress,
    cancelToken: job.cancelToken,
  );
  if (job.cancelToken?.isCanceled == true) {
    await _deleteIncompleteExport(job.outputPath);
  }
  if (result.success) {
    return ExportResult(
      success: true,
      message: 'Multi-track export complete.',
      outputPath: job.outputPath,
    );
  }
  return ExportResult(
    success: false,
    message: result.message.trim().isEmpty
        ? 'Multi-track FFmpeg export failed.'
        : result.message.trim(),
  );
}

Future<ExportResult> generateCaptionPreview(ExportJob job) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return const ExportResult(
      success: false,
      message: 'Caption preview generation currently requires the desktop app.',
    );
  }
  if (!await File(job.inputPath).exists()) {
    return ExportResult(
      success: false,
      message: 'Input video was not found: ${job.inputPath}',
    );
  }
  try {
    final outputPath = await generateAutomaticCaptionAss(
      job,
      onProgress: job.onProgress,
    );
    return ExportResult(
      success: true,
      message: 'Caption preview generated.',
      outputPath: outputPath,
    );
  } on CaptionGenerationException catch (error) {
    return ExportResult(success: false, message: error.message);
  }
}

/// Builds the edited speech track without rendering a single video frame.
///
/// This keeps caption generation away from NVENC/CUDA video workloads and
/// reduces a long edited video to a small mono PCM file before Whisper starts.
Future<ExportResult> exportCaptionAudioSequence({
  required List<CaptionAudioSegment> segments,
  required String outputPath,
  void Function(double progress, String status)? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  if (segments.isEmpty) {
    return const ExportResult(
      success: false,
      message: 'No edited audio sections were provided.',
    );
  }
  if (!await isExportAvailable()) {
    return const ExportResult(
      success: false,
      message: 'FFmpeg was not found.',
    );
  }
  final output = File(outputPath);
  await output.parent.create(recursive: true);

  final args = <String>['-y'];
  final filters = <String>[];
  final concatInputs = <String>[];
  var totalDuration = 0.0;
  for (var index = 0; index < segments.length; index++) {
    if (cancelToken?.isCanceled == true) {
      return const ExportResult(success: false, message: 'Export canceled.');
    }
    final segment = segments[index];
    final speed = _safeSpeed(segment.speed);
    final sourceDuration = segment.duration.clamp(0.001, 86400).toDouble();
    final outputDuration = sourceDuration / speed;
    totalDuration += outputDuration;
    final hasAudio = await _hasAudioStream(
      segment.inputPath,
      cancelToken: cancelToken,
    );
    if (hasAudio) {
      args.addAll([
        '-ss',
        _seconds(segment.sourceStart.clamp(0, 86400).toDouble()),
        '-t',
        _seconds(sourceDuration),
        '-i',
        segment.inputPath,
      ]);
      final tempo = _tempoFilters(speed).join(',');
      filters.add(
        '[$index:a]$tempo,aresample=16000,'
        'aformat=sample_fmts=s16:channel_layouts=mono,'
        'atrim=duration=${_seconds(outputDuration)},'
        'asetpts=PTS-STARTPTS[captionAudio$index]',
      );
    } else {
      args.addAll([
        '-f',
        'lavfi',
        '-t',
        _seconds(outputDuration),
        '-i',
        'anullsrc=channel_layout=mono:sample_rate=16000',
      ]);
      filters.add(
        '[$index:a]atrim=duration=${_seconds(outputDuration)},'
        'asetpts=PTS-STARTPTS[captionAudio$index]',
      );
    }
    concatInputs.add('[captionAudio$index]');
  }
  filters.add(
    '${concatInputs.join()}concat=n=${segments.length}:v=0:a=1[captionAudio]',
  );
  args.addAll([
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[captionAudio]',
    '-vn',
    '-ac',
    '1',
    '-ar',
    '16000',
    '-c:a',
    'pcm_s16le',
    outputPath,
  ]);
  final result = await _runFfmpeg(
    args,
    durationSeconds: totalDuration,
    onProgress: onProgress,
    cancelToken: cancelToken,
  );
  if (!result.success || cancelToken?.isCanceled == true) {
    await _deleteIncompleteExport(outputPath);
    return ExportResult(success: false, message: result.message);
  }
  return ExportResult(
    success: true,
    message: 'Edited caption audio prepared.',
    outputPath: outputPath,
  );
}

Future<ExportResult> exportVideoSequence(SequenceExportJob job) async {
  try {
    return await _exportVideoSequence(job);
  } catch (error, stackTrace) {
    await _recordUnexpectedExportError(
      operation: 'timeline sequence export',
      inputPath: job.jobs.isEmpty ? null : job.jobs.first.inputPath,
      outputPath: job.outputPath,
      error: error,
      stackTrace: stackTrace,
    );
    await _deleteIncompleteExport(job.outputPath);
    return ExportResult(
      success: false,
      message: 'Timeline sequence stopped safely: $error',
    );
  }
}

Future<ExportResult> _exportVideoSequence(SequenceExportJob job) async {
  if (job.jobs.isEmpty) {
    return const ExportResult(
      success: false,
      message: 'No clips were provided for timeline export.',
    );
  }

  if (!await isExportAvailable()) {
    return const ExportResult(
      success: false,
      message: 'FFmpeg was not found. Install FFmpeg and add it to PATH.',
    );
  }

  final outputDirectory = Directory(File(job.outputPath).parent.path);
  if (!await outputDirectory.exists()) {
    await outputDirectory.create(recursive: true);
  }

  final musicPath = job.settings.musicPath;
  final hasMusic = musicPath != null && musicPath.isNotEmpty;
  if (hasMusic && !await File(musicPath).exists()) {
    return ExportResult(
      success: false,
      message: 'Background music was not found: $musicPath',
    );
  }
  final musicHasAudio = hasMusic &&
      await _hasAudioStream(musicPath, cancelToken: job.cancelToken);
  if (hasMusic && !musicHasAudio) {
    return const ExportResult(
      success: false,
      message: 'Background music file does not contain an audio stream.',
    );
  }

  final tempDirectory = await Directory.systemTemp.createTemp(
    'klipio_sequence_',
  );
  try {
    final renderedClips = <String>[];
    for (var index = 0; index < job.jobs.length; index++) {
      final clipJob = job.jobs[index];
      final clipOutput =
          '${tempDirectory.path}${Platform.pathSeparator}clip_${index.toString().padLeft(4, '0')}.mp4';
      final result = await exportVideo(
        ExportJob(
          inputPath: clipJob.inputPath,
          outputPath: clipOutput,
          settings: clipJob.settings.copyWith(musicPath: ''),
          cancelToken: job.cancelToken,
          onProgress: (progress, status) {
            final base = index / job.jobs.length;
            final slice = 0.9 / job.jobs.length;
            job.onProgress?.call(base * 0.9 + progress * slice, status);
          },
        ),
      );
      if (!result.success) {
        return ExportResult(
          success: false,
          message: 'Clip ${index + 1} failed: ${result.message}',
        );
      }
      renderedClips.add(clipOutput);
    }

    final concatResult = await _concatRenderedClips(
      renderedClips,
      job.outputPath,
      settings: job.settings,
      musicHasAudio: musicHasAudio,
      onProgress: job.onProgress == null
          ? null
          : (progress, status) {
              job.onProgress!(0.9 + progress * 0.1, status);
            },
      cancelToken: job.cancelToken,
    );
    if (!concatResult.success) {
      return concatResult;
    }
    return ExportResult(
      success: true,
      message: 'Timeline export complete.',
      outputPath: job.outputPath,
    );
  } finally {
    if (job.cancelToken?.isCanceled == true) {
      await _deleteIncompleteExport(job.outputPath);
    }
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<bool> _hasAudioStream(
  String path, {
  ExportCancelToken? cancelToken,
}) {
  if (cancelToken != null) {
    return _probeAudioStream(path, cancelToken: cancelToken);
  }
  final key = File(path).absolute.path.toLowerCase();
  return _audioStreamProbeFutures.putIfAbsent(
    key,
    () => _probeAudioStream(path),
  );
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
    '${Directory.systemTemp.path}${Platform.pathSeparator}klipio_concat_${DateTime.now().microsecondsSinceEpoch}.txt',
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
      '${Directory.systemTemp.path}${Platform.pathSeparator}KlipioLogs',
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
            const Duration(minutes: 4) &&
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
          'The media worker stopped making progress for 4 minutes and was terminated to keep Windows responsive.',
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
    '${Directory.systemTemp.path}${Platform.pathSeparator}klipio_ffmpeg_scripts',
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
