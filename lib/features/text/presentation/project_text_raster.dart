import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../composition/domain/text_geometry.dart';
import '../../export/domain/export_models.dart';
import '../domain/title_visual_state.dart';

/// Flutter owns shaping, fallback, line breaking and glyph metrics for titles.
/// Rasterization uses project dimensions and never a widget's device ratio.
abstract final class ProjectTextRaster {
  static TextStyle style(
          {required String font,
          required double size,
          required double tracking,
          required double canvasHeight}) =>
      TextStyle(
          fontFamily: font,
          fontSize: TextGeometry.fontSize(size, canvasHeight),
          fontWeight: FontWeight.w800,
          letterSpacing: tracking * TextGeometry.scale(canvasHeight),
          height: 1);

  static ui.Color color(String hex, double opacity) => ui.Color(0xff000000 |
          (int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xffffff))
      .withOpacity(opacity.clamp(0.0, 1.0));

  static Future<Uint8List> png(
      TextOverlaySettings text, int width, int height) async {
    final layout = shape(text, width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    layout.paint(canvas, ui.Size(width.toDouble(), height.toDouble()),
        TitleTimelineResolver.resolve(text, text.timelineStart));
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Text raster encoding failed');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image?.dispose();
      picture.dispose();
      layout.dispose();
    }
  }

  static List<Object> layoutKey(
          TextOverlaySettings text, double width, double height,
          {String? content}) =>
      [
        content ?? text.text,
        width,
        height,
        text.font,
        text.size,
        text.tracking,
        text.color,
        text.opacity,
        text.stroke,
        text.strokeColor,
        text.strokeOpacity,
        text.shadow,
        text.shadowColor,
        text.shadowOpacity
      ];

  static ProjectTitleLayout shape(
      TextOverlaySettings text, double width, double height,
      {String? content}) {
    final scale = TextGeometry.scale(height.toDouble());
    final base = style(
            font: text.font,
            size: text.size,
            tracking: text.tracking,
            canvasHeight: height.toDouble())
        .copyWith(
      shadows: text.shadow && text.shadowOpacity > 0
          ? [
              Shadow(
                  color: color(text.shadowColor, text.shadowOpacity),
                  offset: ui.Offset(3 * scale, 3 * scale),
                  blurRadius: 7 * scale)
            ]
          : null,
    );
    final painters = <TextPainter>[];
    TextPainter layout(TextStyle style) {
      final painter = TextPainter(
          text: TextSpan(text: content ?? text.text, style: style),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling)
        ..layout(maxWidth: width.toDouble());
      painters.add(painter);
      return painter;
    }

    final fill = layout(base.copyWith(color: color(text.color, text.opacity)));
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const origin = ui.Offset.zero;
    if (text.stroke > 0 && text.strokeOpacity > 0) {
      layout(base.copyWith(
              foreground: ui.Paint()
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = text.stroke * scale
                ..strokeJoin = ui.StrokeJoin.round
                ..color = color(text.strokeColor, text.strokeOpacity)))
          .paint(canvas, origin);
    }
    fill.paint(canvas, origin);
    final result = ProjectTitleLayout(
        recorder.endRecording(),
        fill.size,
        (text.stroke * scale + 24 * scale).ceilToDouble(),
        color(text.strokeColor, text.strokeOpacity),
        scale);
    for (final painter in painters) {
      painter.dispose();
    }
    return result;
  }
}

/// Full-paragraph shaping is reusable independently of timeline composition.
/// Export may rasterize this tight layer once; no full-canvas glyph-frame cache.
class ProjectTitleLayout {
  ProjectTitleLayout(
      this.picture, this.size, this.padding, this.lineColor, this.unitScale);
  final ui.Picture picture;
  final ui.Size size;
  final double padding, unitScale;
  final ui.Color lineColor;
  ui.Image? _glyphs;
  int get cachedBytes =>
      _glyphs == null ? 0 : _glyphs!.width * _glyphs!.height * 4;

  Future<void> cacheGlyphs() async {
    if (_glyphs != null) return;
    final width = (size.width + padding * 2).ceil();
    final height = (size.height + padding * 2).ceil();
    // Fail preparation instead of silently clipping oversized editable text.
    // The export transaction preserves an existing destination on this failure.
    if (width > 32768 || height > 32768 || width <= 0 || height <= 0) {
      throw StateError('Title glyph raster exceeds supported dimensions');
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(padding, padding);
    canvas.drawPicture(picture);
    final padded = recorder.endRecording();
    try {
      _glyphs = await padded.toImage(width, height);
    } finally {
      padded.dispose();
    }
  }

  // Glyph-local scale, then rotation about paragraph center, then anchor/pan.
  // Opacity applies once to the composed layer (fill, stroke, shadow and line).
  void paint(ui.Canvas canvas, ui.Size canvasSize, TitleVisualState state) {
    if (!state.active || state.opacity <= 0) return;
    canvas.save();
    canvas.translate((canvasSize.width - size.width) * state.x + size.width / 2,
        (canvasSize.height - size.height) * state.y + size.height / 2);
    canvas.rotate(state.rotation);
    canvas.scale(state.scaleX, state.scaleY);
    if (state.opacity < 1) {
      canvas.saveLayer(
          null,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withOpacity(state.opacity));
    }
    final origin = ui.Offset(-size.width / 2, -size.height / 2);
    if (_glyphs case final image?) {
      canvas.drawImage(image, origin - ui.Offset(padding, padding), ui.Paint());
    } else {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.drawPicture(picture);
      canvas.restore();
    }
    if (state.lineWidth > 0) {
      final width = size.width * state.lineWidth;
      canvas.drawRect(
          ui.Rect.fromLTWH(-width / 2, size.height / 2 + 4 * unitScale, width,
              4 * unitScale),
          ui.Paint()..color = lineColor);
    }
    if (state.opacity < 1) canvas.restore();
    canvas.restore();
  }

  void dispose() {
    _glyphs?.dispose();
    _glyphs = null;
    picture.dispose();
  }
}
