import '../../timeline/application/timeline_editor.dart';
import '../../timeline/domain/timeline_models.dart';

/// A gesture draft bound to a durable revision and clip instance. It is never
/// serialized and never enters export capture. Both canvas and inspector use
/// the normal transform command when the gesture is accepted.
class TransformPreview {
  TimelineModel? _revision;
  String? _clipId;
  ClipTransform? _value;

  bool update(TimelineModel revision, String clipId, ClipTransform value) {
    final target = revision.clipById(clipId);
    if (target == null || target.track.isLocked) return false;
    if (_revision != null &&
        (!identical(revision, _revision) || _clipId != clipId)) {
      discard();
      return false;
    }
    _revision = revision;
    _clipId = clipId;
    _value = value;
    return true;
  }

  ClipTransform? valueFor(TimelineModel revision, String clipId) =>
      identical(revision, _revision) && clipId == _clipId ? _value : null;

  TimelineModel resolve(TimelineModel revision) {
    if (!identical(_revision, revision)) {
      discard();
      return revision;
    }
    if (_clipId == null || _value == null) return revision;
    return const TimelineEditor()
        .updateClipTransform(revision, _clipId!, _value!);
  }

  TimelineModel? accept(TimelineModel revision, String? selectedId) {
    final value = _value;
    final id = _clipId;
    final valid = identical(_revision, revision) &&
        selectedId == id &&
        id != null &&
        value != null;
    discard();
    if (!valid) return null;
    final previous = revision.clipById(id)?.clip.transform;
    if (previous == null) return null;
    final values = value.toJson();
    if (previous
        .toJson()
        .entries
        .every((entry) => values[entry.key] == entry.value)) return null;
    return const TimelineEditor().updateClipTransform(revision, id, value);
  }

  void discard() {
    _revision = null;
    _clipId = null;
    _value = null;
  }
}
