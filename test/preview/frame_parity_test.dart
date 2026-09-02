import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/video_geometry.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

// Evidence: actual FFmpeg RGB frames versus a CPU reference for the active
// preview's contain/stretch/pan/center-rotation contract. NOT native texture
// capture; not a text-shaping or audio test. No lossy output encoder is used.
void main() {
  for (final variant in ['static', 'animated', 'effect-transition']) {
    final animated = variant == 'animated';
    test(
        'RGB frames match preview geometry interiors and exact gap frames ($variant)',
        () async {
      final bundled =
          File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe');
      final ffmpeg = bundled.existsSync() ? bundled.absolute.path : 'ffmpeg';
      final temp =
          await Directory.systemTemp.createTemp('klipio-frame-parity-');
      addTearDown(() => temp.delete(recursive: true));
      final raw = File('${temp.path}/source.rgb');
      final source = '${temp.path}/source.mkv';
      final bytes = Uint8List(64 * 32 * 3 * 20);
      for (var frame = 0; frame < 20; frame++) {
        for (var y = 0; y < 32; y++) {
          for (var x = 0; x < 64; x++) {
            final shade = x < 32 ? (frame < 10 ? 255 : 64) : 128;
            final offset = ((frame * 32 + y) * 64 + x) * 3;
            bytes.fillRange(offset, offset + 3, shade);
          }
        }
      }
      await raw.writeAsBytes(bytes);
      final encoded = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-y',
        '-f',
        'rawvideo',
        '-pixel_format',
        'rgb24',
        '-video_size',
        '64x32',
        '-framerate',
        '10',
        '-i',
        raw.path,
        '-c:v',
        'ffv1',
        source
      ]);
      expect(encoded.exitCode, 0, reason: '${encoded.stderr}');
      final clips = [
        for (var i = 0; i < 3; i++)
          ClipModel(
              id: 'clip$i',
              mediaPath: source,
              timelineStart: [0.0, 0.4, 1.0][i],
              duration: 0.4,
              sourceStart: [0.0, 1.0, 0.2][i],
              zIndex: 0,
              playbackSpeed: [0.5, 1.0, 2.0][i],
              effects: variant == 'effect-transition' && i == 2
                  ? const [
                      ClipEffect(id: 'invert', type: ClipEffectType.invert),
                    ]
                  : const [],
              transitionIn: variant == 'effect-transition' && i == 2
                  ? const ClipTransition(
                      type: ClipTransitionType.dissolve, duration: 0.2)
                  : null,
              keyframes: animated && i == 2
                  ? const [
                      ClipKeyframe(
                          offset: 0,
                          transform: ClipTransform(
                              scaleX: 1,
                              scaleY: 1,
                              positionX: 0.7,
                              positionY: 0.3,
                              rotationDegrees: 27,
                              opacity: 0.3,
                              flip: 'right')),
                      ClipKeyframe(
                          offset: 0.3,
                          transform: ClipTransform(
                              scaleX: 1.2,
                              scaleY: 0.8,
                              positionX: 0.7,
                              positionY: 0.3,
                              rotationDegrees: 27,
                              opacity: 0.7,
                              flip: 'right')),
                    ]
                  : const [],
              transform: ClipTransform(
                  scaleX: 1.2,
                  scaleY: 0.8,
                  positionX: 0.7,
                  positionY: 0.3,
                  rotationDegrees: [0.0, 90.0, 27.0][i],
                  opacity: 0.7,
                  flip: 'right'))
      ];
      final timeline = TimelineModel(tracks: [
        TrackModel(id: 'v', type: TrackType.video, index: 0, clips: clips)
      ], duration: 1.6);
      // Export consumes reopened project data; the independent reference keeps
      // the original model, including keyframes, effects and transition state.
      final restored = TimelineModel.fromJson(timeline.toJson());
      final plan = const MultiTrackFilterBuilder().build(
          MultiTrackExportJob(
              timeline: restored,
              outputPath: 'unused.mp4',
              width: 96,
              height: 128,
              frameRate: 10),
          encoder: 'libx264',
          sourceDimensions: {source: (width: 64, height: 32)});
      final args = plan.arguments.take(plan.arguments.indexOf('-map')).toList();
      final rendered = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            ...args,
            '-map',
            '[outv]',
            '-an',
            '-frames:v',
            '16',
            '-pix_fmt',
            'rgb24',
            '-f',
            'rawvideo',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(rendered.exitCode, 0, reason: '${rendered.stderr}');
      final frames = rendered.stdout as List<int>;
      const frameBytes = 96 * 128 * 3;
      expect(frames.length, frameBytes * 16);
      for (var frame = 0; frame < 16; frame++) {
        final target = ProgramTimelineMapper.resolve(timeline, frame / 10);
        var compared = 0;
        var maxError = 0;
        var totalError = 0;
        var worst = '';
        for (var y = 0; y < 128; y++) {
          for (var x = 0; x < 96; x++) {
            final expected =
                _reference(target.clip, target.sourceSeconds, x + 0.5, y + 0.5);
            if (expected == null) continue;
            for (var channel = 0; channel < 3; channel++) {
              final actual =
                  frames[frame * frameBytes + (y * 96 + x) * 3 + channel];
              final error = (actual - expected).abs();
              if (error > maxError) {
                worst = 'x=$x y=$y expected=$expected actual=$actual';
              }
              maxError = math.max(maxError, error);
              totalError += error;
              compared++;
            }
          }
        }
        // Three levels allow RGB/YUV conversion and 8-bit alpha quantization.
        // The 3px edge band is excluded only for resampling, never interiors.
        expect(compared, greaterThan(frameBytes * 0.7));
        expect(maxError, lessThanOrEqualTo(3),
            reason: 'frame=$frame mean=${totalError / compared} $worst');
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}

int? _reference(ClipModel? clip, double? sourceTime, double x, double y) {
  if (clip == null) return 0;
  final transform = clip.transformAt(
      (sourceTime! - clip.sourceStart) / clip.resolvedPlaybackSpeed());
  final box = VideoGeometry.resolve(
      canvasWidth: 96,
      canvasHeight: 128,
      sourceWidth: 64,
      sourceHeight: 32,
      scaleX: transform.scaleX,
      scaleY: transform.scaleY,
      positionX: transform.positionX,
      positionY: transform.positionY);
  final angle = transform.rotationDegrees * math.pi / 180;
  final dx = x - (box.left + box.width / 2);
  final dy = y - (box.top + box.height / 2);
  final localX = math.cos(angle) * dx + math.sin(angle) * dy;
  final localY = -math.sin(angle) * dx + math.cos(angle) * dy;
  if ((localX.abs() - box.width / 2).abs() < 3 ||
      (localY.abs() - box.height / 2).abs() < 3 ||
      localX.abs() < 3) return null;
  if (localX.abs() >= box.width / 2 || localY.abs() >= box.height / 2) return 0;
  var shade = localX > 0 ? (sourceTime < 1 ? 255 : 64) : 128;
  for (final effect in clip.effects) {
    if (effect.enabled && effect.type == ClipEffectType.invert) {
      shade = 255 - shade;
    }
  }
  final local = (sourceTime - clip.sourceStart) / clip.resolvedPlaybackSpeed();
  final transitionAlpha = clip.transitionIn == null
      ? 1.0
      : (local / clip.transitionIn!.duration).clamp(0.0, 1.0);
  return (shade * transform.opacity * transitionAlpha).round();
}
