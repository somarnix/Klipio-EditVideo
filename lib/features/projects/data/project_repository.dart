import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';
import '../domain/klipio_project.dart';
import 'project_serializer.dart';

class ProjectRepository {
  const ProjectRepository({this.serializer = const ProjectSerializer()});

  final ProjectSerializer serializer;

  Future<List<String>> listProjectFiles() => discoverKlipioProjectPaths();

  Future<KlipioProject> read(String projectPath) async {
    final source = await File(projectPath).readAsString();
    return serializer.decode(source);
  }

  Future<void> write(String projectPath, KlipioProject project) async {
    await ensureKlipioProjectStructure(projectPath);
    final file = File(projectPath);
    final temporary = File('$projectPath.tmp');
    await temporary.writeAsString(serializer.encode(project), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<String> createProjectPath(String name) async {
    final root = await klipioDraftsRoot();
    final directory = await uniqueKlipioProjectDirectory(root, name);
    await directory.create(recursive: true);
    final path = '${directory.path}${Platform.pathSeparator}'
        '$klipioProjectFileName';
    await ensureKlipioProjectStructure(path);
    return path;
  }
}
