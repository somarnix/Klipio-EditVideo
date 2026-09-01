import '../../timeline/domain/timeline_models.dart';
import 'project_metadata.dart';

class KlipioProject {
  const KlipioProject({
    required this.metadata,
    required this.timeline,
    this.mediaPaths = const [],
    this.exportSettings = const {},
  });

  final ProjectMetadata metadata;
  final TimelineModel timeline;
  final List<String> mediaPaths;
  final Map<String, Object?> exportSettings;

  KlipioProject copyWith({
    ProjectMetadata? metadata,
    TimelineModel? timeline,
    List<String>? mediaPaths,
    Map<String, Object?>? exportSettings,
  }) =>
      KlipioProject(
        metadata: metadata ?? this.metadata,
        timeline: timeline ?? this.timeline,
        mediaPaths: mediaPaths ?? this.mediaPaths,
        exportSettings: exportSettings ?? this.exportSettings,
      );

  Map<String, Object?> toJson() => {
        'metadata': metadata.toJson(),
        'timeline': timeline.toJson(),
        'mediaPaths': mediaPaths,
        'exportSettings': exportSettings,
      };

  factory KlipioProject.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return KlipioProject(
      metadata: ProjectMetadata.fromJson(json['metadata']),
      timeline: TimelineModel.fromJson(json['timeline']),
      mediaPaths: [
        for (final path in json['mediaPaths'] as List? ?? const []) '$path'
      ],
      exportSettings: Map<String, Object?>.from(
        json['exportSettings'] as Map? ?? const {},
      ),
    );
  }
}
