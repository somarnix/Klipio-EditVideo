import '../../timeline/application/timeline_editor.dart';
import '../../timeline/domain/timeline_models.dart';

/// A validated all-or-nothing edit; history/save are driven only after success.
class EffectEdit {
  EffectEdit._(this.before, this.after);
  final TimelineModel before, after;
  static EffectEdit? apply(
      TimelineModel model, Map<String, List<ClipEffect>> additions) {
    if (additions.isEmpty) return null;
    for (final entry in additions.entries) {
      final target = model.clipById(entry.key);
      if (target == null ||
          target.track.type != TrackType.video ||
          target.track.isLocked ||
          entry.value.isEmpty) return null;
      final ids = target.clip.effects.map((e) => e.id).toSet();
      for (final effect in entry.value) {
        if (effect.id.isEmpty ||
            !effect.amount.isFinite ||
            effect.amount < -1 ||
            effect.amount > 3 ||
            !ids.add(effect.id)) {
          return null;
        }
      }
    }
    var next = model;
    for (final entry in additions.entries) {
      for (final effect in entry.value) {
        next = const TimelineEditor().addClipEffect(next, entry.key, effect);
      }
    }
    return EffectEdit._(model, next);
  }

  static EffectEdit? change(TimelineModel model, String clipId, String effectId,
      {double? amount, bool? enabled, bool remove = false}) {
    final target = model.clipById(clipId);
    if (target == null ||
        target.track.type != TrackType.video ||
        target.track.isLocked ||
        (amount != null && (!amount.isFinite || amount < -1 || amount > 3))) {
      return null;
    }
    final found = target.clip.effects.where((e) => e.id == effectId).toList();
    if (found.length != 1) return null;
    final old = found.single;
    if (!remove &&
        (amount == null || amount == old.amount) &&
        (enabled == null || enabled == old.enabled)) return null;
    final next = remove
        ? const TimelineEditor().removeClipEffect(model, clipId, effectId)
        : const TimelineEditor().updateClipEffect(model, clipId, effectId,
            (e) => e.copyWith(amount: amount, enabled: enabled));
    return EffectEdit._(model, next);
  }
}

/// Browser-only overlay. Tokens bind to an exact clip instance/revision, not a path.
class EffectPreview {
  int _generation = 0;
  EffectPreviewToken? _token;
  List<ClipEffect> _effects = const [];
  EffectPreviewToken? begin(TimelineModel model, String clipId) {
    discard();
    final target = model.clipById(clipId);
    if (target == null ||
        target.track.isLocked ||
        target.track.type != TrackType.video) return null;
    return _token = EffectPreviewToken._(_generation, target.clip);
  }

  bool complete(
      EffectPreviewToken token, TimelineModel model, List<ClipEffect> effects) {
    if (!identical(token, _token) ||
        token.generation != _generation ||
        !identical(model.clipById(token.clip.id)?.clip, token.clip) ||
        model.clipById(token.clip.id)?.track.isLocked != false ||
        effects.any((e) => !e.amount.isFinite)) return false;
    _effects = List.unmodifiable(effects);
    return true;
  }

  void discard() {
    _generation++;
    _token = null;
    _effects = const [];
  }

  void validate(TimelineModel model) {
    final token = _token;
    if (token != null &&
        (!identical(model.clipById(token.clip.id)?.clip, token.clip) ||
            model.clipById(token.clip.id)?.track.isLocked != false)) discard();
  }

  TimelineModel resolve(TimelineModel model) {
    validate(model);
    final token = _token;
    if (token == null || _effects.isEmpty) return model;
    return model.copyWith(tracks: [
      for (final track in model.tracks)
        track.copyWith(clips: [
          for (final clip in track.clips)
            if (clip.id == token.clip.id)
              clip.copyWith(effects: [...clip.effects, ..._effects])
            else
              clip
        ])
    ]);
  }
}

class EffectPreviewToken {
  EffectPreviewToken._(this.generation, this.clip);
  final int generation;
  final ClipModel clip;
}
