class AdjustmentSettings {
  const AdjustmentSettings({
    this.temperature = 0,
    this.tint = 0,
    this.exposure = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.whites = 0,
    this.blacks = 0,
    this.saturation = 0,
    this.sharpen = 0,
    this.fade = 0,
    this.vignette = 0,
  });

  final double temperature;
  final double tint;
  final double exposure;
  final double contrast;
  final double highlights;
  final double shadows;
  final double whites;
  final double blacks;
  final double saturation;
  final double sharpen;
  final double fade;
  final double vignette;

  bool get isNeutral => this == const AdjustmentSettings();

  AdjustmentSettings copyWith({
    double? temperature,
    double? tint,
    double? exposure,
    double? contrast,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    double? saturation,
    double? sharpen,
    double? fade,
    double? vignette,
  }) =>
      AdjustmentSettings(
        temperature: temperature ?? this.temperature,
        tint: tint ?? this.tint,
        exposure: exposure ?? this.exposure,
        contrast: contrast ?? this.contrast,
        highlights: highlights ?? this.highlights,
        shadows: shadows ?? this.shadows,
        whites: whites ?? this.whites,
        blacks: blacks ?? this.blacks,
        saturation: saturation ?? this.saturation,
        sharpen: sharpen ?? this.sharpen,
        fade: fade ?? this.fade,
        vignette: vignette ?? this.vignette,
      );

  @override
  bool operator ==(Object other) =>
      other is AdjustmentSettings &&
      temperature == other.temperature &&
      tint == other.tint &&
      exposure == other.exposure &&
      contrast == other.contrast &&
      highlights == other.highlights &&
      shadows == other.shadows &&
      whites == other.whites &&
      blacks == other.blacks &&
      saturation == other.saturation &&
      sharpen == other.sharpen &&
      fade == other.fade &&
      vignette == other.vignette;

  @override
  int get hashCode => Object.hash(
        temperature,
        tint,
        exposure,
        contrast,
        highlights,
        shadows,
        whites,
        blacks,
        saturation,
        sharpen,
        fade,
        vignette,
      );
}
