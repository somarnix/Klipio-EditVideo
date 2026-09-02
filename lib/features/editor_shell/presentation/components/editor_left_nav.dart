import 'package:flutter/material.dart';

import '../controllers/editor_workspace_controller.dart';

class EditorLeftNav extends StatelessWidget {
  const EditorLeftNav({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final EditorWorkspaceSection selected;
  final ValueChanged<EditorWorkspaceSection> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
        minWidth: 58,
        groupAlignment: -1,
        labelType: NavigationRailLabelType.none,
        selectedIndex: EditorWorkspaceSection.values.indexOf(selected),
        onDestinationSelected: (index) =>
            onSelected(EditorWorkspaceSection.values[index]),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.video_library_outlined),
            label: Text('Media'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.title_outlined),
            label: Text('Text'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.audiotrack_outlined),
            label: Text('Audio'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.subtitles_outlined),
            label: Text('Captions'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.auto_fix_high_outlined),
            label: Text('Effects'),
          ),
        ],
      );
}
