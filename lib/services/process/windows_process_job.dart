import 'dart:async';
import 'dart:io';
import '../../core/storage/application_paths.dart';

import 'package:flutter/services.dart';
import '../diagnostics/performance_diagnostics.dart';

const MethodChannel _processJobChannel = MethodChannel('klipio/process_job');
final Map<int, Process> _klipioWorkers = <int, Process>{};
final Map<int, Map<String, Object?>> _workerDetails = {};
List<Map<String, Object?>> get klipioWorkerDiagnostics => [
      for (final entry in _workerDetails.entries)
        {'pid': entry.key, ...entry.value},
    ];
Future<void> _processLogQueue = Future<void>.value();

int get activeKlipioWorkerCount => _klipioWorkers.length;

void _logWorker(String message) {
  final line = '${DateTime.now().toIso8601String()} $message\r\n';
  _processLogQueue = _processLogQueue.then((_) async {
    try {
      final directory = ApplicationPaths.logs;
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}${Platform.pathSeparator}worker-processes.log',
      );
      if (await file.exists() && await file.length() > 2 * 1024 * 1024) {
        final previous = File('${file.path}.previous');
        if (await previous.exists()) await previous.delete();
        await file.rename(previous.path);
      }
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Diagnostics must never interfere with editing or worker cleanup.
    }
  });
}

/// Places a heavy worker in Klipio's Windows Job Object.
///
/// Windows closes the job if Klipio exits or crashes, which guarantees that a
/// registered FFmpeg, FFprobe, or caption worker cannot remain orphaned.
Future<void> registerKlipioWorker(
  Process process, {
  String? jobType,
  String? asset,
  String? executable,
}) async {
  _klipioWorkers[process.pid] = process;
  _workerDetails[process.pid] = {
    'jobType': jobType,
    'asset': asset,
    'executable': executable,
    'startedAt': DateTime.now().toIso8601String(),
    'canceling': false,
  };
  _logWorker('[PROCESS] START PID=${process.pid}');
  PerformanceDiagnostics.instance.event('FFMPEG_START', {
    'pid': process.pid,
    'jobType': jobType,
    'source': asset,
    'executable': executable,
  });
  unawaited(process.exitCode.then<void>(
    (code) {
      _klipioWorkers.remove(process.pid);
      _workerDetails.remove(process.pid);
      _logWorker('[PROCESS] EXIT PID=${process.pid} CODE=$code');
      PerformanceDiagnostics.instance
          .event('FFMPEG_END', {'pid': process.pid, 'exitCode': code});
    },
    onError: (Object error, StackTrace _) {
      _klipioWorkers.remove(process.pid);
      _workerDetails.remove(process.pid);
      _logWorker('[PROCESS] EXIT PID=${process.pid} ERROR=$error');
    },
  ));
  if (!Platform.isWindows) return;
  try {
    await _processJobChannel.invokeMethod<void>(
      'registerWorker',
      <String, Object?>{
        'pid': process.pid,
        'background': jobType == 'proxy' ||
            jobType == 'waveform' ||
            jobType == 'thumbnail'
      },
    );
  } on MissingPluginException {
    // Unit tests and non-runner embedders do not install the native channel.
  } on PlatformException {
    // Awaited tree termination remains the fallback if job assignment fails.
  } catch (_) {
    // Headless tests do not initialize Flutter's platform-message binding.
  }
}

/// Terminates one registered worker and its descendants, then waits briefly
/// for the OS to release the process handle.
Future<void> terminateKlipioWorker(Process process) async {
  if (!_klipioWorkers.containsKey(process.pid)) return;
  _workerDetails[process.pid]?['canceling'] = true;
  _logWorker('[PROCESS] TERMINATE PID=${process.pid}');
  if (Platform.isWindows) {
    try {
      await Process.run(
        'taskkill.exe',
        ['/PID', '${process.pid}', '/T', '/F'],
      ).timeout(const Duration(seconds: 4));
    } catch (_) {
      try {
        process.kill();
      } catch (_) {}
    }
  } else {
    try {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(const Duration(seconds: 1));
      return;
    } catch (_) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }
  try {
    await process.exitCode.timeout(const Duration(seconds: 3));
  } catch (_) {
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {}
  }
}

/// Emergency shutdown used by app disposal and fatal operation recovery.
Future<void> terminateAllKlipioWorkers() async {
  final workers = List<Process>.of(_klipioWorkers.values);
  if (workers.isEmpty) return;
  _logWorker('[CLEANUP] terminating ${workers.length} workers');
  await Future.wait<void>(workers.map(terminateKlipioWorker));
  _logWorker('[CLEANUP] ${_klipioWorkers.length} external processes remain');
}
