import 'dart:async';
import '../../editor/application/effect_edit.dart';
import '../../editor/application/transition_edit.dart';
import '../../editor/application/transform_preview.dart';
import '../../editor/application/snapshot_history.dart';
import '../../editor/presentation/effect_preview_interaction.dart';
import '../../editor/presentation/asset_browser_shell.dart';
import '../../editor/presentation/inspector/inspector_value_control.dart';
import '../../editor/presentation/inspector/clip_transform_controls.dart';
import '../../editor/presentation/layout/workspace_panel_tabs.dart';
import '../../preview/engine/software_effect_frame.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:klipio/features/timeline/presentation/timeline_gesture_feedback.dart';
import '../../../core/storage/application_paths.dart';
import '../../../services/diagnostics/performance_diagnostics.dart';
import 'package:video_player/video_player.dart';

import 'package:klipio/app/bootstrap.dart';
import 'package:klipio/core/localization/klipio_localizations.dart';
import 'package:klipio/core/storage/recovering_shared_preferences.dart';
import 'package:klipio/core/theme/app_theme.dart';
import 'package:klipio/features/captions/domain/ass_text.dart';
import 'package:klipio/features/captions/domain/editable_caption.dart';
import 'package:klipio/features/captions/application/caption_project_export.dart';
import 'package:klipio/features/timeline/domain/detach_audio_edit.dart';
import 'package:klipio/features/timeline/domain/linked_audio_edit_guard.dart';
import 'package:klipio/features/captions/domain/caption_style.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/composition/domain/video_geometry.dart';
import 'package:klipio/features/text/presentation/project_text.dart';
import 'package:klipio/features/text/presentation/project_title_view.dart';
import 'package:klipio/features/text/domain/title_visual_state.dart';
import 'package:klipio/features/text/domain/title_project.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';
import 'package:klipio/features/timeline/domain/clip_speed_edit.dart';
import 'package:klipio/features/editor/domain/editor_selection.dart';
import 'package:klipio/features/editor/domain/video_render_settings.dart';
import 'package:klipio/features/editor/domain/video_target_selection.dart';
import 'package:klipio/features/editor/presentation/layout/workspace_panels.dart';
import 'package:klipio/features/editor/presentation/creative_browser.dart';
import 'package:klipio/features/text/domain/text_case.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/export_service.dart';
import 'package:klipio/features/preview/engine/multi_track_preview.dart';
import 'package:klipio/features/preview/engine/preview_controller.dart';
import 'package:klipio/features/preview/engine/professional_clip_preview.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/preview/engine/playable_source_ranges.dart';
import 'package:klipio/features/preview/engine/playback_operation_queue.dart';
import 'package:klipio/features/preview/engine/backend_clip_end_policy.dart';
import 'package:klipio/features/preview/program_monitor/interactive_transform_overlay.dart';
import 'package:klipio/features/settings/data/app_settings.dart';
import 'package:klipio/features/projects/services/editor_project_repository.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/application/timeline_scrub_controller.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/domain/timeline_boundary.dart';
import 'package:klipio/features/timeline/presentation/dynamic_timeline_view.dart';
import 'package:klipio/features/timeline/presentation/timeline_quick_actions.dart';
import 'package:klipio/features/updates/update_service.dart';
import 'package:klipio/services/automation/automation_job.dart';
import 'package:klipio/services/automation/mcp_bridge.dart';
import 'package:klipio/services/capcut/capcut_draft_service.dart';
import 'package:klipio/services/platform/platform_support.dart' as platform;
import 'package:klipio/services/process/windows_process_job.dart';
import 'package:klipio/services/tasks/media_job_manager.dart';

part '../../../app/editor_app_shell.dart';
part '../../home/presentation/editor_home_screen.dart';
part '../../home/presentation/home_migrate_project_to_bundle.dart';
part '../../home/presentation/home_home_export_progress_card.dart';
part '../../projects/services/editor_project_bundle.dart';
part '../../settings/presentation/editor_settings_dialog.dart';
part '../domain/editor_application_types.dart';
part 'editor_screen.dart';
part 'editor_support_widgets.dart';
part '../../settings/presentation/editor_settings_dialog_app_settings_dialog_state.dart';
part '../../settings/presentation/editor_settings_dialog_klipio_update_dialog.dart';
part 'editor_support_widgets_editor_history_snapshot.dart';
part 'editor_support_widgets_text_overlay_draft.dart';
part 'operations/controls_is_light_ui.dart';
part 'operations/controls_show_cap_cut_draft_settings_dialog.dart';
part 'operations/controls_auto_hook_best_moments_seconds.dart';
part 'operations/controls_transition_preset_library.dart';
part 'operations/workspace_panel_color.dart';
part 'operations/workspace_panel_shell.dart';
part 'operations/workspace_clip_inspector.dart';
part 'operations/workspace_text_control_section.dart';
part 'operations/effects_muted_text_color.dart';
part 'operations/preview_monitor_chrome_color.dart';
part 'operations/preview_source_monitor_panel.dart';
part 'operations/preview_program_transport_bar.dart';
part 'operations/preview_live_preview_video.dart';
part 'operations/preview_preview_color_matrix.dart';
part 'operations/automation_sync_mcp_bridge.dart';
part 'operations/projects_open_project_from_mcp.dart';
part 'operations/projects_proxy_cache_folder.dart';
part 'operations/projects_project_media_card.dart';
part 'operations/captions_load_installed_windows_fonts.dart';
part 'operations/captions_select_dynamic_timeline_caption.dart';
part 'operations/captions_manual_caption_editor_controls.dart';
part 'operations/captions_caption_preset_picker.dart';
part 'operations/captions_caption_cues_from_ass.dart';
part 'operations/captions_caption_word_flow.dart';
part 'operations/export_load_export_availability.dart';
part 'operations/export_export_videos_impl.dart';
part 'operations/export_show_export_settings_dialog.dart';
part 'operations/export_export_progress_dialog.dart';
part 'operations/export_build_export_jobs.dart';
part 'operations/timeline_repair_loaded_timeline.dart';
part 'operations/timeline_load_timeline_filmstrips.dart';
part 'operations/timeline_clip_timeline_edit_with_ranges.dart';
part 'operations/timeline_professional_target_clip.dart';
part 'operations/timeline_timeline_panel.dart';
part 'operations/timeline_timeline_tracks.dart';
part 'operations/timeline_timeline_track_label.dart';
part 'operations/timeline_select_timeline_marquee.dart';
part 'operations/timeline_show_timeline_clip_context_menu.dart';
part 'operations/timeline_delete_selected_timeline_items.dart';
part 'operations/timeline_timeline_clip.dart';
part 'operations/media_parse_video_target_expression.dart';
part 'operations/media_set_picked_videos.dart';
part 'operations/media_media_library_panel.dart';
part 'operations/text_text_overlays_from_json.dart';
part 'operations/text_delete_text_overlay_at.dart';
part 'operations/audio_cache_waveform.dart';

KlipioAutomationJob? startupAutomationJob;

Future<void> runKlipioApplication(List<String> args) async {
  startupAutomationJob = KlipioAutomationJob.fromCommandLine(args);
  await bootstrapKlipio(
    app: const KlipioApp(),
    initialize: () async {
      try {
        await (await _klipioDraftsRoot()).create(recursive: true);
      } catch (_) {
        // The editor can still start and report a concrete save error later.
      }
    },
  );
}
