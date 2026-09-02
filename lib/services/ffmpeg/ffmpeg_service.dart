import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/storage/application_paths.dart';

import '../process/windows_process_job.dart';

class FfmpegProcessResult {
  const FfmpegProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  bool get succeeded => exitCode == 0;
}

class FfmpegService {
  const FfmpegService({this.executable = 'ffmpeg'});

  final String executable;

  Future<FfmpegProcessResult> run(
    List<String> arguments, {
    void Function(String line)? onProgressLine,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final process =
        await Process.start(ApplicationPaths.mediaTool(executable), arguments);
    await registerKlipioWorker(process);
    final stdoutBuffer = _BoundedFfmpegBuffer();
    final stderrBuffer = _BoundedFfmpegBuffer();
    final outputDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => stdoutBuffer.writeln(line));
    final errorDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      stderrBuffer.writeln(line);
      onProgressLine?.call(line);
    });
    final exitCode = await Future.any<int>([
      process.exitCode,
      Future<int>.delayed(timeout, () => -1),
    ]);
    if (exitCode == -1) await terminateKlipioWorker(process);
    await Future.wait([outputDone, errorDone])
        .timeout(const Duration(seconds: 3), onTimeout: () => const <void>[]);
    return FfmpegProcessResult(
      exitCode: exitCode,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
    );
  }
}

class _BoundedFfmpegBuffer {
  static const int _limit = 64 * 1024;
  final StringBuffer _buffer = StringBuffer();
  int _length = 0;

  void writeln(Object? value) {
    if (_length >= _limit) return;
    final text = '$value\n';
    final remaining = _limit - _length;
    final accepted =
        text.length <= remaining ? text : text.substring(0, remaining);
    _buffer.write(accepted);
    _length += accepted.length;
  }

  @override
  String toString() => _buffer.toString();
}
