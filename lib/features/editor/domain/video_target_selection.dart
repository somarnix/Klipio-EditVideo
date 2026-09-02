class VideoTargetSelectionResult {
  const VideoTargetSelectionResult({
    required this.indexes,
    this.error,
  });

  final List<int> indexes;
  final String? error;
}

/// Parses one-based video selections such as `1,2,4 to 7,9`.
VideoTargetSelectionResult parseVideoTargetSelection(
  String expression,
  int videoCount,
) {
  final text = expression
      .trim()
      .toLowerCase()
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-');
  if (videoCount <= 0) {
    return const VideoTargetSelectionResult(
      indexes: <int>[],
      error: 'Import videos first.',
    );
  }
  if (text == 'all') {
    return VideoTargetSelectionResult(
      indexes: List<int>.generate(videoCount, (index) => index),
    );
  }
  if (text.isEmpty) {
    return const VideoTargetSelectionResult(
      indexes: <int>[],
      error: 'Enter video numbers, for example 1,2,4 to 7.',
    );
  }
  final selected = <int>{};
  for (final rawPart in text.split(',')) {
    final part = rawPart.trim();
    if (part.isEmpty) {
      return const VideoTargetSelectionResult(
        indexes: <int>[],
        error: 'Remove empty commas.',
      );
    }
    final range = RegExp(r'^(\d+)\s*(?:-|to)\s*(\d+)$').firstMatch(part);
    if (range != null) {
      final start = int.parse(range.group(1)!);
      final end = int.parse(range.group(2)!);
      if (start < 1 || end < 1 || start > videoCount || end > videoCount) {
        return VideoTargetSelectionResult(
          indexes: const <int>[],
          error: 'Video numbers must be between 1 and $videoCount.',
        );
      }
      if (end < start) {
        return const VideoTargetSelectionResult(
          indexes: <int>[],
          error: 'A range must go from a smaller number to a larger number.',
        );
      }
      for (var number = start; number <= end; number++) {
        selected.add(number - 1);
      }
      continue;
    }
    final number = int.tryParse(part);
    if (number == null) {
      return const VideoTargetSelectionResult(
        indexes: <int>[],
        error: 'Use commas and ranges such as 1,2,4 to 7,9.',
      );
    }
    if (number < 1 || number > videoCount) {
      return VideoTargetSelectionResult(
        indexes: const <int>[],
        error: 'Video numbers must be between 1 and $videoCount.',
      );
    }
    selected.add(number - 1);
  }
  final indexes = selected.toList()..sort();
  return VideoTargetSelectionResult(indexes: indexes);
}
