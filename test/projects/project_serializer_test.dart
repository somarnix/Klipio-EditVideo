import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/projects/data/project_serializer.dart';
import 'package:klipio/features/projects/domain/klipio_project.dart';
import 'package:klipio/features/projects/domain/project_metadata.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  test('project serializer preserves metadata and dynamic tracks', () {
    final now = DateTime.utc(2026, 8, 19);
    final project = KlipioProject(
      metadata: ProjectMetadata(
        id: 'project-1',
        name: 'Architecture Test',
        createdAt: now,
        updatedAt: now,
      ),
      timeline: const TimelineModel(
        duration: 5,
        tracks: [
          TrackModel(
            id: 'video-1',
            type: TrackType.video,
            index: 1,
            clips: [
              ClipModel(
                id: 'clip-1',
                mediaPath: r'C:\media\clip.mp4',
                timelineStart: 0,
                duration: 5,
                sourceStart: 2,
                zIndex: 0,
              ),
            ],
          ),
        ],
      ),
      mediaPaths: const [r'C:\media\clip.mp4'],
    );

    const serializer = ProjectSerializer();
    final restored = serializer.decode(serializer.encode(project));

    expect(restored.metadata.name, 'Architecture Test');
    expect(restored.timeline.videoTracks, hasLength(1));
    expect(restored.timeline.videoTracks.single.clips.single.sourceStart, 2);
    expect(restored.mediaPaths, hasLength(1));
  });
}
