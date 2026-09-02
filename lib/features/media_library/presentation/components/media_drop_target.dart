import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class MediaDropTarget extends StatefulWidget {
  const MediaDropTarget(
      {super.key, required this.child, required this.onDropped});

  final Widget child;
  final ValueChanged<List<String>> onDropped;

  @override
  State<MediaDropTarget> createState() => _MediaDropTargetState();
}

class _MediaDropTargetState extends State<MediaDropTarget> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) => DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (details) {
          setState(() => _dragging = false);
          widget.onDropped([for (final file in details.files) file.path]);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: _dragging
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: widget.child,
        ),
      );
}
