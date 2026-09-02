import '../../timeline/application/timeline_editor.dart';
import '../../timeline/domain/timeline_models.dart';

class TransitionEdit {
  TransitionEdit._(this.before, this.after);
  final TimelineModel before, after;
  static TransitionEdit? prepare(
      TimelineModel model, String clipId, ClipTransition? value) {
    final next = const TimelineEditor().setClipTransition(model, clipId, value);
    return identical(next, model) ? null : TransitionEdit._(model, next);
  }
}

/// Full source revision is the token: moving either side invalidates a join preview.
class TransitionPreview {
  TransitionPreviewToken? _token;
  TimelineModel? _visual;
  TransitionPreviewToken begin(TimelineModel model, String clipId) {
    discard();
    return _token = TransitionPreviewToken._(model, clipId);
  }

  bool complete(TransitionPreviewToken token, TimelineModel current,
      ClipTransition value) {
    if (!identical(token, _token) || !identical(current, token.model)) {
      return false;
    }
    final edit = TransitionEdit.prepare(current, token.clipId, value);
    if (edit == null) {
      return false;
    }
    _visual = edit.after;
    return true;
  }

  TimelineModel resolve(TimelineModel model) {
    if (!identical(_token?.model, model)) discard();
    return _visual ?? model;
  }

  void discard() {
    _token = null;
    _visual = null;
  }
}

class TransitionPreviewToken {
  TransitionPreviewToken._(this.model, this.clipId);
  final TimelineModel model;
  final String clipId;
}
