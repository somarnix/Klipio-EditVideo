import 'package:flutter/material.dart';

import '../../domain/editor_selection.dart';

enum LeftWorkspaceTab { media, text, captions, effects, audio }

class ContextAwareInspector extends StatefulWidget {
  const ContextAwareInspector({
    super.key,
    required this.selection,
    required this.projectDetails,
    required this.videoProperties,
    required this.audioProperties,
    required this.textProperties,
    required this.captionProperties,
    this.transitionProperties,
  });

  final EditorSelection selection;
  final Widget projectDetails;
  final Widget videoProperties;
  final Widget audioProperties;
  final Widget textProperties;
  final Widget captionProperties;
  final Widget? transitionProperties;

  @override
  State<ContextAwareInspector> createState() => _ContextAwareInspectorState();
}

class _ContextAwareInspectorState extends State<ContextAwareInspector> {
  late bool _showEdit;

  bool get _hasSelection =>
      widget.selection.kind != EditorSelectionKind.none &&
      widget.selection.id.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _showEdit = _hasSelection;
  }

  @override
  void didUpdateWidget(covariant ContextAwareInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection.kind != widget.selection.kind ||
        oldWidget.selection.id != widget.selection.id) {
      _showEdit = _hasSelection;
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = switch (widget.selection.kind) {
      EditorSelectionKind.none => widget.projectDetails,
      EditorSelectionKind.videoClip => widget.videoProperties,
      EditorSelectionKind.audioClip => widget.audioProperties,
      EditorSelectionKind.textLayer => widget.textProperties,
      EditorSelectionKind.captionCue => widget.captionProperties,
      EditorSelectionKind.transition =>
        widget.transitionProperties ?? widget.videoProperties,
    };
    final label = switch (widget.selection.kind) {
      EditorSelectionKind.none => 'Nothing selected',
      EditorSelectionKind.videoClip => 'Video',
      EditorSelectionKind.audioClip => 'Audio',
      EditorSelectionKind.textLayer => 'Text',
      EditorSelectionKind.captionCue => 'Captions',
      EditorSelectionKind.transition => 'Transition',
    };
    return Column(
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _InspectorTabButton(
                  label: 'Details',
                  selected: !_showEdit,
                  onTap: () => setState(() => _showEdit = false),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _InspectorTabButton(
                  label: _hasSelection ? 'Edit · $label' : 'Edit',
                  selected: _showEdit,
                  enabled: _hasSelection,
                  onTap: () => setState(() => _showEdit = true),
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: KeyedSubtree(
                key:
                    ValueKey('${widget.selection.kind}:${widget.selection.id}'),
                child:
                    _showEdit && _hasSelection ? edit : widget.projectDetails)),
      ],
    );
  }
}

class _InspectorTabButton extends StatelessWidget {
  const _InspectorTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withOpacity(0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(5),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enabled
                  ? (selected ? scheme.primary : scheme.onSurface)
                  : scheme.onSurface.withOpacity(0.38),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
