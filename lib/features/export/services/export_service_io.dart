import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../core/storage/application_paths.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../captions/services/caption_service_io.dart';
import '../../../services/process/windows_process_job.dart';
import '../domain/export_models.dart';
import 'multi_track_filter_builder.dart';
import 'export_output_transaction.dart';
import 'caption_frame_stream.dart';
import '../../text/presentation/caption_paragraph.dart';
import 'package:flutter/painting.dart' show TextStyle;

part 'export_service_io_probe_result.dart';
part 'export_service_io_prepared_ffmpeg_arguments.dart';
part 'export_service_io_video_encoder_works.dart';

const _softwareH264Encoder = 'libx264';
const _softwareHevcEncoder = 'libx265';
Future<bool>? _exportAvailabilityFuture;
final Map<String, String> _preferredVideoEncoders = {};
final Map<String, Future<bool>> _audioStreamProbeFutures = {};
final Map<String, Future<String?>> _videoCodecProbeFutures = {};

String _bundledToolPath(String executableName) {
  return ApplicationPaths.mediaTool(executableName);
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
  return exportOutputTransaction(
      outputPath: job.outputPath,
      cancelToken: job.cancelToken,
      validate: (path) async =>
          await _probeVideoDimensions(path, job.cancelToken) != null,
      render: (path) => _exportVideoSafely(ExportJob(
          inputPath: job.inputPath,
          outputPath: path,
          settings: job.settings,
          onProgress: job.onProgress,
          cancelToken: job.cancelToken)));
}

Future<ExportResult> _exportVideoSafely(ExportJob job) async {
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
  final captured = job.withOutputPath(job.outputPath);
  return exportOutputTransaction(
      outputPath: job.outputPath,
      cancelToken: job.cancelToken,
      validate: (path) async =>
          await _probeVideoDimensions(path, job.cancelToken) != null,
      render: (path) =>
          _prepareMultiTrackTimeline(captured.withOutputPath(path)));
}

Future<ExportResult> _prepareMultiTrackTimeline(MultiTrackExportJob job) async {
  CaptionFrameStream? captionStream;
  var renderingStarted = false;
  try {
    final cues = job.captionParagraphSpec == null
        ? const <CaptionCueSettings>[]
        : (job.captionSettings?.captionCues ?? const <CaptionCueSettings>[])
            .where((c) =>
                (c.words.isEmpty || job.captionParagraphSpec!.timedHighlight) &&
                c.end > c.start &&
                c.text.trim().isNotEmpty)
            .toList();
    if (cues.isNotEmpty || job.textOverlays.isNotEmpty) {
      captionStream = await CaptionFrameStream.open(
          cues: cues,
          spec: job.captionParagraphSpec ??
              const CaptionParagraphSpec(style: TextStyle()),
          titles: job.textOverlays,
          width: job.width,
          height: job.height,
          fps: job.frameRate,
          duration: job.timeline.duration,
          token: job.cancelToken);
    }
    renderingStarted = true;
    final result = await _exportMultiTrackTimeline(job,
        titlesStreamed: job.textOverlays.isNotEmpty,
        captionStreamUrl: captionStream?.url);
    if (captionStream?.error != null) {
      throw StateError('Caption stream failed: ${captionStream!.error}');
    }
    return result;
  } catch (error, stackTrace) {
    await _recordUnexpectedExportError(
      operation: 'multi-track export',
      inputPath: null,
      outputPath: job.outputPath,
      error: error,
      stackTrace: stackTrace,
    );
    // Raster preparation has not touched the destination. Preserve any old
    // output if shaping/encoding fails before the renderer is started.
    if (renderingStarted) await _deleteIncompleteExport(job.outputPath);
    return ExportResult(
      success: false,
      message: 'Timeline export stopped safely: $error',
    );
  } finally {
    await captionStream?.close();
  }
}

Future<ExportResult> _exportMultiTrackTimeline(MultiTrackExportJob job,
    {bool titlesStreamed = false, String? captionStreamUrl}) async {
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
  // Compatibility only: unsupported word motion/curvature stays on ASS.
  // Whole cues and supported timed-word styles use the shared Flutter painter.
  // Never emit a second ASS rendering of an already rasterized cue.
  final captionSettings = job.captionSettings?.copyWith(captionCues: [
    for (final entry
        in (job.captionSettings?.captionCues ?? const <CaptionCueSettings>[])
            .indexed)
      if (captionStreamUrl == null ||
          job.captionParagraphSpec == null ||
          (entry.$2.words.isNotEmpty &&
              job.captionParagraphSpec?.timedHighlight != true))
        entry.$2,
  ]);
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
  final dimensions = <String, ({double width, double height})>{};
  final rotatedPaths = {
    for (final track in job.timeline.videoTracks)
      if (!track.isMuted)
        for (final clip in track.clips)
          if (!clip.isMuted &&
              (clip.transform.rotationDegrees != 0 ||
                  clip.keyframes.isNotEmpty))
            clip.mediaPath
  };
  for (final path in rotatedPaths) {
    if (job.cancelToken?.isCanceled == true) return canceled();
    final size = await _probeVideoDimensions(path, job.cancelToken);
    if (size == null) {
      if (job.cancelToken?.isCanceled == true) return canceled();
      return ExportResult(
          success: false,
          message: 'Cannot resolve source dimensions for rotated clip: $path');
    }
    dimensions[path] = size;
  }
  final plan = builder.build(
    job,
    encoder: encoder,
    audioClipIdsWithStreams: audioClipIds,
    captionAssPath: captionAssPath,
    hardwareDecoding: hardwareDecodingActive,
    sourceDimensions: dimensions,
    titlesStreamed: titlesStreamed,
    captionStreamUrl: captionStreamUrl,
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
          sourceDimensions: dimensions,
          titlesStreamed: titlesStreamed,
          captionStreamUrl: captionStreamUrl,
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
  return exportOutputTransaction(
      outputPath: job.outputPath,
      cancelToken: job.cancelToken,
      validate: (path) async =>
          await _probeVideoDimensions(path, job.cancelToken) != null,
      render: (path) => _exportVideoSequenceSafely(SequenceExportJob(
          jobs: job.jobs,
          outputPath: path,
          settings: job.settings,
          onProgress: job.onProgress,
          cancelToken: job.cancelToken)));
}

Future<ExportResult> _exportVideoSequenceSafely(SequenceExportJob job) async {
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

  final tempDirectory = await ApplicationPaths.temporary.createTemp(
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
