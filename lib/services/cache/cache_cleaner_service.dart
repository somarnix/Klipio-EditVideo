import 'dart:io';

class CacheCleanResult {
  const CacheCleanResult({required this.files, required this.bytes});

  final int files;
  final int bytes;
}

class CacheCleanerService {
  const CacheCleanerService();

  Future<CacheCleanResult> clear(Iterable<Directory> directories) async {
    var files = 0;
    var bytes = 0;
    for (final directory in directories) {
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) continue;
        try {
          bytes += await entity.length();
          await entity.delete();
          files++;
        } catch (_) {
          // A renderer may still own this cache entry; leave it for next pass.
        }
      }
    }
    return CacheCleanResult(files: files, bytes: bytes);
  }
}
