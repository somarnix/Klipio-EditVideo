import 'package:flutter/material.dart';

import '../../../core/utils/duration_utils.dart';

class ProgramTransport extends StatelessWidget {
  const ProgramTransport({
    super.key,
    required this.playing,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.onPlayPause,
    required this.onPreviousFrame,
    required this.onNextFrame,
    required this.onVolume,
    required this.onFullscreen,
  });

  final bool playing;
  final double positionSeconds;
  final double durationSeconds;
  final VoidCallback onPlayPause;
  final VoidCallback onPreviousFrame;
  final VoidCallback onNextFrame;
  final VoidCallback onVolume;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${formatEditorTimecode(durationFromSeconds(positionSeconds))} / '
              '${formatEditorTimecode(durationFromSeconds(durationSeconds))}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const Spacer(),
          IconButton(
              onPressed: onPreviousFrame,
              icon: const Icon(Icons.skip_previous)),
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(onPressed: onNextFrame, icon: const Icon(Icons.skip_next)),
          IconButton(
              onPressed: onVolume, icon: const Icon(Icons.volume_up_outlined)),
          IconButton(
              onPressed: onFullscreen, icon: const Icon(Icons.fullscreen)),
        ],
      );
}
