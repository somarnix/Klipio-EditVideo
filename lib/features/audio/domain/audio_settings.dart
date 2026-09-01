class AudioSettings {
  const AudioSettings({
    this.volume = 1,
    this.pan = 0,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.isMuted = false,
    this.ducking = false,
  });

  final double volume;
  final double pan;
  final Duration fadeIn;
  final Duration fadeOut;
  final bool isMuted;
  final bool ducking;

  AudioSettings copyWith({
    double? volume,
    double? pan,
    Duration? fadeIn,
    Duration? fadeOut,
    bool? isMuted,
    bool? ducking,
  }) =>
      AudioSettings(
        volume: volume ?? this.volume,
        pan: pan ?? this.pan,
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        isMuted: isMuted ?? this.isMuted,
        ducking: ducking ?? this.ducking,
      );
}
