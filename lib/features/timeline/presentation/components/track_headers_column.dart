import 'package:flutter/material.dart';

import '../../domain/timeline_models.dart';
import '../headers/track_header.dart';

class TrackHeadersColumn extends StatelessWidget {
  const TrackHeadersColumn({
    super.key,
    required this.tracks,
    required this.trackHeight,
    required this.onTrackChanged,
  });

  final List<TrackModel> tracks;
  final double trackHeight;
  final ValueChanged<TrackModel> onTrackChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final track in tracks)
            SizedBox(
              height: trackHeight,
              child: TrackHeader(
                label: track.label,
                muted: track.isMuted,
                locked: track.isLocked,
                hidden: false,
                onMute: () => onTrackChanged(
                  track.copyWith(isMuted: !track.isMuted),
                ),
                onLock: () => onTrackChanged(
                  track.copyWith(isLocked: !track.isLocked),
                ),
                onVisibility: () {},
              ),
            ),
        ],
      );
}
