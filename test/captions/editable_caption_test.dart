import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/captions/domain/editable_caption.dart';
import 'package:klipio/features/text/domain/caption_word_resolver.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';
import 'package:klipio/features/export/services/caption_frame_stream.dart';
import 'package:klipio/features/export/domain/export_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final motion in ['box', 'bounce', 'pop']) {
    test(
        'caption $motion identity survives two file round trips and timing/text edits',
        () async {
      final root =
          await Directory.systemTemp.createTemp('klipio-caption-roundtrip-');
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/captions.json');
      final initial = EditableCaptionCue(
          start: 0,
          end: 2,
          text: 'ខ្មែរ English 👩🏽‍💻\nHello',
          x: .3,
          y: .7,
          metadata: {
            'style': {
              'alignment': 'center',
              'opacity': .8,
              'stroke': 2,
              'shadow': 3,
              'background': 0xff0000ff
            },
            'animation': {'type': motion, 'amount': .7},
            'speaker': 'speaker-1'
          },
          words: [
            EditableCaptionWord(start: 0, end: 1, text: 'ខ្មែរ', metadata: {
              'range': [0, 5],
              'emphasis': true
            }),
            EditableCaptionWord(start: 1, end: 2, text: 'English')
          ]);
      Future<EditableCaptionCue> roundTrip(EditableCaptionCue cue) async {
        await file.writeAsString(jsonEncode(cue.toJson()), flush: true);
        return EditableCaptionCue.fromJson(
            jsonDecode(await file.readAsString()) as Map,
            migrationKey: 'unused-for-identified-cue');
      }

      final reopened = await roundTrip(initial);
      expect(reopened.toJson(), initial.toJson());
      final edited =
          reopened.copyWith(end: 3, text: '${reopened.text} 😀', words: [
        reopened.words.first.copyWith(end: .8),
        reopened.words.last.copyWith(start: .8, end: 3)
      ]);
      final twice = await roundTrip(edited);
      expect(twice.id, initial.id);
      expect(twice.words.map((w) => w.id), initial.words.map((w) => w.id));
      expect(twice.toJson(), edited.toJson());
      final spec = CaptionParagraphSpec(
          motion: motion,
          style: const TextStyle(fontSize: 72),
          timedHighlight: true,
          activeWordBackground: Colors.blue);
      List<({int start, int end})> resolve(
              EditableCaptionCue cue, double time) =>
          CaptionWordResolver.resolve(
              text: cue.text,
              cueStart: cue.start,
              cueEnd: cue.end,
              time: time,
              words: cue.words
                  .map((w) => (text: w.text, start: w.start, end: w.end)));
      for (final t in [-.1, 0.0, .4, .799999, .8, 1.5, 3.0]) {
        final before = resolve(edited, t), after = resolve(twice, t);
        expect(after, before);
        final a = spec.highlightedLayout(edited.text, 180, 1080, before);
        final b = spec.highlightedLayout(twice.text, 180, 1080, after);
        try {
          expect(b.highlightBounds, a.highlightBounds);
        } finally {
          a.dispose();
          b.dispose();
        }
      }
      Future<List<int>> frames(EditableCaptionCue cue) async {
        final stream = await CaptionFrameStream.open(cues: [
          CaptionCueSettings(
              id: cue.id,
              start: cue.start,
              end: cue.end,
              text: cue.text,
              x: cue.x,
              y: cue.y,
              words: [
                for (final w in cue.words)
                  CaptionWordSettings(
                      id: w.id, start: w.start, end: w.end, text: w.text)
              ])
        ], spec: spec, width: 64, height: 64, fps: 5, duration: 3);
        try {
          final socket = await Socket.connect(
              InternetAddress.loopbackIPv4, stream.server.port);
          return await socket
              .fold<List<int>>([], (all, bytes) => all..addAll(bytes));
        } finally {
          await stream.close();
        }
      }

      final beforeFrames = await frames(edited);
      expect(beforeFrames.where((byte) => byte != 0), isNotEmpty);
      expect(await frames(twice), beforeFrames);
    });
  }
  test(
      'legacy migration is deterministic and explicit IDs remain authoritative',
      () {
    final legacy = {
      'start': 0,
      'end': 1,
      'text': 'Hi Hi',
      'words': [
        {'start': 0, 'end': .5, 'text': 'Hi'},
        {'start': .5, 'end': 1, 'text': 'Hi'}
      ]
    };
    final a = EditableCaptionCue.fromJson(legacy, migrationKey: 'asset/0');
    final b = EditableCaptionCue.fromJson(legacy, migrationKey: 'asset/0');
    expect(a.toJson(), b.toJson());
    expect(a.words.first.id, isNot(a.words.last.id));
    expect(
        EditableCaptionCue.fromJson(a.toJson(), migrationKey: 'moved/99')
            .toJson(),
        a.toJson());
    expect(EditableCaptionCue.fromJson(legacy, migrationKey: 'asset/1').id,
        isNot(a.id));
  });
  test(
      'caption metadata and words cannot be mutated through caller collections',
      () {
    final metadata = <String, Object?>{
      'animation': {'amount': .5}
    };
    final words = [EditableCaptionWord(start: 0, end: 1, text: 'Hi')];
    final cue = EditableCaptionCue(
        start: 0, end: 1, text: 'Hi', words: words, metadata: metadata);
    words.clear();
    (metadata['animation'] as Map)['amount'] = 1.0;
    expect(cue.words.length, 1);
    expect((cue.metadata['animation'] as Map)['amount'], .5);
  });
  test('legacy string timestamps retain word timing and identity', () {
    final cue = EditableCaptionCue.fromJson({
      'start': '0',
      'end': '1',
      'text': 'Hi',
      'words': [
        {'start': '0.1', 'end': '0.9', 'text': 'Hi'}
      ]
    }, migrationKey: 'legacy/0');
    expect(cue.words.single.start, .1);
    expect(cue.words.single.end, .9);
    expect(
        EditableCaptionCue.fromJson(cue.toJson(), migrationKey: 'ignored')
            .toJson(),
        cue.toJson());
  });
  test('explicit segment forks preserve metadata without aliasing identity',
      () {
    final word = EditableCaptionWord(
        start: 0, end: 1, text: 'Hi', metadata: {'emphasis': true});
    final cue = EditableCaptionCue(
        start: 0,
        end: 1,
        text: 'Hi',
        words: [word],
        metadata: {'speaker': 'speaker-1'});
    final fork = cue.copyWith(
        id: '${cue.id}/clip/B',
        start: 3,
        end: 4,
        words: [word.copyWith(id: '${word.id}/clip/B', start: 3, end: 4)]);
    expect(fork.id, isNot(cue.id));
    expect(fork.words.single.id, isNot(word.id));
    expect(fork.metadata, cue.metadata);
    expect(fork.words.single.metadata, word.metadata);
    expect(fork.copyWith(text: 'Edited').id, fork.id);
  });
}
