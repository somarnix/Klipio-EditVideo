import 'dart:io';

import 'package:path_provider/path_provider.dart' as provider;

/// Installed files are read-only inputs. All generated data is user-owned and
/// survives replacement of a versioned application runtime.
abstract final class ApplicationPaths {
  static Directory get executableDirectory =>
      File(Platform.resolvedExecutable).parent;

  static Directory get installRoot =>
      executableDirectory.parent.uri.pathSegments
                  .where((part) => part.isNotEmpty)
                  .last ==
              'versions'
          ? executableDirectory.parent.parent
          : executableDirectory;

  static String mediaTool(String name) {
    if (!Platform.isWindows || (name != 'ffmpeg' && name != 'ffprobe')) {
      return name;
    }
    for (final relative in ['runtime/media/$name.exe', '$name.exe']) {
      final file = File('${executableDirectory.path}/$relative');
      if (file.existsSync()) return file.path;
    }
    if (File('${executableDirectory.path}/runtime-manifest.json')
        .existsSync()) {
      throw FileSystemException(
          'Installed media runtime is missing; repair Klipio.',
          '${executableDirectory.path}/runtime/media/$name.exe');
    }
    // Developer/non-bundled execution only. Production staging validates both.
    return name;
  }

  static Directory _local(String folder) {
    final local = Platform.environment['LOCALAPPDATA'];
    final base = Platform.isWindows && local != null
        ? '$local/Klipio'
        : '${Directory.systemTemp.path}/Klipio';
    return Directory('$base/$folder')..createSync(recursive: true);
  }

  static Directory get cache => _local('Cache');
  static Directory get temporary => _local('Temp');
  static Directory get logs => _local('Logs');
  static Directory get diagnostics => _local('diagnostics');

  static File get installerLanguage => File(
      '${Platform.environment['APPDATA'] ?? temporary.path}/Klipio/klipio-language.txt');

  /// Company metadata changed from the Flutter template to Somarnix. Preserve
  /// the old plugin preference store once, without overwriting newer settings.
  static Future<void> migrateLegacyPreferences() async {
    if (!Platform.isWindows) return;
    // Test hosts and Dart tools must never migrate the logged-in user's store.
    if (!Platform.resolvedExecutable.toLowerCase().endsWith('klipio.exe')) {
      return;
    }
    final roaming = Platform.environment['APPDATA'];
    if (roaming == null) return;
    final legacy = File('$roaming/com.example/Klipio/shared_preferences.json');
    if (!await legacy.exists()) return;
    final destination = await provider.getApplicationSupportDirectory();
    final target = File('${destination.path}/shared_preferences.json');
    if (!await target.exists()) {
      if (await legacy.exists() && legacy.path != target.path) {
        await destination.create(recursive: true);
        await legacy.copy(target.path);
      }
    }
  }
}

Future<Directory> getTemporaryDirectory() async => Platform.isWindows
    ? ApplicationPaths.temporary
    : await provider.getTemporaryDirectory();

Future<Directory> getCacheDirectory() async => Platform.isWindows
    ? ApplicationPaths.cache
    : await provider.getTemporaryDirectory();

Future<Directory> getApplicationSupportDirectory() =>
    provider.getApplicationSupportDirectory();

Future<Directory> getApplicationDocumentsDirectory() =>
    provider.getApplicationDocumentsDirectory();
