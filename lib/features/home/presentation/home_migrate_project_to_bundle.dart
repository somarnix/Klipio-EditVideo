part of '../../editor_shell/presentation/editor_application.dart';

extension _HomeMigrateProjectToBundle on _KlipioHomeScreenState {
  Future<String> _migrateProjectToBundle(String sourcePath) async {
    if (await _isManagedKlipioProjectPath(sourcePath)) return sourcePath;
    final source = File(sourcePath);
    if (!await source.exists() ||
        !sourcePath.toLowerCase().endsWith('.klipio.json')) {
      return sourcePath;
    }
    Directory? projectDirectory;
    try {
      final decoded = jsonDecode(await source.readAsString());
      if (decoded is! Map) return sourcePath;
      final savedName = '${decoded['outputName'] ?? ''}'.trim();
      final legacyName = platform.basename(sourcePath).replaceFirst(
            RegExp(r'\.klipio\.json$', caseSensitive: false),
            '',
          );
      final draftsRoot = await _klipioDraftsRoot();
      projectDirectory = await _uniqueKlipioProjectDirectory(
        draftsRoot,
        savedName.isEmpty ? legacyName : savedName,
      );
      final targetPath =
          '${projectDirectory.path}${Platform.pathSeparator}$_klipioProjectFileName';
      await _writeKlipioProjectBundleFiles(
        targetPath,
        Map<String, Object?>.from(decoded),
        createBackup: false,
      );
      // Delete the legacy file only after the complete project bundle has
      // been written successfully. A failed migration keeps the original.
      await source.delete();
      return targetPath;
    } catch (_) {
      if (projectDirectory != null && await projectDirectory.exists()) {
        try {
          await projectDirectory.delete(recursive: true);
        } catch (_) {
          // The original legacy project remains the source of truth.
        }
      }
      return sourcePath;
    }
  }

  Future<void> _loadProjects() async {
    final generation = ++_projectLoadGeneration;
    final projects = <_HomeProject>[];
    if (mounted) {
      _updateHome(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final draftsRoot = await _klipioDraftsRoot();
      await draftsRoot.create(recursive: true);
      final prefs = await loadSharedPreferencesRecovering();
      final savedPaths =
          prefs.getStringList(_EditorScreenState._recentProjectsKey) ??
              const <String>[];
      final paths = <String>[];
      var migrated = false;
      for (final savedPath in savedPaths) {
        final resolvedPath = await _migrateProjectToBundle(savedPath);
        migrated = migrated || resolvedPath != savedPath;
        if (resolvedPath != savedPath) {
          var migratedName = platform.basename(File(resolvedPath).parent.path);
          try {
            final decoded = jsonDecode(await File(resolvedPath).readAsString());
            if (decoded is Map &&
                '${decoded['outputName'] ?? ''}'.trim().isNotEmpty) {
              migratedName = '${decoded['outputName']}'.trim();
            }
          } catch (_) {
            // The folder name is a safe fallback for editor synchronization.
          }
          widget.onProjectRenamed(savedPath, resolvedPath, migratedName);
        }
        paths.add(resolvedPath);
      }
      final discoveredPaths = await _discoverKlipioProjectPaths().timeout(
        const Duration(seconds: 8),
        onTimeout: () => const <String>[],
      );
      for (final discoveredPath in discoveredPaths) {
        if (paths.any(
            (path) => path.toLowerCase() == discoveredPath.toLowerCase())) {
          continue;
        }
        paths.add(discoveredPath);
        migrated = true;
      }
      if (migrated) await _saveRecentProjectPaths(paths);
      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) {
          projects.add(_HomeProject(path: path, missing: true));
          continue;
        }
        try {
          final stat = await file.stat();
          final decoded = jsonDecode(await file.readAsString());
          final data = decoded is Map ? decoded : const {};
          final managedProject = await _isManagedKlipioProjectPath(path);
          final videos = data['videos'] as List? ?? const [];
          String? sourceVideoPath;
          for (final item in videos) {
            if (item is! Map) continue;
            final candidate = '${item['path'] ?? ''}'.trim();
            if (candidate.isNotEmpty && File(candidate).existsSync()) {
              sourceVideoPath = candidate;
              break;
            }
          }
          final outputName = '${data['outputName'] ?? ''}'.trim();
          final coverPath = managedProject
              ? '${file.parent.path}${Platform.pathSeparator}cover.jpg'
              : null;
          projects.add(
            _HomeProject(
              path: path,
              name: outputName.isEmpty
                  ? (managedProject
                      ? platform.basename(file.parent.path)
                      : platform.basename(path).replaceFirst(
                            RegExp(
                              r'\.klipio\.json$|\.json$',
                              caseSensitive: false,
                            ),
                            '',
                          ))
                  : outputName,
              modified: stat.modified,
              videoCount: videos.length,
              sourceVideoPath: sourceVideoPath,
              thumbnailPath: coverPath != null && File(coverPath).existsSync()
                  ? coverPath
                  : null,
            ),
          );
        } catch (_) {
          projects.add(_HomeProject(path: path, missing: true));
        }
      }
    } catch (error) {
      if (!mounted || generation != _projectLoadGeneration) return;
      _updateHome(() {
        _loading = false;
        _loadError = 'Recent projects could not be loaded. $error';
      });
      return;
    }
    if (!mounted || generation != _projectLoadGeneration) return;
    _updateHome(() {
      _projects = projects;
      _loading = false;
      _loadError = null;
    });
    final cacheDirectory = await getCacheDirectory();
    final thumbnailCache =
        '${cacheDirectory.path}${Platform.pathSeparator}klipio_thumbnails';
    for (var index = 0; index < projects.length; index++) {
      if (projects[index].thumbnailPath != null) continue;
      final sourcePath = projects[index].sourceVideoPath;
      if (sourcePath == null) continue;
      var thumbnailPath =
          await platform.thumbnailForVideo(sourcePath, thumbnailCache);
      if (!mounted || generation != _projectLoadGeneration) return;
      if (thumbnailPath == null || !File(thumbnailPath).existsSync()) continue;
      if (await _isManagedKlipioProjectPath(projects[index].path)) {
        final coverPath =
            '${File(projects[index].path).parent.path}${Platform.pathSeparator}cover.jpg';
        try {
          await File(thumbnailPath).copy(coverPath);
          thumbnailPath = coverPath;
        } catch (_) {
          // The generated cache thumbnail is still usable.
        }
      }
      _updateHome(() {
        final currentIndex = _projects.indexWhere(
          (project) => project.path == projects[index].path,
        );
        if (currentIndex < 0) return;
        _projects = [..._projects]..[currentIndex] =
              _projects[currentIndex].copyWith(
            thumbnailPath: thumbnailPath,
          );
      });
    }
  }

  Future<void> _showSettings() => showKlipioSettingsDialog(
        context,
        settings: widget.settings,
        onSaved: widget.onSettingsChanged,
      );

  void _projectMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: KText(message)),
    );
  }

  Future<void> _saveRecentProjectPaths(List<String> paths) async {
    final unique = <String>[];
    for (final path in paths) {
      if (unique.any((item) => item.toLowerCase() == path.toLowerCase())) {
        continue;
      }
      unique.add(path);
      if (unique.length == _EditorScreenState._maxRecentProjects) break;
    }
    final prefs = await loadSharedPreferencesRecovering();
    await prefs.setStringList(_EditorScreenState._recentProjectsKey, unique);
    widget.onRecentProjectsChanged(List.unmodifiable(unique));
  }

  Future<void> _forgetRecentProject(String path) async {
    final prefs = await loadSharedPreferencesRecovering();
    final paths = prefs
            .getStringList(_EditorScreenState._recentProjectsKey)
            ?.where((item) => item.toLowerCase() != path.toLowerCase())
            .toList() ??
        <String>[];
    await _saveRecentProjectPaths(paths);
  }

  Future<void> _rememberRecentProject(String path) async {
    final prefs = await loadSharedPreferencesRecovering();
    final paths = prefs.getStringList(_EditorScreenState._recentProjectsKey) ??
        <String>[];
    await _saveRecentProjectPaths([
      path,
      ...paths.where((item) => item.toLowerCase() != path.toLowerCase()),
    ]);
  }

  Future<void> _replaceRecentProjectPath(
    String oldPath,
    String newPath,
  ) async {
    final prefs = await loadSharedPreferencesRecovering();
    final paths = prefs.getStringList(_EditorScreenState._recentProjectsKey) ??
        <String>[];
    await _saveRecentProjectPaths([
      newPath,
      ...paths.where(
        (item) =>
            item.toLowerCase() != oldPath.toLowerCase() &&
            item.toLowerCase() != newPath.toLowerCase(),
      ),
    ]);
  }

  Future<void> _renameHomeProject(_HomeProject project) async {
    if (project.missing || !File(project.path).existsSync()) {
      _projectMessage('The project file no longer exists.');
      return;
    }
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const KText('Rename project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Project name',
            prefixIcon: Icon(Icons.drive_file_rename_outline),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const KText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
            },
            child: const KText('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name == project.name) return;
    try {
      final decoded = jsonDecode(await File(project.path).readAsString());
      if (decoded is! Map) throw const FormatException('Invalid project file');
      final data = Map<String, Object?>.from(decoded);
      data['outputName'] = name;
      data['savedAt'] = DateTime.now().toIso8601String();
      var newPath = project.path;
      if (await _isManagedKlipioProjectPath(project.path)) {
        final oldDirectory = File(project.path).parent;
        final targetDirectory = await _uniqueKlipioProjectDirectory(
          oldDirectory.parent,
          name,
          currentPath: oldDirectory.path,
        );
        if (targetDirectory.path.toLowerCase() !=
            oldDirectory.path.toLowerCase()) {
          await oldDirectory.rename(targetDirectory.path);
          newPath =
              '${targetDirectory.path}${Platform.pathSeparator}$_klipioProjectFileName';
        }
      }
      await _writeKlipioProjectBundleFiles(newPath, data);
      widget.onProjectRenamed(project.path, newPath, name);
      await _replaceRecentProjectPath(project.path, newPath);
      await _loadProjects();
      _projectMessage('Project renamed to $name.');
    } catch (error) {
      _projectMessage('Could not rename project: $error');
    }
  }

  Future<void> _duplicateHomeProject(_HomeProject project) async {
    if (project.missing || !File(project.path).existsSync()) {
      _projectMessage('The project file no longer exists.');
      return;
    }
    try {
      final decoded = jsonDecode(await File(project.path).readAsString());
      if (decoded is! Map) throw const FormatException('Invalid project file');
      final data = Map<String, Object?>.from(decoded);
      final copyName = '${project.name} Copy';
      data['outputName'] = copyName;
      data['savedAt'] = DateTime.now().toIso8601String();
      final draftsRoot = await _klipioDraftsRoot();
      final targetDirectory = await _uniqueKlipioProjectDirectory(
        draftsRoot,
        copyName,
      );
      if (await _isManagedKlipioProjectPath(project.path)) {
        await _copyKlipioProjectDirectory(
          File(project.path).parent,
          targetDirectory,
        );
      } else {
        await targetDirectory.create(recursive: true);
      }
      final target =
          '${targetDirectory.path}${Platform.pathSeparator}$_klipioProjectFileName';
      await _writeKlipioProjectBundleFiles(
        target,
        data,
        createBackup: false,
      );
      await _rememberRecentProject(target);
      await _loadProjects();
      _projectMessage('Duplicated as $copyName.');
    } catch (error) {
      _projectMessage('Could not duplicate project: $error');
    }
  }

  Future<void> _deleteHomeProject(_HomeProject project) async {
    final managedProject = await _isManagedKlipioProjectPath(project.path);
    if (!mounted) return;
    final deleteMessage = managedProject
        ? 'Delete "${project.name}" and its complete Klipio Drafts project folder? Project cache, backups, cover, and resources stored inside that folder will be removed. Original source media outside the project folder and exported files will stay safe.'
        : 'Delete "${project.name}" from Recent Projects and remove its project file? Source videos, audio, and exported files will not be deleted.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const KText('Delete project?'),
        content: KText(deleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const KText('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const KText('Delete project'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final file = File(project.path);
      if (managedProject) {
        final projectDirectory = file.parent;
        if (await projectDirectory.exists()) {
          await projectDirectory.delete(recursive: true);
        }
      } else if (await file.exists()) {
        await file.delete();
      }
      await widget.onProjectDeleted(project.path);
      await _forgetRecentProject(project.path);
      await _loadProjects();
      _projectMessage('Project deleted. Source media was not removed.');
    } catch (error) {
      _projectMessage('Could not delete project: $error');
    }
  }

  Future<void> _openHomeProjectFolder(_HomeProject project) async {
    final folder = File(project.path).parent.path;
    if (!Directory(folder).existsSync()) {
      _projectMessage('The project folder no longer exists.');
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', [folder]);
      } else if (Platform.isMacOS) {
        await Process.start('open', [folder]);
      } else {
        await Process.start('xdg-open', [folder]);
      }
    } catch (error) {
      _projectMessage('Could not open the project folder: $error');
    }
  }

  void _handleHomeProjectAction(
    _HomeProject project,
    _HomeProjectAction action,
  ) {
    switch (action) {
      case _HomeProjectAction.rename:
        unawaited(_renameHomeProject(project));
      case _HomeProjectAction.duplicate:
        unawaited(_duplicateHomeProject(project));
      case _HomeProjectAction.delete:
        unawaited(_deleteHomeProject(project));
      case _HomeProjectAction.openFolder:
        unawaited(_openHomeProjectFolder(project));
    }
  }

  void _showFutureFeature(String title, String description) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.rocket_launch_outlined),
        title: KText(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: KText(
              '$description\n\nThis product screen is ready for a future service integration. No charge will be made.'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const KText('Got it'),
          ),
        ],
      ),
    );
  }

  String _modifiedLabel(DateTime? value) {
    if (value == null) return 'Unavailable';
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${value.month}/${value.day}/${value.year}';
  }
}
