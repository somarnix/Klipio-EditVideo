import 'package:flutter/material.dart';

class ProgramOverlayLayer {
  const ProgramOverlayLayer({
    required this.id,
    required this.zIndex,
    required this.child,
    this.visible = true,
  });

  final String id;
  final int zIndex;
  final Widget child;
  final bool visible;
}

class ProgramOverlayStack extends StatelessWidget {
  const ProgramOverlayStack({super.key, required this.layers});

  final List<ProgramOverlayLayer> layers;

  @override
  Widget build(BuildContext context) {
    final visible = layers.where((layer) => layer.visible).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        for (final layer in visible)
          KeyedSubtree(key: ValueKey(layer.id), child: layer.child)
      ],
    );
  }
}
