import 'dart:convert';
import 'dart:io';

/// Startup instructions written by the local Video Edit Operator.
///
/// The editor intentionally accepts a file on disk instead of opening a
/// network port. This keeps the automation local, inspectable, and easy to
/// recover if either Klipio or CapCut is closed during a job.
class KlipioAutomationJob {
  const KlipioAutomationJob({
    required this.jobPath,
    required this.sourceMode,
    required this.sourcePath,
    required this.outputFolder,
    required this.outputRatio,
    required this.originalVolume,
    required this.musicVolume,
    required this.hookMode,
    required this.hookLength,
    required this.createCapCutDraft,
    required this.renderEdits,
    required this.capCutOneFolder,
    required this.resultPath,
    this.musicPath,
  });

  final String jobPath;
  final String sourceMode;
  final String sourcePath;
  final String outputFolder;
  final String outputRatio;
  final double originalVolume;
  final double musicVolume;
  final String? musicPath;
  final String hookMode;
  final String hookLength;
  final bool createCapCutDraft;
  final bool renderEdits;
  final bool capCutOneFolder;
  final String resultPath;

  static KlipioAutomationJob? fromCommandLine(List<String> args) {
    final index = args.indexOf('--automation-job');
    if (index < 0 || index + 1 >= args.length) return null;
    final jobPath = File(args[index + 1]).absolute.path;
    final file = File(jobPath);
    if (!file.existsSync()) {
      throw FileSystemException('Automation job does not exist.', jobPath);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('Automation job must be a JSON object.');
    }
    final data = Map<String, dynamic>.from(decoded);
    final source =
        Map<String, dynamic>.from(data['source'] as Map? ?? const {});
    final edit = Map<String, dynamic>.from(data['edit'] as Map? ?? const {});
    final capCut =
        Map<String, dynamic>.from(data['capcut'] as Map? ?? const {});
    final outputFolder = '${data['outputFolder'] ?? ''}'.trim();
    final resultPath = '${data['resultPath'] ?? '$jobPath.result.json'}'.trim();
    return KlipioAutomationJob(
      jobPath: jobPath,
      sourceMode: '${source['mode'] ?? 'file'}'.trim().toLowerCase(),
      sourcePath: '${source['path'] ?? ''}'.trim(),
      outputFolder: outputFolder,
      outputRatio: '${edit['outputRatio'] ?? 'original'}'.trim(),
      originalVolume: _doubleValue(edit['originalVolume'], 1),
      musicVolume: _doubleValue(edit['musicVolume'], 0.7),
      musicPath: _optionalText(edit['musicPath']),
      hookMode: '${edit['hookMode'] ?? 'none'}'.trim(),
      hookLength: '${edit['hookLength'] ?? 'auto'}'.trim(),
      createCapCutDraft: capCut['createDraft'] as bool? ?? true,
      renderEdits: capCut['renderEdits'] as bool? ?? true,
      capCutOneFolder: capCut['oneFolder'] as bool? ?? false,
      resultPath: resultPath,
    );
  }

  Future<void> writeResult(
    String status, {
    String? message,
    String? draftFolder,
  }) async {
    final target = File(resultPath);
    await target.parent.create(recursive: true);
    await target.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'jobPath': jobPath,
        'status': status,
        'message': message ?? '',
        'draftFolder': draftFolder,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }
}

double _doubleValue(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

String? _optionalText(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
