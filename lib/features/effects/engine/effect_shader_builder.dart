import '../../timeline/domain/timeline_models.dart';

class EffectShaderBuilder {
  const EffectShaderBuilder();

  List<String> build(List<ClipEffect> effects) => [
        for (final effect in effects)
          if (effect.enabled) _filter(effect),
      ];

  String _filter(ClipEffect effect) {
    final amount = effect.amount;
    return switch (effect.type) {
      ClipEffectType.brightness => 'eq=brightness=${amount.toStringAsFixed(3)}',
      ClipEffectType.contrast =>
        'eq=contrast=${(1 + amount).toStringAsFixed(3)}',
      ClipEffectType.saturation =>
        'eq=saturation=${(1 + amount).toStringAsFixed(3)}',
      ClipEffectType.gamma => 'eq=gamma=${(1 + amount).toStringAsFixed(3)}',
      ClipEffectType.grayscale => 'hue=s=0',
      ClipEffectType.sepia =>
        'colorchannelmixer=.393:.769:.189:.349:.686:.168:.272:.534:.131',
      ClipEffectType.blur => 'gblur=sigma=${amount.abs().toStringAsFixed(2)}',
      ClipEffectType.sharpen => 'unsharp=5:5:${amount.toStringAsFixed(2)}',
      ClipEffectType.invert => 'negate',
      ClipEffectType.hueRotate => 'hue=h=${(amount * 180).toStringAsFixed(2)}',
      _ => 'null',
    };
  }
}
