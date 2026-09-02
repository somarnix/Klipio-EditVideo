import 'package:characters/characters.dart';

/// Shared display policy for preview and export. Keeps paragraph/space layout
/// intact and never divides the first extended grapheme cluster of a token.
/// This is casing, not linguistic word segmentation or font shaping.
String applyTextCase(String text, String letterCase) => switch (letterCase) {
      'upper' => text.toUpperCase(),
      'lower' => text.toLowerCase(),
      'title' => text.splitMapJoin(RegExp(r'\S+'), onMatch: (match) {
          final clusters = match.group(0)!.characters;
          return '${clusters.first.toUpperCase()}'
              '${clusters.skip(1).toString().toLowerCase()}';
        }),
      _ => text,
    };
