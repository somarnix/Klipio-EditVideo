import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/storage/application_paths.dart';

import '../process/windows_process_job.dart';

class FfmpegRunResult {
  const FfmpegRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.elapsed,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration elapsed;

  bool get succeeded => exitCode == 0;
}

/// Runs one FFmpeg process with bounded logs and complete tree cancellation.
class FfmpegProcessRunner {
  FfmpegProcessRunner({this.executable = 'ffmpeg'});

  final String executable;
  Process? _activeProcess;

  bool get isRunning => _activeProcess != null;

  Future<FfmpegRunResult> run(
    List<String> arguments, {
    Duration timeout = const Duration(minutes: 30),
    void Function(String line)? onProgressLine,
  }) async {
    if (_activeProcess != null) {
      throw StateError('This FFmpeg runner already owns a process.');
    }
    final stopwatch = Stopwatch()..start();
    final process =
        await Process.start(ApplicationPaths.mediaTool(executable), arguments);
    _activeProcess = process;
    await registerKlipioWorker(process);
    final stdoutBuffer = _BoundedOutput();
    final stderrBuffer = _BoundedOutput();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach(stdoutBuffer.add);
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      stderrBuffer.add(line);
      onProgressLine?.call(line);
    });

    var exitCode = -1;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      await terminateKlipioWorker(process);
    } finally {
      await Future.wait<void>([stdoutDone, stderrDone]).timeout(
        const Duration(seconds: 3),
        onTimeout: () => const <void>[],
      );
      _activeProcess = null;
      stopwatch.stop();
    }
    return FfmpegRunResult(
      exitCode: exitCode,
      stdout: stdoutBuffer.value,
      stderr: stderrBuffer.value,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<void> cancel() async {
    final process = _activeProcess;
    if (process != null) await terminateKlipioWorker(process);
  }
}

class _BoundedOutput {
  static const int _maximumCharacters = 64 * 1024;
  final StringBuffer _buffer = StringBuffer();
  int _length = 0;

  String get value => _buffer.toString();

  void add(String line) {
    if (_length >= _maximumCharacters) return;
    final value = '$line\n';
    final remaining = _maximumCharacters - _length;
    final accepted =
        value.length <= remaining ? value : value.substring(0, remaining);
    _buffer.write(accepted);
    _length += accepted.length;
  }
}
