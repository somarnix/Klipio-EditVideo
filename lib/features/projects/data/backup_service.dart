import 'dart:io';

class BackupService {
  const BackupService({this.maximumBackups = 20});

  final int maximumBackups;

  Future<File?> create(String projectPath) async {
    final source = File(projectPath);
    if (!await source.exists()) return null;
    final backupDirectory = Directory(
      '${source.parent.path}${Platform.pathSeparator}Backups',
    );
    await backupDirectory.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final backup = await source.copy(
      '${backupDirectory.path}${Platform.pathSeparator}project-$stamp.klipio.json',
    );
    await _removeOldBackups(backupDirectory);
    return backup;
  }

  Future<void> _removeOldBackups(Directory directory) async {
    final files = await directory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final file in files.skip(maximumBackups)) {
      await file.delete();
    }
  }
}
