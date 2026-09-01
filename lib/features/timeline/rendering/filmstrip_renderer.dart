import 'dart:io';

import 'package:flutter/material.dart';

class FilmstripRenderer extends StatelessWidget {
  const FilmstripRenderer({
    super.key,
    required this.thumbnailPaths,
    this.fit = BoxFit.cover,
  });

  final List<String> thumbnailPaths;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (thumbnailPaths.isEmpty) return const ColoredBox(color: Colors.black26);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / thumbnailPaths.length;
        return ClipRect(
          child: Row(
            children: [
              for (final path in thumbnailPaths)
                SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: Image.file(
                    File(path),
                    fit: fit,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Colors.black26),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
