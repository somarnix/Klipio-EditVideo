import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../../export/domain/export_models.dart';
import '../domain/title_visual_state.dart';
import 'project_text_raster.dart';

/// The active monitor adapter: time is supplied by the program timeline.
/// Layout is retained across seeks and transform-only/keyframe updates.
class ProjectTitleView extends StatefulWidget {
  const ProjectTitleView({super.key, required this.title, required this.time});
  final TextOverlaySettings title;
  final double time;
  @override
  State<ProjectTitleView> createState() => _ProjectTitleViewState();
}

class _ProjectTitleViewState extends State<ProjectTitleView> {
  ProjectTitleLayout? _layout;
  List<Object>? _layoutKey;
  @override
  void dispose() {
    _layout?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final state = TitleTimelineResolver.resolve(widget.title, widget.time);
        final key = ProjectTextRaster.layoutKey(
            widget.title, constraints.maxWidth, constraints.maxHeight,
            content: state.text);
        if (!listEquals(key, _layoutKey)) {
          _layout?.dispose();
          _layout = ProjectTextRaster.shape(
              widget.title, constraints.maxWidth, constraints.maxHeight,
              content: state.text);
          _layoutKey = key;
        }
        return CustomPaint(
            size: constraints.biggest,
            painter: _TitlePainter(_layout!, state, constraints.biggest));
      });
}

class _TitlePainter extends CustomPainter {
  _TitlePainter(this.layout, this.state, this._canvasSize);
  final ProjectTitleLayout layout;
  final TitleVisualState state;
  final Size _canvasSize;
  @override
  void paint(Canvas canvas, Size size) {
    layout.paint(canvas, size, state);
  }

  @override
  bool hitTest(Offset position) {
    if (!state.active ||
        state.opacity <= 0 ||
        state.scaleX == 0 ||
        state.scaleY == 0) return false;
    final pivot = Offset(
        (_canvasSize.width - layout.size.width) * state.x +
            layout.size.width / 2,
        (_canvasSize.height - layout.size.height) * state.y +
            layout.size.height / 2);
    final local = position - pivot;
    final c = math.cos(state.rotation), s = math.sin(state.rotation);
    final point = Offset((c * local.dx + s * local.dy) / state.scaleX,
        (-s * local.dx + c * local.dy) / state.scaleY);
    return Rect.fromCenter(
            center: Offset.zero,
            width: layout.size.width,
            height: layout.size.height)
        .contains(point);
  }

  @override
  bool shouldRepaint(_TitlePainter old) =>
      old.layout != layout ||
      !listEquals(old.state.compositionKey, state.compositionKey);
}
