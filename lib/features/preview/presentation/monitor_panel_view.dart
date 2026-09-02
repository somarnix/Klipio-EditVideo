import 'package:flutter/material.dart';

import '../../../core/theme/editor_colors.dart';
import '../application/monitor_player_controller.dart';
import 'components/monitor_canvas_display.dart';
import 'components/monitor_transport_bar.dart';

class MonitorPanelView extends StatelessWidget {
  const MonitorPanelView({
    super.key,
    required this.controller,
    required this.videoSurface,
    this.aspectRatio = 16 / 9,
    this.overlays = const [],
    this.title = 'Player-Timeline 01',
  });

  final MonitorPlayerController controller;
  final Widget videoSurface;
  final double aspectRatio;
  final List<Widget> overlays;
  final String title;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: EditorColors.panel,
        child: Column(
          children: [
            SizedBox(
              height: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(title),
                ),
              ),
            ),
            Expanded(
              child: MonitorCanvasDisplay(
                aspectRatio: aspectRatio,
                overlays: overlays,
                child: videoSurface,
              ),
            ),
            SizedBox(
              height: 44,
              child: MonitorTransportBar(controller: controller),
            ),
          ],
        ),
      );
}
