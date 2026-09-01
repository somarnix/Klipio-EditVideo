import 'dart:async';
import 'dart:io';

import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/export_service.dart';
import 'package:klipio/features/captions/services/caption_service_io.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual captions preserve movable cue position in ASS export', () async {
    final path = await generateManualCaptionAss(
      const ExportJob(
        inputPath: 'position-test.mp4',
        outputPath: 'unused.mp4',
        settings: VideoEditSettings(
          speed: 1,
          flip: 'none',
          scaleX: 1,
          scaleY: 1,
          zoom: 1,
          watermarkPath: null,
          watermarkPosition: 'custom',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1,
          musicVolume: 0,
          captionCues: [
            CaptionCueSettings(
              start: 0,
              end: 1,
              text: 'Move me',
              x: 0.25,
              y: 0.35,
            ),
          ],
        ),
      ),
    );
    final contents = await File(path).readAsString();
    expect(contents, contains(r'{\pos(480,378)}MOVE ME'));
  });

  test('export token pause waits for resume', () async {
    final token = ExportCancelToken()..pause();
    var completed = false;
    final waiting = token.waitUntilResumed().then((value) {
      completed = true;
      return value;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(completed, isFalse);
    expect(token.isPaused, isTrue);

    token.resume();
    expect(await waiting, isTrue);
    expect(token.isPaused, isFalse);
  });

  test('cancel releases a paused export token', () async {
    final token = ExportCancelToken()..pause();
    final waiting = token.waitUntilResumed();
    token.cancel();
    expect(await waiting, isFalse);
    expect(token.isCanceled, isTrue);
    expect(token.isPaused, isFalse);
  });

  test('cancel broadcasts through whenCanceled', () async {
    final token = ExportCancelToken();
    var notified = false;
    final notification = token.whenCanceled.then((_) => notified = true);

    token.cancel();
    await notification;

    expect(notified, isTrue);
    expect(token.isCanceled, isTrue);
  });

  test('cancelAndWait waits until tracked workers have exited', () async {
    final token = ExportCancelToken();
    final worker = Completer<void>();
    token.trackOperation(worker.future);
    var cancellationFinished = false;

    final cancellation = token.cancelAndWait().then((_) {
      cancellationFinished = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(token.isCanceled, isTrue);
    expect(token.activeOperationCount, 1);
    expect(cancellationFinished, isFalse);

    worker.complete();
    await cancellation;

    expect(token.activeOperationCount, 0);
    expect(cancellationFinished, isTrue);
  });

  test('desktop export handles watermark, music, speed, and silent videos',
      () async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return;
    }
    if (!await isExportAvailable()) {
      return;
    }

    final temp = await Directory.systemTemp.createTemp('klipio_export_test_');
    addTearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    final source = '${temp.path}${Platform.pathSeparator}source.mp4';
    final anamorphic = '${temp.path}${Platform.pathSeparator}anamorphic.mp4';
    final silent = '${temp.path}${Platform.pathSeparator}silent.mp4';
    final music = '${temp.path}${Platform.pathSeparator}music.m4a';
    final watermark = '${temp.path}${Platform.pathSeparator}watermark.png';
    final edited = '${temp.path}${Platform.pathSeparator}edited.mp4';
    final editedSilent =
        '${temp.path}${Platform.pathSeparator}edited_silent.mp4';

    await _runFfmpeg([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=160x90:rate=15:duration=1',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=1',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      source,
    ]);
    await _runFfmpeg([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=160x90:rate=15:duration=1',
      '-vf',
      'setsar=5/3',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      anamorphic,
    ]);
    await _runFfmpeg([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=160x90:rate=15:duration=1',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      silent,
    ]);
    await _runFfmpeg([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=880:duration=1.5',
      '-c:a',
      'aac',
      music,
    ]);
    await _runFfmpeg([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=32x16',
      '-frames:v',
      '1',
      watermark,
    ]);

    final fullProgress = <double>[];
    final fullResult = await exportVideo(
      ExportJob(
        inputPath: source,
        outputPath: edited,
        settings: VideoEditSettings(
          speed: 1.2,
          flip: 'left',
          scaleX: 1.1,
          scaleY: 1.0,
          zoom: 1.2,
          watermarkPath: watermark,
          watermarkPosition: 'bottom-right',
          watermarkSize: 0.16,
          musicPath: music,
          originalVolume: 0.7,
          musicVolume: 0.4,
          outputRatio: '9:16',
          panX: -0.4,
          panY: 0.25,
          overlayText: 'Klipio',
          overlayTextX: 0.5,
          overlayTextY: 0.1,
          overlayTextSize: 22,
          overlayTextColor: '#22C55E',
          overlayTextOpacity: 0.9,
          overlayTextStroke: 2,
          overlayTextStrokeColor: '#111827',
          overlayTextShadowColor: '#3B82F6',
          overlayTextShadow: true,
          overlayTextAnimation: 'fade-in',
          brightness: 0.05,
          contrast: 1.1,
          saturation: 1.2,
          gamma: 0.95,
          watermarkX: 0.1,
          watermarkY: 0.1,
        ),
        onProgress: (progress, _) => fullProgress.add(progress),
      ),
    );

    expect(fullResult.success, isTrue, reason: fullResult.message);
    expect(fullProgress, isNotEmpty);
    expect(fullProgress.first, greaterThanOrEqualTo(0.01));
    expect(fullProgress.last, 1);
    expect(await File(edited).length(), greaterThan(0));
    final portraitSize = await _videoSize(edited);
    expect(portraitSize.width, lessThan(portraitSize.height));

    final multiText = '${temp.path}${Platform.pathSeparator}multi_text.mp4';
    final multiTextResult = await exportVideo(
      ExportJob(
        inputPath: source,
        outputPath: multiText,
        settings: const VideoEditSettings(
          speed: 1.0,
          flip: 'up',
          scaleX: 1.0,
          scaleY: 1.0,
          zoom: 1.0,
          watermarkPath: null,
          watermarkPosition: 'custom',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1.0,
          musicVolume: 0.7,
          textOverlays: [
            TextOverlaySettings(
              text: 'Top',
              x: 0.5,
              y: 0.15,
              color: '#22C55E',
              strokeColor: '#111827',
            ),
            TextOverlaySettings(
              text: 'Bottom',
              x: 0.5,
              y: 0.8,
              color: '#FACC15',
              strokeColor: '#EF4444',
              animation: 'flow up',
              animationDuration: 0.5,
              startX: 0.5,
              startY: 1,
            ),
          ],
        ),
      ),
    );
    expect(multiTextResult.success, isTrue, reason: multiTextResult.message);
    expect(await File(multiText).length(), greaterThan(0));

    final oversizedText =
        '${temp.path}${Platform.pathSeparator}oversized_text.mp4';
    final oversizedTextResult = await exportVideo(
      ExportJob(
        inputPath: source,
        outputPath: oversizedText,
        settings: VideoEditSettings(
          speed: 1,
          flip: 'none',
          scaleX: 1,
          scaleY: 1,
          zoom: 1,
          watermarkPath: null,
          watermarkPosition: 'custom',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1,
          musicVolume: 0,
          textOverlays: [
            for (var index = 0; index < 180; index++)
              TextOverlaySettings(
                text: 'Caption $index ${'long filter text ' * 8}',
                timelineStart: 2,
                timelineEnd: 3,
              ),
          ],
        ),
      ),
    );
    expect(
      oversizedTextResult.success,
      isTrue,
      reason: oversizedTextResult.message,
    );
    expect(await File(oversizedText).length(), greaterThan(0));

    final manualCaptions =
        '${temp.path}${Platform.pathSeparator}manual_captions.mp4';
    final manualCaptionResult = await exportVideo(
      ExportJob(
        inputPath: source,
        outputPath: manualCaptions,
        settings: const VideoEditSettings(
          speed: 1,
          flip: 'none',
          scaleX: 1,
          scaleY: 1,
          zoom: 1,
          watermarkPath: null,
          watermarkPosition: 'custom',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1,
          musicVolume: 0.7,
          automaticCaptions: true,
          captionCase: 'original',
          captionCues: [
            CaptionCueSettings(
              start: 0.05,
              end: 0.9,
              text: 'Editable caption',
              words: [
                CaptionWordSettings(
                  start: 0.05,
                  end: 0.4,
                  text: 'Editable',
                ),
                CaptionWordSettings(
                  start: 0.4,
                  end: 0.9,
                  text: 'caption',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    expect(
      manualCaptionResult.success,
      isTrue,
      reason: manualCaptionResult.message,
    );
    expect(await File(manualCaptions).length(), greaterThan(0));

    final layered = '${temp.path}${Platform.pathSeparator}layered.mp4';
    final layeredResult = await exportMultiTrackTimeline(
      MultiTrackExportJob(
        outputPath: layered,
        width: 320,
        height: 180,
        frameRate: 15,
        videoBitrateKbps: 1200,
        hardwareEncoding: false,
        captionSettings: const VideoEditSettings(
          speed: 1,
          flip: 'none',
          scaleX: 1,
          scaleY: 1,
          zoom: 1,
          watermarkPath: null,
          watermarkPosition: 'custom',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1,
          musicVolume: 1,
          automaticCaptions: false,
          captionFont: 'Arial',
          captionFontSize: 28,
          captionCase: 'original',
          captionCues: [
            CaptionCueSettings(
              start: 0.2,
              end: 0.8,
              text: 'Timeline caption',
            ),
          ],
        ),
        timeline: TimelineModel(
          tracks: [
            TrackModel(
              id: 'video-1',
              type: TrackType.video,
              index: 1,
              clips: [
                ClipModel(
                  id: 'base-video',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: 1,
                  sourceStart: 0,
                  zIndex: 0,
                ),
              ],
            ),
            TrackModel(
              id: 'video-2',
              type: TrackType.video,
              index: 2,
              clips: [
                ClipModel(
                  id: 'overlay-video',
                  mediaPath: source,
                  timelineStart: 0.2,
                  duration: 0.6,
                  sourceStart: 0.1,
                  zIndex: 1,
                  transform: const ClipTransform(
                    opacity: 0.75,
                    scaleX: 0.45,
                    scaleY: 0.45,
                    positionX: 0.85,
                    positionY: 0.15,
                    blendMode: 'multiply',
                  ),
                  effects: const [
                    ClipEffect(
                      id: 'real-blur',
                      type: ClipEffectType.blur,
                      amount: 0.15,
                    ),
                    ClipEffect(
                      id: 'real-vignette',
                      type: ClipEffectType.vignette,
                      amount: 0.4,
                    ),
                  ],
                  transitionIn: const ClipTransition(
                    type: ClipTransitionType.dissolve,
                    duration: 0.15,
                  ),
                  keyframes: const [
                    ClipKeyframe(
                      offset: 0,
                      transform: ClipTransform(
                        opacity: 0.75,
                        scaleX: 0.45,
                        scaleY: 0.45,
                        positionX: 0.2,
                        positionY: 0.15,
                        rotationDegrees: -2,
                        blendMode: 'multiply',
                      ),
                    ),
                    ClipKeyframe(
                      offset: 0.6,
                      transform: ClipTransform(
                        opacity: 0.75,
                        scaleX: 0.45,
                        scaleY: 0.45,
                        positionX: 0.85,
                        positionY: 0.15,
                        rotationDegrees: 2,
                        blendMode: 'multiply',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            TrackModel(
              id: 'audio-1',
              type: TrackType.audio,
              index: 1,
              clips: [
                ClipModel(
                  id: 'base-audio',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: 1,
                  sourceStart: 0,
                  zIndex: 0,
                ),
              ],
            ),
          ],
          duration: 1,
        ),
      ),
    );
    expect(layeredResult.success, isTrue, reason: layeredResult.message);
    expect(await File(layered).length(), greaterThan(0));
    expect(await _mediaDuration(layered), closeTo(1, 0.2));

    final fixedPortrait =
        '${temp.path}${Platform.pathSeparator}fixed_portrait.mp4';
    final fixedPortraitResult = await exportMultiTrackTimeline(
      MultiTrackExportJob(
        outputPath: fixedPortrait,
        width: 120,
        height: 160,
        frameRate: 15,
        videoBitrateKbps: 600,
        hardwareEncoding: false,
        playbackSpeedsByMediaPath: {anamorphic: 1.15},
        timeline: TimelineModel(
          tracks: [
            TrackModel(
              id: 'video-1',
              type: TrackType.video,
              index: 1,
              clips: [
                ClipModel(
                  id: 'anamorphic-video',
                  mediaPath: anamorphic,
                  timelineStart: 0,
                  duration: 1 / 1.15,
                  sourceStart: 0,
                  zIndex: 0,
                  transform: const ClipTransform(
                    scaleX: 1.2,
                    scaleY: 2,
                    canvasMode: 'none',
                  ),
                ),
              ],
            ),
          ],
          duration: 1 / 1.15,
        ),
      ),
    );
    expect(
      fixedPortraitResult.success,
      isTrue,
      reason: fixedPortraitResult.message,
    );
    expect(await _videoSize(fixedPortrait), (width: 120, height: 160));
    expect(await _videoSampleAspectRatio(fixedPortrait), '1:1');
    expect(await _mediaDuration(fixedPortrait), closeTo(1 / 1.15, 0.12));
    final topPixel = await _videoPixel(fixedPortrait, x: 60, y: 4);
    final centerPixel = await _videoPixel(fixedPortrait, x: 60, y: 80);
    expect(topPixel.reduce((left, right) => left + right), lessThan(18));
    expect(centerPixel.reduce((left, right) => left + right), greaterThan(30));

    final transitioned =
        '${temp.path}${Platform.pathSeparator}transitioned.mp4';
    final transitionedResult = await exportMultiTrackTimeline(
      MultiTrackExportJob(
        outputPath: transitioned,
        width: 320,
        height: 180,
        frameRate: 15,
        videoBitrateKbps: 1200,
        hardwareEncoding: false,
        timeline: TimelineModel(
          tracks: [
            TrackModel(
              id: 'video-1',
              type: TrackType.video,
              index: 1,
              clips: [
                ClipModel(
                  id: 'transition-video-1',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: 0.7,
                  sourceStart: 0,
                  zIndex: 0,
                ),
                ClipModel(
                  id: 'transition-video-2',
                  mediaPath: source,
                  timelineStart: 0.5,
                  duration: 0.7,
                  sourceStart: 0.2,
                  zIndex: 0,
                  transitionIn: const ClipTransition(
                    type: ClipTransitionType.slideLeft,
                    duration: 0.2,
                  ),
                ),
              ],
            ),
            TrackModel(
              id: 'audio-1',
              type: TrackType.audio,
              index: 1,
              clips: [
                ClipModel(
                  id: 'transition-audio-1',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: 0.7,
                  sourceStart: 0,
                  zIndex: 0,
                ),
                ClipModel(
                  id: 'transition-audio-2',
                  mediaPath: source,
                  timelineStart: 0.5,
                  duration: 0.7,
                  sourceStart: 0.2,
                  zIndex: 0,
                  transitionIn: const ClipTransition(
                    type: ClipTransitionType.slideLeft,
                    duration: 0.2,
                  ),
                ),
              ],
            ),
          ],
          duration: 1.2,
        ),
      ),
    );
    expect(
      transitionedResult.success,
      isTrue,
      reason: transitionedResult.message,
    );
    expect(await File(transitioned).length(), greaterThan(0));
    expect(await _mediaDuration(transitioned), closeTo(1.2, 0.2));

    final sequence = '${temp.path}${Platform.pathSeparator}sequence.mp4';
    final sequenceResult = await exportVideoSequence(
      SequenceExportJob(
        outputPath: sequence,
        settings: const VideoEditSettings(
          speed: 1.0,
          flip: 'none',
          scaleX: 1.0,
          scaleY: 1.0,
          zoom: 1.0,
          watermarkPath: null,
          watermarkPosition: 'custom',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1.0,
          musicVolume: 0.7,
        ),
        jobs: [
          ExportJob(
            inputPath: source,
            outputPath: '${temp.path}${Platform.pathSeparator}sequence_1.mp4',
            settings: const VideoEditSettings(
              speed: 1.0,
              flip: 'none',
              scaleX: 1.0,
              scaleY: 1.0,
              zoom: 1.0,
              watermarkPath: null,
              watermarkPosition: 'custom',
              watermarkSize: 0.12,
              musicPath: null,
              originalVolume: 1.0,
              musicVolume: 0.7,
            ),
          ),
          ExportJob(
            inputPath: source,
            outputPath: '${temp.path}${Platform.pathSeparator}sequence_2.mp4',
            settings: const VideoEditSettings(
              speed: 1.0,
              flip: 'none',
              scaleX: 1.0,
              scaleY: 1.0,
              zoom: 1.0,
              watermarkPath: null,
              watermarkPosition: 'custom',
              watermarkSize: 0.12,
              musicPath: null,
              originalVolume: 1.0,
              musicVolume: 0.7,
            ),
          ),
        ],
      ),
    );
    expect(sequenceResult.success, isTrue, reason: sequenceResult.message);
    expect(await File(sequence).length(), greaterThan(0));
    expect(await _mediaDuration(sequence), greaterThan(1.5));

    final captionAudio =
        '${temp.path}${Platform.pathSeparator}caption_timeline.wav';
    final captionAudioResult = await exportCaptionAudioSequence(
      outputPath: captionAudio,
      segments: [
        CaptionAudioSegment(
          inputPath: source,
          sourceStart: 0,
          duration: 0.8,
          speed: 1,
        ),
        CaptionAudioSegment(
          inputPath: silent,
          sourceStart: 0,
          duration: 0.8,
          speed: 2,
        ),
      ],
    );
    expect(
      captionAudioResult.success,
      isTrue,
      reason: captionAudioResult.message,
    );
    expect(await File(captionAudio).length(), greaterThan(1000));
    expect(await _mediaDuration(captionAudio), closeTo(1.2, 0.15));
    final captionAudioInfo = await _audioInfo(captionAudio);
    expect(captionAudioInfo, contains('pcm_s16le,16000,1'));

    const animations = [
      'fade in',
      'fade out',
      'text typing',
      'flow up',
      'flow down',
      'flow left',
      'flow right',
      'pop up line',
    ];
    for (final animation in animations) {
      final output =
          '${temp.path}${Platform.pathSeparator}animation_${animation.replaceAll(' ', '_')}.mp4';
      final result = await exportVideo(
        ExportJob(
          inputPath: source,
          outputPath: output,
          settings: VideoEditSettings(
            speed: 1.0,
            flip: 'none',
            scaleX: 1.0,
            scaleY: 1.0,
            zoom: 1.0,
            watermarkPath: null,
            watermarkPosition: 'custom',
            watermarkSize: 0.12,
            musicPath: null,
            originalVolume: 1.0,
            musicVolume: 0.7,
            overlayText: 'Roth',
            overlayTextX: 0.5,
            overlayTextY: 0.5,
            overlayTextSize: 24,
            overlayTextColor: '#FACC15',
            overlayTextStroke: 2,
            overlayTextStrokeColor: '#EF4444',
            overlayTextShadowColor: '#000000',
            overlayTextAnimation: animation,
          ),
        ),
      );
      expect(result.success, isTrue, reason: '$animation: ${result.message}');
      expect(await File(output).length(), greaterThan(0));
    }

    final silentResult = await exportVideo(
      ExportJob(
        inputPath: silent,
        outputPath: editedSilent,
        settings: const VideoEditSettings(
          speed: 1.5,
          flip: 'none',
          scaleX: 1.0,
          scaleY: 1.0,
          zoom: 1.0,
          watermarkPath: null,
          watermarkPosition: 'bottom-right',
          watermarkSize: 0.12,
          musicPath: null,
          originalVolume: 1.0,
          musicVolume: 0.7,
          outputRatio: '1:1',
        ),
      ),
    );

    expect(silentResult.success, isTrue, reason: silentResult.message);
    expect(await File(editedSilent).length(), greaterThan(0));
    final squareSize = await _videoSize(editedSilent);
    expect(squareSize.width, squareSize.height);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> _runFfmpeg(List<String> args) async {
  final result = await Process.run('ffmpeg', args);
  if (result.exitCode != 0) {
    fail('ffmpeg failed: ${result.stderr}');
  }
}

Future<({int width, int height})> _videoSize(String path) async {
  final result = await Process.run('ffprobe', [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=width,height',
    '-of',
    'csv=s=x:p=0',
    path,
  ]);
  if (result.exitCode != 0) {
    fail('ffprobe failed: ${result.stderr}');
  }
  final parts = '${result.stdout}'.trim().split('x');
  return (width: int.parse(parts[0]), height: int.parse(parts[1]));
}

Future<String> _videoSampleAspectRatio(String path) async {
  final result = await Process.run('ffprobe', [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=sample_aspect_ratio',
    '-of',
    'default=noprint_wrappers=1:nokey=1',
    path,
  ]);
  if (result.exitCode != 0) {
    fail('ffprobe failed: ${result.stderr}');
  }
  return '${result.stdout}'.trim();
}

Future<List<int>> _videoPixel(
  String path, {
  required int x,
  required int y,
}) async {
  final result = await Process.run(
    'ffmpeg',
    [
      '-v',
      'error',
      '-ss',
      '0.5',
      '-i',
      path,
      '-vf',
      'crop=2:2:$x:$y,scale=1:1,format=rgb24',
      '-frames:v',
      '1',
      '-f',
      'rawvideo',
      'pipe:1',
    ],
    stdoutEncoding: null,
  );
  if (result.exitCode != 0) {
    fail('ffmpeg pixel sample failed: ${result.stderr}');
  }
  return List<int>.from(result.stdout as List<int>).take(3).toList();
}

Future<double> _mediaDuration(String path) async {
  final result = await Process.run('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'default=noprint_wrappers=1:nokey=1',
    path,
  ]);
  if (result.exitCode != 0) {
    fail('ffprobe failed: ${result.stderr}');
  }
  return double.parse('${result.stdout}'.trim());
}

Future<String> _audioInfo(String path) async {
  final result = await Process.run('ffprobe', [
    '-v',
    'error',
    '-select_streams',
    'a:0',
    '-show_entries',
    'stream=codec_name,sample_rate,channels',
    '-of',
    'csv=p=0',
    path,
  ]);
  if (result.exitCode != 0) {
    fail('ffprobe failed: ${result.stderr}');
  }
  return '${result.stdout}'.trim();
}
