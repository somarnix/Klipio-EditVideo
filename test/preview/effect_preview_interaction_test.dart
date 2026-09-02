import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/editor/application/effect_edit.dart';
import 'package:klipio/features/editor/application/snapshot_history.dart';
import 'package:klipio/features/editor/presentation/effect_preview_interaction.dart';
import 'package:klipio/features/preview/engine/software_effect_frame.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const a = ClipModel(
    id: 'A',
    mediaPath: 'shared',
    timelineStart: 0,
    duration: 1,
    sourceStart: 0,
    zIndex: 0,
    effects: [ClipEffect(id: 'invert', type: ClipEffectType.invert)]);

class ControlledDecoder extends EffectFrameDecoder {
  final requests = <(String, double, Completer<Uint8List>)>[];
  bool closed = false;
  @override
  Future<Uint8List> decode(String path, double time) {
    final done = Completer<Uint8List>();
    requests.add((path, time, done));
    return done.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  testWidgets(
      'real browser hover/discard/Escape/click keeps history and save state separate',
      (tester) async {
    final session = EditorSession()
      ..timeline = TimelineModel(duration: 1, tracks: [
        TrackModel(
            id: 'V1',
            type: TrackType.video,
            index: 1,
            clips: [a.copyWith(effects: [])])
      ]);
    final preview = EffectPreview();
    final history = SnapshotHistory<EditorProjectRevision>();
    var serial = 0, autosaves = 0;
    void discard() => preview.discard();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: EffectPreviewInteraction(
                    enabled: true,
                    preview: () {
                      final token = preview.begin(session.timeline, 'A')!;
                      preview.complete(token, session.timeline, a.effects);
                    },
                    discard: discard,
                    apply: () {
                      final edit = EffectEdit.apply(session.timeline, {
                        'A': [
                          ClipEffect(
                              id: 'effect-${serial++}',
                              type: ClipEffectType.invert)
                        ]
                      });
                      if (session.commitEffect(edit,
                          beforeChange: () => history.record(
                              'apply', session.capture,
                              coalesce: false))) {
                        discard();
                        autosaves++;
                      }
                    },
                    child: const SizedBox(
                        width: 100, height: 80, child: Text('Negative')))))));
    final before = session.capture();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Negative')));
    await tester.pump();
    expect(preview.resolve(session.timeline).clipById('A')!.clip.effects,
        hasLength(1));
    expect(session.capture().data, before.data);
    expect(history.undoEntries, isEmpty);
    expect(autosaves, 0);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(
        identical(preview.resolve(session.timeline), session.timeline), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
        identical(preview.resolve(session.timeline), session.timeline), isTrue);
    await mouse.moveTo(tester.getCenter(find.text('Negative')));
    await tester.pump();
    await tester.tap(find.text('Negative'));
    await tester.pump();
    expect(history.undoEntries, hasLength(1));
    expect(autosaves, 1);
    expect(session.timeline.clipById('A')!.clip.effects, hasLength(1));
    expect(
        identical(preview.resolve(session.timeline), session.timeline), isTrue);
    await tester.tap(find.text('Negative'));
    await tester.pump();
    expect(history.undoEntries,
        hasLength(2)); // Rapid deliberate stacking is not coalesced.
    expect(session.timeline.clipById('A')!.clip.effects.map((e) => e.id),
        ['effect-0', 'effect-1']);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets(
      'software preview rejects stale clip completion and bounds pending work',
      (tester) async {
    final decoder = ControlledDecoder();
    Future<void> show(ClipModel clip, double time) async {
      await tester.pumpWidget(MaterialApp(
          home: SizedBox(
              width: 64,
              height: 64,
              child: SoftwareEffectFrame(
                  clip: clip, time: time, decoder: decoder))));
    }

    final png = (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(Colors.red, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      picture.dispose();
      return bytes;
    }))!;
    await show(a, .1);
    expect(decoder.requests, hasLength(1));
    await show(a.copyWith(id: 'B'), .2);
    await show(a.copyWith(id: 'B'), .3);
    expect(decoder.requests,
        hasLength(1)); // Latest request replaces pending, no parallel decode.
    decoder.requests.first.$3.complete(png);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(decoder.requests, hasLength(2));
    expect(decoder.requests.last.$2, .3);
    decoder.requests.last.$3.complete(png);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await show(a.copyWith(id: 'B'), .4);
    expect(decoder.requests, hasLength(3));
    decoder.requests.last.$3.completeError(StateError('decode failed'));
    await tester.pump();
    await tester
        .pump(); // Present the frame scheduled by the async error handler.
    expect(find.text('Effect preview failed — Retry'), findsOneWidget);
    await tester.tap(find.text('Effect preview failed — Retry'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(decoder.closed, isTrue);
    decoder.requests.last.$3.complete(png);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
