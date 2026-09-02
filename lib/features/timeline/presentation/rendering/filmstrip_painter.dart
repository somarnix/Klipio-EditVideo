import 'dart:io';

import 'package:flutter/material.dart';

/// Paint-efficient filmstrip that decodes only the visible thumbnail widgets.
class FilmstripView extends StatelessWidget {
  const FilmstripView({
    super.key,
    required this.paths,
    this.fit = BoxFit.cover,
  });

  final List<String> paths;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visibleCount =
              (constraints.maxWidth / 84).ceil().clamp(1, paths.length);
          return Row(
            children: [
              for (var index = 0; index < visibleCount; index++)
                Expanded(
                  child: Image.file(
                    File(paths[(index * paths.length / visibleCount)
                        .floor()
                        .clamp(0, paths.length - 1)]),
                    fit: fit,
                    height: double.infinity,
                    cacheWidth: 160,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
