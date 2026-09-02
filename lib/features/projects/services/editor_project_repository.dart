import 'dart:convert';
import 'dart:io';
import 'project_file_writer.dart';
import 'project_recovery.dart';

const projectFileName = 'project.klipio.json';
const projectMetaFileName = 'project-meta.json';
bool isProjectBundlePath(String path) =>
    File(path).uri.pathSegments.last.toLowerCase() == projectFileName;

/// Production bundle persistence, independent of widgets and media preparation.
class EditorProjectRepository {
  const EditorProjectRepository();
  Future<ProjectReadResult> read(String path) =>
      readProjectWithBackup(File(path));
  Future<void> write(String path, Map<String, Object?> data,
          {bool createBackup = true}) =>
      _writeKlipioProjectBundleFiles(path, data, createBackup: createBackup);
}

Future<void> ensureProjectStructure(String projectPath) async {
  if (!isProjectBundlePath(projectPath)) return;
  final root = File(projectPath).parent;
  await root.create(recursive: true);
  for (final relativePath in [
    'Resources',
    'Resources${Platform.pathSeparator}Media',
    'Resources${Platform.pathSeparator}Audio',
    'Resources${Platform.pathSeparator}Images',
    'Timelines',
    'Cache',
    'Cache${Platform.pathSeparator}Thumbnails',
    'Cache${Platform.pathSeparator}Proxies',
    'Backups',
  ]) {
    await Directory(
      '${root.path}${Platform.pathSeparator}$relativePath',
    ).create(recursive: true);
  }
}

final _projectBundleWrites = ProjectWriteQueue();

Future<void> _writeKlipioProjectBundleFiles(
  String projectPath,
  Map<String, Object?> projectData, {
  bool createBackup = true,
}) {
  // Detach nested mutable editor data before this transaction waits in queue.
  final captured = jsonDecode(jsonEncode(projectData)) as Map<String, dynamic>;
  return _projectBundleWrites.run(() => _writeCapturedProjectBundle(
        projectPath,
        captured,
        createBackup: createBackup,
      ));
}

Future<void> _writeCapturedProjectBundle(
  String projectPath,
  Map<String, Object?> projectData, {
  bool createBackup = true,
}) async {
  final projectFile = File(projectPath);
  if (!isProjectBundlePath(projectPath)) {
    await replaceProjectFile(projectFile, jsonEncode(projectData));
    return;
  }
  await ensureProjectStructure(projectPath);
  final root = projectFile.parent;
  if (createBackup && await projectFile.exists()) {
    final backupPath =
        '${root.path}${Platform.pathSeparator}Backups${Platform.pathSeparator}project.previous.klipio.json';
    await replaceProjectFile(
        File(backupPath), await projectFile.readAsString());
  }
  await replaceProjectFile(projectFile, jsonEncode(projectData));
  final videos = projectData['videos'] as List? ?? const [];
  final coverSourcePath = videos.isEmpty || videos.first is! Map
      ? ''
      : '${(videos.first as Map)['path'] ?? ''}';
  final metadataFile = File(
    '${root.path}${Platform.pathSeparator}$projectMetaFileName',
  );
  String previousCoverSourcePath = '';
  if (await metadataFile.exists()) {
    try {
      final previous = jsonDecode(await metadataFile.readAsString());
      if (previous is Map) {
        previousCoverSourcePath = '${previous['coverSourcePath'] ?? ''}';
      }
    } catch (_) {
      // Invalid metadata should never keep a stale project cover alive.
    }
  }
  if (previousCoverSourcePath.toLowerCase() != coverSourcePath.toLowerCase()) {
    final cover = File(
      '${root.path}${Platform.pathSeparator}cover.jpg',
    );
    if (await cover.exists()) await cover.delete();
  }
  final metadata = <String, Object?>{
    'name': '${projectData['outputName'] ?? ''}',
    'formatVersion': projectData['version'] ?? 1,
    'savedAt': projectData['savedAt'] ?? DateTime.now().toIso8601String(),
    'videoCount': videos.length,
    'projectFile': projectFileName,
    'coverSourcePath': coverSourcePath,
  };
  await replaceProjectFile(metadataFile, jsonEncode(metadata));
  await replaceProjectFile(
    File(
      '${root.path}${Platform.pathSeparator}Timelines${Platform.pathSeparator}timeline.json',
    ),
    jsonEncode({
      'selectedComposition': projectData['selectedComposition'],
      'timelines': projectData['timelines'] ?? const <String, Object?>{},
      'timeline': projectData['timeline'],
    }),
  );
}
