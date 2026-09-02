import 'dart:io';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:characters/characters.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/caption_frame_stream.dart';
import 'package:klipio/features/text/domain/title_visual_state.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const title = TextOverlaySettings(
    id: 'title',
    text: 'សួស្តី 👩🏽‍💻 e\u0301',
    timelineStart: 1,
    timelineEnd: 3,
    animation: 'flow right',
    animationDuration: 2,
    startX: 0,
    x: .6,
    y: .5);
const keys = [
  ClipKeyframe(
      offset: 0,
      transform: ClipTransform(positionX: .2, scaleX: .5, opacity: .2)),
  ClipKeyframe(
      offset: 1,
      transform: ClipTransform(positionX: .8, scaleY: 2, rotationDegrees: 90)),
  ClipKeyframe(
      offset: 2,
      transform: ClipTransform(positionY: .8, scaleX: 2, opacity: .4)),
];
const timeline = TimelineModel(duration: 4, tracks: [
  TrackModel(id: 'text-1', type: TrackType.text, index: 1, clips: [
    ClipModel(
        id: 'title',
        mediaPath: 'title',
        timelineStart: 1,
        duration: 2,
        sourceStart: 0,
        zIndex: 0,
        keyframes: keys),
  ]),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'title trim and split preserve the original animation clock and interpolated edges',
      () {
    const editor = TimelineEditor();
    final original = TitleTimelineResolver.bind(title, timeline);
    final trimmed = editor.resizeClip(timeline,
        clipId: 'title', startEdge: true, deltaSeconds: .4);
    final resolved = TitleTimelineResolver.bind(title, trimmed);
    expect(trimmed.clipById('title')!.clip.sourceStart, 0);
    final reopened = TimelineModel.fromJson(trimmed.toJson());
    expect(reopened.clipById('title')!.clip.textAnimationOffset,
        trimmed.clipById('title')!.clip.textAnimationOffset);
    expect(
        TitleTimelineResolver.resolve(
                TitleTimelineResolver.bind(title, reopened), 1.5)
            .compositionKey,
        TitleTimelineResolver.resolve(resolved, 1.5).compositionKey);
    for (final time in [1.4, 1.5, 2.0, 2.999999]) {
      final a = TitleTimelineResolver.resolve(original, time);
      final b = TitleTimelineResolver.resolve(resolved, time);
      expect(b.x, closeTo(a.x, 1e-12));
      expect(b.y, closeTo(a.y, 1e-12));
      expect(b.scaleX, closeTo(a.scaleX, 1e-12));
      expect(b.scaleY, closeTo(a.scaleY, 1e-12));
      expect(b.rotation, closeTo(a.rotation, 1e-12));
      expect(b.opacity, closeTo(a.opacity, 1e-12));
    }
    expect(TitleTimelineResolver.resolve(resolved, 1.399999).active, isFalse);
    expect(TitleTimelineResolver.resolve(resolved, 3).active, isFalse);
    final split = editor.splitClip(timeline, clipId: 'title', playhead: 1.4);
    final second = split.textTracks.single.clips.last;
    final fork =
        TitleTimelineResolver.bind(title.withComposition(id: second.id), split);
    expect(TitleTimelineResolver.resolve(fork, 1.5).compositionKey,
        TitleTimelineResolver.resolve(resolved, 1.5).compositionKey);
    final endTrim = editor.resizeClip(timeline,
        clipId: 'title', startEdge: false, deltaSeconds: -.5);
    final shortened = TitleTimelineResolver.bind(title, endTrim);
    expect(TitleTimelineResolver.resolve(shortened, 2.25).compositionKey,
        TitleTimelineResolver.resolve(original, 2.25).compositionKey);
    expect(TitleTimelineResolver.resolve(shortened, 2.5).active, isFalse);
  });

  test(
      'typing never divides graphemes; preset phases clamp rather than wall-clock loop',
      () {
    final typing = TextOverlaySettings(
        text: title.text,
        animation: 'text typing',
        timelineStart: 1,
        timelineEnd: 3,
        animationDuration: 1);
    for (var i = 0; i <= 100; i++) {
      final visual = TitleTimelineResolver.resolve(typing, 1 + i / 100);
      expect(
          title.text.characters.take(visual.text.characters.length).toString(),
          visual.text);
    }
    expect(TitleTimelineResolver.resolve(typing, 2.5).text, title.text);
    expect(TitleTimelineResolver.resolve(typing, 3).active, isFalse);
    final zero = title.withComposition(animationDuration: 0);
    expect(TitleTimelineResolver.resolve(zero, 1).phase, 1);
    final tiny = title.withComposition(start: 1, end: 1.000001);
    expect(TitleTimelineResolver.resolve(tiny, 1).active, isTrue);
    expect(TitleTimelineResolver.resolve(tiny, 1.000001).active, isFalse);
  });

  for (final width in [1920, 3840]) {
    test('title glyph reuse and cancel cleanup at $width', () async {
      final token = ExportCancelToken();
      final height = width * 9 ~/ 16;
      final stream = await CaptionFrameStream.open(
          cues: const [],
          spec: const CaptionParagraphSpec(style: TextStyle()),
          titles: [title.withComposition(start: 0, end: 100, keyframes: keys)],
          width: width,
          height: height,
          fps: 30,
          duration: 100,
          token: token);
      addTearDown(stream.close);
      final socket = await Socket.connect(
          InternetAddress.loopbackIPv4, stream.server.port);
      var received = 0;
      await for (final bytes in socket) {
        received += bytes.length;
        if (received >= width * height * 4 * 3) {
          token.cancel();
          break;
        }
      }
      socket.destroy();
      await stream.close();
      expect(stream.titleLayouts, 1);
      expect(stream.peakCachedBytes, width * height * 4);
      expect(stream.peakTitleGlyphBytes, greaterThan(0));
      expect(stream.retainedTitleGlyphBytes, 0);
      expect(stream.error, isNull);
      // ignore: avoid_print
      print('TITLE_RESOURCE $width x $height layouts=${stream.titleLayouts} '
          'outputCache=${stream.peakCachedBytes} glyphCache=${stream.peakTitleGlyphBytes} retained=0');
    });
  }
}
