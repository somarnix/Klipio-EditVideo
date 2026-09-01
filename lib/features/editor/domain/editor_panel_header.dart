class EditorPanelHeaderModel {
  const EditorPanelHeaderModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.closable = true,
  });

  final String id;
  final String title;
  final String? subtitle;
  final bool closable;
}
