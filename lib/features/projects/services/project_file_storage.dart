import 'dart:io';

import '../data/backup_service.dart';
import '../data/project_repository.dart';
import '../domain/klipio_project.dart';

/// Owns durable project reads/writes and backup sequencing.
class ProjectFileStorage {
  const ProjectFileStorage({
    this.repository = const ProjectRepository(),
    this.backups = const BackupService(),
  });

  final ProjectRepository repository;
  final BackupService backups;

  Future<List<String>> list() => repository.listProjectFiles();

  Future<KlipioProject> read(String path) => repository.read(path);

  Future<String> createPath(String name) => repository.createProjectPath(name);

  Future<void> write(
    String path,
    KlipioProject project, {
    bool createBackup = true,
  }) async {
    if (createBackup && await File(path).exists()) {
      await backups.create(path);
    }
    await repository.write(path, project);
  }
}
