import 'package:flutter/material.dart';

class TimelineClipWidget extends StatelessWidget {
  const TimelineClipWidget({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.child,
    required this.onTap,
    this.onSecondaryTap,
    this.onTrimStart,
    this.onTrimEnd,
  });

  final String label;
  final bool selected;
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final GestureDragUpdateCallback? onTrimStart;
  final GestureDragUpdateCallback? onTrimEnd;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : color,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                left: 4,
                top: 3,
                right: 4,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                  ),
                ),
              ),
              if (onTrimStart != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onHorizontalDragUpdate: onTrimStart,
                    child: Container(width: 7, color: color),
                  ),
                ),
              if (onTrimEnd != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onHorizontalDragUpdate: onTrimEnd,
                    child: Container(width: 7, color: color),
                  ),
                ),
            ],
          ),
        ),
      );
}
