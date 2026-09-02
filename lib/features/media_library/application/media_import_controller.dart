import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../media/data/media_probe_repository.dart';
import '../domain/media_item.dart';

class MediaImportController extends ChangeNotifier {
  MediaImportController({MediaProbeRepository? probe})
      : probe = probe ?? const MediaProbeRepository();

  final MediaProbeRepository probe;
  final List<MediaItem> _items = [];
  bool _importing = false;
  String? _error;

  List<MediaItem> get items => List.unmodifiable(_items);
  bool get importing => _importing;
  String? get error => _error;

  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.video,
    );
    await importPaths([
      for (final file in result?.files ?? const <PlatformFile>[])
        if (file.path != null) file.path!,
    ]);
  }

  Future<void> pickFolder() async {
    final folder = await FilePicker.platform.getDirectoryPath();
    if (folder == null) return;
    _error = 'Folder scanning is delegated to the platform media service.';
    notifyListeners();
  }

  Future<void> importPaths(Iterable<String> paths) async {
    final unique =
        paths.map((path) => path.trim()).where((path) => path.isNotEmpty);
    _importing = true;
    _error = null;
    notifyListeners();
    try {
      for (final path in unique) {
        if (_items.any((item) => item.asset.path == path)) continue;
        try {
          _items.add(MediaItem(asset: await probe.probe(path)));
          notifyListeners();
        } catch (error) {
          _error = 'Could not import $path: $error';
        }
      }
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  void select(String id, {bool toggle = false}) {
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      _items[index] = item.copyWith(
        selected: item.id == id
            ? (toggle ? !item.selected : true)
            : (toggle ? item.selected : false),
      );
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}
