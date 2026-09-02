import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/domain/caption_visual_state.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final motion in ['bounce', 'pop']) {
    test('$motion wrapped word uses one pivot and preserves surrounding pixels',
        () async {
      const text = 'Fixed\nEnglish Khmer\nStill';
      const spec = CaptionParagraphSpec(
          style: TextStyle(fontSize: 90, color: Colors.red),
          inactiveColor: Colors.white,
          timedHighlight: true);
      final layout = spec.highlightedLayout(text, 90, 1080, const []);
      addTearDown(layout.dispose);
      final state = CaptionTimelineResolver(
          cueId: 'c',
          text: text,
          start: 0,
          end: 1,
          motion: motion,
          words: const [
            CaptionTimedWord(
                id: 'w',
                text: 'English Khmer',
                start: 0,
                end: 1,
                rangeStart: 6,
                rangeEnd: 19)
          ]).resolve(.5);
      final boxes = layout.boundsFor(state.ranges);
      expect(boxes.length, greaterThan(1));
      const origin = Offset(100, 40);
      Future<List<int>> raster(bool reference) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        if (!reference) {
          layout.paint(canvas, origin, visualState: state);
        } else {
          canvas.save();
          for (final box in boxes) {
            canvas.clipRect(box.shift(origin), clipOp: ui.ClipOp.difference);
          }
          layout.inactivePainter!.paint(canvas, origin);
          canvas.restore();
          final pivot =
              boxes.reduce((a, b) => a.expandToInclude(b)).center + origin;
          final word = state.words.single;
          canvas.save();
          // Paragraph placement -> word pivot -> bounce translation -> scale
          // -> original-space glyph mask. Translation is not scaled.
          canvas.translate(pivot.dx, pivot.dy + word.offsetY * 90);
          canvas.scale(word.scale);
          canvas.translate(-pivot.dx, -pivot.dy);
          final mask = Path();
          for (final box in boxes) {
            mask.addRect(box.shift(origin));
          }
          canvas.clipPath(mask);
          layout.painter.paint(canvas, origin);
          canvas.restore();
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 900);
        try {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          return bytes.buffer
              .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
              .toList();
        } finally {
          image.dispose();
          picture.dispose();
        }
      }

      final actual = await raster(false);
      expect(actual.where((b) => b != 0), isNotEmpty);
      expect(actual, await raster(true));
    });
  }
}
