import 'package:flutter/material.dart';

/// Narrow desktop alternative to squeezing four panels below their usable
/// width. Only presentation selection lives here; children retain their owners.
class WorkspacePanelTabs extends StatefulWidget {
  const WorkspacePanelTabs(
      {super.key,
      required this.panels,
      required this.labels,
      this.selectedPanel,
      this.onPanelChanged});
  final Map<String, Widget> panels;
  final Map<String, String> labels;
  final ValueChanged<String>? onPanelChanged;
  final String? selectedPanel;

  @override
  State<WorkspacePanelTabs> createState() => _WorkspacePanelTabsState();
}

class _WorkspacePanelTabsState extends State<WorkspacePanelTabs> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    if (widget.panels.isEmpty) return const SizedBox.shrink();
    final requested = widget.selectedPanel ?? _selected;
    final selected = widget.panels.containsKey(requested)
        ? requested!
        : widget.panels.keys.first;
    return Column(children: [
      SizedBox(
        height: 38,
        child: Row(children: [
          for (final id in widget.panels.keys)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: Text(widget.labels[id] ?? id,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: id == selected,
                      onSelected: (_) {
                        widget.onPanelChanged?.call(id);
                        setState(() => _selected = id);
                      },
                    ))),
        ]),
      ),
      Expanded(
          child: IndexedStack(
        index: widget.panels.keys.toList().indexOf(selected),
        sizing: StackFit.expand,
        children: [
          for (final entry in widget.panels.entries)
            TickerMode(
                enabled: entry.key == selected,
                child:
                    KeyedSubtree(key: ValueKey(entry.key), child: entry.value))
        ],
      )),
    ]);
  }
}
