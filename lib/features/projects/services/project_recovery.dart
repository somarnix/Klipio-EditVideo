import 'dart:convert';
import 'dart:io';

class ProjectReadResult {
  const ProjectReadResult(this.data, {required this.recovered});
  final Map<String, dynamic> data;
  final bool recovered;
}

/// Reads the legacy runtime envelope without changing either recovery candidate.
/// Missing media is intentionally not treated as corruption.
Future<ProjectReadResult> readProjectWithBackup(File primary) async {
  Future<Map<String, dynamic>> read(File file) async {
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic> ||
        value['videos'] is! List ||
        (value['videos'] as List).any((entry) => entry is! Map)) {
      throw const FormatException('Invalid Klipio project envelope.');
    }
    return value;
  }

  try {
    return ProjectReadResult(await read(primary), recovered: false);
  } on FormatException {
    // Parse/envelope corruption permits recovery. Permission and device errors
    // must surface instead of silently opening an older project.
    final backup = File('${primary.parent.path}${Platform.pathSeparator}'
        'Backups${Platform.pathSeparator}project.previous.klipio.json');
    return ProjectReadResult(await read(backup), recovered: true);
  }
}
