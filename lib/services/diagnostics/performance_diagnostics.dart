import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/storage/application_paths.dart';

/// Lightweight opt-in diagnostics for manual Windows performance sessions.
/// It is completely disabled in release/profile builds unless explicitly
/// enabled with `--dart-define=KLIPIO_PERF_DIAGNOSTICS=true`.
class PerformanceDiagnostics {
  PerformanceDiagnostics._();
  static final PerformanceDiagnostics instance = PerformanceDiagnostics._();
  bool get enabled =>
      kDebugMode ||
      const bool.fromEnvironment('KLIPIO_PERF_DIAGNOSTICS',
          defaultValue: false);
  IOSink? _sink;
  Timer? _sampler;
  String? path;

  Future<void> start() async {
    if (!enabled || _sink != null) return;
    final dir = ApplicationPaths.diagnostics;
    await dir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    path =
        '${dir.path}${Platform.pathSeparator}performance-session-$stamp.jsonl';
    _sink = File(path!).openWrite(mode: FileMode.append);
    event('APP_START', {'pid': pid});
    _sampler =
        Timer.periodic(const Duration(milliseconds: 500), (_) => _sample());
  }

  void event(String name, [Map<String, Object?> data = const {}]) {
    final sink = _sink;
    if (sink == null) return;
    sink.writeln(jsonEncode(
        {'ts': DateTime.now().toIso8601String(), 'event': name, ...data}));
  }

  Future<void> _sample() async {
    final rss = ProcessInfo.currentRss;
    final workers = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      "(Get-Process -Id $pid -ErrorAction SilentlyContinue | Select-Object CPU,WorkingSet64,Threads).CPU"
    ]);
    event('RESOURCE_SAMPLE',
        {'rssBytes': rss, 'cpuSeconds': '${workers.stdout}'.trim()});
  }

  Future<void> close() async {
    if (_sink == null) return;
    event('SHUTDOWN_COMPLETE');
    _sampler?.cancel();
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
