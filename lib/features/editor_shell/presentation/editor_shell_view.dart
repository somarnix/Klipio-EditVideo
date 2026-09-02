import 'package:flutter/material.dart';

import '../../../core/constants/layout_dimensions.dart';
import '../../../core/theme/editor_colors.dart';
import 'components/editor_center_workspace.dart';
import 'components/editor_left_nav.dart';
import 'components/editor_status_bar.dart';
import 'components/editor_top_bar.dart';
import 'controllers/editor_workspace_controller.dart';

class EditorShellView extends StatefulWidget {
  const EditorShellView({
    super.key,
    this.controller,
    this.mediaLibrary,
    this.monitor,
    this.inspector,
    this.timeline,
    this.onHome,
    this.onUndo,
    this.onRedo,
    this.onSave,
    this.onExport,
  });

  final EditorWorkspaceController? controller;
  final Widget? mediaLibrary;
  final Widget? monitor;
  final Widget? inspector;
  final Widget? timeline;
  final VoidCallback? onHome;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSave;
  final VoidCallback? onExport;

  @override
  State<EditorShellView> createState() => _EditorShellViewState();
}

class _EditorShellViewState extends State<EditorShellView> {
  late final EditorWorkspaceController _ownedController;

  EditorWorkspaceController get _controller =>
      widget.controller ?? _ownedController;

  @override
  void initState() {
    super.initState();
    _ownedController = EditorWorkspaceController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: EditorColors.background,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final bodyHeight = constraints.maxHeight -
                  LayoutDimensions.topBarHeight -
                  LayoutDimensions.statusBarHeight;
              final timelineHeight = _controller.timelineHeight.clamp(
                LayoutDimensions.minimumTimelineHeight,
                bodyHeight * 0.7,
              );
              return Column(
                children: [
                  EditorTopBar(
                    projectName: _controller.projectName,
                    onHome: widget.onHome,
                    onUndo: widget.onUndo,
                    onRedo: widget.onRedo,
                    onSave: widget.onSave,
                    onExport: widget.onExport,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              EditorLeftNav(
                                selected: _controller.section,
                                onSelected: _controller.selectSection,
                              ),
                              Expanded(
                                child: EditorCenterWorkspace(
                                  left: widget.mediaLibrary ??
                                      const _WorkspacePlaceholder('Media'),
                                  center: widget.monitor ??
                                      const _WorkspacePlaceholder('Monitor'),
                                  inspector: widget.inspector ??
                                      const _WorkspacePlaceholder('Inspector'),
                                  leftWidth: _controller.leftWidth,
                                  inspectorWidth: _controller.inspectorWidth,
                                  onLeftWidthChanged: (value) =>
                                      _controller.resizeLeft(
                                    value,
                                    constraints.maxWidth,
                                  ),
                                  onInspectorWidthChanged: (value) =>
                                      _controller.resizeInspector(
                                    value,
                                    constraints.maxWidth,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) =>
                                _controller.resizeTimeline(
                              _controller.timelineHeight - details.delta.dy,
                              bodyHeight,
                            ),
                            child: const SizedBox(
                              height: LayoutDimensions.splitterThickness,
                              child: ColoredBox(color: EditorColors.border),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: timelineHeight,
                          child: widget.timeline ??
                              const _WorkspacePlaceholder('Timeline'),
                        ),
                      ],
                    ),
                  ),
                  EditorStatusBar(
                    status: _controller.status,
                    busy: _controller.busy,
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _WorkspacePlaceholder extends StatelessWidget {
  const _WorkspacePlaceholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: EditorColors.panel,
        child: Center(child: Text(label)),
      );
}
