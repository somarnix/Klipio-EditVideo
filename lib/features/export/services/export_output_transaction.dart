import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/export_models.dart';

// Only publication is serialized. Concurrent renderers keep unique staging.
// Windows can reject overlapping replacements of the same destination.
// The queue is established when a job reaches the commit path; therefore
// publication order is explicit FIFO (commit-enqueue order), independent of
// which renderer finished preparation first. A canceled/failed job never
// publishes and cannot displace the last valid destination.
final _publicationTails = <String, Future<void>>{};
Future<bool> _publish(
    File pending, File destination, ExportCancelToken? token) async {
  final normalized = destination.absolute.uri.normalizePath().toFilePath();
  final key = Platform.isWindows ? normalized.toLowerCase() : normalized;
  final previous = _publicationTails[key];
  final done = Completer<void>();
  _publicationTails[key] = done.future;
  try {
    if (previous != null) await previous;
    if (token?.isCanceled == true) return false;
    await pending.rename(destination.path);
    return true;
  } finally {
    done.complete();
    if (identical(_publicationTails[key], done.future)) {
      _publicationTails.remove(key);
    }
  }
}

/// The renderer owns only a unique sibling staging directory, never the user's
/// destination. Rename publishes on the same filesystem without delete-first.
Future<ExportResult> exportOutputTransaction({
  required String outputPath,
  required Future<ExportResult> Function(String stagingPath) render,
  required Future<bool> Function(String stagingPath) validate,
  ExportCancelToken? cancelToken,
}) async {
  Directory? staging;
  try {
    if (cancelToken?.isCanceled == true) {
      return const ExportResult(success: false, message: 'Export canceled.');
    }
    final destination = File(outputPath).absolute;
    await destination.parent.create(recursive: true);
    staging = await destination.parent.createTemp('.klipio-export-');
    final name = destination.uri.pathSegments.last;
    final pending = File('${staging.path}${Platform.pathSeparator}$name');
    final result = await render(pending.path);
    if (cancelToken?.isCanceled == true) {
      return const ExportResult(success: false, message: 'Export canceled.');
    }
    if (!result.success) return result;
    if (!await pending.exists() ||
        await pending.length() == 0 ||
        !await validate(pending.path)) {
      return const ExportResult(
          success: false,
          message:
              'Export output verification failed; previous output preserved.');
    }
    if (cancelToken?.isCanceled == true) {
      return const ExportResult(success: false, message: 'Export canceled.');
    }
    // This is the commit point. No delete/copy fallback: failure preserves the
    // old destination. Cancellation after commit cannot roll back publication.
    if (!await _publish(pending, destination, cancelToken)) {
      return const ExportResult(success: false, message: 'Export canceled.');
    }
    return ExportResult(
        success: true, message: result.message, outputPath: outputPath);
  } catch (error) {
    return ExportResult(
        success: false,
        message: 'Export stopped safely; previous output preserved: $error');
  } finally {
    if (staging != null) {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } on FileSystemException catch (error) {
        debugPrint('Export staging cleanup failed: $error');
      }
    }
  }
}
