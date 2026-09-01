import '../../../services/tasks/render_task_queue.dart';
import '../domain/export_models.dart';
import '../services/export_service.dart';

class ExportCoordinator {
  ExportCoordinator({RenderTaskQueue? queue})
      : queue = queue ?? RenderTaskQueue();

  final RenderTaskQueue queue;

  Future<ExportResult> enqueue(ExportJob job) =>
      queue.add(() => exportVideo(job));

  Future<ExportResult> enqueueSequence(SequenceExportJob job) =>
      queue.add(() => exportVideoSequence(job));

  Future<ExportResult> enqueueMultiTrack(MultiTrackExportJob job) =>
      queue.add(() => exportMultiTrackTimeline(job));
}
