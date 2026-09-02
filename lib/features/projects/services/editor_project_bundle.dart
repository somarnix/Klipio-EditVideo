part of '../../editor_shell/presentation/editor_application.dart';

const _klipioProjectFileName = 'project.klipio.json';

String normalizeVideoTitle(String value) {
  var title = value.trim();
  final slash = math.max(title.lastIndexOf('/'), title.lastIndexOf('\\'));
  if (slash >= 0) title = title.substring(slash + 1);
  title = title.replaceFirst(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '');
  title = title.replaceFirst(RegExp(r'^\s*\d+\s*[.\-_)]\s*'), '');
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'''[โ€โ€'`โ€โ€"]'''), '')
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String numberedExportBaseName(
  String base, {
  required int number,
  required bool enabled,
  bool patternIncludesNumber = false,
}) {
  if (!enabled || patternIncludesNumber) return base;
  return '$number.$base';
}

String _safeProjectDirectoryName(String value) {
  var safe = value
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (safe.isEmpty) safe = 'Klipio Project';
  if (safe.length > 80) safe = safe.substring(0, 80).trimRight();
  return safe;
}

bool _isKlipioProjectBundlePath(String path) =>
    platform.basename(path).toLowerCase() == _klipioProjectFileName;

bool _sameWindowsPath(String left, String right) =>
    Directory(left).absolute.uri.normalizePath().toFilePath().toLowerCase() ==
    Directory(right).absolute.uri.normalizePath().toFilePath().toLowerCase();

Future<Directory> _klipioDraftsRoot() async {
  final userProfile = Platform.environment['USERPROFILE']?.trim();
  if (Platform.isWindows && userProfile != null && userProfile.isNotEmpty) {
    return Directory(
      '$userProfile${Platform.pathSeparator}Klipio Drafts',
    );
  }
  final documents = await getApplicationDocumentsDirectory();
  return Directory(
    '${documents.parent.path}${Platform.pathSeparator}Klipio Drafts',
  );
}

Future<bool> _isManagedKlipioProjectPath(String projectPath) async {
  if (!_isKlipioProjectBundlePath(projectPath)) return false;
  final draftsRoot = await _klipioDraftsRoot();
  final projectDirectory = File(projectPath).parent;
  return _sameWindowsPath(projectDirectory.parent.path, draftsRoot.path);
}

Future<String?> _projectFileFromSelectedFolder(String selectedFolder) async {
  final projectPath =
      '$selectedFolder${Platform.pathSeparator}$_klipioProjectFileName';
  if (!await _isManagedKlipioProjectPath(projectPath) ||
      !await File(projectPath).exists()) {
    return null;
  }
  return projectPath;
}

Future<List<String>> _discoverKlipioProjectPaths() async {
  final root = await _klipioDraftsRoot();
  await root.create(recursive: true);
  final projects = <(String, DateTime)>[];
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory) continue;
    final path =
        '${entity.path}${Platform.pathSeparator}$_klipioProjectFileName';
    final file = File(path);
    if (!await file.exists()) continue;
    final stat = await file.stat();
    projects.add((path, stat.modified));
  }
  projects.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final project in projects) project.$1];
}

Future<void> _ensureKlipioProjectStructure(String path) =>
    ensureProjectStructure(path);

Future<Directory> _uniqueKlipioProjectDirectory(
  Directory parent,
  String preferredName, {
  String? currentPath,
}) async {
  await parent.create(recursive: true);
  final safeName = _safeProjectDirectoryName(preferredName);
  for (var index = 0; index < 10000; index++) {
    final suffix = index == 0 ? '' : ' ($index)';
    final candidate = Directory(
      '${parent.path}${Platform.pathSeparator}$safeName$suffix',
    );
    if (currentPath != null &&
        candidate.path.toLowerCase() == currentPath.toLowerCase()) {
      return candidate;
    }
    if (!await candidate.exists()) return candidate;
  }
  return Directory(
    '${parent.path}${Platform.pathSeparator}$safeName ${DateTime.now().millisecondsSinceEpoch}',
  );
}

Future<void> _copyKlipioProjectDirectory(
  Directory source,
  Directory target,
) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final targetPath =
        '${target.path}${Platform.pathSeparator}${platform.basename(entity.path)}';
    if (entity is Directory) {
      await _copyKlipioProjectDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}

Future<void> _writeKlipioProjectBundleFiles(
        String path, Map<String, Object?> data, {bool createBackup = true}) =>
    const EditorProjectRepository()
        .write(path, data, createBackup: createBackup);
