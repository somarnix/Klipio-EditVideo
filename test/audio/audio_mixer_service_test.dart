import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/audio/domain/audio_settings.dart';
import 'package:klipio/features/audio/services/audio_mixer_service.dart';

void main() {
  test('audio mixer builds synchronized multi-input amix graph', () {
    const service = AudioMixerService();
    final graph = service.buildFilter(const [
      AudioMixerInput(inputIndex: 0, timelineStart: 0, duration: 3),
      AudioMixerInput(
        inputIndex: 1,
        timelineStart: 2.5,
        duration: 4,
        settings: AudioSettings(volume: 0.4),
      ),
    ]);

    expect(graph, contains('[0:a]'));
    expect(graph, contains('adelay=2500|2500'));
    expect(graph, contains('amix=inputs=2'));
    expect(graph, endsWith('[aout]'));
  });
}
