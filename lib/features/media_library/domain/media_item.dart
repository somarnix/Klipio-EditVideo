import '../../media/domain/media_asset.dart';

class MediaItem {
  const MediaItem({
    required this.asset,
    this.thumbnailPath,
    this.proxyPath,
    this.selected = false,
  });

  final MediaAsset asset;
  final String? thumbnailPath;
  final String? proxyPath;
  final bool selected;

  String get id => asset.path;

  MediaItem copyWith({
    MediaAsset? asset,
    String? thumbnailPath,
    String? proxyPath,
    bool? selected,
  }) =>
      MediaItem(
        asset: asset ?? this.asset,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        proxyPath: proxyPath ?? this.proxyPath,
        selected: selected ?? this.selected,
      );
}
