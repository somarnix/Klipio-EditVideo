import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../domain/text_case.dart';
import '../domain/caption_visual_state.dart';

/// Captured typography in 1080-high project reference units, not UI pixels.
/// This is derived render state; the editable cue remains structured data.
class CaptionParagraphSpec {
  const CaptionParagraphSpec(
      {required this.style,
      this.textCase = 'none',
      this.background = const Color(0x00000000),
      this.padding = 0,
      this.radius = 0,
      this.alignment = TextAlign.center,
      this.timedHighlight = false,
      this.motion = 'highlight',
      this.activeWordBackground = const Color(0x00000000),
      this.inactiveColor = const Color(0xFFFFFFFF)});
  final Color activeWordBackground;
  final String motion;
  final bool timedHighlight;
  final Color inactiveColor;
  final TextStyle style;
  final String textCase;
  final Color background;
  final double padding;
  final double radius;
  final TextAlign alignment;

  CaptionParagraphLayout highlightedLayout(String text, double width,
      double height, List<({int start, int end})> highlights) {
    final active = layout(text, width, height);
    final inactive = CaptionParagraphSpec(
            style: style.copyWith(color: inactiveColor),
            textCase: textCase,
            background: background,
            padding: padding,
            radius: radius,
            alignment: alignment)
        .layout(text, width, height);
    return CaptionParagraphLayout(
        active.painter, active.inset, background, active.radius,
        inactivePainter: inactive.painter,
        highlights: highlights,
        activeWordBackground: activeWordBackground,
        wordBoxPadding: Offset(7 * height / 1080, 3 * height / 1080));
  }

  CaptionParagraphLayout layout(
      String text, double width, double canvasHeight) {
    final scale = canvasHeight / 1080;
    final inset = background.alpha == 0 ? 0.0 : padding * scale;
    final painter = TextPainter(
        text: TextSpan(
            text: applyTextCase(text, textCase),
            style: style.copyWith(
                fontSize: (style.fontSize ?? 42) * scale,
                letterSpacing: (style.letterSpacing ?? 0) * scale,
                shadows: style.shadows
                    ?.map((s) => Shadow(
                        color: s.color,
                        offset: s.offset * scale,
                        blurRadius: s.blurRadius * scale))
                    .toList())),
        textDirection: TextDirection.ltr,
        textAlign: alignment,
        textScaler: TextScaler.noScaling)
      ..layout(maxWidth: (width - inset * 2).clamp(0.0, width));
    return CaptionParagraphLayout(painter, inset, background, radius * scale);
  }

  Future<ui.Image> image(String text, int width, int height,
      {required double x, required double y}) async {
    final paragraph = layout(text, width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paragraph.paint(
        canvas,
        Offset((width - paragraph.size.width) * x.clamp(0, 1),
            (height - paragraph.size.height) * y.clamp(0, 1)));
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
      paragraph.dispose();
    }
  }
}

class CaptionParagraphLayout {
  CaptionParagraphLayout(this.painter, this.inset, this.background, this.radius,
      {this.inactivePainter,
      this.highlights = const [],
      this.wordBoxPadding = Offset.zero,
      this.activeWordBackground = const Color(0x00000000)});
  final Offset wordBoxPadding;
  final Color activeWordBackground;
  final TextPainter? inactivePainter;
  final List<({int start, int end})> highlights;
  final TextPainter painter;
  final double inset;
  final Color background;
  final double radius;
  Size get size => Size(painter.width + inset * 2, painter.height + inset);

  /// Selection boxes come from the shaped paragraph, including wrapped lines.
  /// No character-count approximation or independent word shaping is involved.
  List<Rect> get highlightBounds => boundsFor(highlights);
  List<Rect> boundsFor(List<({int start, int end})> ranges) => [
        for (final range in ranges)
          for (final box in painter.getBoxesForSelection(
              TextSelection(baseOffset: range.start, extentOffset: range.end)))
            box.toRect(),
      ];
  void paint(Canvas canvas, Offset offset,
      {List<({int start, int end})>? activeRanges,
      CaptionVisualState? visualState}) {
    if (visualState != null && !visualState.active) return;
    activeRanges = visualState?.ranges ?? activeRanges;
    if (background.alpha > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(offset & size, Radius.circular(radius)),
          Paint()..color = background);
    }
    final origin = offset + Offset(inset, inset / 2);
    if (inactivePainter == null) {
      painter.paint(canvas, origin);
    } else {
      if (visualState != null &&
          (visualState.motion == 'bounce' || visualState.motion == 'pop')) {
        // Full paragraphs remain shaped. Clip and transform selected glyph
        // regions; never reshape Khmer/emoji as separate word widgets.
        canvas.save();
        for (final box in boundsFor(visualState.ranges)) {
          canvas.clipRect(box.shift(origin), clipOp: ui.ClipOp.difference);
        }
        inactivePainter!.paint(canvas, origin);
        canvas.restore();
        final em = painter.text!.style!.fontSize!;
        for (final word in visualState.words) {
          final boxes = boundsFor([(start: word.start, end: word.end)]);
          if (boxes.isEmpty) continue;
          // One word can span multiple shaped runs/lines. Use one pivot and
          // one paint operation, not a different transform for every box.
          final target =
              boxes.reduce((a, b) => a.expandToInclude(b)).shift(origin);
          final mask = Path();
          for (final box in boxes) {
            mask.addRect(box.shift(origin));
          }
          canvas.save();
          canvas.translate(
              target.center.dx, target.center.dy + word.offsetY * em);
          canvas.scale(word.scale, word.scale);
          canvas.translate(-target.center.dx, -target.center.dy);
          canvas.clipPath(mask);
          painter.paint(canvas, origin);
          canvas.restore();
        }
        return;
      }
      final bounds =
          activeRanges == null ? highlightBounds : boundsFor(activeRanges);
      if (activeWordBackground.alpha > 0) {
        for (final box in bounds) {
          final padded = Rect.fromLTRB(
              box.left - wordBoxPadding.dx,
              box.top - wordBoxPadding.dy,
              box.right + wordBoxPadding.dx,
              box.bottom + wordBoxPadding.dy);
          canvas.drawRect(
              padded.shift(origin), Paint()..color = activeWordBackground);
        }
      }
      inactivePainter!.paint(canvas, origin);
      final path = Path();
      for (final box in bounds) {
        path.addRect(box.shift(origin));
      }
      canvas.save();
      canvas.clipPath(path);
      painter.paint(canvas, origin);
      canvas.restore();
    }
  }

  void dispose() {
    painter.dispose();
    inactivePainter?.dispose();
  }
}

/// Layout and glyph paint are shared with export, including wrapping/padding.
class CaptionParagraphView extends StatelessWidget {
  const CaptionParagraphView(
      {super.key,
      required this.spec,
      required this.text,
      this.highlights,
      this.visualState,
      required this.canvasHeight});
  final List<({int start, int end})>? highlights;
  final CaptionVisualState? visualState;
  final CaptionParagraphSpec spec;
  final String text;
  final double canvasHeight;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final layout = highlights == null
            ? spec.layout(text, constraints.maxWidth, canvasHeight)
            : spec.highlightedLayout(
                text, constraints.maxWidth, canvasHeight, highlights!);
        final size = layout.size;
        layout.dispose();
        return CustomPaint(
            size: size,
            painter: _ParagraphPainter(spec, text, constraints.maxWidth,
                canvasHeight, highlights, visualState));
      });
}

class _ParagraphPainter extends CustomPainter {
  _ParagraphPainter(this.spec, this.text, this.width, this.height,
      this.highlights, this.visualState);
  final CaptionVisualState? visualState;
  final List<({int start, int end})>? highlights;
  final CaptionParagraphSpec spec;
  final String text;
  final double width, height;
  @override
  void paint(Canvas canvas, Size size) {
    final layout = highlights == null
        ? spec.layout(text, width, height)
        : spec.highlightedLayout(text, width, height, highlights!);
    try {
      layout.paint(canvas, Offset.zero, visualState: visualState);
    } finally {
      layout.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _ParagraphPainter old) =>
      old.spec != spec ||
      old.visualState != visualState ||
      old.highlights != highlights ||
      old.text != text ||
      old.width != width ||
      old.height != height;
}
