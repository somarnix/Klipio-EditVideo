import 'package:flutter/material.dart';

import '../../../core/constants/layout_dimensions.dart';
import '../../../core/theme/editor_colors.dart';
import '../application/timeline_controller.dart';
import '../application/timeline_zoom_controller.dart';
import 'components/timeline_ruler_view.dart';
import 'components/timeline_toolbar_view.dart';
import 'components/track_headers_column.dart';
import 'components/track_lanes_viewport.dart';

class TimelinePanelView extends StatefulWidget {
  const TimelinePanelView({
    super.key,
    required this.controller,
    required this.zoomController,
    this.onSpeedChanged,
    this.onSyncSettings,
  });

  final TimelineController controller;
  final TimelineZoomController zoomController;
  final ValueChanged<double>? onSpeedChanged;
  final VoidCallback? onSyncSettings;

  @override
  State<TimelinePanelView> createState() => _TimelinePanelViewState();
}

class _TimelinePanelViewState extends State<TimelinePanelView> {
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.controller.selection,
          widget.zoomController,
        ]),
        builder: (context, _) {
          final timeline = widget.controller.timeline;
          final pixels = widget.zoomController.pixelsPerSecond;
          return ColoredBox(
            color: EditorColors.panel,
            child: Column(
              children: [
                SizedBox(
                  height: LayoutDimensions.timelineToolbarHeight,
                  child: TimelineToolbarView(
                    selectionCount: widget.controller.selection.clipIds.length,
                    onSplit: widget.controller.splitSelected,
                    onSpeedChanged: widget.onSpeedChanged ?? (_) {},
                    onDeleteRipple: widget.controller.deleteSelected,
                    onSyncSettings: widget.onSyncSettings ?? () {},
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        child: Column(
                          children: [
                            const SizedBox(
                              height: LayoutDimensions.timelineRulerHeight,
                            ),
                            TrackHeadersColumn(
                              tracks: timeline.tracks,
                              trackHeight: LayoutDimensions.defaultTrackHeight,
                              onTrackChanged: (track) {
                                widget.controller.timeline =
                                    widget.controller.editor.updateTrack(
                                  timeline,
                                  track.id,
                                  (_) => track,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TimelineRulerView(
                                duration: timeline.duration,
                                pixelsPerSecond: pixels,
                                onSeek: widget.controller.seek,
                              ),
                              TrackLanesViewport(
                                timeline: timeline,
                                pixelsPerSecond: pixels,
                                trackHeight:
                                    LayoutDimensions.defaultTrackHeight,
                                selectedClipIds:
                                    widget.controller.selection.clipIds,
                                onClipSelected:
                                    widget.controller.selection.selectOnly,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}
