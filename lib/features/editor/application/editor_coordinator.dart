import '../domain/editor_selection.dart';
import 'editor_controller.dart';

/// Coordinates selections between timeline, preview, left dock and inspector.
class EditorCoordinator {
  const EditorCoordinator(this.controller);

  final EditorController controller;

  void selectVideo(String clipId) =>
      controller.select(EditorSelection.video(clipId));
  void selectAudio(String clipId) =>
      controller.select(EditorSelection.audio(clipId));
  void selectText(String clipId) =>
      controller.select(EditorSelection.text(clipId));
  void selectCaption(String cueId) =>
      controller.select(EditorSelection.caption(cueId));
  void clearSelection() => controller.select(const EditorSelection.none());
}
