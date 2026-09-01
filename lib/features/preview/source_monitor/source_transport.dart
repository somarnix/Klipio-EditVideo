import 'package:flutter/material.dart';

class SourceTransport extends StatelessWidget {
  const SourceTransport({
    super.key,
    required this.playing,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onVolume,
    required this.onFullscreen,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onVolume;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
              onPressed: onPrevious, icon: const Icon(Icons.skip_previous)),
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.skip_next)),
          IconButton(
              onPressed: onVolume, icon: const Icon(Icons.volume_up_outlined)),
          IconButton(
              onPressed: onFullscreen, icon: const Icon(Icons.fullscreen)),
        ],
      );
}
