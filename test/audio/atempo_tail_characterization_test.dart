import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const rate = 48000;
const binSamples = 48; // Existing 1 ms detector, not a new tolerance.

// One cue has two distinguishable regions: 2 kHz first half, 1 kHz last half.
// Both have integer periods in a detector bin. Never fill a missing tail with
// repeated source samples, which could disguise a processor failure.
Future<void> writeTone(File file, int samples) async {
  final bytes = ByteData(44 + samples * 2);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  bytes.setUint32(4, 36 + samples * 2, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, rate, Endian.little);
  bytes.setUint32(28, rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  bytes.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    final frequency = i < samples ~/ 2 ? 2000 : 1000;
    bytes.setInt16(
        44 + i * 2,
        (4096 * math.sin(2 * math.pi * frequency * i / rate)).round(),
        Endian.little);
  }
  await file.writeAsBytes(bytes.buffer.asUint8List());
}

typedef Audible = ({
  int samples,
  int firstSample,
  int lastSample,
  int firstBin,
  int endBin,
  int tailToneEndBin
});

Audible measure(ByteData pcm) {
  var first = -1, end = -1, tail = -1;
  final count = pcm.lengthInBytes ~/ 4;
  var firstSample = -1, lastSample = -1;
  for (var sample = 0; sample < count; sample++) {
    if (pcm.getFloat32(sample * 4, Endian.little).abs() > .002) {
      if (firstSample < 0) firstSample = sample;
      lastSample = sample;
    }
  }
  for (var bin = 0; bin < count ~/ binSamples; bin++) {
    var energy = 0.0, real = 0.0, imaginary = 0.0;
    for (var n = 0; n < binSamples; n++) {
      final value = pcm.getFloat32((bin * binSamples + n) * 4, Endian.little);
      energy += value * value;
      final phase = 2 * math.pi * 1000 * n / rate;
      real += value * math.cos(phase);
      imaginary += value * math.sin(phase);
    }
    if (math.sqrt(energy / binSamples) > .002) {
      if (first < 0) first = bin;
      end = bin + 1;
    }
    // The distinct final 1 kHz content, not merely nonzero/silent padding.
    if (2 * math.sqrt(real * real + imaginary * imaginary) / binSamples >
        .002) {
      tail = bin + 1;
    }
  }
  return (
    samples: count,
    firstSample: firstSample,
    lastSample: lastSample,
    firstBin: first,
    endBin: end,
    tailToneEndBin: tail
  );
}

void main() {
  test(
      'isolated atempo tail matrix: source, processor, clip, mix, bounded flush',
      () async {
    final root = await Directory.systemTemp.createTemp('klipio-atempo-tail-');
    addTearDown(() => root.delete(recursive: true));
    final ffmpeg =
        File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
    Future<ByteData> pcm(List<String> args) async {
      final result = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            ...args,
            '-ac',
            '1',
            '-ar',
            '$rate',
            '-f',
            'f32le',
            'pipe:1',
          ],
          stdoutEncoding: null);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return ByteData.sublistView(
          Uint8List.fromList(result.stdout as List<int>));
    }

    var shortTailLosses = 0, headroomStillLosesTail = 0;
    // atempo's implementation rounds sample_rate/24 up to a power of two.
    // Characterize 1/2/4 such windows as INPUT processing silence only.
    var window = 1;
    while (window < rate ~/ 24) {
      window *= 2;
    }
    for (final ms in [20, 100, 200, 400, 1000, 2000]) {
      final source = File('${root.path}/tone-$ms.wav');
      await writeTone(source, ms * binSamples);
      final directBytes = await pcm(['-i', source.path]);
      final direct = measure(directBytes);
      expect(direct.samples, ms * binSamples);
      expect(direct.firstBin, 0);
      expect(direct.endBin, ms);
      expect(direct.tailToneEndBin, ms);
      for (final speed in [.5, .75, 1.0, 1.5, 2.0]) {
        final expectedSamples = (ms * binSamples / speed).round();
        final expectedEndBin = expectedSamples ~/ binSamples;
        final tempo = speed == 1 ? 'anull' : 'atempo=$speed';
        final raw = measure(await pcm(['-i', source.path, '-af', tempo]));
        final clip = measure(await pcm([
          '-i',
          source.path,
          '-af',
          'atrim=end_sample=${ms * binSamples},asetpts=PTS-STARTPTS,'
              '$tempo,atrim=end_sample=$expectedSamples,volume=1,adelay=0|0,asetpts=N/SR/TB'
        ]));
        final plan = const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
              timeline:
                  TimelineModel(duration: expectedSamples / rate, tracks: [
                TrackModel(
                    id: 'audio-1',
                    type: TrackType.audio,
                    index: 1,
                    clips: [
                      ClipModel(
                          id: 'clip',
                          mediaPath: source.path,
                          timelineStart: 0,
                          sourceStart: 0,
                          duration: expectedSamples / rate,
                          playbackSpeed: speed,
                          zIndex: 0),
                    ]),
              ]),
              outputPath: 'unused.mp4',
              width: 16,
              height: 16,
              frameRate: 10,
            ),
            encoder: 'libx264');
        final mixedBytes = await pcm([
          ...plan.arguments.take(plan.arguments.indexOf('-map')),
          '-map',
          '[outv]',
          '-f',
          'null',
          '-',
          '-map',
          '[outa]',
        ]);
        final mix = measure(mixedBytes);
        expect(mix.samples, expectedSamples);
        // Diagnostic isolation: mixer must not introduce further audible loss.
        expect((clip.endBin - mix.endBin).abs(), lessThanOrEqualTo(1));
        expect((clip.tailToneEndBin - mix.tailToneEndBin).abs(),
            lessThanOrEqualTo(1));
        if (speed == 1) {
          expect(mixedBytes.buffer.asUint8List(),
              directBytes.buffer.asUint8List());
        }
        if (expectedEndBin - raw.endBin > 1) shortTailLosses++;
        final flush = <int, Audible>{};
        for (final windows in [1, 2, 4]) {
          final padded = measure(await pcm([
            '-i',
            source.path,
            '-af',
            'apad=pad_len=${window * windows},$tempo,atrim=end_sample=$expectedSamples'
          ]));
          expect(padded.samples, expectedSamples);
          flush[windows] = padded;
        }
        if (expectedEndBin - flush[4]!.tailToneEndBin > 1) {
          headroomStillLosesTail++;
        }
        // ignore: avoid_print
        print(
            'TAIL speed=$speed source_ms=$ms expected_samples=$expectedSamples '
            'expected_end_bin=$expectedEndBin source=$direct raw=$raw clip=$clip mix=$mix '
            'headroom_windows=$flush');
      }
    }
    // Characterization guards, not acceptance of degraded content. If a future
    // FFmpeg update resolves these limitations, review the evidence explicitly.
    expect(shortTailLosses, greaterThan(0));
    expect(headroomStillLosesTail, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
