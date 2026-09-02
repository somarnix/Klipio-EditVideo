import 'dart:convert';
import 'dart:io';
import '../../core/storage/application_paths.dart';
import 'dart:math';

import '../../features/captions/domain/srt_document.dart';
import '../../features/export/domain/export_models.dart';
import '../process/windows_process_job.dart';

part 'capcut_draft_service_text_material.dart';
part 'capcut_draft_service_built_clip.dart';

final _random = Random.secure();

String _bundledToolPath(String executableName) {
  return ApplicationPaths.mediaTool(executableName);
}

String get _ffprobeExecutable => _bundledToolPath('ffprobe');

Future<bool> isCapCutDesktopRunning() async {
  if (!Platform.isWindows) return false;
  try {
    final result = await Process.run('tasklist', [
      '/FI',
      'IMAGENAME eq CapCut.exe',
      '/FO',
      'CSV',
      '/NH',
    ]);
    return '${result.stdout}'.toLowerCase().contains('"capcut.exe"');
  } catch (_) {
    return false;
  }
}

class CapCutDraftClip {
  const CapCutDraftClip({
    required this.inputPath,
    required this.name,
    required this.settings,
  });

  final String inputPath;
  final String name;
  final VideoEditSettings settings;
}

class CapCutDraftResult {
  const CapCutDraftResult({
    required this.success,
    required this.message,
    this.draftFolder,
    this.captionFolder,
    this.projectName,
  });

  final bool success;
  final String message;
  final String? draftFolder;
  final String? captionFolder;
  final String? projectName;
}

Future<CapCutDraftResult> createCapCutDraft({
  required String projectName,
  required List<CapCutDraftClip> clips,
  String? outputRoot,
  bool launchCapCut = true,
  bool includeCaptionsInDraft = true,
  bool exportCaptionSrt = false,
}) async {
  if (!Platform.isWindows) {
    return const CapCutDraftResult(
      success: false,
      message: 'CapCut draft export is available on Windows only.',
    );
  }
  if (clips.isEmpty) {
    return const CapCutDraftResult(
      success: false,
      message: 'No clips were provided for CapCut draft export.',
    );
  }

  final outputFolder = await _draftRoot(outputRoot);
  final capCutRoot = await _capCutDraftRoot();
  final root = capCutRoot ?? outputFolder;
  if (root == null) {
    return const CapCutDraftResult(
      success: false,
      message: 'Could not find a folder for the CapCut draft.',
    );
  }

  final cleanedProjectName = _capCutSafeName(projectName, maxLength: 110);
  final safeProjectName = cleanedProjectName.isEmpty
      ? 'Klipio ${_timestampName()}'
      : cleanedProjectName;
  final draftFolder = await _uniqueFolder(root, safeProjectName);
  await Directory(draftFolder).create(recursive: true);
  try {
    final builtClips = <_BuiltClip>[];
    final safeMediaPaths = <String, String>{};
    for (final clip in clips) {
      final media = await _probeMedia(clip.inputPath);
      if (media == null) {
        throw Exception('Could not read video info: ${clip.inputPath}');
      }
      final safeInputPath = await _capCutSafeMediaPath(
        clip.inputPath,
        root,
        safeMediaPaths,
      );
      builtClips.add(_BuiltClip(
        clip: CapCutDraftClip(
          inputPath: safeInputPath,
          name: clip.name,
          settings: clip.settings,
        ),
        media: media,
      ));
    }

    final draftId = _uuid();
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final materialIdsByPath = <String, String>{};
    final localMaterialIdsByPath = <String, String>{};
    final videoMaterials = <Map<String, Object?>>[];
    final metaVideoMaterials = <Map<String, Object?>>[];
    final segments = <Map<String, Object?>>[];
    final textMaterials = <Map<String, Object?>>[];
    final captionSegments = <Map<String, Object?>>[];
    final textSegments = <Map<String, Object?>>[];
    final subtitleCues = <SrtEntry>[];
    final speeds = <Map<String, Object?>>[];
    final placeholderId = _uuid();
    final canvasId = _uuid();
    final soundMappingId = _uuid();
    final colorId = _uuid();
    final vocalId = _uuid();
    var targetStartUs = 0;
    var renderIndex = 0;

    for (final built in builtClips) {
      final clip = built.clip;
      final media = built.media;
      final normalizedPath = _jsonPath(File(clip.inputPath).absolute.path);
      final displayName = _mediaDisplayName(clip.name);
      final materialKey = '$normalizedPath|$displayName';
      final materialId = materialIdsByPath.putIfAbsent(materialKey, _uuid);
      final localMaterialId =
          localMaterialIdsByPath.putIfAbsent(materialKey, _uuidLower);
      if (!videoMaterials.any((item) => item['id'] == materialId)) {
        videoMaterials.add(_videoMaterial(
          id: materialId,
          localMaterialId: localMaterialId,
          path: normalizedPath,
          name: displayName,
          durationUs: _secondsToUs(media.durationSeconds),
          width: media.width,
          height: media.height,
          settings: clip.settings,
        ));
        metaVideoMaterials.add(_metaMaterial(
          id: localMaterialId,
          path: normalizedPath,
          name: displayName,
          durationUs: _secondsToUs(media.durationSeconds),
          width: media.width,
          height: media.height,
          nowSec: nowSec,
          nowUs: nowUs,
          type: 0,
          metetype: 'video',
        ));
      }

      final sourceStartSeconds = clip.settings.trimStartSeconds < 0
          ? 0.0
          : clip.settings.trimStartSeconds;
      final sourceEndSeconds = clip.settings.trimEndSeconds > sourceStartSeconds
          ? clip.settings.trimEndSeconds
          : media.durationSeconds;
      final sourceDurationSeconds = (sourceEndSeconds - sourceStartSeconds)
          .clamp(0.0, media.durationSeconds)
          .toDouble();
      if (sourceDurationSeconds <= 0) continue;

      final speed = _safeSpeed(clip.settings.speed);
      final sourceStartUs = _secondsToUs(sourceStartSeconds);
      final sourceDurationUs = _secondsToUs(sourceDurationSeconds);
      final targetDurationUs = _secondsToUs(sourceDurationSeconds / speed);
      final speedId = _uuid();
      speeds.add({
        'curve_speed': null,
        'id': speedId,
        'mode': 0,
        'speed': speed,
        'type': 'speed',
      });
      segments.add(_videoSegment(
        id: _uuid(),
        materialId: materialId,
        speed: speed,
        sourceStartUs: sourceStartUs,
        sourceDurationUs: sourceDurationUs,
        targetStartUs: targetStartUs,
        targetDurationUs: targetDurationUs,
        renderIndex: renderIndex++,
        settings: clip.settings,
        refs: [
          speedId,
          placeholderId,
          canvasId,
          soundMappingId,
          colorId,
          vocalId,
        ],
      ));
      _addNativeTextSegments(
        textMaterials: textMaterials,
        captionSegments: captionSegments,
        textSegments: textSegments,
        includeCaptionsInDraft: includeCaptionsInDraft,
        subtitleCues: exportCaptionSrt ? subtitleCues : null,
        settings: clip.settings,
        sourceStartSeconds: sourceStartSeconds,
        sourceEndSeconds: sourceEndSeconds,
        speed: speed,
        targetStartUs: targetStartUs,
        targetDurationUs: targetDurationUs,
      );
      targetStartUs += targetDurationUs;
    }

    if (segments.isEmpty) {
      throw Exception('No valid CapCut timeline segments were created.');
    }

    final firstMedia = builtClips.first.media;
    final canvas = _canvasSize(firstMedia, builtClips.first.clip.settings);
    final draftContent = _draftContent(
      id: draftId,
      durationUs: targetStartUs,
      fps: firstMedia.fps,
      width: canvas.width,
      height: canvas.height,
      ratio: canvas.ratioName,
      videoMaterials: videoMaterials,
      speeds: speeds,
      textMaterials: textMaterials,
      captionSegments: captionSegments,
      textSegments: textSegments,
      placeholderId: placeholderId,
      canvasId: canvasId,
      soundMappingId: soundMappingId,
      colorId: colorId,
      vocalId: vocalId,
      segments: segments,
    );
    final draftMeta = _draftMeta(
      id: draftId,
      name: safeProjectName,
      folder: draftFolder,
      root: root,
      durationUs: targetStartUs,
      materials: metaVideoMaterials,
      nowUs: nowUs,
    );

    await _writeAtomicString(
      '$draftFolder${Platform.pathSeparator}draft_content.json',
      const JsonEncoder().convert(draftContent),
    );
    await _writeAtomicString(
      '$draftFolder${Platform.pathSeparator}draft_meta_info.json',
      const JsonEncoder().convert(draftMeta),
    );
    await _writeAtomicString(
      '$draftFolder${Platform.pathSeparator}draft_settings',
      '[General]\n'
          'draft_create_time=$nowSec\n'
          'draft_last_edit_time=$nowSec\n'
          'real_edit_seconds=0\n'
          'real_edit_keys=1\n',
    );
    await _writeAtomicString(
      '$draftFolder${Platform.pathSeparator}draft_virtual_store.json',
      const JsonEncoder().convert({
        'draft_materials': [],
        'draft_virtual_store': [
          {
            'type': 0,
            'value': [
              {
                'creation_time': 0,
                'display_name': '',
                'filter_type': 0,
                'id': '',
                'import_time': 0,
                'import_time_us': 0,
                'sort_sub_type': 0,
                'sort_type': 0,
                'subdraft_filter_type': 0,
              }
            ],
          },
          {
            'type': 1,
            'value': [
              for (final id in localMaterialIdsByPath.values)
                {'child_id': id, 'parent_id': ''}
            ],
          },
          {'type': 2, 'value': []},
        ],
      }),
    );
    await _writeAtomicString(
      '$draftFolder${Platform.pathSeparator}README.txt',
      'CapCut draft created by Klipio.\n'
          'Open CapCut Desktop and look for "$safeProjectName" in Drafts.\n'
          '${exportCaptionSrt ? 'Import the SRT file from the Caption folder using CapCut Captions > Add captions > Import file.\n' : ''}',
    );

    String? realCaptionFolder;
    if (exportCaptionSrt) {
      realCaptionFolder = '$draftFolder${Platform.pathSeparator}Caption';
      await Directory(realCaptionFolder).create(recursive: true);
      if (subtitleCues.isNotEmpty) {
        final subtitlePath = '$realCaptionFolder${Platform.pathSeparator}'
            '${_capCutSafeName(safeProjectName, maxLength: 100)}.srt';
        await _writeAtomicString(
          subtitlePath,
          buildSrtDocument(subtitleCues),
        );
      } else {
        await _writeAtomicString(
          '$realCaptionFolder${Platform.pathSeparator}README.txt',
          'No generated caption cues were available for this draft.\n',
        );
      }
    }

    await _registerDraft(
      draftRoot: root,
      draftFolder: draftFolder,
      draftId: draftId,
      projectName: safeProjectName,
      durationUs: targetStartUs,
      materialsSize: await _timelineMaterialsSize(clips),
      nowUs: nowUs,
    );
    final outputDraftFolder = await _outputVisibleDraftFolder(
      draftFolder: draftFolder,
      projectName: safeProjectName,
      outputRoot: outputFolder,
    );
    if (launchCapCut) await _openCapCut();

    return CapCutDraftResult(
      success: true,
      message: subtitleCues.isNotEmpty
          ? 'CapCut draft and Caption SRT created.'
          : 'CapCut draft created.',
      draftFolder: outputDraftFolder,
      captionFolder: realCaptionFolder == null
          ? null
          : '$outputDraftFolder${Platform.pathSeparator}Caption',
      projectName: safeProjectName,
    );
  } catch (error) {
    await _deleteIncompleteDraftFolder(draftFolder);
    return CapCutDraftResult(
      success: false,
      message: 'Could not create CapCut draft "$safeProjectName": $error',
    );
  }
}

Map<String, Object?> _draftContent({
  required String id,
  required int durationUs,
  required double fps,
  required int width,
  required int height,
  required String ratio,
  required List<Map<String, Object?>> videoMaterials,
  required List<Map<String, Object?>> speeds,
  required List<Map<String, Object?>> textMaterials,
  required List<Map<String, Object?>> captionSegments,
  required List<Map<String, Object?>> textSegments,
  required String placeholderId,
  required String canvasId,
  required String soundMappingId,
  required String colorId,
  required String vocalId,
  required List<Map<String, Object?>> segments,
}) {
  final placeholder = _placeholderInfo(placeholderId);
  final canvas = _canvas(canvasId);
  final sound = _soundMapping(soundMappingId);
  final color = _materialColor(colorId);
  final vocal = _vocalSeparation(vocalId);
  return {
    'canvas_config': {
      'background': null,
      'height': height,
      'ratio': ratio,
      'width': width,
    },
    'color_space': 0,
    'config': {
      'adjust_max_index': 1,
      'attachment_info': [],
      'combination_max_index': 1
    },
    'cover': null,
    'create_time': 0,
    'draft_type': '',
    'duration': durationUs,
    'extra_info': null,
    'fps': fps,
    'free_render_index_mode_on': false,
    'function_assistant_info': null,
    'group_container': null,
    'id': id,
    'is_drop_frame_timecode': false,
    'keyframes': {'adjusts': [], 'audios': [], 'videos': []},
    'keyframe_graph_list': [],
    'last_modified_platform': {
      'app_id': 3704,
      'app_source': 'cc',
      'app_version': '0.0.0'
    },
    'lyrics_effects': [],
    'materials': _materials(
      videos: videoMaterials,
      speeds: speeds,
      texts: textMaterials,
      placeholder: placeholder,
      canvas: canvas,
      sound: sound,
      color: color,
      vocal: vocal,
    ),
    'mutable_config': null,
    'name': '',
    'new_version': '169.0.0',
    'path': '',
    'platform': {'app_id': 3704, 'app_source': 'cc', 'app_version': '0.0.0'},
    'relationships': [],
    'render_index_track_mode_on': false,
    'retouch_cover': null,
    'smart_ads_info': null,
    'source': 'default',
    'static_cover_image_path': '',
    'time_marks': null,
    'tracks': [
      {
        'attribute': 0,
        'flag': 0,
        'id': _uuid(),
        'is_default_name': true,
        'name': '',
        'segments': segments,
        'type': 'video',
      },
      if (captionSegments.isNotEmpty)
        {
          'attribute': 0,
          'flag': 0,
          'id': _uuid(),
          'is_default_name': false,
          'name': 'Captions',
          'segments': captionSegments,
          'type': 'text',
        },
      if (textSegments.isNotEmpty)
        {
          'attribute': 0,
          'flag': 0,
          'id': _uuid(),
          'is_default_name': false,
          'name': 'Text',
          'segments': textSegments,
          'type': 'text',
        }
    ],
    'uneven_animation_template_info': null,
    'update_time': 0,
    'version': 360000,
  };
}

Map<String, Object?> _materials({
  required List<Map<String, Object?>> videos,
  required List<Map<String, Object?>> speeds,
  required List<Map<String, Object?>> texts,
  required Map<String, Object?> placeholder,
  required Map<String, Object?> canvas,
  required Map<String, Object?> sound,
  required Map<String, Object?> color,
  required Map<String, Object?> vocal,
}) {
  final emptyNames = [
    'ai_translates',
    'audios',
    'audio_balances',
    'audio_effects',
    'audio_fades',
    'audio_pannings',
    'audio_pitch_shifts',
    'audio_track_indexes',
    'beats',
    'chromas',
    'color_curves',
    'common_mask',
    'digital_humans',
    'digital_human_model_dressing',
    'effects',
    'flowers',
    'green_screens',
    'hsl',
    'images',
    'log_color_wheels',
    'manual_deformations',
    'masks',
    'material_animations',
    'material_colors',
    'multi_language_current',
    'multi_language_refs',
    'placeholder_infos',
    'plugin_effects',
    'primary_color_wheels',
    'realtime_denoises',
    'shapes',
    'sound_channel_mappings',
    'speeds',
    'stickers',
    'texts',
    'text_templates',
    'transitions',
    'video_effects',
    'video_masks',
    'videos',
    'vocal_separations',
  ];
  final map = <String, Object?>{for (final name in emptyNames) name: []};
  map['canvases'] = [canvas];
  map['material_colors'] = [color];
  map['placeholder_infos'] = [placeholder];
  map['sound_channel_mappings'] = [sound];
  map['speeds'] = speeds;
  map['texts'] = texts;
  map['videos'] = videos;
  map['vocal_separations'] = [vocal];
  return map;
}

void _addNativeTextSegments({
  required List<Map<String, Object?>> textMaterials,
  required List<Map<String, Object?>> captionSegments,
  required List<Map<String, Object?>> textSegments,
  required bool includeCaptionsInDraft,
  required List<SrtEntry>? subtitleCues,
  required VideoEditSettings settings,
  required double sourceStartSeconds,
  required double sourceEndSeconds,
  required double speed,
  required int targetStartUs,
  required int targetDurationUs,
}) {
  for (final cue in settings.captionCues) {
    final text =
        _applyCaptionCase(_cleanDraftText(cue.text), settings.captionCase);
    if (text.isEmpty) continue;
    final cueStart = cue.start.clamp(sourceStartSeconds, sourceEndSeconds);
    final cueEnd = cue.end.clamp(sourceStartSeconds, sourceEndSeconds);
    if (cueEnd <= cueStart) continue;

    final materialId = _uuid();
    final startUs =
        targetStartUs + _secondsToUs((cueStart - sourceStartSeconds) / speed);
    final durationUs = _secondsToUs((cueEnd - cueStart) / speed);
    if (durationUs <= 0) continue;

    subtitleCues?.add(SrtEntry(
      startMicroseconds: startUs,
      endMicroseconds: startUs + durationUs,
      text: text,
    ));
    if (!includeCaptionsInDraft) continue;

    textMaterials.add(_textMaterial(
      id: materialId,
      text: text,
      font: settings.captionFont,
      fontSize: settings.captionFontSize,
      color: settings.captionColor,
      opacity: settings.captionOpacity,
      bold: settings.captionBold,
      italic: settings.captionItalic,
      underline: settings.captionUnderline,
      strokeColor: settings.captionStrokeColor,
      strokeWidth:
          settings.captionStrokeEnabled ? settings.captionStrokeWidth : 0,
      shadow: settings.captionShadowEnabled,
      tracking: settings.captionCharacterSpacing,
      lineSpacing: settings.captionLineSpacing,
      isCaption: true,
    ));
    captionSegments.add(_textSegment(
      materialId: materialId,
      targetStartUs: startUs,
      targetDurationUs: durationUs,
      x: _normalizedTextX(cue.x),
      y: _normalizedTextY(cue.y),
      renderIndex: 10000 + captionSegments.length,
      isCaption: true,
    ));
  }

  final legacyText = _cleanDraftText(settings.overlayText);
  if (legacyText.isNotEmpty) {
    final materialId = _uuid();
    textMaterials.add(_textMaterial(
      id: materialId,
      text: legacyText,
      font: settings.overlayFont,
      fontSize: settings.overlayTextSize,
      color: settings.overlayTextColor,
      opacity: settings.overlayTextOpacity,
      bold: true,
      italic: false,
      underline: false,
      strokeColor: settings.overlayTextStrokeColor,
      strokeWidth: settings.overlayTextStroke,
      shadow: settings.overlayTextShadow,
      tracking: 0,
      lineSpacing: 0,
    ));
    textSegments.add(_textSegment(
      materialId: materialId,
      targetStartUs: targetStartUs,
      targetDurationUs: targetDurationUs,
      x: _normalizedTextX(settings.overlayTextX),
      y: _normalizedTextY(settings.overlayTextY),
      renderIndex: 11000 + textSegments.length,
    ));
  }

  for (final overlay in settings.textOverlays.where((item) => item.visible)) {
    final text = _cleanDraftText(overlay.text);
    if (text.isEmpty) continue;
    final localStartSeconds = overlay.timelineStart <= 0
        ? 0.0
        : overlay.timelineStart.clamp(0.0, targetDurationUs / 1000000);
    final localEndSeconds = overlay.timelineEnd > localStartSeconds
        ? overlay.timelineEnd
            .clamp(localStartSeconds, targetDurationUs / 1000000)
        : targetDurationUs / 1000000;
    final durationUs = _secondsToUs(localEndSeconds - localStartSeconds);
    if (durationUs <= 0) continue;

    final materialId = _uuid();
    textMaterials.add(_textMaterial(
      id: materialId,
      text: text,
      font: overlay.font,
      fontSize: overlay.size,
      color: overlay.color,
      opacity: overlay.opacity,
      bold: true,
      italic: false,
      underline: false,
      strokeColor: overlay.strokeColor,
      strokeWidth: overlay.stroke,
      shadow: overlay.shadow,
      tracking: overlay.tracking,
      lineSpacing: 0,
    ));
    textSegments.add(_textSegment(
      materialId: materialId,
      targetStartUs: targetStartUs + _secondsToUs(localStartSeconds),
      targetDurationUs: durationUs,
      x: _normalizedTextX(overlay.x),
      y: _normalizedTextY(overlay.y),
      renderIndex: 12000 + textSegments.length,
    ));
  }
}
