import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

String _newId() =>
    'caption-${List.generate(16, (_) => Random.secure().nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
String _id(Object? value, String seed) => value is String && value.isNotEmpty
    ? value
    : 'legacy-${sha256.convert(utf8.encode(seed))}';
double? _number(Object? value) {
  final result = double.tryParse('$value');
  return result != null && result.isFinite ? result : null;
}

Object? _freeze(Object? value) => value is Map
    ? Map<String, Object?>.unmodifiable(
        value.map((k, v) => MapEntry('$k', _freeze(v))))
    : value is List
        ? List<Object?>.unmodifiable(value.map(_freeze))
        : value;
Map<String, Object?> _extra(Map json, Set<String> keys) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in json.entries)
        if (!keys.contains(entry.key)) '${entry.key}': _freeze(entry.value)
    });

/// Editable caption identity, independent of text, timing and derived rasters.
/// Unknown JSON fields (style, speaker, animation and range metadata) survive
/// load/edit/save, without making unsupported metadata a rendering promise.
class EditableCaptionWord {
  EditableCaptionWord(
      {String? id,
      required this.start,
      required this.end,
      required this.text,
      Map<String, Object?> metadata = const {}})
      : id = id ?? _newId(),
        metadata = _extra(metadata, const {});
  final String id, text;
  final double start, end;
  final Map<String, Object?> metadata;
  EditableCaptionWord copyWith(
          {String? id, double? start, double? end, String? text}) =>
      EditableCaptionWord(
          id: id ?? this.id,
          start: start ?? this.start,
          end: end ?? this.end,
          text: text ?? this.text,
          metadata: metadata);
  Map<String, Object?> toJson() =>
      {...metadata, 'id': id, 'start': start, 'end': end, 'text': text};
  factory EditableCaptionWord.fromJson(Map json,
          {required String migrationKey}) =>
      EditableCaptionWord(
          id: _id(json['id'], migrationKey),
          start: _number(json['start'])!,
          end: _number(json['end'])!,
          text: '${json['text'] ?? ''}',
          metadata: _extra(json, const {'id', 'start', 'end', 'text'}));
}

class EditableCaptionCue {
  EditableCaptionCue(
      {String? id,
      required this.start,
      required this.end,
      required this.text,
      List<EditableCaptionWord> words = const [],
      this.x = .5,
      this.y = .78,
      Map<String, Object?> metadata = const {}})
      : id = id ?? _newId(),
        words = List.unmodifiable(words),
        metadata = _extra(metadata, const {});
  final String id, text;
  final double start, end, x, y;
  final List<EditableCaptionWord> words;
  final Map<String, Object?> metadata;
  EditableCaptionCue copyWith(
          {String? id,
          double? start,
          double? end,
          String? text,
          List<EditableCaptionWord>? words,
          double? x,
          double? y}) =>
      EditableCaptionCue(
          id: id ?? this.id,
          start: start ?? this.start,
          end: end ?? this.end,
          text: text ?? this.text,
          words: words ?? this.words,
          x: x ?? this.x,
          y: y ?? this.y,
          metadata: metadata);
  Map<String, Object?> toJson() => {
        ...metadata,
        'id': id,
        'start': start,
        'end': end,
        'text': text,
        'x': x,
        'y': y,
        'words': words.map((w) => w.toJson()).toList()
      };
  factory EditableCaptionCue.fromJson(Map json,
      {required String migrationKey}) {
    final id = _id(json['id'], migrationKey);
    return EditableCaptionCue(
        id: id,
        start: _number(json['start'])!,
        end: _number(json['end'])!,
        text: '${json['text'] ?? ''}',
        x: (double.tryParse('${json['x']}') ?? .5).clamp(0, 1),
        y: (double.tryParse('${json['y']}') ?? .78).clamp(0, 1),
        words: [
          for (final entry in (json['words'] as List? ?? const []).indexed)
            if (entry.$2 is Map &&
                _number(entry.$2['start']) != null &&
                _number(entry.$2['end']) != null)
              EditableCaptionWord.fromJson(entry.$2 as Map,
                  migrationKey: '$id/word/${entry.$1}')
        ],
        metadata: _extra(
            json, const {'id', 'start', 'end', 'text', 'x', 'y', 'words'}));
  }
}
