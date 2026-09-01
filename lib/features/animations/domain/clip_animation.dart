enum ClipAnimationPhase { enter, exit, combo }

enum ClipAnimationType {
  none,
  fade,
  zoom,
  slideLeft,
  slideRight,
  slideUp,
  slideDown,
  spin
}

class ClipAnimation {
  const ClipAnimation({
    required this.phase,
    required this.type,
    this.duration = const Duration(milliseconds: 500),
  });

  final ClipAnimationPhase phase;
  final ClipAnimationType type;
  final Duration duration;
}
