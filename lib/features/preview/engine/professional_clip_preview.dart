import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../timeline/domain/timeline_models.dart';
import '../../composition/domain/effect_render_state.dart';
import '../../timeline/domain/transition_boundary.dart';

class ProfessionalClipPreview extends StatelessWidget {
  const ProfessionalClipPreview({
    super.key,
    required this.clip,
    required this.playheadSeconds,
    required this.child,
  });

  final ClipModel clip;
  final double playheadSeconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    for (final effect in EffectRenderState.active(clip)) {
      result = _effect(effect, result);
    }
    final transition = clip.transitionIn;
    if (transition == null) return result;
    final progress = TransitionBoundary.progress(clip, playheadSeconds);
    result = Opacity(opacity: progress, child: result);
    if (transition.type == ClipTransitionType.slideLeft ||
        transition.type == ClipTransitionType.slideRight) {
      final direction =
          transition.type == ClipTransitionType.slideLeft ? 1 : -1;
      result = FractionalTranslation(
        translation: Offset(direction * (1 - progress), 0),
        child: result,
      );
    } else if (transition.type == ClipTransitionType.slideUp ||
        transition.type == ClipTransitionType.slideDown) {
      final direction = transition.type == ClipTransitionType.slideUp ? 1 : -1;
      result = FractionalTranslation(
        translation: Offset(0, direction * (1 - progress)),
        child: result,
      );
    }
    return result;
  }

  Widget _effect(ClipEffect effect, Widget child) {
    final supportsSignedAmount = {
      ClipEffectType.temperature,
      ClipEffectType.tint,
      ClipEffectType.exposure,
      ClipEffectType.brightness,
      ClipEffectType.contrast,
      ClipEffectType.highlights,
      ClipEffectType.shadows,
      ClipEffectType.whites,
      ClipEffectType.blacks,
      ClipEffectType.brilliance,
      ClipEffectType.saturation,
      ClipEffectType.gamma,
    }.contains(effect.type);
    final amount =
        effect.amount.clamp(supportsSignedAmount ? -1 : 0, 3).toDouble();
    return switch (effect.type) {
      ClipEffectType.temperature => ColorFiltered(
          colorFilter: ColorFilter.matrix(_temperature(amount)),
          child: child,
        ),
      ClipEffectType.tint => ColorFiltered(
          colorFilter: ColorFilter.matrix(_tint(amount)),
          child: child,
        ),
      ClipEffectType.exposure => ColorFiltered(
          colorFilter: ColorFilter.matrix(_brightness(amount * 0.28)),
          child: child,
        ),
      ClipEffectType.brightness => ColorFiltered(
          colorFilter: ColorFilter.matrix(_brightness(amount * 0.25)),
          child: child,
        ),
      ClipEffectType.contrast => ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1 + amount * 0.5)),
          child: child,
        ),
      ClipEffectType.highlights => ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1 + amount * 0.12)),
          child: child,
        ),
      ClipEffectType.shadows => ColorFiltered(
          colorFilter: ColorFilter.matrix(_brightness(amount * 0.12)),
          child: child,
        ),
      ClipEffectType.whites => ColorFiltered(
          colorFilter: ColorFilter.matrix(_brightness(amount * 0.12)),
          child: child,
        ),
      ClipEffectType.blacks => ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1 + amount * 0.22)),
          child: child,
        ),
      ClipEffectType.brilliance => ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturation(1 + amount * 0.22)),
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(_contrast(1 + amount * 0.14)),
            child: child,
          ),
        ),
      ClipEffectType.saturation => ColorFiltered(
          colorFilter: ColorFilter.matrix(_saturation(1 + amount * 0.75)),
          child: child,
        ),
      ClipEffectType.gamma => ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1 + amount * 0.35)),
          child: child,
        ),
      ClipEffectType.clarity => ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1 + amount * 0.16)),
          child: child,
        ),
      ClipEffectType.fade => ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1 - amount * 0.28)),
          child: child,
        ),
      ClipEffectType.grayscale => ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayscale),
          child: child,
        ),
      ClipEffectType.sepia => ColorFiltered(
          colorFilter: const ColorFilter.matrix(_sepia),
          child: child,
        ),
      ClipEffectType.blur => ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: amount * 4,
            sigmaY: amount * 4,
          ),
          child: child,
        ),
      ClipEffectType.vignette => Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.82,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity((amount * 0.32).clamp(0, 0.8)),
                      ],
                      stops: const [0.48, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ClipEffectType.sharpen => child,
      ClipEffectType.invert => ColorFiltered(
          colorFilter: const ColorFilter.matrix(EffectRenderState.invertMatrix),
          child: child,
        ),
      ClipEffectType.hueRotate => ColorFiltered(
          colorFilter: ColorFilter.matrix(_hueRotate(amount)),
          child: child,
        ),
      ClipEffectType.glitch => Stack(
          fit: StackFit.passthrough,
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                1, 0, 0, 0, 0, // Red only
                0, 0, 0, 0, 0,
                0, 0, 0, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: FractionalTranslation(
                translation: Offset(-0.02 * amount, 0),
                child: child,
              ),
            ),
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0, 0, 0, 0, 0,
                0, 1, 0, 0, 0, // Green and Blue
                0, 0, 1, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: FractionalTranslation(
                translation: Offset(0.02 * amount, 0),
                child: child,
              ),
            ),
          ],
        ),
    };
  }

  static List<double> _brightness(double value) {
    final offset = value * 255;
    return [
      1,
      0,
      0,
      0,
      offset,
      0,
      1,
      0,
      0,
      offset,
      0,
      0,
      1,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _temperature(double value) {
    final red = 1 + value * 0.16;
    final blue = 1 - value * 0.16;
    return [
      red,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      blue,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _tint(double value) {
    return [
      1 + value * 0.05,
      0,
      0,
      0,
      0,
      0,
      1 - value * 0.13,
      0,
      0,
      0,
      0,
      0,
      1 + value * 0.05,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _contrast(double value) {
    final offset = 128 * (1 - value);
    return [
      value,
      0,
      0,
      0,
      offset,
      0,
      value,
      0,
      0,
      offset,
      0,
      0,
      value,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static List<double> _saturation(double value) {
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    final inverse = 1 - value;
    return [
      inverse * r + value,
      inverse * g,
      inverse * b,
      0,
      0,
      inverse * r,
      inverse * g + value,
      inverse * b,
      0,
      0,
      inverse * r,
      inverse * g,
      inverse * b + value,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static const _grayscale = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static const _sepia = <double>[
    0.393,
    0.769,
    0.189,
    0,
    0,
    0.349,
    0.686,
    0.168,
    0,
    0,
    0.272,
    0.534,
    0.131,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  static List<double> _hueRotate(double value) {
    // 0 to 3 -> maps to 0 to 360 degrees roughly
    final angle = value * 120 * (math.pi / 180.0);
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return [
      0.213 + cosA * 0.787 - sinA * 0.213,
      0.715 - cosA * 0.715 - sinA * 0.715,
      0.072 - cosA * 0.072 + sinA * 0.928,
      0,
      0,
      0.213 - cosA * 0.213 + sinA * 0.143,
      0.715 + cosA * 0.285 + sinA * 0.140,
      0.072 - cosA * 0.072 - sinA * 0.283,
      0,
      0,
      0.213 - cosA * 0.213 - sinA * 0.787,
      0.715 - cosA * 0.715 + sinA * 0.715,
      0.072 + cosA * 0.928 + sinA * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }
}
