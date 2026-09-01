class CaptionWord {
  const CaptionWord(
      {required this.text, required this.start, required this.end});

  final String text;
  final double start;
  final double end;

  Map<String, Object?> toJson() => {'text': text, 'start': start, 'end': end};

  factory CaptionWord.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return CaptionWord(
      text: '${json['text'] ?? ''}',
      start: double.tryParse('${json['start'] ?? 0}') ?? 0,
      end: double.tryParse('${json['end'] ?? 0}') ?? 0,
    );
  }
}

class CaptionCue {
  const CaptionCue({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
    this.words = const [],
  });

  final String id;
  final double start;
  final double end;
  final String text;
  final List<CaptionWord> words;

  double get duration => end - start;

  CaptionCue copyWith({double? start, double? end, String? text}) => CaptionCue(
        id: id,
        start: start ?? this.start,
        end: end ?? this.end,
        text: text ?? this.text,
        words: words,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'text': text,
        'words': [for (final word in words) word.toJson()],
      };

  factory CaptionCue.fromJson(Object? value) {
    final json = value is Map ? value : const {};
    return CaptionCue(
      id: '${json['id'] ?? ''}',
      start: double.tryParse('${json['start'] ?? 0}') ?? 0,
      end: double.tryParse('${json['end'] ?? 0}') ?? 0,
      text: '${json['text'] ?? ''}',
      words: [
        for (final word in json['words'] as List? ?? const [])
          CaptionWord.fromJson(word),
      ],
    );
  }
}
