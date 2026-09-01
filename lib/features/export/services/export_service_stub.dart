import '../domain/export_models.dart';

Future<bool> isExportAvailable() async => false;

Future<ExportResult> exportVideo(ExportJob job) async {
  return const ExportResult(
    success: false,
    message: 'Export is not available on this platform yet.',
  );
}

Future<ExportResult> exportMultiTrackTimeline(MultiTrackExportJob job) async {
  return const ExportResult(
    success: false,
    message: 'Multi-track export is not supported on this platform.',
  );
}

Future<ExportResult> generateCaptionPreview(ExportJob job) async {
  return const ExportResult(
    success: false,
    message: 'Caption preview is not available on this platform yet.',
  );
}

Future<ExportResult> exportCaptionAudioSequence({
  required List<CaptionAudioSegment> segments,
  required String outputPath,
  void Function(double progress, String status)? onProgress,
  ExportCancelToken? cancelToken,
}) async {
  return const ExportResult(
    success: false,
    message: 'Caption audio preparation is not available on this platform.',
  );
}

Future<ExportResult> exportVideoSequence(SequenceExportJob job) async {
  return const ExportResult(
    success: false,
    message: 'Sequence export is not available on this platform yet.',
  );
}
