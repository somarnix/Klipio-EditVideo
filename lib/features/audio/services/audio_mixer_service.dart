import '../domain/audio_settings.dart';

class AudioMixerInput {
  const AudioMixerInput({
    required this.inputIndex,
    required this.timelineStart,
    required this.duration,
    this.settings = const AudioSettings(),
  });

  final int inputIndex;
  final double timelineStart;
  final double duration;
  final AudioSettings settings;
}

class AudioMixerService {
  const AudioMixerService();

  String buildFilter(List<AudioMixerInput> inputs, {String output = 'aout'}) {
    if (inputs.isEmpty) return '';
    final filters = <String>[];
    final labels = <String>[];
    for (var index = 0; index < inputs.length; index++) {
      final input = inputs[index];
      final label = 'amix$index';
      final delay = (input.timelineStart * 1000).round();
      final settings = input.settings;
      final volume = settings.isMuted ? 0 : settings.volume.clamp(0, 10);
      final chain = <String>[
        'atrim=duration=${input.duration.toStringAsFixed(6)}',
        'asetpts=PTS-STARTPTS',
        'volume=${volume.toStringAsFixed(4)}',
        if (settings.fadeIn > Duration.zero)
          'afade=t=in:st=0:d=${settings.fadeIn.inMilliseconds / 1000}',
        if (settings.fadeOut > Duration.zero)
          'afade=t=out:st=${(input.duration - settings.fadeOut.inMilliseconds / 1000).clamp(0, input.duration)}:d=${settings.fadeOut.inMilliseconds / 1000}',
        'adelay=$delay|$delay',
      ];
      filters.add('[${input.inputIndex}:a]${chain.join(',')}[$label]');
      labels.add('[$label]');
    }
    filters.add(
      '${labels.join()}amix=inputs=${labels.length}:dropout_transition=0:normalize=0[$output]',
    );
    return filters.join(';');
  }
}
