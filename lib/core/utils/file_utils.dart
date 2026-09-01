import 'dart:io';
import 'dart:math' as math;
import '../constants/app_constants.dart';
import '../../services/platform/platform_support.dart' as platform;

String normalizeVideoTitle(String value) {
  var title = value.trim();
  final slash = math.max(title.lastIndexOf('/'), title.lastIndexOf('\\'));
  if (slash >= 0) title = title.substring(slash + 1);
  title = title.replaceFirst(RegExp(r'\.[a-zA-Z0-9]{2,5}$'), '');
  title = title.replaceFirst(RegExp(r'^\s*\d+\s*[.\-_)]\s*'), '');
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'''[‘’'`“”"]'''), '')
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String safeProjectDirectoryName(String value) {
  var safe = value
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (safe.isEmpty) safe = 'Klipio Project';
  if (safe.length > 80) safe = safe.substring(0, 80).trimRight();
  return safe;
}

bool isKlipioProjectBundlePath(String path) =>
    platform.basename(path).toLowerCase() == klipioProjectFileName;

bool sameWindowsPath(String left, String right) =>
    Directory(left).absolute.uri.normalizePath().toFilePath().toLowerCase() ==
    Directory(right).absolute.uri.normalizePath().toFilePath().toLowerCase();

Future<Directory> klipioDraftsRoot() async {
  final userProfile = Platform.environment['USERPROFILE']?.trim();
  if (Platform.isWindows && userProfile != null && userProfile.isNotEmpty) {
    return Directory(
      '$userProfile${Platform.pathSeparator}Klipio Drafts',
    );
  }
  final userHome = Platform.environment['HOME'];
  return Directory(
    '${userHome ?? '/tmp'}${Platform.pathSeparator}Klipio Drafts',
  );
}

Future<bool> isManagedKlipioProjectPath(String projectPath) async {
  if (!isKlipioProjectBundlePath(projectPath)) return false;
  final draftsRoot = await klipioDraftsRoot();
  final projectDirectory = File(projectPath).parent;
  return sameWindowsPath(projectDirectory.parent.path, draftsRoot.path);
}

Future<String?> projectFileFromSelectedFolder(String selectedFolder) async {
  final projectPath =
      '$selectedFolder${Platform.pathSeparator}$klipioProjectFileName';
  if (!await isManagedKlipioProjectPath(projectPath) ||
      !await File(projectPath).exists()) {
    return null;
  }
  return projectPath;
}

Future<List<String>> discoverKlipioProjectPaths() async {
  final root = await klipioDraftsRoot();
  await root.create(recursive: true);
  final projects = <(String, DateTime)>[];
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory) continue;
    final path =
        '${entity.path}${Platform.pathSeparator}$klipioProjectFileName';
    final file = File(path);
    if (!await file.exists()) continue;
    final stat = await file.stat();
    projects.add((path, stat.modified));
  }
  projects.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final project in projects) project.$1];
}

Future<void> ensureKlipioProjectStructure(String projectPath) async {
  if (!isKlipioProjectBundlePath(projectPath)) return;
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

Future<Directory> uniqueKlipioProjectDirectory(
  Directory parent,
  String preferredName, {
  String? currentPath,
}) async {
  await parent.create(recursive: true);
  final safeName = safeProjectDirectoryName(preferredName);
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

Future<void> copyKlipioProjectDirectory(
  Directory source,
  Directory target,
) async {
  await target.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final targetPath =
        '${target.path}${Platform.pathSeparator}${platform.basename(entity.path)}';
    if (entity is Directory) {
      await copyKlipioProjectDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}
