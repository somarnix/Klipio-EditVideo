import 'package:flutter/material.dart';

import '../../../../core/theme/editor_styles.dart';
import '../../../../core/utils/timecode_formatter.dart';
import '../../application/monitor_player_controller.dart';

class MonitorTransportBar extends StatelessWidget {
  const MonitorTransportBar({super.key, required this.controller});

  final MonitorPlayerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '${TimecodeFormatter.format(controller.position, frameRate: controller.frameRate)} / '
                '${TimecodeFormatter.format(controller.duration, frameRate: controller.frameRate)}',
                style: EditorStyles.timecode,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Previous frame',
              onPressed: () => controller.step(-1),
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: controller.playing ? 'Pause' : 'Play',
              onPressed: controller.togglePlaying,
              icon: Icon(controller.playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Next frame',
              onPressed: () => controller.step(1),
              icon: const Icon(Icons.skip_next),
            ),
            IconButton(
              tooltip: 'Loop',
              onPressed: () => controller.setLooping(!controller.looping),
              icon: Icon(
                Icons.repeat,
                color: controller.looping
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ],
        ),
      );
}
