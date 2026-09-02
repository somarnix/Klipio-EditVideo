part of 'editor_application.dart';

class _TextOverlayDraft {
  const _TextOverlayDraft({
    this.id = '',
    this.text = '',
    this.font = 'Arial',
    this.size = 44,
    this.color = Colors.white,
    this.opacity = 1,
    this.stroke = 3,
    this.strokeColor = Colors.black,
    this.strokeOpacity = 0.9,
    this.shadowColor = Colors.black,
    this.shadowOpacity = 0.65,
    this.animation = 'none',
    this.animationDuration = 1,
    this.x = 0.5,
    this.y = 0.75,
    this.startX = 0.5,
    this.startY = 1,
    this.timelineStart = 0,
    this.duration = 0,
    this.trackIndex = 1,
    this.isVisible = true,
    this.isLocked = false,
    this.tracking = 0,
    this.curve = 0,
  });

  final String id;
  final String text;
  final String font;
  final double size;
  final Color color;
  final double opacity;
  final double stroke;
  final Color strokeColor;
  final double strokeOpacity;
  final Color shadowColor;
  final double shadowOpacity;
  final String animation;
  final double animationDuration;
  final double x;
  final double y;
  final double startX;
  final double startY;
  final double timelineStart;
  final double duration;
  final int trackIndex;
  final bool isVisible;
  final bool isLocked;
  final double tracking;
  final double curve;

  _TextOverlayDraft copyWith({
    String? id,
    String? text,
    String? font,
    double? size,
    Color? color,
    double? opacity,
    double? stroke,
    Color? strokeColor,
    double? strokeOpacity,
    Color? shadowColor,
    double? shadowOpacity,
    String? animation,
    double? animationDuration,
    double? x,
    double? y,
    double? startX,
    double? startY,
    double? timelineStart,
    double? duration,
    int? trackIndex,
    bool? isVisible,
    bool? isLocked,
    double? tracking,
    double? curve,
  }) {
    return _TextOverlayDraft(
      id: id ?? this.id,
      text: text ?? this.text,
      font: font ?? this.font,
      size: size ?? this.size,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      stroke: stroke ?? this.stroke,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeOpacity: strokeOpacity ?? this.strokeOpacity,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      animation: animation ?? this.animation,
      animationDuration: animationDuration ?? this.animationDuration,
      x: x ?? this.x,
      y: y ?? this.y,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      timelineStart: timelineStart ?? this.timelineStart,
      duration: duration ?? this.duration,
      trackIndex: trackIndex ?? this.trackIndex,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      tracking: tracking ?? this.tracking,
      curve: curve ?? this.curve,
    );
  }

  TextOverlaySettings toSettings(String Function(Color color) colorToHex) {
    return TextOverlaySettings(
      id: id,
      text: text,
      font: font,
      size: size,
      color: colorToHex(color),
      opacity: opacity,
      stroke: stroke,
      strokeColor: colorToHex(strokeColor),
      strokeOpacity: strokeOpacity,
      shadow: true,
      shadowColor: colorToHex(shadowColor),
      shadowOpacity: shadowOpacity,
      animation: animation,
      animationDuration: animationDuration,
      x: x,
      y: y,
      startX: startX,
      startY: startY,
      timelineStart: timelineStart,
      timelineEnd: duration <= 0 ? 0 : timelineStart + duration,
      visible: isVisible,
      tracking: tracking,
      curve: curve,
    );
  }

  Map<String, Object?> toJson(String Function(Color color) colorToHex) => {
        'id': id,
        'text': text,
        'font': font,
        'size': size,
        'color': colorToHex(color),
        'opacity': opacity,
        'stroke': stroke,
        'strokeColor': colorToHex(strokeColor),
        'strokeOpacity': strokeOpacity,
        'shadowColor': colorToHex(shadowColor),
        'shadowOpacity': shadowOpacity,
        'animation': animation,
        'animationDuration': animationDuration,
        'x': x,
        'y': y,
        'startX': startX,
        'startY': startY,
        'timelineStart': timelineStart,
        'duration': duration,
        'trackIndex': trackIndex,
        'isVisible': isVisible,
        'isLocked': isLocked,
        'tracking': tracking,
        'curve': curve,
      };
}

typedef _EditableSlider = InspectorValueControl;
