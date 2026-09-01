import 'package:flutter/material.dart';

enum EditorToolCategory {
  media,
  audio,
  text,
  stickers,
  captions,
  effects,
  transitions,
  filters,
  adjustments,
}

extension EditorToolCategoryView on EditorToolCategory {
  String get label => switch (this) {
        EditorToolCategory.media => 'Media',
        EditorToolCategory.audio => 'Audio',
        EditorToolCategory.text => 'Text',
        EditorToolCategory.stickers => 'Stickers',
        EditorToolCategory.captions => 'Captions',
        EditorToolCategory.effects => 'Effects',
        EditorToolCategory.transitions => 'Transitions',
        EditorToolCategory.filters => 'Filters',
        EditorToolCategory.adjustments => 'Adjust',
      };

  IconData get icon => switch (this) {
        EditorToolCategory.media => Icons.video_library_outlined,
        EditorToolCategory.audio => Icons.music_note_outlined,
        EditorToolCategory.text => Icons.title,
        EditorToolCategory.stickers => Icons.emoji_emotions_outlined,
        EditorToolCategory.captions => Icons.closed_caption_outlined,
        EditorToolCategory.effects => Icons.auto_awesome_outlined,
        EditorToolCategory.transitions => Icons.compare_arrows,
        EditorToolCategory.filters => Icons.filter_vintage_outlined,
        EditorToolCategory.adjustments => Icons.tune,
      };
}

class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.categories = EditorToolCategory.values,
  });

  final EditorToolCategory selected;
  final ValueChanged<EditorToolCategory> onSelected;
  final List<EditorToolCategory> categories;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onSelected(category),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 58),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: category == selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 18),
                        const SizedBox(height: 2),
                        Text(category.label,
                            style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
