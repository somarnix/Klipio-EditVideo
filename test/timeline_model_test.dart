import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/preview/engine/multi_track_preview.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  const editor = TimelineEditor(snapThreshold: 0.15);

  test('dynamic tracks move, snap, split, and survive JSON round-trip', () {
    const clip = ClipModel(
      id: 'clip-1',
      mediaPath: 'source.mp4',
      timelineStart: 0,
      duration: 4,
      sourceStart: 2,
      zIndex: 0,
    );
    var model = const TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [clip],
        ),
        TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
      ],
      duration: 4,
    );

    model = editor.addTrack(model, TrackType.video);
    expect(model.videoTracks.map((track) => track.label), ['V1', 'V2']);

    model = editor.moveClip(
      model,
      clipId: clip.id,
      targetTrackId: 'video-2',
      timelineStart: 4.92,
      playhead: 5,
    );
    final moved = model.clipById(clip.id)!;
    expect(moved.track.label, 'V2');
    expect(moved.clip.timelineStart, 5);
    expect(moved.clip.zIndex, 1);

    model = editor.splitClip(model, clipId: clip.id, playhead: 7);
    expect(model.videoTracks.last.clips, hasLength(2));
    expect(model.videoTracks.last.clips.first.duration, 2);
    expect(model.videoTracks.last.clips.last.sourceStart, 4);
    expect(
      model.videoTracks.last.clips
          .every((part) => part.replacesClipId == clip.id),
      isTrue,
    );

    final restored = TimelineModel.fromJson(model.toJson());
    expect(restored.videoTracks, hasLength(2));
    expect(restored.videoTracks.last.clips, hasLength(2));
    expect(restored.videoTracks.last.clips.first.replacesClipId, clip.id);
    expect(restored.duration, 9);
    expect(restored.activeClips(7.5, TrackType.video), hasLength(1));
  });

  test('group followers can move without independent snapping', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'leader',
              mediaPath: 'one.mp4',
              timelineStart: 1,
              duration: 2,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'follower',
              mediaPath: 'two.mp4',
              timelineStart: 4,
              duration: 2,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'snap-candidate',
              mediaPath: 'three.mp4',
              timelineStart: 7.05,
              duration: 1,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 8.05,
    );

    final moved = editor.moveClip(
      model,
      clipId: 'follower',
      targetTrackId: 'video-1',
      timelineStart: 5,
      snap: false,
    );

    expect(moved.clipById('follower')!.clip.timelineStart, 5);
  });

  test('an intentional copy can clear inherited clip lineage', () {
    const splitPart = ClipModel(
      id: 'base-a-1000',
      mediaPath: 'source.mp4',
      timelineStart: 0,
      duration: 1,
      sourceStart: 0,
      zIndex: 1,
      replacesClipId: 'base',
    );

    final copied = splitPart.copyWith(
      id: 'copy',
      timelineStart: 3,
      clearReplacesClipId: true,
    );

    expect(copied.replacesClipId, isNull);
    expect(copied.timelineStart, 3);
  });

  test('linked V/A clips move, trim, split, and delete together', () {
    var model = const TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'linked',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 6,
              sourceStart: 2,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(id: 'video-2', type: TrackType.video, index: 2),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-linked',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 6,
              sourceStart: 2,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'linked',
            ),
          ],
        ),
      ],
      duration: 6,
    );

    model = editor.moveClip(
      model,
      clipId: 'linked',
      targetTrackId: 'video-2',
      timelineStart: 3,
    );
    expect(model.clipById('audio-linked')?.clip.timelineStart, 3);

    model = editor.resizeClip(
      model,
      clipId: 'linked',
      startEdge: true,
      deltaSeconds: 1,
    );
    final linkedAudio = model.clipById('audio-linked')!.clip;
    expect(linkedAudio.timelineStart, 4);
    expect(linkedAudio.sourceStart, 3);
    expect(linkedAudio.duration, 5);

    model = editor.splitClip(model, clipId: 'linked', playhead: 6);
    expect(model.audioTracks.first.clips, hasLength(2));
    expect(model.clipById('audio-linked-a-6000'), isNotNull);
    expect(model.clipById('audio-linked-b-6000'), isNotNull);

    model = editor.deleteClip(model, 'linked-a-6000');
    expect(model.clipById('audio-linked-a-6000'), isNull);
    expect(model.clipById('audio-linked-b-6000'), isNotNull);
  });

  test('deleting the V1 opening ripples the anchored unlocked timeline', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'opening',
              mediaPath: 'main.mp4',
              timelineStart: 0,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'main',
              mediaPath: 'main.mp4',
              timelineStart: 3,
              duration: 7,
              sourceStart: 3,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'video-2',
          type: TrackType.video,
          index: 2,
          clips: [
            ClipModel(
              id: 'overlay',
              mediaPath: 'overlay.mp4',
              timelineStart: 4,
              duration: 2,
              sourceStart: 0,
              zIndex: 1,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-opening',
              mediaPath: 'main.mp4',
              timelineStart: 0,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'opening',
            ),
            ClipModel(
              id: 'audio-main',
              mediaPath: 'main.mp4',
              timelineStart: 3,
              duration: 7,
              sourceStart: 3,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'main',
            ),
          ],
        ),
      ],
      duration: 10,
    );

    final deleted = editor.deleteClip(model, 'opening');

    expect(deleted.clipById('opening'), isNull);
    expect(deleted.clipById('audio-opening'), isNull);
    expect(deleted.clipById('main')!.clip.timelineStart, 0);
    expect(deleted.clipById('audio-main')!.clip.timelineStart, 0);
    expect(deleted.clipById('overlay')!.clip.timelineStart, 1);
  });

  test('keep after playhead removes the left side and closes the V1 gap', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'first',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 100,
              zIndex: 0,
            ),
            ClipModel(
              id: 'next',
              mediaPath: 'next.mp4',
              timelineStart: 10,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-first',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 100,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'first',
            ),
          ],
        ),
      ],
      duration: 15,
    );

    final edited = editor.keepClipAfterPlayhead(
      model,
      clipId: 'first',
      playhead: 4,
    );

    final kept = edited.clipById('first-b-4000')!.clip;
    expect(kept.timelineStart, 0);
    expect(kept.sourceStart, 104);
    expect(kept.duration, 6);
    expect(edited.clipById('next')!.clip.timelineStart, 6);
    final audio = edited.clipById('audio-first-b-4000')!.clip;
    expect(audio.timelineStart, 0);
    expect(audio.sourceStart, 104);
    expect(audio.linkedClipId, kept.id);
    expect(edited.duration, 11);
  });

  test('keep before playhead removes the right side and ripples later V1', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'first',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 20,
              zIndex: 0,
            ),
            ClipModel(
              id: 'next',
              mediaPath: 'next.mp4',
              timelineStart: 10,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
      ],
      duration: 15,
    );

    final edited = editor.keepClipBeforePlayhead(
      model,
      clipId: 'first',
      playhead: 4,
    );

    final kept = edited.clipById('first-a-4000')!.clip;
    expect(kept.timelineStart, 0);
    expect(kept.sourceStart, 20);
    expect(kept.duration, 4);
    expect(edited.clipById('next')!.clip.timelineStart, 4);
    expect(edited.duration, 9);
  });

  test('deleting a later V1 clip preserves an intentional leading gap', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'lead-gap-clip',
              mediaPath: 'a.mp4',
              timelineStart: 5,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'remove',
              mediaPath: 'b.mp4',
              timelineStart: 8,
              duration: 2,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
      ],
      duration: 10,
    );

    final edited = editor.deleteClip(model, 'remove');
    expect(edited.clipById('lead-gap-clip')!.clip.timelineStart, 5);
    expect(edited.duration, 8);
  });

  test('moving the later split to V2 keeps its continuation source time', () {
    var model = const TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'song-video',
              mediaPath: 'song.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(id: 'video-2', type: TrackType.video, index: 2),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-song-video',
              mediaPath: 'song.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'song-video',
            ),
          ],
        ),
      ],
      duration: 10,
    );

    model = editor.splitClip(model, clipId: 'song-video', playhead: 4);
    model = editor.moveClip(
      model,
      clipId: 'song-video-b-4000',
      targetTrackId: 'video-2',
      timelineStart: 7,
    );

    final movedVideo = model.clipById('song-video-b-4000')!.clip;
    final movedAudio = model.clipById('audio-song-video-b-4000')!.clip;
    expect(movedVideo.sourceStart, 4);
    expect(movedAudio.sourceStart, 4);
    expect(movedVideo.timelineStart, 7);
    expect(movedAudio.timelineStart, 7);
  });

  test('linked audio stays inside video until explicitly extracted', () {
    const video = ClipModel(
      id: 'video',
      mediaPath: 'source.mp4',
      timelineStart: 0,
      duration: 8,
      sourceStart: 0,
      zIndex: 0,
    );
    const linked = ClipModel(
      id: 'audio-video',
      mediaPath: 'source.mp4',
      timelineStart: 0,
      duration: 8,
      sourceStart: 0,
      zIndex: 0,
      isLinkedAudio: true,
      linkedClipId: 'video',
    );
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [video],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [linked],
        ),
      ],
      duration: 8,
    );

    expect(model.displayTracks.map((track) => track.label), ['V1']);
    expect(model.linkedAudioForVideo('video')?.id, 'audio-video');

    final extracted = model.copyWith(
      tracks: [
        model.videoTracks.first,
        model.audioTracks.first.copyWith(
          clips: [
            linked.copyWith(
              id: 'extracted',
              isLinkedAudio: false,
              clearLinkedClipId: true,
            ),
          ],
        ),
      ],
    );
    expect(extracted.displayTracks.map((track) => track.label), ['V1', 'A1']);
    expect(extracted.linkedAudioForVideo('video'), isNull);
  });

  test('locked tracks reject split, resize, move, and delete', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          isLocked: true,
          clips: [
            ClipModel(
              id: 'locked',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 8,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(id: 'video-2', type: TrackType.video, index: 2),
      ],
      duration: 8,
    );

    expect(editor.splitClip(model, clipId: 'locked', playhead: 4), same(model));
    expect(editor.deleteClip(model, 'locked'), same(model));
    expect(
      editor.resizeClip(
        model,
        clipId: 'locked',
        startEdge: false,
        deltaSeconds: 2,
      ),
      same(model),
    );
    expect(
      editor.moveClip(
        model,
        clipId: 'locked',
        targetTrackId: 'video-2',
        timelineStart: 2,
      ),
      same(model),
    );
  });

  test('true multi-track preview renders each visible active layer once', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'v1',
              mediaPath: 'base.mp4',
              timelineStart: 0,
              duration: 2,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'video-2',
          type: TrackType.video,
          index: 2,
          clips: [
            ClipModel(
              id: 'v2',
              mediaPath: 'overlay.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 1,
            ),
          ],
        ),
      ],
      duration: 10,
    );

    final overlap = MultiTrackPreview.activeVideoLayers(
      model: model,
      playheadSeconds: 1,
      includeBaseTrack: true,
    );
    expect(overlap.map((layer) => layer.clip.id), ['v1', 'v2']);
    expect(
      MultiTrackPreview.directTextureLayer(
        model: model,
        playheadSeconds: 1,
        preferredMediaPath: 'overlay.mp4',
      )?.clip.id,
      'v2',
    );

    final afterV1 = MultiTrackPreview.activeVideoLayers(
      model: model,
      playheadSeconds: 5,
      includeBaseTrack: true,
    );
    expect(afterV1.map((layer) => layer.clip.id), ['v2']);

    final hiddenV2 = model.copyWith(
      tracks: [
        model.videoTracks.first,
        model.videoTracks.last.copyWith(isMuted: true),
      ],
    );
    expect(
      MultiTrackPreview.activeVideoLayers(
        model: hiddenV2,
        playheadSeconds: 5,
        includeBaseTrack: true,
      ),
      isEmpty,
    );
    expect(
      MultiTrackPreview.directTextureLayer(
        model: hiddenV2,
        playheadSeconds: 1,
        preferredMediaPath: 'base.mp4',
      )?.clip.id,
      'v1',
    );
    expect(
      MultiTrackPreview.directTextureLayer(
        model: hiddenV2,
        playheadSeconds: 5,
        preferredMediaPath: 'base.mp4',
      ),
      isNull,
    );
  });

  test('clip effects, transitions, linked audio, and keyframes persist', () {
    var model = const TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'first',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 4,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'second',
              mediaPath: 'source.mp4',
              timelineStart: 4,
              duration: 4,
              sourceStart: 4,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-first',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 4,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'first',
            ),
            ClipModel(
              id: 'audio-second',
              mediaPath: 'source.mp4',
              timelineStart: 4,
              duration: 4,
              sourceStart: 4,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'second',
            ),
          ],
        ),
      ],
      duration: 8,
    );

    model = editor.setClipTransition(
      model,
      'second',
      const ClipTransition(
        type: ClipTransitionType.slideLeft,
        duration: 1,
      ),
    );
    model = editor.addClipEffect(
      model,
      'second',
      const ClipEffect(
        id: 'fx-1',
        type: ClipEffectType.vignette,
        amount: 0.7,
      ),
    );
    model = editor.setClipKeyframe(
      model,
      'second',
      const ClipKeyframe(
        offset: 1,
        transform: ClipTransform(positionX: 0.2, rotationDegrees: -5),
      ),
    );
    model = editor.setClipKeyframe(
      model,
      'second',
      const ClipKeyframe(
        offset: 3,
        transform: ClipTransform(positionX: 0.8, rotationDegrees: 5),
      ),
    );

    expect(model.clipById('second')!.clip.timelineStart, 3);
    expect(model.clipById('audio-second')!.clip.timelineStart, 3);
    expect(model.hasMultiTrackContent, isTrue);
    expect(model.clipById('second')!.clip.transformAt(2).positionX,
        closeTo(0.5, 0.001));

    final restored = TimelineModel.fromJson(model.toJson());
    final clip = restored.clipById('second')!.clip;
    expect(clip.transitionIn?.type, ClipTransitionType.slideLeft);
    expect(clip.effects.single.type, ClipEffectType.vignette);
    expect(clip.keyframes, hasLength(2));

    final plan = const MultiTrackFilterBuilder().build(
      MultiTrackExportJob(timeline: restored, outputPath: 'output.mp4'),
      encoder: 'libx264',
      audioClipIdsWithStreams: {'audio-first', 'audio-second'},
    );
    expect(plan.filterGraph, contains('vignette='));
    expect(plan.filterGraph, contains('fade=t=in'));
    expect(plan.filterGraph, contains('afade=t=in'));
    expect(plan.filterGraph, contains('min(max((t-3)'));
    expect(plan.filterGraph, contains('rotate='));
  });

  test('FFmpeg builder creates overlay and amix graph for many tracks', () {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'base',
              mediaPath: 'base.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'video-2',
          type: TrackType.video,
          index: 2,
          clips: [
            ClipModel(
              id: 'pip',
              mediaPath: 'pip.mp4',
              timelineStart: 1,
              duration: 2,
              sourceStart: 3,
              zIndex: 1,
              transform: ClipTransform(
                opacity: 0.8,
                scaleX: 0.4,
                scaleY: 0.4,
                positionX: 0.8,
                positionY: 0.2,
                blendMode: 'multiply',
              ),
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-base',
              mediaPath: 'base.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-2',
          type: TrackType.audio,
          index: 2,
          clips: [
            ClipModel(
              id: 'audio-music',
              mediaPath: 'music.mp3',
              timelineStart: 1,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
              volume: 0.4,
            ),
          ],
        ),
      ],
      duration: 5,
    );
    const job = MultiTrackExportJob(
      timeline: model,
      outputPath: 'output.mp4',
      textOverlays: [
        TextOverlaySettings(
          text: 'Title',
          timelineStart: 1.5,
          timelineEnd: 3.5,
        ),
      ],
    );
    final plan = const MultiTrackFilterBuilder().build(
      job,
      encoder: 'libx264',
      audioClipIdsWithStreams: {'audio-base', 'audio-music'},
    );

    expect(plan.videoInputCount, 2);
    expect(plan.audioInputCount, 2);
    expect(plan.filterGraph, contains('setpts=PTS+1/TB'));
    expect(plan.filterGraph, contains('fps=30'));
    expect(plan.filterGraph, contains('overlay=x='));
    expect(plan.filterGraph, contains('blend=all_mode=multiply'));
    expect(plan.filterGraph, contains("enable='gte(t,1)*lt(t,3)'"));
    expect(plan.filterGraph, contains('amix=inputs=2'));
    expect(plan.filterGraph, contains('drawtext='));
    expect(plan.filterGraph, contains(r'gte(t\,1.5)*lt(t\,3.5)'));
    expect(plan.filterGraph, contains('setsar=1,format=yuv420p[outv]'));
    expect(plan.arguments, contains('[outv]'));
    expect(plan.arguments, contains('[outa]'));
  });

  test('canvas settings persist and produce real export filters', () {
    const blurModel = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'canvas-clip',
              mediaPath: 'portrait.mp4',
              timelineStart: 2,
              duration: 4,
              sourceStart: 3,
              zIndex: 0,
              transform: ClipTransform(
                canvasMode: 'blur',
                canvasColor: '#F4C70F',
                canvasPattern: 'dots',
                canvasBlur: 40,
                flip: 'left',
              ),
            ),
          ],
        ),
      ],
      duration: 6,
    );

    final restored = TimelineModel.fromJson(blurModel.toJson());
    final transform = restored.clipById('canvas-clip')!.clip.transform;
    expect(transform.canvasMode, 'blur');
    expect(transform.canvasColor, '#F4C70F');
    expect(transform.canvasPattern, 'dots');
    expect(transform.canvasBlur, 40);
    expect(transform.flip, 'left');

    final blurPlan = const MultiTrackFilterBuilder().build(
      MultiTrackExportJob(timeline: restored, outputPath: 'blur.mp4'),
      encoder: 'libx264',
    );
    expect(blurPlan.filterGraph, contains('split=2'));
    expect(blurPlan.filterGraph, contains('gblur=sigma=20:steps=1'));
    expect(blurPlan.filterGraph, contains('scale=480:270'));
    expect(
      blurPlan.filterGraph,
      contains(
        'scale=1920:1080:force_original_aspect_ratio=decrease:'
        'force_divisible_by=2:reset_sar=1,'
        'scale=trunc(iw*1/2)*2:trunc(ih*1/2)*2:reset_sar=1',
      ),
    );
    expect(
      blurPlan.filterGraph,
      contains(
        'x=(W-w)/2+(2*(0.5)-1)*abs(W-w)/2:'
        'y=(H-h)/2+(2*(0.5)-1)*abs(H-h)/2',
      ),
    );
    expect(blurPlan.filterGraph, contains('fps=30,hflip'));
    expect(blurPlan.filterGraph, contains('trim=start=0:duration=4'));
    expect(blurPlan.filterGraph, contains('setpts=PTS+2/TB'));
    expect(blurPlan.filterGraph, contains('setsar=1,format=yuv420p[outv]'));
    expect(blurPlan.arguments, containsAllInOrder(['-ss', '3', '-t', '4']));

    final patternTimeline = TimelineModel.fromJson(restored.toJson());
    final patternClip = patternTimeline.clipById('canvas-clip')!.clip.copyWith(
          transform: transform.copyWith(canvasMode: 'pattern'),
        );
    final patternModel = patternTimeline.copyWith(
      tracks: [
        patternTimeline.videoTracks.first.copyWith(clips: [patternClip]),
      ],
    );
    final patternPlan = const MultiTrackFilterBuilder().build(
      MultiTrackExportJob(timeline: patternModel, outputPath: 'pattern.mp4'),
      encoder: 'libx264',
    );
    expect(patternPlan.filterGraph, contains('color=0xF4C70F'));
    expect(patternPlan.filterGraph, contains('drawgrid='));
  });

  test('multi-track builder reuses linked media input and one ASS stage', () {
    const timeline = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'clip-1',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 4,
              sourceStart: 12,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-clip-1',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 4,
              sourceStart: 12,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 4,
    );
    final plan = const MultiTrackFilterBuilder().build(
      const MultiTrackExportJob(
        timeline: timeline,
        outputPath: 'output.mp4',
        hardwareDecoding: true,
        playbackSpeedsByMediaPath: {'source.mp4': 1.15},
      ),
      encoder: 'hevc_nvenc',
      audioClipIdsWithStreams: {'audio-clip-1'},
      captionAssPath: r'C:\temp\timeline captions.ass',
    );

    expect(plan.arguments.where((argument) => argument == '-i'), hasLength(1));
    expect(
      plan.arguments,
      containsAllInOrder(['-hwaccel', 'auto', '-ss', '12', '-t', '4']),
    );
    expect(plan.filterGraph,
        contains("ass=filename='C\\:/temp/timeline captions.ass'"));
    expect(plan.filterGraph, contains('setpts=(PTS-STARTPTS)/1.15'));
    expect(plan.filterGraph, contains('atempo=1.15'));
    expect(plan.filterGraph.split('ass=filename='), hasLength(2));
    expect(plan.arguments, contains('hevc_nvenc'));
  });

  test('text tracks persist and text clip handles resize their timing', () {
    var model = const TimelineModel(
      tracks: [
        TrackModel(id: 'video-1', type: TrackType.video, index: 1),
        TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
        TrackModel(
          id: 'text-1',
          type: TrackType.text,
          index: 1,
          clips: [
            ClipModel(
              id: 'title-1',
              mediaPath: 'title-1',
              timelineStart: 2,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 7,
    );

    model = editor.resizeClip(
      model,
      clipId: 'title-1',
      startEdge: true,
      deltaSeconds: 1,
    );
    var clip = model.clipById('title-1')!.clip;
    expect(clip.timelineStart, 3);
    expect(clip.duration, 4);
    expect(clip.sourceStart, 0);

    model = editor.resizeClip(
      model,
      clipId: 'title-1',
      startEdge: false,
      deltaSeconds: 2,
    );
    clip = model.clipById('title-1')!.clip;
    expect(clip.duration, 6);

    final restored = TimelineModel.fromJson(model.toJson());
    expect(restored.textTracks.single.label, 'T1');
    expect(restored.clipById('title-1')!.clip.timelineEnd, 9);
  });

  test('copied clips insert on a chosen dynamic track', () {
    var model = TimelineModel.empty();
    model = editor.addTrack(model, TrackType.video);
    model = editor.insertClip(
      model,
      trackId: 'video-2',
      clip: const ClipModel(
        id: 'copy-1',
        mediaPath: 'copied.mp4',
        timelineStart: 6,
        duration: 3,
        sourceStart: 1,
        zIndex: 0,
      ),
    );

    final inserted = model.clipById('copy-1')!;
    expect(inserted.track.label, 'V2');
    expect(inserted.clip.timelineStart, 6);
    expect(inserted.clip.zIndex, 1);
    expect(model.duration, 9);
  });

  test('clip color adjustments preserve signed values', () {
    final effect = ClipEffect.fromJson({
      'id': 'brightness-down',
      'type': 'brightness',
      'amount': -0.45,
      'enabled': true,
    });

    expect(effect.amount, -0.45);
    expect(effect.toJson()['amount'], -0.45);
  });
}
