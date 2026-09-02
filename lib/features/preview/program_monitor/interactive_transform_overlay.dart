import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../timeline/domain/timeline_models.dart';

/// Direct manipulation handles for the active Program Monitor video layer.
class InteractiveTransformOverlay extends StatefulWidget {
  const InteractiveTransformOverlay({
    super.key,
    required this.frame,
    required this.transform,
    required this.onTransformChanged,
    this.onTransformStart,
    this.onTransformEnd,
    this.onTransformCancel,
    this.snapThreshold = 5,
  });

  final Rect frame;
  final ClipTransform transform;
  final ValueChanged<ClipTransform> onTransformChanged;
  final VoidCallback? onTransformStart;
  final VoidCallback? onTransformEnd;
  final VoidCallback? onTransformCancel;
  final double snapThreshold;

  @override
  State<InteractiveTransformOverlay> createState() =>
      _InteractiveTransformOverlayState();
}

class _InteractiveTransformOverlayState
    extends State<InteractiveTransformOverlay> {
  bool _snapX = false;
  bool _snapY = false;
  Offset _moveDelta = Offset.zero;
  Offset? _moveStartCenter;
  ClipTransform? _moveStartTransform;

  void _start() => widget.onTransformStart?.call();

  void _startMove() {
    _moveDelta = Offset.zero;
    _moveStartCenter = widget.frame.center;
    _moveStartTransform = widget.transform;
    _start();
  }

  void _finish() {
    if (mounted) setState(() => _snapX = _snapY = false);
    _moveStartCenter = null;
    _moveStartTransform = null;
    _moveDelta = Offset.zero;
    widget.onTransformEnd?.call();
  }

  void _cancel() {
    _moveStartCenter = null;
    _moveStartTransform = null;
    _moveDelta = Offset.zero;
    if (mounted) setState(() => _snapX = _snapY = false);
    widget.onTransformCancel?.call();
  }

  void _move(DragUpdateDetails details, Size canvas) {
    _moveDelta += details.delta;
    final initial = _moveStartTransform ?? widget.transform;
    final travelX = (canvas.width - widget.frame.width).abs() / 2;
    final travelY = (canvas.height - widget.frame.height).abs() / 2;
    var x = travelX <= 0.5
        ? initial.positionX
        : initial.positionX + _moveDelta.dx / (travelX * 2);
    var y = travelY <= 0.5
        ? initial.positionY
        : initial.positionY + _moveDelta.dy / (travelY * 2);
    final nextCenter = (_moveStartCenter ?? widget.frame.center) + _moveDelta;
    final snapX =
        (nextCenter.dx - canvas.width / 2).abs() <= widget.snapThreshold;
    final snapY =
        (nextCenter.dy - canvas.height / 2).abs() <= widget.snapThreshold;
    if (snapX) x = 0.5;
    if (snapY) y = 0.5;
    _updateGuides(snapX, snapY);
    widget.onTransformChanged(
      initial.copyWith(
        positionX: x.clamp(0.0, 1.0).toDouble(),
        positionY: y.clamp(0.0, 1.0).toDouble(),
      ),
    );
  }

  void _uniformScale(DragUpdateDetails details, Alignment corner) {
    final dx = corner.x < 0 ? -details.delta.dx : details.delta.dx;
    final dy = corner.y < 0 ? -details.delta.dy : details.delta.dy;
    final divisor = math.max(80.0, widget.frame.width + widget.frame.height);
    final factor = (1 + (dx + dy) / divisor).clamp(0.05, 20.0);
    widget.onTransformChanged(
      widget.transform.withScale(widget.transform.scaleX * factor,
          width: true, uniform: true),
    );
  }

  void _edgeScale(DragUpdateDetails details, Alignment edge) {
    var scaleX = widget.transform.scaleX;
    var scaleY = widget.transform.scaleY;
    if (edge.x != 0) {
      final delta = edge.x < 0 ? -details.delta.dx : details.delta.dx;
      scaleX = (scaleX * (1 + delta / math.max(40, widget.frame.width)))
          .clamp(ClipTransform.minimumScale, ClipTransform.maximumScale)
          .toDouble();
    }
    if (edge.y != 0) {
      final delta = edge.y < 0 ? -details.delta.dy : details.delta.dy;
      scaleY = (scaleY * (1 + delta / math.max(40, widget.frame.height)))
          .clamp(ClipTransform.minimumScale, ClipTransform.maximumScale)
          .toDouble();
    }
    widget.onTransformChanged(
      widget.transform.copyWith(scaleX: scaleX, scaleY: scaleY),
    );
  }

  void _rotate(DragUpdateDetails details) {
    widget.onTransformChanged(
      widget.transform.copyWith(
        rotationDegrees:
            (widget.transform.rotationDegrees + details.delta.dx * 0.65)
                .remainder(360),
      ),
    );
  }

  void _updateGuides(bool x, bool y) {
    if (x == _snapX && y == _snapY) return;
    if ((x && !_snapX) || (y && !_snapY)) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _snapX = x;
      _snapY = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = constraints.biggest;
        if (canvas.isEmpty || widget.frame.isEmpty) {
          return const SizedBox.shrink();
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                canvas.width * 0.1,
                canvas.height * 0.1,
                canvas.width * 0.8,
                canvas.height * 0.8,
              ),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x55ffffff)),
                  ),
                ),
              ),
            ),
            if (_snapX)
              Positioned(
                left: canvas.width / 2,
                top: 0,
                bottom: 0,
                child: const _GuideLine(vertical: true),
              ),
            if (_snapY)
              Positioned(
                top: canvas.height / 2,
                left: 0,
                right: 0,
                child: const _GuideLine(vertical: false),
              ),
            Positioned.fromRect(
              rect: widget.frame,
              child: Transform.rotate(
                angle: widget.transform.rotationDegrees * math.pi / 180,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: GestureDetector(
                          key: const ValueKey('transform-move'),
                          behavior: HitTestBehavior.translucent,
                          onPanStart: (_) => _startMove(),
                          onPanUpdate: (details) => _move(details, canvas),
                          onPanEnd: (_) => _finish(),
                          onPanCancel: _cancel,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xff22d3ee),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final corner in const <Alignment>[
                      Alignment.topLeft,
                      Alignment.topRight,
                      Alignment.bottomLeft,
                      Alignment.bottomRight,
                    ])
                      _handle(
                        key: 'transform-corner-${corner.x}-${corner.y}',
                        alignment: corner,
                        cursor: corner.x * corner.y > 0
                            ? SystemMouseCursors.resizeUpLeftDownRight
                            : SystemMouseCursors.resizeUpRightDownLeft,
                        onUpdate: (details) => _uniformScale(details, corner),
                      ),
                    for (final edge in const <Alignment>[
                      Alignment.topCenter,
                      Alignment.centerRight,
                      Alignment.bottomCenter,
                      Alignment.centerLeft,
                    ])
                      _handle(
                        key: 'transform-edge-${edge.x}-${edge.y}',
                        alignment: edge,
                        cursor: edge.x == 0
                            ? SystemMouseCursors.resizeUpDown
                            : SystemMouseCursors.resizeLeftRight,
                        onUpdate: (details) => _edgeScale(details, edge),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: widget.frame.center.dx - 14,
              top: math.max(2, widget.frame.top - 38),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: GestureDetector(
                  key: const ValueKey('transform-rotate'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _start(),
                  onPanUpdate: _rotate,
                  onPanEnd: (_) => _finish(),
                  onPanCancel: _cancel,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.rotate_right,
                      size: 20,
                      color: Color(0xff22d3ee),
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _handle({
    required String key,
    required Alignment alignment,
    required MouseCursor cursor,
    required GestureDragUpdateCallback onUpdate,
  }) {
    return Align(
      alignment: alignment,
      child: FractionalTranslation(
        translation: Offset(alignment.x * 0.5, alignment.y * 0.5),
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            key: ValueKey(key),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _start(),
            onPanUpdate: onUpdate,
            onPanEnd: (_) => _finish(),
            onPanCancel: _cancel,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0xaa000000), blurRadius: 3)],
              ),
              child: SizedBox(width: 12, height: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xfffacc15),
        child: SizedBox(width: vertical ? 1 : double.infinity, height: 1),
      );
}
