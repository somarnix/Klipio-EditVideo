import 'package:flutter/material.dart';

import '../../inspector/application/inspector_controller.dart';
import '../../inspector/presentation/inspector_panel_view.dart';
import '../../media_library/application/media_import_controller.dart';
import '../../media_library/presentation/media_library_view.dart';
import '../../preview/application/monitor_player_controller.dart';
import '../../preview/presentation/monitor_panel_view.dart';
import '../../timeline/application/timeline_controller.dart';
import '../../timeline/application/timeline_zoom_controller.dart';
import '../../timeline/presentation/timeline_panel_view.dart';
import 'editor_shell_view.dart';

/// Composition root for the extracted feature-first editor.
///
/// The production editor can replace each controller callback independently
/// while the parent layout remains free of media, timeline, and export logic.
class ModularEditorWorkspace extends StatefulWidget {
  const ModularEditorWorkspace({super.key, this.videoSurface});

  final Widget? videoSurface;

  @override
  State<ModularEditorWorkspace> createState() => _ModularEditorWorkspaceState();
}

class _ModularEditorWorkspaceState extends State<ModularEditorWorkspace> {
  late final MediaImportController _media;
  late final TimelineController _timeline;
  late final TimelineZoomController _zoom;
  late final InspectorController _inspector;
  late final MonitorPlayerController _monitor;

  @override
  void initState() {
    super.initState();
    _media = MediaImportController();
    _timeline = TimelineController();
    _zoom = TimelineZoomController();
    _inspector = InspectorController();
    _monitor = MonitorPlayerController(
      seekHandler: (position) async => _timeline.seek(
        position.inMicroseconds / Duration.microsecondsPerSecond,
      ),
      playHandler: () async {},
      pauseHandler: () async {},
    );
  }

  @override
  void dispose() {
    _monitor.dispose();
    _inspector.dispose();
    _zoom.dispose();
    _timeline.dispose();
    _media.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorShellView(
        mediaLibrary: MediaLibraryView(controller: _media),
        monitor: MonitorPanelView(
          controller: _monitor,
          videoSurface: widget.videoSurface ??
              const ColoredBox(
                color: Colors.black,
                child: Center(child: Text('No media selected')),
              ),
        ),
        inspector: InspectorPanelView(controller: _inspector),
        timeline: TimelinePanelView(
          controller: _timeline,
          zoomController: _zoom,
          onSpeedChanged: _inspector.updateSpeed,
        ),
      );
}
