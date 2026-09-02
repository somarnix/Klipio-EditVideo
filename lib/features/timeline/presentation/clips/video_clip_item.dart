import 'package:flutter/material.dart';

import '../../../../core/theme/editor_colors.dart';
import '../../rendering/filmstrip_renderer.dart';
import '../clips/clip_widget.dart';

class VideoClipItem extends StatelessWidget {
  const VideoClipItem({
    super.key,
    required this.label,
    required this.selected,
    required this.thumbnailPaths,
    required this.onSelected,
    this.onTrimStart,
    this.onTrimEnd,
  });

  final String label;
  final bool selected;
  final List<String> thumbnailPaths;
  final VoidCallback onSelected;
  final GestureDragUpdateCallback? onTrimStart;
  final GestureDragUpdateCallback? onTrimEnd;

  @override
  Widget build(BuildContext context) => TimelineClipWidget(
        label: label,
        selected: selected,
        color: EditorColors.videoTrack,
        onTap: onSelected,
        onTrimStart: onTrimStart,
        onTrimEnd: onTrimEnd,
        child: FilmstripRenderer(thumbnailPaths: thumbnailPaths),
      );
}
