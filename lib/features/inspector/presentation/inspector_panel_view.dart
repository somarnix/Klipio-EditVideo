import 'package:flutter/material.dart';

import '../../../core/theme/editor_colors.dart';
import '../application/inspector_controller.dart';
import 'tabs/audio_properties_tab.dart';
import 'tabs/canvas_background_tab.dart';
import 'tabs/speed_curve_tab.dart';
import 'tabs/video_transform_tab.dart';

class InspectorPanelView extends StatelessWidget {
  const InspectorPanelView({super.key, required this.controller});

  final InspectorController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => DefaultTabController(
          length: 4,
          child: ColoredBox(
            color: EditorColors.panel,
            child: Column(
              children: [
                const SizedBox(
                  height: 40,
                  child: TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Video'),
                      Tab(text: 'Audio'),
                      Tab(text: 'Speed'),
                      Tab(text: 'Canvas'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      VideoTransformTab(controller: controller),
                      AudioPropertiesTab(controller: controller),
                      SpeedCurveTab(controller: controller),
                      CanvasBackgroundTab(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
