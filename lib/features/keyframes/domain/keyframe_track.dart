enum KeyframeInterpolation { linear, easeIn, easeOut, easeInOut }

class PropertyKeyframe {
  const PropertyKeyframe({
    required this.time,
    required this.value,
    this.interpolation = KeyframeInterpolation.linear,
  });

  final double time;
  final double value;
  final KeyframeInterpolation interpolation;
}

class KeyframeTrack {
  const KeyframeTrack({required this.property, this.keyframes = const []});

  final String property;
  final List<PropertyKeyframe> keyframes;
}
