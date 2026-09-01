class ProjectMetadata {
  const ProjectMetadata({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.width = 1920,
    this.height = 1080,
    this.frameRate = 30,
    this.schemaVersion = 2,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int width;
  final int height;
  final double frameRate;
  final int schemaVersion;

  String get aspectRatio => '$width:$height';

  ProjectMetadata copyWith({
    String? name,
    DateTime? updatedAt,
    int? width,
    int? height,
    double? frameRate,
  }) =>
      ProjectMetadata(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        width: width ?? this.width,
        height: height ?? this.height,
        frameRate: frameRate ?? this.frameRate,
        schemaVersion: schemaVersion,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'width': width,
        'height': height,
        'frameRate': frameRate,
        'schemaVersion': schemaVersion,
      };

  factory ProjectMetadata.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    final now = DateTime.now();
    return ProjectMetadata(
      id: '${json['id'] ?? now.microsecondsSinceEpoch}',
      name: '${json['name'] ?? 'Untitled Project'}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? now,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? now,
      width: int.tryParse('${json['width'] ?? 1920}') ?? 1920,
      height: int.tryParse('${json['height'] ?? 1080}') ?? 1080,
      frameRate: double.tryParse('${json['frameRate'] ?? 30}') ?? 30,
      schemaVersion: int.tryParse('${json['schemaVersion'] ?? 1}') ?? 1,
    );
  }
}
