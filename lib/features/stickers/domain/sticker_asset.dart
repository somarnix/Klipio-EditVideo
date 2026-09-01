enum StickerType { image, animatedImage, video }

class StickerAsset {
  const StickerAsset({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.type,
    this.category = 'General',
  });

  final String id;
  final String name;
  final String assetPath;
  final StickerType type;
  final String category;
}
