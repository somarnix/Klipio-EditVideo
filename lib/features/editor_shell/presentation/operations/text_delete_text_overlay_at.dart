part of '../editor_application.dart';

// text operations owned by the editor state; extracted without changing timing.
extension _TextDeleteTextOverlayAt on _EditorScreenState {
  void _deleteTextOverlayAt(int index) {
    if (index < 0 || index >= _textOverlays.length) return;
    if (_textOverlays[index].isLocked) {
      _showMessage(
        'Unlock T${_textOverlays[index].trackIndex} before deleting text.',
      );
      return;
    }
    _recordEditorHistory('text-delete');
    _updateEditor(() {
      final removed = _textOverlays.removeAt(index);
      _multiTrackTimeline =
          _timelineEditor.deleteClip(_multiTrackTimeline, removed.id);
      if (_textOverlays.isEmpty) {
        _textOverlays.add(const _TextOverlayDraft());
      }
      _selectedTextOverlayIndex = index.clamp(0, _textOverlays.length - 1);
      _loadTextOverlay(_textOverlays[_selectedTextOverlayIndex]);
      _selectedTimelineClipIds.remove(removed.id);
      _selectedTimelineClipId = null;
      _editorSelection = _videos.isEmpty
          ? const EditorSelection.none()
          : EditorSelection.video(_videos[_selectedVideoIndex].path);
    });
    unawaited(_autosaveProject());
  }
}
