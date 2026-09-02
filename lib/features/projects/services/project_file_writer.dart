import 'dart:async';
import 'dart:io';

/// Serializes bundle transactions; a failed save must not poison later saves.
class ProjectWriteQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

/// Writes beside the destination, then replaces it only after the data flush.
/// Never deletes the existing destination as a fallback if rename fails.
Future<void> replaceProjectFile(File destination, String contents) async {
  final staging =
      await Directory(destination.parent.path).createTemp('.klipio-save-');
  final temporary =
      File('${staging.path}${Platform.pathSeparator}pending.json');
  try {
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(destination.path);
  } finally {
    // Only our uniquely created staging directory is disposable.
    if (await temporary.exists()) await temporary.delete();
    await staging.delete();
  }
}
