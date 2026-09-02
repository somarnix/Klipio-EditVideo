part of '../editor_application.dart';

// preview operations owned by the editor state; extracted without changing timing.
extension _PreviewPreviewColorMatrix on _EditorScreenState {
  List<double> _previewColorMatrix() {
    final saturation = _saturation.clamp(0.0, 3.0).toDouble();
    final contrast = _contrast.clamp(0.0, 3.0).toDouble();
    final brightness = (_brightness.clamp(-1.0, 1.0) * 255).toDouble();
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    final sr = (1 - saturation) * r;
    final sg = (1 - saturation) * g;
    final sb = (1 - saturation) * b;
    final offset = 128 * (1 - contrast) + brightness;
    return [
      (sr + saturation) * contrast,
      sg * contrast,
      sb * contrast,
      0,
      offset,
      sr * contrast,
      (sg + saturation) * contrast,
      sb * contrast,
      0,
      offset,
      sr * contrast,
      sg * contrast,
      (sb + saturation) * contrast,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Future<void> _setPreviewSpeed(double value) async {
    final speed = value
        .clamp(_EditorScreenState._minVideoSpeed,
            _EditorScreenState._maxVideoSpeed)
        .toDouble();
    final target = _professionalTargetClip();
    if (target != null) {
      final migrated = ClipSpeedEdit.migrate(_multiTrackTimeline,
          _videoPlaybackSpeedsForExport(_multiTrackTimeline));
      final next = ClipSpeedEdit.apply(migrated, {target.clip.id}, speed);
      if (identical(next, migrated)) return;
      _recordEditorHistory('clip-speed');
      _updateEditor(() {
        _multiTrackTimeline = next;
        _speed = speed;
      });
      // A faster edit can shorten the program under a paused playhead. Reuse
      // the canonical seek queue, never leave source-clock space on the ruler.
      final end = _programPlaybackDurationSeconds();
      if (_liveTimelineSeconds > end) {
        _requestMultiTrackTimelineSeek(end);
      } else {
        _setLiveTimelinePlayhead(_currentProgramSeconds());
      }
      unawaited(_autosaveProject());
    } else {
      if (_hasAuthoritativeProgramTimeline) return;
      _setSelectedTransformEdit((edit) => edit.copyWith(speed: speed));
    }
    final controller = _previewController;
    // Inspector selection is not necessarily the clip currently playing.
    if (target != null && _programTimelineClipId != target.clip.id) return;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setPlaybackSpeed(speed);
      } catch (_) {
        if (!mounted) return;
        _updateEditor(() {
          _status = 'Speed will apply on export. Preview player limited it.';
        });
      }
    }
  }

  double _previewAudioVolume(double value) => value.clamp(0.0, 1.0).toDouble();

  List<_TextOverlayDraft> _previewTextOverlays() {
    final overlays = List<_TextOverlayDraft>.of(_textOverlays);
    if (_selectedTextOverlayIndex >= 0 &&
        _selectedTextOverlayIndex < overlays.length) {
      overlays[_selectedTextOverlayIndex] = _currentTextOverlayDraft();
    }
    return overlays;
  }
}
