class FilterPreset {
  const FilterPreset({
    required this.id,
    required this.name,
    this.category = 'General',
    this.lutPath,
    this.values = const {},
  });

  final String id;
  final String name;
  final String category;
  final String? lutPath;
  final Map<String, double> values;
}
