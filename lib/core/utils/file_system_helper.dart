import 'dart:io';

abstract final class FileSystemHelper {
  static Future<Directory> ensureDirectory(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<bool> isWritableDirectory(String path) async {
    try {
      final directory = await ensureDirectory(path);
      final probe =
          File('${directory.path}${Platform.pathSeparator}.write-test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static bool isDriveAvailable(String path) {
    if (!Platform.isWindows || path.length < 3 || path[1] != ':') return true;
    return Directory(path.substring(0, 3)).existsSync();
  }

  static String join(String first, String second) {
    final separator = Platform.pathSeparator;
    return '${first.replaceAll(RegExp(r'[\\/]+$'), '')}$separator'
        '${second.replaceAll(RegExp(r'^[\\/]+'), '')}';
  }
}
