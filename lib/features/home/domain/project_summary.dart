class ProjectSummary {
  const ProjectSummary({
    required this.name,
    required this.projectPath,
    required this.updatedAt,
    this.thumbnailPath,
    this.mediaCount = 0,
    this.duration = Duration.zero,
  });

  final String name;
  final String projectPath;
  final DateTime updatedAt;
  final String? thumbnailPath;
  final int mediaCount;
  final Duration duration;
}
