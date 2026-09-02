import 'dart:convert';
import 'dart:io';
import 'package:klipio/features/captions/services/caption_service_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/domain/clip_speed_edit.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/composition/domain/render_scene.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';

TimelineModel fixture() => TimelineModel(tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
        for (var i = 0; i < 3; i++)
          ClipModel(
              id: 'v$i',
              mediaPath: 'same.mp4',
              timelineStart: i * 4,
              duration: 4,
              sourceStart: 10.0 + i * 20,
              zIndex: 0,
              playbackSpeed: [0.5, 1.0, 2.0][i]),
      ]),
      TrackModel(id: 'a', type: TrackType.audio, index: 0, clips: [
        for (var i = 0; i < 3; i++)
          ClipModel(
              id: 'a$i',
              mediaPath: 'same.mp4',
              timelineStart: i * 4,
              duration: 4,
              sourceStart: 10.0 + i * 20,
              zIndex: 0,
              volume: [0.2, 0.5, 0.8][i],
              isLinkedAudio: true,
              linkedClipId: 'v$i'),
      ]),
    ], duration: 12);

void main() {
  test('legacy independent audio never inherits a same-path video speed', () {
    const timeline = TimelineModel(tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
        ClipModel(
            id: 'video',
            mediaPath: 'same.mp4',
            timelineStart: 0,
            duration: 4,
            sourceStart: 0,
            zIndex: 0),
      ]),
      TrackModel(id: 'a', type: TrackType.audio, index: 0, clips: [
        ClipModel(
            id: 'independent',
            mediaPath: 'same.mp4',
            timelineStart: 1,
            duration: 4,
            sourceStart: 10,
            zIndex: 0,
            volume: 0.3),
        ClipModel(
            id: 'explicit',
            mediaPath: 'same.mp4',
            timelineStart: 6,
            duration: 2,
            sourceStart: 20,
            zIndex: 0,
            playbackSpeed: 0.5),
      ]),
    ], duration: 8);
    final snapshot = ProgramRenderSnapshot.build(
        sourceTimeline: timeline, playbackSpeedsByMediaPath: {'same.mp4': 2});
    final independent = snapshot.outputTimeline.clipById('independent')!.clip;
    expect(independent.resolvedPlaybackSpeed(), 1);
    expect(independent.timelineStart, 1);
    expect(independent.duration, 4);
    expect(independent.volume, 0.3);
    final explicit = snapshot.outputTimeline.clipById('explicit')!.clip;
    expect(explicit.resolvedPlaybackSpeed(), 0.5);
    expect(explicit.timelineStart, 6);
    expect(explicit.duration, 4);
  });
  test(
      'mixed-speed composition preserves gap, trailing canvas, overlays and independent audio',
      () async {
    final original = fixture();
    ClipModel decorate(ClipModel clip) => clip.copyWith(
        timelineStart:
            clip.timelineStart + (clip.timelineStart > 0 ? 0.001 : 0),
        transform: const ClipTransform(
            scaleX: 1.2,
            scaleY: 0.8,
            positionX: 0.7,
            positionY: 0.3,
            rotationDegrees: 27,
            opacity: 0.7,
            flip: 'down'),
        transitionIn: clip.id == 'v1'
            ? const ClipTransition(
                type: ClipTransitionType.dissolve, duration: 0.2)
            : null);
    final source = TimelineModel(tracks: [
      for (final track in original.tracks)
        track.copyWith(clips: track.clips.map(decorate).toList()),
      const TrackModel(id: 'music', type: TrackType.audio, index: 1, clips: [
        ClipModel(
            id: 'music',
            mediaPath: 'music.wav',
            timelineStart: 0.25,
            duration: 1,
            sourceStart: 2,
            zIndex: 0,
            volume: 0.35,
            playbackSpeed: 1),
      ]),
    ], duration: 13.001);
    final snapshot = ProgramRenderSnapshot.build(
        sourceTimeline: source, playbackSpeedsByMediaPath: const {});
    expect(snapshot.outputTimeline.duration, closeTo(15.001, 1e-8));
    expect(snapshot.outputTimeline.clipById('music')!.clip.timelineStart, 0.25);
    expect(snapshot.outputTimeline.clipById('music')!.clip.volume, 0.35);
    expect(ProgramTimelineMapper.resolve(snapshot.outputTimeline, 8.0005).isGap,
        isTrue);
    expect(ProgramTimelineMapper.resolve(snapshot.outputTimeline, 14.5).isGap,
        isTrue);
    for (final time in [
      0.0,
      4.0,
      7.999999,
      8.0,
      8.0005,
      8.001,
      8.1,
      10.001,
      12.001,
      13.001,
      14.001,
      14.5
    ]) {
      final preview =
          ProgramTimelineMapper.resolve(snapshot.outputTimeline, time);
      final render = snapshot.resolve(
          composition:
              const CompositionModel(width: 900, height: 1200, frameRate: 30),
          timelineSeconds: time);
      expect(render.clips.isEmpty, preview.isGap);
      if (!preview.isGap) {
        expect(render.clips, hasLength(1),
            reason:
                'time=$time, clips=${render.clips.map((c) => c.clipId).toList()}');
        expect(render.clips.single.clipId, preview.clip!.id);
        expect(render.clips.single.sourceSeconds, preview.sourceSeconds);
        expect(render.clips.single.rotationDegrees, 27);
        expect(render.clips.single.opacity, 0.7);
      }
    }
    const captions = VideoEditSettings(
        speed: 1,
        flip: 'none',
        scaleX: 1,
        scaleY: 1,
        zoom: 1,
        watermarkPath: null,
        watermarkPosition: 'custom',
        watermarkSize: 0.12,
        musicPath: null,
        originalVolume: 1,
        musicVolume: 0,
        captionCase: 'original',
        captionCues: [
          CaptionCueSettings(
              start: 8.001,
              end: 8.2,
              text: 'សួស្តី hello 👩🏽‍💻',
              x: 0.25,
              y: 0.75)
        ]);
    final ass = await generateManualCaptionAss(
        const ExportJob(
            inputPath: 'same.mp4',
            outputPath: 'unused.mp4',
            settings: captions),
        playResWidth: 900,
        playResHeight: 1200);
    final contents = await File(ass).readAsString();
    expect(contents, contains('PlayResX: 900'));
    expect(contents, contains('PlayResY: 1200'));
    expect(contents, contains(r'\pos(225,900)'));
    final plan = const MultiTrackFilterBuilder().build(
        MultiTrackExportJob(
            timeline: snapshot.outputTimeline,
            outputPath: 'out.mp4',
            width: 900,
            height: 1200,
            captionSettings: captions,
            textOverlays: const [
              TextOverlaySettings(
                  text: 'Title\nសួស្តី',
                  size: 54,
                  x: 0.3,
                  y: 0.2,
                  timelineStart: 0,
                  timelineEnd: 2)
            ]),
        encoder: 'libx264',
        captionAssPath: ass,
        sourceDimensions: {'same.mp4': (width: 1600, height: 900)});
    expect(plan.duration, snapshot.outputTimeline.duration);
    expect(plan.filterGraph, contains('fade=t=in:st=0:d=0.2'));
    expect(plan.filterGraph, contains('volume=0.35'));
    expect(plan.filterGraph, contains('fontsize=60'));
    expect(plan.filterGraph, contains('ass=filename='));
    expect(plan.filterGraph, contains('gte(t,8.001)'));
  });
  test(
      'three reused clip instances survive reopen with independent render clocks',
      () {
    final reopened =
        TimelineModel.fromJson(jsonDecode(jsonEncode(fixture().toJson())));
    final snapshot = ProgramRenderSnapshot.build(
        sourceTimeline: reopened, playbackSpeedsByMediaPath: {'same.mp4': 4});
    expect(snapshot.outputTimeline.duration, 14);
    final starts = [0.0, 8.0, 12.0];
    final durations = [8.0, 4.0, 2.0];
    for (var i = 0; i < 3; i++) {
      final speed = [0.5, 1.0, 2.0][i];
      expect(snapshot.playbackForClip('v$i')!.speed, speed);
      expect(snapshot.playbackForClip('v$i')!.volume, [0.2, 0.5, 0.8][i]);
      final audio = snapshot.outputTimeline.clipById('a$i')!.clip;
      expect(audio.timelineStart, starts[i]);
      expect(audio.duration, durations[i]);
      expect(audio.resolvedPlaybackSpeed(), speed);
      for (final local in [0.0, durations[i] / 2, durations[i] - 0.000001]) {
        final t = starts[i] + local;
        final target =
            ProgramTimelineMapper.resolve(snapshot.outputTimeline, t);
        expect(target.clip!.id, 'v$i');
        expect(
            target.sourceSeconds, closeTo(10 + i * 20 + local * speed, 1e-8));
        final scene = snapshot.resolve(
            composition:
                const CompositionModel(width: 900, height: 1200, frameRate: 30),
            timelineSeconds: t);
        expect(scene.clips.single.clipId, target.clip!.id);
        expect(scene.clips.single.sourceSeconds, target.sourceSeconds);
      }
    }
    expect(ProgramTimelineMapper.resolve(snapshot.outputTimeline, 14).isGap,
        isTrue);
    final plan = const MultiTrackFilterBuilder().build(
        MultiTrackExportJob(
            timeline: snapshot.outputTimeline,
            outputPath: 'out.mp4',
            width: 900,
            height: 1200,
            playbackSpeedsByMediaPath: {'same.mp4': 4}),
        encoder: 'libx264');
    for (final speed in ['0.5', '1', '2']) {
      expect(plan.filterGraph, contains('setpts=(PTS-STARTPTS)/$speed'));
      if (speed == '1') {
        expect(
            plan.filterGraph,
            contains(
                'anull,apad=whole_dur=4,atrim=duration=4,asetpts=N/SR/TB'));
        expect(plan.filterGraph, isNot(contains('atempo=1,')));
      } else {
        expect(plan.filterGraph, contains('atempo=$speed'));
      }
    }
    for (final volume in ['0.2', '0.5', '0.8']) {
      expect(plan.filterGraph, contains('volume=$volume'));
    }
  });

  test('edit A preserves B/C and migrates legacy defaults exactly once', () {
    final original = fixture();
    final edited = ClipSpeedEdit.apply(original, {'v0'}, 3);
    expect(edited.clipById('v0')!.clip.playbackSpeed, 3);
    expect(edited.clipById('a0')!.clip.playbackSpeed, 3);
    expect(edited.clipById('v1')!.clip.toJson(),
        original.clipById('v1')!.clip.toJson());
    expect(edited.clipById('v2')!.clip.toJson(),
        original.clipById('v2')!.clip.toJson());
    final legacy = TimelineModel.fromJson({
      'tracks': [
        {
          'id': 'v',
          'type': 'video',
          'index': 0,
          'clips': [
            {'id': 'old', 'mediaPath': 'same.mp4', 'duration': 4}
          ]
        }
      ],
      'duration': 4
    });
    final migrated = ClipSpeedEdit.migrate(legacy, {'same.mp4': 0.5});
    expect(
        ClipSpeedEdit.migrate(migrated, {'same.mp4': 4})
            .clipById('old')!
            .clip
            .playbackSpeed,
        0.5);
  });

  test('locked linked audio rejects speed edit atomically', () {
    final original = fixture();
    final locked = original.copyWith(tracks: [
      original.tracks.first,
      original.tracks.last.copyWith(isLocked: true)
    ]);
    expect(identical(ClipSpeedEdit.apply(locked, {'v0'}, 2), locked), isTrue);
  });
}
