import '../../timeline/domain/timeline_models.dart';

/// Both adapters consume the same ordered, enabled instance stack. Invert is
/// the existing binary effect; its legacy amount remains editable-file metadata.
abstract final class EffectRenderState {
  static List<ClipEffect> active(ClipModel clip) =>
      List.unmodifiable(clip.effects.where((e) => e.enabled));
  static const invertGain = -1.0, invertBias = 255.0;
  static const invertMatrix = <double>[
    invertGain,
    0,
    0,
    0,
    invertBias,
    0,
    invertGain,
    0,
    0,
    invertBias,
    0,
    0,
    invertGain,
    0,
    invertBias,
    0,
    0,
    0,
    1,
    0,
  ];
  // RGB rather than YUV negation: complement each color component, not luma.
  static String get invertFilter =>
      "lutrgb=r='${invertBias.toInt()}+${invertGain.toInt()}*val':"
      "g='${invertBias.toInt()}+${invertGain.toInt()}*val':"
      "b='${invertBias.toInt()}+${invertGain.toInt()}*val'";
}
