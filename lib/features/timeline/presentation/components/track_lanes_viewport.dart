import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/timeline_models.dart';
import '../clips/audio_clip_item.dart';
import '../clips/caption_clip_item.dart';
import '../clips/video_clip_item.dart';

class TrackLanesViewport extends StatelessWidget {
  const TrackLanesViewport({
    super.key,
    required this.timeline,
    required this.pixelsPerSecond,
    required this.trackHeight,
    required this.selectedClipIds,
    required this.onClipSelected,
    this.thumbnailPaths = const {},
    this.waveforms = const {},
  });

  final TimelineModel timeline;
  final double pixelsPerSecond;
  final double trackHeight;
  final Set<String> selectedClipIds;
  final ValueChanged<String> onClipSelected;
  final Map<String, List<String>> thumbnailPaths;
  final Map<String, List<double>> waveforms;

  @override
  Widget build(BuildContext context) {
    final width = math.max(1.0, timeline.duration * pixelsPerSecond);
    return SizedBox(
      width: width,
      height: timeline.tracks.length * trackHeight,
      child: Column(
        children: [
          for (final track in timeline.tracks)
            SizedBox(
              height: trackHeight,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.white12)),
                      ),
                    ),
                  ),
                  for (final clip in track.clips)
                    Positioned(
                      left: clip.timelineStart * pixelsPerSecond,
                      top: 3,
                      width: math.max(8, clip.duration * pixelsPerSecond),
                      bottom: 3,
                      child: switch (track.type) {
                        TrackType.video => VideoClipItem(
                            label: _name(clip.mediaPath),
                            selected: selectedClipIds.contains(clip.id),
                            thumbnailPaths:
                                thumbnailPaths[clip.mediaPath] ?? const [],
                            onSelected: () => onClipSelected(clip.id),
                          ),
                        TrackType.audio => AudioClipItem(
                            label: _name(clip.mediaPath),
                            selected: selectedClipIds.contains(clip.id),
                            peaks: waveforms[clip.mediaPath] ?? const [],
                            onSelected: () => onClipSelected(clip.id),
                          ),
                        TrackType.text => CaptionClipItem(
                            text: _name(clip.mediaPath),
                            selected: selectedClipIds.contains(clip.id),
                            onSelected: () => onClipSelected(clip.id),
                          ),
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _name(String path) => path.replaceAll('\\', '/').split('/').last;
}
