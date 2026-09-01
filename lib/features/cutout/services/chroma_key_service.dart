class ChromaKeySettings {
  const ChromaKeySettings({
    this.color = '0x00FF00',
    this.similarity = 0.2,
    this.blend = 0.08,
  });

  final String color;
  final double similarity;
  final double blend;
}

class ChromaKeyService {
  const ChromaKeyService();

  String buildFilter(ChromaKeySettings settings) =>
      'chromakey=${settings.color}:'
      '${settings.similarity.clamp(0.01, 1).toStringAsFixed(3)}:'
      '${settings.blend.clamp(0, 1).toStringAsFixed(3)}';
}
