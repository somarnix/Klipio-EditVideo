import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/utils/timecode_formatter.dart';
import '../../domain/media_item.dart';

class MediaCardItem extends StatelessWidget {
  const MediaCardItem({super.key, required this.item, required this.onTap});

  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: item.selected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: item.thumbnailPath == null
                    ? const ColoredBox(
                        color: Colors.black26,
                        child: Icon(Icons.movie_outlined),
                      )
                    : Image.file(
                        File(item.thumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: Colors.black26),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.asset.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      TimecodeFormatter.format(item.asset.duration),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
