import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  for (final speed in [.5, 1.0, 2.0]) {
    for (final gap in [0.0, 1e-15, .001, .25]) {
      test('PCM outgoing fade speed=$speed gap=$gap', () async {
        final root = await Directory.systemTemp.createTemp('klipio-fade-out-');
        addTearDown(() => root.delete(recursive: true));
        final ffmpeg = File(
                'ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
        final source = '${root.path}/tone.wav';
        final generated = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=1000:sample_rate=48000:duration=4',
          '-c:a',
          'pcm_s16le',
          source
        ]);
        expect(generated.exitCode, 0, reason: '${generated.stderr}');
        // Captured output-time clips: source span is output duration * speed.
        final timeline = TimelineModel(duration: 1.5 + gap, tracks: [
          TrackModel(id: 'a', type: TrackType.audio, index: 0, clips: [
            ClipModel(
                id: 'first',
                mediaPath: source,
                timelineStart: 0,
                sourceStart: .2,
                duration: 1,
                zIndex: 0,
                playbackSpeed: speed,
                volume: .5),
            ClipModel(
                id: 'second',
                mediaPath: source,
                timelineStart: 1 + gap,
                sourceStart: .2,
                duration: .5,
                zIndex: 0,
                playbackSpeed: speed,
                volume: 0,
                transitionIn: const ClipTransition(
                    type: ClipTransitionType.dissolve, duration: .4))
          ])
        ]);
        final plan = const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
                timeline: timeline,
                outputPath: 'unused.mp4',
                width: 16,
                height: 16,
                frameRate: 10),
            encoder: 'libx264');
        final prefix = plan.arguments.take(plan.arguments.indexOf('-map'));
        final rendered = await Process.run(
            ffmpeg,
            [
              '-v',
              'error',
              ...prefix,
              '-map',
              '[outv]',
              '-f',
              'null',
              '-',
              '-map',
              '[outa]',
              '-ac',
              '1',
              '-ar',
              '48000',
              '-f',
              'f32le',
              'pipe:1'
            ],
            stdoutEncoding: null);
        expect(rendered.exitCode, 0, reason: '${rendered.stderr}');
        final data = ByteData.sublistView(
            Uint8List.fromList(rendered.stdout as List<int>));
        double rms(double t) {
          final start = (t * 48000).round();
          var sum = 0.0;
          for (var i = start; i < start + 48; i++) {
            final value = data.getFloat32(i * 4, Endian.little);
            sum += value * value;
          }
          return math.sqrt(sum / 48);
        }

        // Fade envelopes include near-completion; unfaded tone amplitudes are
        // sampled before the known atempo tail window (covered separately).
        final adjacent = gap == 0 || gap == 1e-15;
        for (final phase in [0.0, .25, .5, .75, if (adjacent) .99, 1.0]) {
          final t = .6 + .4 * phase;
          final gain = adjacent ? (1 - (t + .0005 - .6) / .4).clamp(0, 1) : 1.0;
          final expected = phase == 1 ? 0.0 : .125 / math.sqrt(2) * .5 * gain;
          final measured = rms(t);
          debugPrint(
              'FADE_OUT speed=$speed gap=$gap phase=$phase expected=$expected '
              'measured=$measured error=${(measured - expected).abs()} tolerance=0.002');
          expect(measured, closeTo(expected, .002));
        }
      });
    }
  }
}
