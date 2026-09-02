import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/domain/detach_audio_edit.dart';
import 'package:klipio/features/timeline/domain/clip_speed_edit.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';

void main() {
  for (final fade in [false, true]) {
    for (final detach in [false, true]) {
      test(
          'export PCM measures reused-source speed, volume, gaps and trailing canvas fade=$fade detach=$detach',
          () async {
        final root =
            await Directory.systemTemp.createTemp('klipio-audio-timing-');
        addTearDown(() => root.delete(recursive: true));
        final ffmpeg = File(
                'ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
        final source = '${root.path}/source.mkv';
        final generated = await Process.run(ffmpeg, [
          '-v',
          'error',
          '-y',
          '-f',
          'lavfi',
          '-i',
          'color=black:s=16x16:r=10:d=2',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=1000:sample_rate=48000:duration=2',
          '-c:v',
          'ffv1',
          '-c:a',
          'pcm_s16le',
          source
        ]);
        expect(generated.exitCode, 0, reason: '${generated.stderr}');
        final sourceTimeline = TimelineModel(tracks: [
          TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
            for (var i = 0; i < 3; i++)
              ClipModel(
                  id: 'v$i',
                  mediaPath: source,
                  timelineStart: i * 0.6,
                  sourceStart: 0.1 + i * 0.5,
                  duration: 0.4,
                  zIndex: 0,
                  playbackSpeed: [0.5, 1.0, 2.0][i]),
          ]),
          TrackModel(id: 'a', type: TrackType.audio, index: 0, clips: [
            for (var i = 0; i < 3; i++)
              ClipModel(
                  id: 'a$i',
                  mediaPath: source,
                  timelineStart: i * 0.6,
                  sourceStart: 0.1 + i * 0.5,
                  duration: 0.4,
                  zIndex: 0,
                  isLinkedAudio: true,
                  transitionIn: fade
                      ? const ClipTransition(
                          type: ClipTransitionType.dissolve, duration: .1)
                      : null,
                  linkedClipId: 'v$i',
                  volume: [0.25, 0.5, 0.75][i]),
          ]),
          TrackModel(id: 'music', type: TrackType.audio, index: 1, clips: [
            ClipModel(
                id: 'independent',
                mediaPath: source,
                timelineStart: 2,
                sourceStart: 0.3,
                duration: 0.1,
                zIndex: 0,
                volume: 0.3),
            ClipModel(
                id: 'muted',
                mediaPath: source,
                timelineStart: 2.2,
                sourceStart: 0,
                duration: 0.1,
                zIndex: 0,
                isMuted: true),
          ]),
        ], duration: 2.4);
        var edited = sourceTimeline;
        if (detach) {
          edited = DetachAudioEdit.apply(edited, 'v2', 'detached');
          edited = ClipSpeedEdit.apply(edited, {'v2'}, .5);
          edited = const TimelineEditor().moveClip(edited,
              clipId: 'v2', targetTrackId: 'v', timelineStart: 3, snap: false);
          edited = const TimelineEditor().deleteClip(edited, 'v2');
          edited =
              TimelineModel.fromJson(jsonDecode(jsonEncode(edited.toJson())));
        }
        final timeline = ProgramRenderSnapshot.build(
            sourceTimeline: edited,
            playbackSpeedsByMediaPath: const {}).outputTimeline;
        final plan = const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
                timeline: timeline,
                outputPath: 'unused.mp4',
                width: 16,
                height: 16,
                frameRate: 10),
            encoder: 'libx264');
        final args =
            plan.arguments.take(plan.arguments.indexOf('-map')).toList();
        final rendered = await Process.run(
            ffmpeg,
            [
              '-v',
              'error',
              ...args,
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
        final bytes = Uint8List.fromList(rendered.stdout as List<int>);
        final data = ByteData.sublistView(bytes);
        final samples = List<double>.generate(
            bytes.length ~/ 4, (i) => data.getFloat32(i * 4, Endian.little));
        double rms(double start, double end) {
          final a = (start * 48000).round();
          final b = math.min((end * 48000).round(), samples.length);
          expect(b, greaterThan(a));
          var energy = 0.0;
          for (var i = a; i < b; i++) {
            energy += samples[i] * samples[i];
          }
          return math.sqrt(energy / (b - a));
        }

        // PCM has no codec priming. atempo rounds sample_rate/24 up to 2048
        // samples here. Gate the tail at HALF that window plus a 1 ms bin.
        // This characterizes the backend, not a promise of sample-exact stretching.
        // https://ffmpeg.org/doxygen/8.0/af__atempo_8c_source.html (yae_reset)
        const tolerance = 1024 / 48000 + 0.001;
        for (final id in [
          'a0',
          'a1',
          detach ? 'detached' : 'a2',
          'independent'
        ]) {
          final clip = timeline.clipById(id)!.clip;
          final start = clip.timelineStart;
          if (id == 'detached') {
            expect(start, closeTo(1.6, 1e-12));
            expect(clip.duration, .2);
            expect(clip.volume, .75);
          }
          final end = clip.timelineEnd;
          final active = <double>[];
          for (var ms = math.max(0, ((start - 0.03) * 1000).floor());
              ms < (end + 0.03) * 1000;
              ms++) {
            if (rms(ms / 1000, (ms + 1) / 1000) > 0.002) active.add(ms / 1000);
          }
          expect(active, isNotEmpty, reason: id);
          final measuredStart = active.first;
          final measuredEnd = active.last + 0.001;
          debugPrint(
              '$id expected=$start..$end measured=$measuredStart..$measuredEnd '
              'error=${measuredStart - start},${measuredEnd - end} tolerance=$tolerance');
          // A linear fade crosses the detector's 0.002 RMS threshold later
          // than clip start. The 1 ms window is reported by its left edge.
          final expectedDetectedStart = fade && id != 'independent'
              ? start +
                  clip.transitionIn!.duration *
                      .002 /
                      (0.125 / math.sqrt(2) * clip.volume) -
                  .0005
              : start;
          expect((measuredStart - expectedDetectedStart).abs(),
              lessThanOrEqualTo(0.001));
          expect((measuredEnd - end).abs(), lessThanOrEqualTo(tolerance));
          if (!fade || id == 'independent') {
            expect(rms(start + 0.03, end - 0.03),
                closeTo(0.125 / math.sqrt(2) * clip.volume, 0.002));
          } else {
            final fadeDuration = clip.transitionIn!.duration;
            for (final fraction in [0.0, .25, .5, .75, 1.0]) {
              final center = start + fadeDuration * fraction;
              final windowStart = math.max(start, center - .0005);
              final windowEnd = windowStart + .001;
              final gain =
                  ((windowStart + windowEnd) / 2 - start) / fadeDuration;
              final expected =
                  0.125 / math.sqrt(2) * clip.volume * gain.clamp(0, 1);
              final measured = rms(windowStart, windowEnd);
              debugPrint('FADE $id phase=$fraction expected=$expected '
                  'measured=$measured error=${(measured - expected).abs()} tolerance=0.002');
              expect(measured, closeTo(expected, .002),
                  reason: '$id phase=$fraction');
            }
          }
        }
        expect(samples.length / 48000, closeTo(timeline.duration, 1 / 48000));
        expect(rms(0.85, 0.95), lessThan(0.00001));
        expect(rms(2.2, timeline.duration), lessThan(0.00001));
      });
    }
  }
}
