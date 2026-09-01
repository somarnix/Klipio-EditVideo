import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../features/captions/domain/srt_document.dart';
import '../../features/export/domain/export_models.dart';
import '../process/windows_process_job.dart';

final _random = Random.secure();

String _bundledToolPath(String executableName) {
  if (!Platform.isWindows) return executableName;

  final appFolder = File(Platform.resolvedExecutable).parent.path;
  final bundledPath = '$appFolder${Platform.pathSeparator}$executableName.exe';
  if (File(bundledPath).existsSync()) {
    return bundledPath;
  }
  return executableName;
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

Map<String, Object?> _textMaterial({
  required String id,
  required String text,
  required String font,
  required double fontSize,
  required String color,
  required double opacity,
  required bool bold,
  required bool italic,
  required bool underline,
  required String strokeColor,
  required double strokeWidth,
  required bool shadow,
  required double tracking,
  required double lineSpacing,
  bool isCaption = false,
}) {
  final draftFontSize = isCaption
      ? _capCutDraftCaptionFontSize(fontSize)
      : _capCutDraftTextFontSize(fontSize);
  final content = {
    'text': text,
    'styles': [
      {
        'range': [0, text.length],
        'size': draftFontSize,
        'font': font,
        'fill': {
          'alpha': opacity.clamp(0.0, 1.0),
          'content': {
            'render_type': 'solid',
            'solid': {
              'alpha': opacity.clamp(0.0, 1.0),
              'color': _capCutColor(color),
            },
          },
        },
      }
    ],
  };
  return {
    'add_type': 0,
    'alignment': 1,
    'autoAdaptCanvasEnabled': false,
    'base_content': '',
    'background_alpha': 0.0,
    'background_color': '',
    'background_fill': '',
    'background_height': 0.14,
    'background_horizontal_offset': 0.0,
    'background_round_radius': 0.0,
    'background_style': 0,
    'background_vertical_offset': 0.0,
    'background_width': 0.14,
    'bold_width': bold ? 0.08 : 0.0,
    'border_alpha': 1.0,
    'border_color': strokeColor,
    'border_mode': 0,
    'border_width': strokeWidth <= 0 ? 0.0 : strokeWidth / 100,
    'caption_template_info': {
      'resource_id': '',
      'third_resource_id': '',
      'resource_name': '',
      'category_id': '',
      'category_name': '',
      'effect_id': '',
      'request_id': '',
      'path': '',
      'is_new': false,
      'source_platform': 0,
    },
    'check_flag': 7,
    'combo_info': {'text_templates': []},
    'content': jsonEncode(content),
    'current_words': {
      'start_time': [],
      'end_time': [],
      'text': [],
    },
    'cutoff_postfix': '',
    'enable_path_typesetting': false,
    'fixed_height': -1.0,
    'fixed_width': -1.0,
    'font_category_id': '',
    'font_category_name': '',
    'font_id': '',
    'font_name': font,
    'font_path': '',
    'font_resource_id': '',
    'font_source_platform': 0,
    'font_team_id': '',
    'font_third_resource_id': '',
    'font_size': draftFontSize,
    'font_title': font,
    'font_url': '',
    'fonts': [],
    'force_apply_line_max_width': false,
    'global_alpha': opacity.clamp(0.0, 1.0),
    'group_id': '',
    'has_shadow': shadow,
    'id': id,
    'initial_scale': 1.0,
    'inner_padding': -1.0,
    'is_batch_replace': false,
    'is_lyric_effect': false,
    'is_rich_text': false,
    'is_words_linear': false,
    'italic_degree': italic ? 10 : 0,
    'ktv_color': '',
    'language': '',
    'layer_weight': 0,
    'letter_spacing': tracking,
    'line_feed': 1,
    'line_max_width': 0.82,
    'line_spacing': lineSpacing,
    'lyric_group_id': '',
    'lyrics_template': {
      'resource_id': '',
      'resource_name': '',
      'panel': '',
      'effect_id': '',
      'path': '',
      'category_id': '',
      'category_name': '',
      'request_id': '',
    },
    'multi_language_current': 'none',
    'name': text.length > 40 ? '${text.substring(0, 40)}...' : text,
    'offset_on_path': 0.0,
    'oneline_cutoff': false,
    'operation_type': 0,
    'original_size': [],
    'preset_category': '',
    'preset_category_id': '',
    'preset_has_set_alignment': false,
    'preset_id': '',
    'preset_index': 0,
    'preset_name': '',
    'punc_model': '',
    'recognize_model': '',
    'recognize_task_id': '',
    'recognize_text': '',
    'recognize_type': isCaption ? 1 : 0,
    'relevance_segment': [],
    'shadow_alpha': shadow ? 0.75 : 0.0,
    'shadow_angle': -45.0,
    'shadow_color': '#000000',
    'shadow_distance': shadow ? 5.0 : 0.0,
    'shadow_point': {'x': 0.0, 'y': 0.0},
    'shadow_smoothing': 0.45,
    'shadow_thickness_projection_angle': 0.0,
    'shadow_thickness_projection_distance': 0.0,
    'shadow_thickness_projection_enable': false,
    'shape_clip_x': false,
    'shape_clip_y': false,
    'single_char_bg_alpha': 1.0,
    'single_char_bg_color': '',
    'single_char_bg_enable': false,
    'single_char_bg_height': 0.0,
    'single_char_bg_horizontal_offset': 0.0,
    'single_char_bg_round_radius': 0.3,
    'single_char_bg_vertical_offset': 0.0,
    'single_char_bg_width': 0.0,
    'source_from': '',
    'ssml_content': '',
    'style_name': '',
    'sub_type': isCaption ? 1 : 0,
    'sub_template_id': -1,
    'subtitle_keywords': null,
    'subtitle_keywords_config': null,
    'subtitle_template_original_fontsize': isCaption ? draftFontSize : 0.0,
    'text_alpha': opacity.clamp(0.0, 1.0),
    'text_color': color,
    'text_curve': null,
    'text_exceeds_path_process_type': 0,
    'text_loop_on_path': false,
    'text_preset_resource_id': '',
    'text_size': draftFontSize,
    'text_to_audio_ids': [],
    'text_typesetting_path_index': 0,
    'text_typesetting_paths': null,
    'text_typesetting_paths_file': '',
    'translate_original_text': '',
    'tts_auto_update': false,
    'type': 'text',
    'typesetting': 0,
    'underline': underline,
    'underline_offset': 0.22,
    'underline_width': 0.05,
    'use_effect_default_color': false,
    'words': {
      'start_time': [],
      'end_time': [],
      'text': [],
    },
  };
}

Map<String, Object?> _textSegment({
  required String materialId,
  required int targetStartUs,
  required int targetDurationUs,
  required double x,
  required double y,
  required int renderIndex,
  bool isCaption = false,
}) {
  final segmentId = _uuid();
  return {
    'caption_info': isCaption
        ? {
            'type': 'subtitle',
            'fragment_info': null,
            'fragment_duration': 0,
            'anims_info': null,
            'keywords_style': '',
            'keyword_extra_style': {
              'keyword_capital': '',
              'keyword_supersize': 1.0,
              'keyword_isolation': '',
              'keyword_isolation_supersize': 1.0,
              'style_unbundling': [],
            },
            'capital': '',
            'modify_info': null,
          }
        : null,
    'cartoon': false,
    'clip': {
      'alpha': 1.0,
      'flip': {'horizontal': false, 'vertical': false},
      'rotation': 0.0,
      'scale': {'x': 1.0, 'y': 1.0},
      'transform': {'x': x, 'y': y},
    },
    'common_keyframes': [],
    'enable_adjust': false,
    'enable_adjust_mask': false,
    'enable_color_adjust_pro': false,
    'enable_color_correct_adjust': false,
    'enable_color_curves': true,
    'enable_color_match_adjust': false,
    'enable_color_wheels': true,
    'enable_hsl': false,
    'enable_hsl_curves': true,
    'enable_lut': false,
    'enable_mask_shadow': false,
    'enable_mask_stroke': false,
    'enable_smart_color_adjust': false,
    'enable_video_mask': true,
    'extra_material_refs': [],
    'group_id': '',
    'hdr_settings': null,
    'id': segmentId,
    'intensifies_audio': false,
    'is_loop': false,
    'is_placeholder': false,
    'is_tone_modify': false,
    'keyframe_refs': [],
    'last_nonzero_volume': 1.0,
    'lyric_keyframes': null,
    'material_id': materialId,
    'raw_segment_id': '',
    'render_index': renderIndex,
    'render_timerange': {'duration': 0, 'start': 0},
    'responsive_layout': {
      'enable': false,
      'horizontal_pos_layout': 0,
      'size_layout': 0,
      'target_follow': '',
      'vertical_pos_layout': 0,
    },
    'reverse': false,
    'segment_color_tag': '',
    'source': 'segmentsourcenormal',
    'source_timerange': null,
    'speed': 1.0,
    'state': 0,
    'target_timerange': {'duration': targetDurationUs, 'start': targetStartUs},
    'template_id': '',
    'template_scene': 'default',
    'track_attribute': 0,
    'track_render_index': 0,
    'uniform_scale': {'on': true, 'value': 1.0},
    'visible': true,
    'volume': 1.0,
  };
}

Map<String, Object?> _draftMeta({
  required String id,
  required String name,
  required String folder,
  required String root,
  required int durationUs,
  required List<Map<String, Object?>> materials,
  required int nowUs,
}) {
  return {
    'cloud_draft_cover': false,
    'cloud_draft_sync': false,
    'draft_cloud_template_id': '',
    'draft_cover': '',
    'draft_enterprise_info': {
      'draft_enterprise_extra': '',
      'draft_enterprise_id': '',
      'draft_enterprise_name': '',
      'enterprise_material': [],
    },
    'draft_fold_path': _jsonPath(folder),
    'draft_id': id,
    'draft_is_ai_packaging_used': false,
    'draft_is_ai_shorts': false,
    'draft_is_cloud_temp_draft': false,
    'draft_is_invisible': false,
    'draft_materials': [
      {'type': 0, 'value': materials},
      {'type': 1, 'value': []},
      {'type': 2, 'value': []},
      {'type': 3, 'value': []},
      {'type': 6, 'value': []},
      {'type': 7, 'value': []},
    ],
    'draft_materials_copied_info': [],
    'draft_name': name,
    'draft_new_version': '',
    'draft_root_path': _jsonPath(root),
    'draft_segment_extra_info': [],
    'draft_type': '',
    'tm_draft_create': nowUs,
    'tm_draft_modified': nowUs,
    'tm_draft_removed': 0,
    'tm_duration': durationUs,
  };
}

Map<String, Object?> _videoMaterial({
  required String id,
  required String localMaterialId,
  required String path,
  required String name,
  required int durationUs,
  required int width,
  required int height,
  required VideoEditSettings settings,
}) {
  const crop = _CropData(
    ratioName: 'free',
    points: {
      'upper_left_x': 0.0,
      'upper_left_y': 0.0,
      'upper_right_x': 1.0,
      'upper_right_y': 0.0,
      'lower_left_x': 0.0,
      'lower_left_y': 1.0,
      'lower_right_x': 1.0,
      'lower_right_y': 1.0,
    },
  );
  return {
    'id': id,
    'unique_id': '',
    'type': 'video',
    'duration': durationUs,
    'path': path,
    'media_path': '',
    'local_id': '',
    'has_audio': true,
    'reverse_path': '',
    'intensifies_path': '',
    'reverse_intensifies_path': '',
    'intensifies_audio_path': '',
    'cartoon_path': '',
    'width': width,
    'height': height,
    'category_id': '',
    'category_name': 'local',
    'material_id': '',
    'material_name': name,
    'material_url': '',
    'crop': crop.points,
    'crop_ratio': crop.ratioName,
    'audio_fade': null,
    'crop_scale': 1.0,
    'extra_type_option': 0,
    'stable': {
      'stable_level': 0,
      'matrix_path': '',
      'time_range': {'start': 0, 'duration': 0},
    },
    'matting': {
      'flag': 0,
      'path': '',
      'interactiveTime': [],
      'has_use_quick_brush': false,
      'strokes': [],
      'has_use_quick_eraser': false,
      'expansion': 0,
      'feather': 0,
      'reverse': false,
      'custom_matting_id': '',
      'enable_matting_stroke': false,
      'is_clould': false,
      'mask_video_path': '',
      'cloud_product_fps': 0.0,
    },
    'source': 0,
    'source_platform': 0,
    'formula_id': '',
    'check_flag': 62978047,
    'video_algorithm': {'algorithms': [], 'time_range': null, 'path': ''},
    'is_unified_beauty_mode': false,
    'is_set_beauty_mode': false,
    'local_material_id': localMaterialId,
    'origin_material_id': '',
    'request_id': '',
    'has_sound_separated': false,
    'is_text_edit_overdub': false,
    'is_ai_generate_content': false,
    'aigc_type': 'none',
    'is_copyright': false,
    'local_material_from': '',
    'live_photo_timestamp': -1,
    'live_photo_cover_path': '',
    'surface_trackings': [],
  };
}

Map<String, Object?> _videoSegment({
  required String id,
  required String materialId,
  required double speed,
  required int sourceStartUs,
  required int sourceDurationUs,
  required int targetStartUs,
  required int targetDurationUs,
  required int renderIndex,
  required VideoEditSettings settings,
  required List<String> refs,
}) {
  final scaleX = settings.scaleX * settings.zoom;
  final scaleY = settings.scaleY * settings.zoom;
  final uniformScale = (scaleX - scaleY).abs() < 0.001;
  final scaleValue = uniformScale ? scaleX : (scaleX + scaleY) / 2;
  return {
    'caption_info': null,
    'cartoon': false,
    'clip': {
      'alpha': 1.0,
      'flip': {
        'horizontal': settings.flip == 'left' || settings.flip == 'right',
        'vertical': settings.flip == 'down' || settings.flip == 'up',
      },
      'rotation': 0.0,
      'scale': {'x': scaleX, 'y': scaleY},
      'transform': {'x': settings.panX, 'y': settings.panY},
    },
    'color_correct_alg_result': '',
    'common_keyframes': [],
    'desc': '',
    'digital_human_template_group_id': '',
    'enable_adjust': true,
    'enable_adjust_mask': false,
    'enable_color_correct_adjust': false,
    'enable_color_curves': true,
    'enable_color_match_adjust': false,
    'enable_color_wheels': true,
    'enable_hsl': false,
    'enable_hsl_curves': true,
    'enable_lut': true,
    'enable_mask_shadow': false,
    'enable_mask_stroke': false,
    'enable_smart_color_adjust': false,
    'enable_video_mask': true,
    'extra_material_refs': refs,
    'group_id': '',
    'hdr_settings': {'intensity': 1.0, 'mode': 1, 'nits': 1000},
    'id': id,
    'intensifies_audio': false,
    'is_loop': false,
    'is_placeholder': false,
    'is_tone_modify': false,
    'keyframe_refs': [],
    'last_nonzero_volume': settings.originalVolume,
    'lyric_keyframes': null,
    'material_id': materialId,
    'raw_segment_id': '',
    'render_index': renderIndex,
    'render_timerange': {'duration': 0, 'start': 0},
    'responsive_layout': {
      'enable': false,
      'horizontal_pos_layout': 0,
      'size_layout': 0,
      'target_follow': '',
      'vertical_pos_layout': 0,
    },
    'reverse': false,
    'source': 'segmentsourcenormal',
    'source_timerange': {'duration': sourceDurationUs, 'start': sourceStartUs},
    'speed': speed,
    'state': 0,
    'target_timerange': {'duration': targetDurationUs, 'start': targetStartUs},
    'template_id': '',
    'template_scene': 'default',
    'track_attribute': 0,
    'track_render_index': 0,
    'uniform_scale': {'on': uniformScale, 'value': scaleValue},
    'visible': true,
    'volume': settings.originalVolume,
  };
}

_CanvasSize _canvasSize(_MediaInfo media, VideoEditSettings settings) {
  final target = _targetRatio(settings.outputRatio);
  if (target == null) {
    return _CanvasSize(
      width: media.width,
      height: media.height,
      ratioName: 'original',
    );
  }
  final source = media.width / media.height;
  if (source > target) {
    return _CanvasSize(
      width: _even(media.height * target),
      height: _even(media.height.toDouble()),
      ratioName: settings.outputRatio,
    );
  }
  return _CanvasSize(
    width: _even(media.width.toDouble()),
    height: _even(media.width / target),
    ratioName: settings.outputRatio,
  );
}

double? _targetRatio(String ratio) {
  return switch (ratio) {
    '16:9' => 16 / 9,
    '9:16' => 9 / 16,
    '4:5' => 4 / 5,
    '1:1' => 1.0,
    '3:4' => 3 / 4,
    '4:3' => 4 / 3,
    _ => null,
  };
}

int _even(double value) {
  final rounded = value.round();
  return rounded.isEven ? rounded : rounded - 1;
}

Map<String, Object?> _metaMaterial({
  required String id,
  required String path,
  required String name,
  required int durationUs,
  required int width,
  required int height,
  required int nowSec,
  required int nowUs,
  required int type,
  required String metetype,
}) {
  return {
    'ai_group_type': '',
    'create_time': nowSec,
    'duration': durationUs,
    'enter_from': 0,
    'extra_info': name,
    'file_Path': path,
    'height': height,
    'id': id,
    'import_time': nowSec,
    'import_time_ms': nowUs,
    'item_source': 1,
    'md5': '',
    'metetype': metetype,
    'roughcut_time_range': {'duration': durationUs, 'start': 0},
    'sub_time_range': {'duration': -1, 'start': -1},
    'type': type,
    'width': width,
  };
}

Map<String, Object?> _placeholderInfo(String id) => {
      'error_path': '',
      'error_text': '',
      'id': id,
      'meta_type': 'none',
      'res_path': '',
      'res_text': '',
      'type': 'placeholder_info',
    };

Map<String, Object?> _canvas(String id) => {
      'album_image': '',
      'blur': 0.0,
      'color': '',
      'id': id,
      'image': '',
      'image_id': '',
      'image_name': '',
      'source_platform': 0,
      'team_id': '',
      'type': 'canvas_color',
    };

Map<String, Object?> _soundMapping(String id) => {
      'audio_channel_mapping': 0,
      'id': id,
      'is_config_open': false,
      'type': '',
    };

Map<String, Object?> _materialColor(String id) => {
      'gradient_angle': 90.0,
      'gradient_colors': [],
      'gradient_percents': [],
      'height': 0.0,
      'id': id,
      'is_color_clip': false,
      'is_gradient': false,
      'solid_color': '',
      'width': 0.0,
    };

Map<String, Object?> _vocalSeparation(String id) => {
      'choice': 0,
      'enter_from': '',
      'final_algorithm': '',
      'id': id,
      'production_path': '',
      'removed_sounds': [],
      'time_range': null,
      'type': 'vocal_separation',
    };

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
