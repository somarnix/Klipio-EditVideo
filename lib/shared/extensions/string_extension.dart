import 'dart:io';

extension KlipioStringExtension on String {
  String get fileName {
    final normalized = replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  String get fileStem {
    final name = fileName;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  String get safeFileName {
    var value = trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (value.isEmpty) value = 'Untitled';
    return value;
  }

  bool get fileExists => File(this).existsSync();
}
