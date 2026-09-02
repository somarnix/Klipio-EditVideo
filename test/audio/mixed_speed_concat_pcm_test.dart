import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  test(
      'mixed-speed concatenation preserves the same PCM clock as placement mixing',
      () async {
    final root = await Directory.systemTemp.createTemp('klipio-concat-pcm-');
    addTearDown(() => root.delete(recursive: true));
    final ffmpeg =
        File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
    final source = '${root.path}/tones.mkv';
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
      source,
    ]);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');
    ClipModel clip(int i, bool audio) => ClipModel(
        id: '${audio ? 'a' : 'v'}$i',
        mediaPath: source,
        timelineStart: i * .4,
        duration: .4,
        sourceStart: i * .5,
        playbackSpeed: [.5, 1.0, 2.0][i],
        volume: [.2, .5, .8][i],
        zIndex: 0,
        isLinkedAudio: audio,
        linkedClipId: audio ? 'v$i' : null);
    final session = EditorSession()
      ..timeline = TimelineModel(tracks: [
        TrackModel(
            id: 'video-1',
            type: TrackType.video,
            index: 1,
            clips: [for (var i = 0; i < 3; i++) clip(i, false)]),
        TrackModel(
            id: 'audio-1',
            type: TrackType.audio,
            index: 1,
            clips: [for (var i = 0; i < 3; i++) clip(i, true)]),
      ], duration: 1.2);
    final path = '${root.path}/project.klipio.json';
    await session.save(path);
    session.dispose();
    final reloaded = EditorSession();
    addTearDown(reloaded.dispose);
    reloaded.restore((await reloaded.read(path)).revision);
    final output = ProgramRenderSnapshot.build(
        sourceTimeline: reloaded.timeline,
        playbackSpeedsByMediaPath: const {}).outputTimeline;
    // Force only the VIDEO adapter off its sequential optimization. The audio
    // revision is identical. This compares two active production render paths.
    final layered = output.copyWith(duration: output.duration, tracks: [
      for (final track in output.tracks)
        track.type != TrackType.video
            ? track
            : track.copyWith(clips: [
                for (final clip in track.clips)
                  clip.copyWith(
                      transform: clip.transform.copyWith(rotationDegrees: 1)),
              ]),
    ]);
    Future<ByteData> render(TimelineModel timeline, bool sequential) async {
      final plan = const MultiTrackFilterBuilder().build(
          MultiTrackExportJob(
              timeline: timeline,
              outputPath: 'unused.mp4',
              width: 16,
              height: 16,
              frameRate: 10),
          encoder: 'libx264');
      expect(plan.filterGraph.contains('seqAudio'), sequential);
      final result = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            ...plan.arguments.take(plan.arguments.indexOf('-map')),
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
            'pipe:1',
          ],
          stdoutEncoding: null);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return ByteData.sublistView(
          Uint8List.fromList(result.stdout as List<int>));
    }

    final sequential = await render(output, true);
    final general = await render(layered, false);
    expect(sequential.lengthInBytes ~/ 4, (output.duration * 48000).round());
    expect(general.lengthInBytes, sequential.lengthInBytes);
    // Integer 1 ms bins, unchanged detector tolerance. Compare event boundaries
    // and volume bands, not waveform phase (amix/concat may packetize differently).
    List<(int, int, int)> events(ByteData bytes) {
      final result = <(int, int, int)>[];
      var previous = 0, start = 0;
      for (var ms = 0; ms <= bytes.lengthInBytes ~/ 192; ms++) {
        var energy = 0.0;
        if (ms < bytes.lengthInBytes ~/ 192) {
          for (var i = 0; i < 48; i++) {
            final value = bytes.getFloat32((ms * 48 + i) * 4, Endian.little);
            energy += value * value;
          }
        }
        final band = energy < .000192
            ? 0
            : energy < .03
                ? 1
                : energy < .15
                    ? 2
                    : 3;
        if (band != previous) {
          if (previous != 0) result.add((start, ms, previous));
          start = ms;
          previous = band;
        }
      }
      return result;
    }

    final expected = events(general), actual = events(sequential);
    expect(expected.map((event) => event.$3).toSet(), {1, 2, 3});
    expect(actual.length, expected.length);
    expect(actual.map((event) => event.$1).toList(), [0, 800, 1200]);
    expect(actual[1].$2, 1200);
    expect(actual[2].$2, 1400);
    for (var i = 0; i < expected.length; i++) {
      expect(actual[i].$3, expected[i].$3);
      expect((actual[i].$1 - expected[i].$1).abs(), lessThanOrEqualTo(1));
      expect((actual[i].$2 - expected[i].$2).abs(), lessThanOrEqualTo(1));
      // ignore: avoid_print
      print(
          'MIXED PCM placement reference=${expected[i]} concat=${actual[i]} tolerance=1ms');
    }
    // This proves placement parity, not sample-exact WSOLA stretching: any
    // finite-input atempo tail in the reference remains separately measurable.
  });
}
