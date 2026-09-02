import 'dart:async';

import '../../export/domain/export_models.dart';
import '../services/caption_service_io.dart';

class AiCaptionGenerator {
  const AiCaptionGenerator();

  Future<String> generate(
    ExportJob editedRangeJob, {
    void Function(double progress, String status)? onProgress,
  }) {
    return generateAutomaticCaptionAss(
      editedRangeJob,
      onProgress: onProgress,
    );
  }
}
