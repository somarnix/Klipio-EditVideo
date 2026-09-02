part of 'capcut_draft_service.dart';

Future<void> _registerDraft({
  required String draftRoot,
  required String draftFolder,
  required String draftId,
  required String projectName,
  required int durationUs,
  required int materialsSize,
  required int nowUs,
}) async {
  final metaPath = _rootMetaPath();
  if (metaPath == null) return;
  final file = File(metaPath);
  Map<String, Object?> rootMeta;
  if (await file.exists()) {
    final raw = await file.readAsString();
    rootMeta = _decodeJsonObject(raw) ??
        {'all_draft_store': [], 'draft_ids': 0, 'root_path': draftRoot};
    await file.copy('$metaPath.bak.${DateTime.now().millisecondsSinceEpoch}');
  } else {
    await file.parent.create(recursive: true);
    rootMeta = {'all_draft_store': [], 'draft_ids': 0, 'root_path': draftRoot};
  }
  final drafts = (rootMeta['all_draft_store'] as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .where((item) => item['draft_id'] != draftId)
      .toList();
  drafts.insert(0, {
    'cloud_draft_cover': false,
    'cloud_draft_sync': false,
    'draft_cloud_last_action_download': false,
    'draft_cloud_purchase_info': '',
    'draft_cloud_template_id': '',
    'draft_cloud_tutorial_info': '',
    'draft_cloud_videocut_purchase_info': '',
    'draft_cover': '',
    'draft_fold_path': _jsonPath(draftFolder),
    'draft_id': draftId,
    'draft_is_ai_shorts': false,
    'draft_is_cloud_temp_draft': false,
    'draft_is_invisible': false,
    'draft_is_web_article_video': false,
    'draft_json_file': '${_jsonPath(draftFolder)}/draft_content.json',
    'draft_name': projectName,
    'draft_new_version': '',
    'draft_root_path': draftRoot,
    'draft_timeline_materials_size': materialsSize,
    'draft_type': '',
    'draft_web_article_video_enter_from': '',
    'streaming_edit_draft_ready': true,
    'tm_draft_cloud_completed': '',
    'tm_draft_cloud_entry_id': -1,
    'tm_draft_cloud_modified': 0,
    'tm_draft_cloud_parent_entry_id': -1,
    'tm_draft_cloud_space_id': -1,
    'tm_draft_cloud_user_id': -1,
    'tm_draft_create': nowUs,
    'tm_draft_modified': nowUs,
    'tm_draft_removed': 0,
    'tm_duration': durationUs,
  });
  rootMeta['all_draft_store'] = drafts;
  rootMeta['draft_ids'] = drafts.length;
  rootMeta['root_path'] = rootMeta['root_path'] ?? _jsonPath(draftRoot);
  await _writeAtomicString(metaPath, const JsonEncoder().convert(rootMeta));
}

Future<_MediaInfo?> _probeMedia(String path) async {
  final process = await Process.start(_ffprobeExecutable, [
    '-v',
    'error',
    '-select_streams',
    'v:0',
    '-show_entries',
    'stream=width,height,r_frame_rate:format=duration',
    '-of',
    'json',
    path,
  ]);
  await registerKlipioWorker(process);
  final stdout = process.stdout.transform(systemEncoding.decoder).join();
  final stderr = process.stderr.drain<void>();
  final outcome = await Future.any<int>([
    process.exitCode,
    Future<int>.delayed(const Duration(seconds: 30), () => -1),
  ]);
  if (outcome == -1) await terminateKlipioWorker(process);
  final output = await stdout.timeout(
    const Duration(seconds: 3),
    onTimeout: () => '',
  );
  await stderr.timeout(const Duration(seconds: 3), onTimeout: () {});
  if (outcome != 0) return null;
  final data = _decodeJsonObject(output);
  if (data == null) return null;
  final streams = data['streams'] as List? ?? const [];
  final stream =
      streams.isEmpty ? const <String, Object?>{} : streams.first as Map;
  final format = data['format'] as Map? ?? const {};
  final duration = double.tryParse('${format['duration'] ?? ''}') ?? 0;
  return _MediaInfo(
    durationSeconds: duration,
    width: int.tryParse('${stream['width'] ?? ''}') ?? 1920,
    height: int.tryParse('${stream['height'] ?? ''}') ?? 1080,
    fps: _parseFps('${stream['r_frame_rate'] ?? ''}'),
  );
}

Future<String?> _capCutDraftRoot() async {
  final metaPath = _rootMetaPath();
  if (metaPath != null) {
    final file = File(metaPath);
    if (await file.exists()) {
      final data = _decodeJsonObject(await file.readAsString());
      if (data != null) {
        final stores = data['all_draft_store'] as List? ?? const [];
        for (final item in stores.whereType<Map>()) {
          final root = '${item['draft_root_path'] ?? ''}';
          if (root.isNotEmpty && await Directory(root).exists()) return root;
        }
      }
    }
  }
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null || userProfile.isEmpty) return null;
  final fallback = '$userProfile${Platform.pathSeparator}CapCut Drafts';
  await Directory(fallback).create(recursive: true);
  return fallback;
}

Map<String, Object?>? _decodeJsonObject(String raw) {
  if (raw.trim().isEmpty) {
    return null;
  }
  try {
    final data = jsonDecode(raw);
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
  } on FormatException {
    return null;
  }
  return null;
}

Future<String?> _draftRoot(String? outputRoot) async {
  if (outputRoot != null && outputRoot.trim().isNotEmpty) {
    final directory = Directory(outputRoot);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }
  return _capCutDraftRoot();
}

String? _rootMetaPath() {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null || localAppData.isEmpty) return null;
  return '$localAppData${Platform.pathSeparator}CapCut${Platform.pathSeparator}'
      'User Data${Platform.pathSeparator}Projects${Platform.pathSeparator}'
      'com.lveditor.draft${Platform.pathSeparator}root_meta_info.json';
}

Future<String> _uniqueFolder(String root, String name) async {
  var candidate = '$root${Platform.pathSeparator}$name';
  var suffix = 1;
  while (await Directory(candidate).exists()) {
    candidate = '$root${Platform.pathSeparator}$name ($suffix)';
    suffix++;
  }
  return candidate;
}

Future<int> _timelineMaterialsSize(List<CapCutDraftClip> clips) async {
  var size = 0;
  final seen = <String>{};
  for (final clip in clips) {
    if (!seen.add(clip.inputPath)) continue;
    final file = File(clip.inputPath);
    if (await file.exists()) {
      size += await file.length();
    }
  }
  return size;
}

Future<String> _capCutSafeMediaPath(
  String inputPath,
  String draftRoot,
  Map<String, String> cache,
) async {
  final source = File(inputPath).absolute;
  final sourcePath = source.path;
  if (!_needsCapCutSafeMediaCopy(sourcePath)) return sourcePath;
  final cached = cache[sourcePath];
  if (cached != null) return cached;
  if (!await source.exists()) return sourcePath;

  final mediaFolder =
      Directory('$draftRoot${Platform.pathSeparator}Klipio Media');
  if (!await mediaFolder.exists()) {
    await mediaFolder.create(recursive: true);
  }
  final length = await source.length();
  final modified = await source.lastModified();
  final hash = _stablePathHash('$sourcePath|$length|${modified.toUtc()}');
  final extension = _mediaExtension(sourcePath);
  final targetPath =
      '${mediaFolder.path}${Platform.pathSeparator}media_$hash$extension';
  final target = File(targetPath);
  if (!await target.exists() || await target.length() != length) {
    await source.copy(targetPath);
  }
  cache[sourcePath] = targetPath;
  return targetPath;
}

bool _needsCapCutSafeMediaCopy(String path) {
  final basename = path.split(RegExp(r'[\\/]')).last;
  return path.length > 180 ||
      RegExp(r'[^\x20-\x7E]').hasMatch(path) ||
      RegExp(r'''['"`^&%#{}[\]()]''').hasMatch(basename);
}

String _stablePathHash(String input) {
  var hash = 0xcbf29ce484222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

Future<String> _outputVisibleDraftFolder({
  required String draftFolder,
  required String projectName,
  required String? outputRoot,
}) async {
  if (outputRoot == null ||
      outputRoot.trim().isEmpty ||
      _samePath(outputRoot, Directory(draftFolder).parent.path)) {
    return draftFolder;
  }

  final visibleFolder = await _uniqueFolder(outputRoot, projectName);
  try {
    final result = await Process.run('cmd', [
      '/c',
      'mklink',
      '/J',
      visibleFolder,
      draftFolder,
    ]);
    if (result.exitCode == 0 && await Directory(visibleFolder).exists()) {
      return visibleFolder;
    }
  } catch (_) {
    // If junction creation fails, return the real CapCut draft folder.
  }
  return draftFolder;
}

Future<void> _writeAtomicString(String path, String contents) async {
  final tempPath = '$path.klipio.tmp';
  final tempFile = File(tempPath);
  if (await tempFile.exists()) await tempFile.delete();
  await tempFile.writeAsString(contents, flush: true);
  try {
    await tempFile.rename(path);
  } on FileSystemException {
    final targetFile = File(path);
    if (await targetFile.exists()) await targetFile.delete();
    await tempFile.rename(path);
  }
}

Future<void> _deleteIncompleteDraftFolder(String draftFolder) async {
  final directory = Directory(draftFolder);
  if (!await directory.exists()) return;
  try {
    await directory.delete(recursive: true);
  } catch (_) {
    // The original failure is more useful than a cleanup failure.
  }
}

Future<void> _openCapCut() async {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final userProfile = Platform.environment['USERPROFILE'];
  final programFiles = Platform.environment['ProgramFiles'];
  final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
  final candidates = [
    if (localAppData != null)
      '$localAppData${Platform.pathSeparator}CapCut${Platform.pathSeparator}Apps${Platform.pathSeparator}CapCut.exe',
    if (localAppData != null)
      '$localAppData${Platform.pathSeparator}Programs${Platform.pathSeparator}CapCut${Platform.pathSeparator}CapCut.exe',
    if (programFiles != null)
      '$programFiles${Platform.pathSeparator}CapCut${Platform.pathSeparator}CapCut.exe',
    if (programFilesX86 != null)
      '$programFilesX86${Platform.pathSeparator}CapCut${Platform.pathSeparator}CapCut.exe',
    if (userProfile != null)
      ...await _userProfileCapCutExecutables(userProfile),
  ];
  for (final candidate in candidates) {
    if (await File(candidate).exists()) {
      try {
        await Process.start(
          candidate,
          const [],
          mode: ProcessStartMode.detached,
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        // The draft is already registered. Opening CapCut is only a convenience.
      }
      return;
    }
  }
}

Future<List<String>> _userProfileCapCutExecutables(String userProfile) async {
  final root = Directory('$userProfile${Platform.pathSeparator}CapCut');
  if (!await root.exists()) return const [];
  final directories = await root
      .list()
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  directories.sort((first, second) => second.path.compareTo(first.path));
  return [
    for (final directory in directories)
      '${directory.path}${Platform.pathSeparator}CapCut.exe',
  ];
}

double _parseFps(String value) {
  final parts = value.split('/');
  if (parts.length == 2) {
    final top = double.tryParse(parts[0]) ?? 0;
    final bottom = double.tryParse(parts[1]) ?? 0;
    if (top > 0 && bottom > 0) return top / bottom;
  }
  return double.tryParse(value) ?? 30.0;
}

int _secondsToUs(double seconds) => (seconds * 1000000).round();

double _safeSpeed(double speed) {
  if (speed.isNaN || speed.isInfinite || speed <= 0) return 1.0;
  return speed;
}

String _cleanDraftText(String input) {
  return input
      .replaceAll(RegExp(r'\\[hH]'), ' ')
      .replaceAll(RegExp(r'\\[nN]'), '\n')
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\\[A-Za-z]+\d*'), ' ')
      .replaceAll(r'\', ' ')
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

String _applyCaptionCase(String input, String captionCase) {
  return switch (captionCase) {
    'upper' => input.toUpperCase(),
    'lower' => input.toLowerCase(),
    'title' => input
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' '),
    _ => input,
  };
}

double _capCutDraftCaptionFontSize(double klipioSize) {
  // Klipio caption sizes are tuned for ASS/Flutter preview. CapCut's
  // native draft `text_size` scale is much larger, so sending 72 directly
  // makes captions cover the frame. Keep small existing CapCut-style sizes,
  // but convert large Klipio preview sizes down to CapCut's native scale.
  final normalized = klipioSize <= 18 ? klipioSize : klipioSize / 4.5;
  return normalized.clamp(6.0, 28.0).toDouble();
}

double _capCutDraftTextFontSize(double klipioSize) {
  final normalized = klipioSize <= 28 ? klipioSize : klipioSize / 3.0;
  return normalized.clamp(7.0, 48.0).toDouble();
}

double _normalizedTextX(double value) {
  return (value.clamp(0.0, 1.0) - 0.5) * 2;
}

double _normalizedTextY(double value) {
  return (0.5 - value.clamp(0.0, 1.0)) * 2;
}

List<double> _capCutColor(String hex) {
  final cleaned = hex.replaceAll('#', '').trim();
  final value = int.tryParse(
    cleaned.length >= 6 ? cleaned.substring(0, 6) : 'FFFFFF',
    radix: 16,
  );
  if (value == null) return const [1.0, 1.0, 1.0];
  return [
    ((value >> 16) & 0xff) / 255,
    ((value >> 8) & 0xff) / 255,
    (value & 0xff) / 255,
  ];
}

String _jsonPath(String path) => path.replaceAll(r'\', '/');

bool _samePath(String first, String second) {
  return _jsonPath(first).toLowerCase().replaceAll(RegExp(r'/+$'), '') ==
      _jsonPath(second).toLowerCase().replaceAll(RegExp(r'/+$'), '');
}

String _capCutSafeName(String input, {int maxLength = 120}) {
  final ascii = _capCutAsciiName(input)
      .replaceAll('’', '')
      .replaceAll('‘', '')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '_')
      .replaceAll(RegExp(r'''['"`^&%#{}[\]()]+'''), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[ ._]+|[ ._]+$'), '');
  final safe = ascii.isEmpty ? 'Klipio' : ascii;
  if (safe.length <= maxLength) return safe;
  return safe.substring(0, maxLength).replaceAll(RegExp(r'[ ._]+$'), '');
}

String _capCutAsciiName(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (_isApostropheRune(rune) || _isQuoteRune(rune)) {
      continue;
    }
    if (_isDashRune(rune)) {
      buffer.write('-');
      continue;
    }
    if (rune >= 0x20 && rune <= 0x7e) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

bool _isApostropheRune(int rune) {
  return rune == 0x0027 ||
      rune == 0x0060 ||
      rune == 0x00b4 ||
      rune == 0x02bc ||
      rune == 0x02bb ||
      rune == 0x2018 ||
      rune == 0x2019;
}

bool _isQuoteRune(int rune) {
  return rune == 0x0022 ||
      rune == 0x201c ||
      rune == 0x201d ||
      rune == 0x00ab ||
      rune == 0x00bb;
}

bool _isDashRune(int rune) {
  return rune == 0x2010 ||
      rune == 0x2011 ||
      rune == 0x2012 ||
      rune == 0x2013 ||
      rune == 0x2014 ||
      rune == 0x2212;
}

String _mediaDisplayName(String input) {
  final safe = _capCutSafeName(input, maxLength: 100);
  final extension = _mediaExtension(input);
  final stem = extension.isEmpty || !safe.toLowerCase().endsWith(extension)
      ? safe
      : safe.substring(0, safe.length - extension.length);
  return '$stem$extension';
}

String _mediaExtension(String path) {
  final basename = path.split(RegExp(r'[\\/]')).last;
  final dot = basename.lastIndexOf('.');
  if (dot <= 0 || dot == basename.length - 1) return '.mp4';
  final extension = basename.substring(dot).toLowerCase();
  return extension.length > 8 ? '.mp4' : extension;
}

String _timestampName() {
  final now = DateTime.now();
  return '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
}

String _uuidLower() => _uuid().toLowerCase();

String _uuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) {
        return byte.toRadixString(16).padLeft(2, '0');
      })
      .join()
      .toUpperCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

class _BuiltClip {
  const _BuiltClip({required this.clip, required this.media});

  final CapCutDraftClip clip;
  final _MediaInfo media;
}

class _MediaInfo {
  const _MediaInfo({
    required this.durationSeconds,
    required this.width,
    required this.height,
    required this.fps,
  });

  final double durationSeconds;
  final int width;
  final int height;
  final double fps;
}

class _CanvasSize {
  const _CanvasSize({
    required this.width,
    required this.height,
    required this.ratioName,
  });

  final int width;
  final int height;
  final String ratioName;
}

class _CropData {
  const _CropData({
    required this.ratioName,
    required this.points,
  });

  final String ratioName;
  final Map<String, double> points;
}
