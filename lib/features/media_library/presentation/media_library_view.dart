import 'package:flutter/material.dart';

import '../../../core/theme/editor_colors.dart';
import '../application/media_import_controller.dart';
import 'components/import_toolbar.dart';
import 'components/media_card_item.dart';
import 'components/media_drop_target.dart';

class MediaLibraryView extends StatelessWidget {
  const MediaLibraryView({super.key, required this.controller});

  final MediaImportController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MediaDropTarget(
          onDropped: controller.importPaths,
          child: ColoredBox(
            color: EditorColors.panel,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ImportToolbar(
                    busy: controller.importing,
                    onImportFiles: controller.pickFiles,
                    onImportFolder: controller.pickFolder,
                  ),
                ),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      controller.error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                Expanded(
                  child: controller.items.isEmpty
                      ? const Center(
                          child: Text('Drop videos here or choose Import'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            childAspectRatio: 1.15,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount: controller.items.length,
                          itemBuilder: (context, index) {
                            final item = controller.items[index];
                            return MediaCardItem(
                              item: item,
                              onTap: () => controller.select(item.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
}
