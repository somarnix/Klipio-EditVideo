import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/services/platform/platform_support.dart' as platform;

void main() {
  test('waveform peaks come from decoded source audio and are cached',
      () async {
    final directory = await Directory.systemTemp.createTemp('klipio-waveform-');
    addTearDown(() => directory.delete(recursive: true));
    final input = File('${directory.path}${Platform.pathSeparator}tone.wav');
    await input.writeAsBytes(_wavWithSilentThenLoudTone());

    final peaks = await platform.audioWaveformPeaks(
      input.path,
      '${directory.path}${Platform.pathSeparator}cache',
    );

    expect(peaks.length, inInclusiveRange(45, 55));
    expect(peaks.take(20).reduce(math.max), lessThan(0.02));
    expect(peaks.skip(30).reduce(math.max), greaterThan(0.5));

    final cached = await platform.audioWaveformPeaks(
      input.path,
      '${directory.path}${Platform.pathSeparator}cache',
    );
    expect(cached, peaks);
  });
}

Uint8List _wavWithSilentThenLoudTone() {
  const sampleRate = 8000;
  const sampleCount = sampleRate;
  const dataLength = sampleCount * 2;
  final bytes = Uint8List(44 + dataLength);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes[offset + index] = value.codeUnitAt(index);
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, dataLength, Endian.little);
  for (var index = sampleRate ~/ 2; index < sampleCount; index++) {
    final sample =
        (math.sin(2 * math.pi * 440 * index / sampleRate) * 26000).round();
    data.setInt16(44 + index * 2, sample, Endian.little);
  }
  return bytes;
}
