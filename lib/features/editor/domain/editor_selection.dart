enum EditorSelectionKind {
  none,
  videoClip,
  audioClip,
  textLayer,
  captionCue,
  transition
}

class EditorSelection {
  const EditorSelection.none()
      : kind = EditorSelectionKind.none,
        id = '',
        label = 'Details';

  const EditorSelection.video(this.id)
      : kind = EditorSelectionKind.videoClip,
        label = 'Video Clip';

  const EditorSelection.audio(this.id)
      : kind = EditorSelectionKind.audioClip,
        label = 'Audio Clip';

  const EditorSelection.text(this.id, {this.label = 'Text Layer'})
      : kind = EditorSelectionKind.textLayer;

  const EditorSelection.caption(this.id, {this.label = 'Caption Cue'})
      : kind = EditorSelectionKind.captionCue;

  // The incoming clip owns the transition. No second clip-selection authority.
  const EditorSelection.transition(this.id)
      : kind = EditorSelectionKind.transition,
        label = 'Transition';

  final EditorSelectionKind kind;
  final String id;
  final String label;
}
