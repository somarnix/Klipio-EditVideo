# Klipio Project Tree

Root: `G:\Klipio`

Package: `klipio`  
Version: `2.0.24+63`  
Platforms: Windows, Android, iOS, and Web scaffolding  
Primary application: Flutter/Dart video editor

This is the canonical filesystem and architecture map for the active Klipio project. Application source, tests, platform runners, tooling, runtime dependencies, installer inputs, and release artifacts are shown below. Generated dependency caches and compiled distributions are summarized rather than expanding hundreds of machine-generated files.

Legend:

- `[source]` maintained application source
- `[test]` automated verification
- `[asset]` packaged runtime content
- `[platform]` Flutter platform runner
- `[tool]` development or packaging automation
- `[generated]` reproducible cache/build output
- `[vendor]` third-party runtime distribution
- `[artifact]` compiled installer or release output
- `[empty]` reserved directory with no current files

## Complete root tree

```text
G:\Klipio\
|-- .dart_tool\                         [generated] Dart/Flutter tool state (67 files)
|   |-- dartpad\
|   |-- extension_discovery\
|   |-- flutter_build\
|   |-- package_config.json
|   |-- package_config_subset
|   `-- version
|-- .git\                               [generated] Git database and history
|-- .idea\                              IDE configuration
|   |-- libraries\
|   |   |-- Dart_SDK.xml
|   |   `-- KotlinJavaRuntime.xml
|   |-- runConfigurations\
|   |   `-- main_dart.xml
|   |-- modules.xml
|   `-- workspace.xml
|-- android\                            [platform] Android runner
|-- apps\
|   `-- desktop\
|       `-- pc-mode\                    [empty] reserved desktop application area
|-- assets\                             [asset] packaged application content
|-- build\                              [generated] Flutter build/test output
|   |-- flutter_assets\
|   |-- native_assets\
|   |-- test_cache\
|   |-- unit_test_assets\
|   |-- windows\
|   `-- .last_build_id
|-- ffmpeg_extracted\                   [vendor] FFmpeg 8.1.2 Windows runtime
|-- image\                              screenshots used by project documentation
|-- installer\                          installer source, payloads, and historical builds
|-- ios\                                [platform] iOS runner
|-- lib\                                [source] Flutter application
|-- mcp_server\                         [tool] Klipio automation/MCP bridge
|-- release\                            [artifact] published and archived Windows installers
|-- test\                               [test] Dart and Flutter test suite
|-- tool\                               [tool] build and maintenance scripts
|-- web\                                [platform] web runner
|-- windows\                            [platform] Windows runner
|-- .flutter-plugins                    [generated]
|-- .flutter-plugins-dependencies       [generated]
|-- .gitattributes
|-- .gitignore
|-- .metadata                           Flutter project metadata
|-- analysis_options.yaml               Dart analyzer rules
|-- BUILD_FULL_WINDOWS_INSTALLER.bat    complete Windows setup entry point
|-- flutter_01.log                      development log
|-- flutter_02.log                      development log
|-- flutter_03.log                      development log
|-- flutter_04.log                      development log
|-- flutter_05.log                      development log
|-- flutter_06.log                      development log
|-- flutter_07.log                      development log
|-- flutter_08.log                      development log
|-- klipio.iml                          IDE module metadata
|-- Project.md                          this project tree
|-- pubspec.lock                        resolved Dart packages
|-- pubspec.yaml                        package, dependency, asset, and version manifest
`-- README.md                           canonical guide and repair report
```

## Application source

The running app starts in the five-line `lib/main.dart`. Its parent library, `editor_application.dart`, connects application shell, home, settings, project storage, support widgets, and editor operations through Dart parts. The editor screen retains fields and lifecycle methods in 833 lines; 45 named operation files hold feature behavior.

Every Dart file under `lib` is below 1,000 lines (largest: 881). Twenty-two empty placeholder folders were removed. The parts still share editor state, so this is a physical decomposition with preserved behavior, not a completed migration to independent controllers. `ModularEditorWorkspace` remains an optional staged composition, not the active application.

Run `powershell -File tool/check_source_structure.ps1` to guard file sizes and empty directories. The full source tree follows.

```text
G:\Klipio\lib
|   main.dart
|
+---app
|       app.dart
|       app_bindings.dart
|       app_routes.dart
|       bootstrap.dart
|       dependencies.dart
|       editor_app_shell.dart
|       klipio_app.dart
|       router.dart
|
+---core
|   +---constants
|   |       app_constants.dart
|   |       editor_constants.dart
|   |       layout_dimensions.dart
|   |
|   +---localization
|   |       klipio_localizations.dart
|   |
|   +---routing
|   |       app_router.dart
|   |       route_names.dart
|   |
|   +---storage
|   |       recovering_shared_preferences.dart
|   |
|   +---theme
|   |       app_colors.dart
|   |       app_spacing.dart
|   |       app_theme.dart
|   |       app_typography.dart
|   |       editor_colors.dart
|   |       editor_styles.dart
|   |       editor_theme.dart
|   |
|   +---utils
|   |       debounce.dart
|   |       debounce_throttler.dart
|   |       duration_utils.dart
|   |       file_system_helper.dart
|   |       file_utils.dart
|   |       logger.dart
|   |       timecode_formatter.dart
|   |
|   \---widgets
|           klipio_button.dart
|           klipio_context_menu.dart
|           klipio_dialog.dart
|           klipio_dropdown.dart
|           klipio_icon_button.dart
|           klipio_icon_toggle.dart
|           klipio_panel.dart
|           klipio_panel_card.dart
|           klipio_slider.dart
|           klipio_tooltip.dart
|
+---features
|   +---adjustments
|   |   \---domain
|   |           adjustment_settings.dart
|   |
|   +---ai
|   |   \---services
|   |           auto_reframe_service.dart
|   |           scene_detector.dart
|   |           silence_remover.dart
|   |
|   +---animations
|   |   \---domain
|   |           clip_animation.dart
|   |
|   +---audio
|   |   +---domain
|   |   |       audio_settings.dart
|   |   |
|   |   \---services
|   |           audio_mixer_service.dart
|   |           waveform_service.dart
|   |
|   +---captions
|   |   +---application
|   |   |       ai_caption_generator.dart
|   |   |
|   |   +---domain
|   |   |       ass_text.dart
|   |   |       caption_cue.dart
|   |   |       caption_segment.dart
|   |   |       caption_style.dart
|   |   |       srt_ass_parser.dart
|   |   |       srt_document.dart
|   |   |
|   |   +---presentation
|   |   |   |   captions_panel_view.dart
|   |   |   |
|   |   |   \---components
|   |   |           subtitle_style_picker.dart
|   |   |
|   |   \---services
|   |           caption_service_io.dart
|   |
|   +---composition
|   |   \---domain
|   |           program_render_snapshot.dart
|   |           render_scene.dart
|   |
|   +---cutout
|   |   \---services
|   |           chroma_key_service.dart
|   |
|   +---editor
|   |   +---application
|   |   |       editor_commands.dart
|   |   |       editor_controller.dart
|   |   |       editor_coordinator.dart
|   |   |
|   |   +---domain
|   |   |       editor_panel_header.dart
|   |   |       editor_selection.dart
|   |   |       resize_handle.dart
|   |   |       video_render_settings.dart
|   |   |       video_target_selection.dart
|   |   |
|   |   \---presentation
|   |       |   editor_page.dart
|   |       |
|   |       +---inspector
|   |       |       inspector_panel.dart
|   |       |
|   |       +---layout
|   |       |       workspace_panels.dart
|   |       |
|   |       \---toolbar
|   |               category_tab_bar.dart
|   |
|   +---editor_shell
|   |   +---domain
|   |   |       editor_application_types.dart
|   |   |
|   |   \---presentation
|   |       |   editor_application.dart
|   |       |   editor_screen.dart
|   |       |   editor_shell_view.dart
|   |       |   editor_support_widgets.dart
|   |       |   editor_support_widgets_editor_history_snapshot.dart
|   |       |   editor_support_widgets_text_overlay_draft.dart
|   |       |   modular_editor_workspace.dart
|   |       |
|   |       +---components
|   |       |       editor_center_workspace.dart
|   |       |       editor_left_nav.dart
|   |       |       editor_status_bar.dart
|   |       |       editor_top_bar.dart
|   |       |
|   |       +---controllers
|   |       |       editor_workspace_controller.dart
|   |       |
|   |       \---operations
|   |               audio_cache_waveform.dart
|   |               automation_sync_mcp_bridge.dart
|   |               captions_caption_cues_from_ass.dart
|   |               captions_caption_preset_picker.dart
|   |               captions_caption_word_flow.dart
|   |               captions_load_installed_windows_fonts.dart
|   |               captions_manual_caption_editor_controls.dart
|   |               captions_select_dynamic_timeline_caption.dart
|   |               controls_auto_hook_best_moments_seconds.dart
|   |               controls_is_light_ui.dart
|   |               controls_show_cap_cut_draft_settings_dialog.dart
|   |               controls_transition_preset_library.dart
|   |               effects_muted_text_color.dart
|   |               export_build_export_jobs.dart
|   |               export_export_progress_dialog.dart
|   |               export_export_videos_impl.dart
|   |               export_load_export_availability.dart
|   |               export_show_export_settings_dialog.dart
|   |               media_media_library_panel.dart
|   |               media_parse_video_target_expression.dart
|   |               media_set_picked_videos.dart
|   |               preview_live_preview_video.dart
|   |               preview_monitor_chrome_color.dart
|   |               preview_preview_color_matrix.dart
|   |               preview_program_transport_bar.dart
|   |               preview_source_monitor_panel.dart
|   |               projects_open_project_from_mcp.dart
|   |               projects_project_media_card.dart
|   |               projects_proxy_cache_folder.dart
|   |               text_delete_text_overlay_at.dart
|   |               text_text_overlays_from_json.dart
|   |               timeline_clip_timeline_edit_with_ranges.dart
|   |               timeline_delete_selected_timeline_items.dart
|   |               timeline_load_timeline_filmstrips.dart
|   |               timeline_professional_target_clip.dart
|   |               timeline_repair_loaded_timeline.dart
|   |               timeline_select_timeline_marquee.dart
|   |               timeline_show_timeline_clip_context_menu.dart
|   |               timeline_timeline_clip.dart
|   |               timeline_timeline_panel.dart
|   |               timeline_timeline_tracks.dart
|   |               timeline_timeline_track_label.dart
|   |               workspace_panel_color.dart
|   |               workspace_panel_shell.dart
|   |               workspace_text_control_section.dart
|   |
|   +---effects
|   |   +---domain
|   |   |       video_effect.dart
|   |   |
|   |   \---engine
|   |           effect_shader_builder.dart
|   |
|   +---export
|   |   +---application
|   |   |       capcut_draft_exporter.dart
|   |   |       export_coordinator.dart
|   |   |
|   |   +---domain
|   |   |       export_config.dart
|   |   |       export_job.dart
|   |   |       export_models.dart
|   |   |       export_preset.dart
|   |   |       export_result.dart
|   |   |       export_settings.dart
|   |   |       program_render_snapshot.dart
|   |   |
|   |   +---presentation
|   |   |   |   export_dialog.dart
|   |   |   |
|   |   |   \---components
|   |   |           export_preset_selector.dart
|   |   |           export_progress_tile.dart
|   |   |
|   |   \---services
|   |           export_service.dart
|   |           export_service_io.dart
|   |           export_service_io_prepared_ffmpeg_arguments.dart
|   |           export_service_io_probe_result.dart
|   |           export_service_io_video_encoder_works.dart
|   |           export_service_stub.dart
|   |           multi_track_filter_builder.dart
|   |
|   +---filters
|   |   \---domain
|   |           filter_preset.dart
|   |
|   +---home
|   |   +---data
|   |   |       recent_project_repository.dart
|   |   |
|   |   +---domain
|   |   |       project_summary.dart
|   |   |
|   |   \---presentation
|   |           editor_home_screen.dart
|   |           home_controller.dart
|   |           home_home_export_progress_card.dart
|   |           home_migrate_project_to_bundle.dart
|   |           home_page.dart
|   |
|   +---inspector
|   |   +---application
|   |   |       inspector_controller.dart
|   |   |
|   |   +---domain
|   |   |       video_render_settings.dart
|   |   |
|   |   \---presentation
|   |       |   inspector_panel_view.dart
|   |       |
|   |       \---tabs
|   |               audio_properties_tab.dart
|   |               canvas_background_tab.dart
|   |               speed_curve_tab.dart
|   |               video_transform_tab.dart
|   |
|   +---keyframes
|   |   +---application
|   |   |       keyframe_interpolator.dart
|   |   |
|   |   \---domain
|   |           keyframe_track.dart
|   |
|   +---masks
|   |   \---domain
|   |           mask_shape.dart
|   |
|   +---media
|   |   +---data
|   |   |       media_probe_repository.dart
|   |   |
|   |   +---domain
|   |   |       media_asset.dart
|   |   |
|   |   \---services
|   |           thumbnail_cache_service.dart
|   |
|   +---media_library
|   |   +---application
|   |   |       media_import_controller.dart
|   |   |
|   |   +---domain
|   |   |       media_item.dart
|   |   |
|   |   \---presentation
|   |       |   media_library_view.dart
|   |       |
|   |       \---components
|   |               import_toolbar.dart
|   |               media_card_item.dart
|   |               media_drop_target.dart
|   |
|   +---preview
|   |   +---application
|   |   |       monitor_player_controller.dart
|   |   |       transform_gizmo_controller.dart
|   |   |
|   |   +---domain
|   |   |       clip_transform.dart
|   |   |       render_scene.dart
|   |   |
|   |   +---engine
|   |   |       multi_track_preview.dart
|   |   |       preview_controller.dart
|   |   |       preview_controller_io.dart
|   |   |       preview_controller_stub.dart
|   |   |       professional_clip_preview.dart
|   |   |       program_timeline_mapper.dart
|   |   |
|   |   +---presentation
|   |   |   |   monitor_panel_view.dart
|   |   |   |
|   |   |   \---components
|   |   |           interactive_gizmo_overlay.dart
|   |   |           monitor_canvas_display.dart
|   |   |           monitor_transport_bar.dart
|   |   |
|   |   +---program_monitor
|   |   |       interactive_transform_overlay.dart
|   |   |       program_monitor.dart
|   |   |       program_monitor_controller.dart
|   |   |       program_overlay_stack.dart
|   |   |       program_transport.dart
|   |   |
|   |   \---source_monitor
|   |           source_monitor.dart
|   |           source_monitor_controller.dart
|   |           source_transport.dart
|   |
|   +---projects
|   |   +---data
|   |   |       autosave_service.dart
|   |   |       backup_service.dart
|   |   |       project_repository.dart
|   |   |       project_serializer.dart
|   |   |
|   |   +---domain
|   |   |       klipio_project.dart
|   |   |       project_metadata.dart
|   |   |       project_model.dart
|   |   |
|   |   \---services
|   |           autosave_manager.dart
|   |           editor_project_bundle.dart
|   |           project_file_storage.dart
|   |
|   +---settings
|   |   +---data
|   |   |       app_settings.dart
|   |   |
|   |   \---presentation
|   |           editor_settings_dialog.dart
|   |           editor_settings_dialog_app_settings_dialog_state.dart
|   |           editor_settings_dialog_klipio_update_dialog.dart
|   |
|   +---speed
|   |   \---domain
|   |           speed_curve.dart
|   |
|   +---stickers
|   |   \---domain
|   |           sticker_asset.dart
|   |
|   +---text
|   |   \---domain
|   |           text_overlay.dart
|   |
|   +---timeline
|   |   +---application
|   |   |       drag_drop_service.dart
|   |   |       snap_service.dart
|   |   |       timeline_controller.dart
|   |   |       timeline_editor.dart
|   |   |       timeline_scrub_controller.dart
|   |   |       timeline_selection_controller.dart
|   |   |       timeline_zoom_controller.dart
|   |   |
|   |   +---domain
|   |   |       clip_effect.dart
|   |   |       clip_keyframe.dart
|   |   |       clip_model.dart
|   |   |       clip_transform.dart
|   |   |       clip_transition.dart
|   |   |       magnetic_track_resolver.dart
|   |   |       timeline_model.dart
|   |   |       timeline_models.dart
|   |   |       track_model.dart
|   |   |
|   |   +---presentation
|   |   |   |   dynamic_clip_widget.dart
|   |   |   |   dynamic_is_light.dart
|   |   |   |   dynamic_timeline_view.dart
|   |   |   |   dynamic_track_row.dart
|   |   |   |   timeline_panel_view.dart
|   |   |   |   timeline_playhead.dart
|   |   |   |   timeline_quick_actions.dart
|   |   |   |   timeline_ruler.dart
|   |   |   |   timeline_toolbar.dart
|   |   |   |
|   |   |   +---clips
|   |   |   |       audio_clip_item.dart
|   |   |   |       caption_clip_item.dart
|   |   |   |       clip_widget.dart
|   |   |   |       video_clip_item.dart
|   |   |   |
|   |   |   +---components
|   |   |   |       timeline_playhead_view.dart
|   |   |   |       timeline_ruler_view.dart
|   |   |   |       timeline_toolbar_view.dart
|   |   |   |       track_headers_column.dart
|   |   |   |       track_lanes_viewport.dart
|   |   |   |
|   |   |   +---headers
|   |   |   |       track_header.dart
|   |   |   |
|   |   |   \---rendering
|   |   |           filmstrip_painter.dart
|   |   |           waveform_painter.dart
|   |   |
|   |   \---rendering
|   |           filmstrip_renderer.dart
|   |           waveform_painter.dart
|   |
|   +---transitions
|   |   \---domain
|   |           transition.dart
|   |
|   \---updates
|       |   update_service.dart
|       |
|       \---services
|               update_service.dart
|
+---services
|   +---automation
|   |       automation_job.dart
|   |       mcp_bridge.dart
|   |
|   +---cache
|   |       cache_cleaner_service.dart
|   |
|   +---capcut
|   |       capcut_draft_service.dart
|   |       capcut_draft_service_built_clip.dart
|   |       capcut_draft_service_text_material.dart
|   |
|   +---ffmpeg
|   |       encoder_probe_service.dart
|   |       ffmpeg_process_runner.dart
|   |       ffmpeg_service.dart
|   |       ffprobe_service.dart
|   |       thumbnail_extractor.dart
|   |
|   +---logging
|   |       app_logger.dart
|   |
|   +---platform
|   |       platform_support.dart
|   |       platform_support_io.dart
|   |       platform_support_stub.dart
|   |       windows_window_manager.dart
|   |
|   +---process
|   |       windows_process_job.dart
|   |
|   \---tasks
|           media_job_manager.dart
|           render_task_queue.dart
|
\---shared
    +---extensions
    |       context_extension.dart
    |       duration_extension.dart
    |       string_extension.dart
    |
    \---models
            picked_video.dart
```

Parent-child ownership:

- `main.dart` -> `editor_application.dart` -> `app/editor_app_shell.dart`.
- Application shell -> home screen -> editor screen.
- Editor screen -> `operations/` for timeline, preview, export, captions, project management, media, audio, text, effects, and workspace controls.
- Timeline parent -> track, clip, ruler, and trim implementations.
- Export parent -> process arguments, media probing, encoder checks, and FFmpeg services.
- CapCut parent -> material serialization and draft storage helpers.
- Existing independent domain models and controllers remain in their feature folders. Shared state decoupling is future work.
## Automated tests

```text
test\
|-- audio\
|   `-- audio_mixer_service_test.dart
|-- captions\
|   |-- ass_text_test.dart
|   `-- srt_document_test.dart
|-- preview\
|   |-- interactive_transform_overlay_test.dart
|   |-- program_timeline_mapper_test.dart
|   `-- render_scene_test.dart
|-- projects\
|   `-- project_serializer_test.dart
|-- timeline\
|   |-- magnetic_track_resolver_test.dart
|   |-- timeline_controller_test.dart
|   |-- timeline_quick_actions_test.dart
|   `-- timeline_scrub_controller_test.dart
|-- audio_waveform_test.dart
|-- dynamic_timeline_view_test.dart
|-- editor_workflow_regression_test.dart
|-- export_service_io_test.dart
|-- media_job_manager_test.dart
|-- process_job_test.dart
|-- timeline_model_test.dart
|-- timeline_thumbnail_test.dart
`-- widget_test.dart
```

Current verified result: 83 tests pass.

## Packaged assets

```text
assets\
|-- branding\
|   |-- KlipioLogo.jpeg
|   |-- Loading.gif
|   |-- OpenAppForPC.mp4
|   |-- OpenAppForPhone.mp4
|   `-- startup_preview.jpg
|-- scripts\
|   |-- ultra_fast_captions.py
|   `-- __pycache__\                    [generated] Python bytecode cache
|-- effects\                            [empty] reserved
|-- filters\                            [empty] reserved
|-- fonts\                              [empty] reserved
|-- icons\                              [empty] reserved
|-- images\                             [empty] reserved
|-- stickers\                           [empty] reserved
|-- text_templates\                     [empty] reserved
`-- transitions\                        [empty] reserved
```

## Windows platform runner

```text
windows\
|-- CMakeLists.txt
|-- flutter\
|   |-- CMakeLists.txt
|   |-- generated_plugin_registrant.cc  [generated]
|   |-- generated_plugin_registrant.h   [generated]
|   `-- generated_plugins.cmake         [generated]
`-- runner\
    |-- resources\
    |   `-- app_icon.ico
    |-- CMakeLists.txt
    |-- flutter_window.cpp
    |-- flutter_window.h
    |-- main.cpp
    |-- resource.h
    |-- runner.exe.manifest
    |-- Runner.rc
    |-- utils.cpp
    |-- utils.h
    |-- win32_window.cpp
    `-- win32_window.h
```

## Android platform runner

```text
android\
|-- app\
|   |-- src\
|   |   |-- debug\
|   |   |   `-- AndroidManifest.xml
|   |   |-- main\
|   |   |   |-- kotlin\com\somarnix\klipio\MainActivity.kt
|   |   |   |-- res\
|   |   |   |   |-- drawable\launch_background.xml
|   |   |   |   |-- drawable-nodpi\launch_image.png
|   |   |   |   |-- drawable-v21\launch_background.xml
|   |   |   |   |-- mipmap-hdpi\ic_launcher.png
|   |   |   |   |-- mipmap-mdpi\ic_launcher.png
|   |   |   |   |-- mipmap-xhdpi\ic_launcher.png
|   |   |   |   |-- mipmap-xxhdpi\ic_launcher.png
|   |   |   |   |-- mipmap-xxxhdpi\ic_launcher.png
|   |   |   |   |-- values\styles.xml
|   |   |   |   `-- values-night\styles.xml
|   |   |   `-- AndroidManifest.xml
|   |   `-- profile\AndroidManifest.xml
|   `-- build.gradle
|-- gradle\wrapper\gradle-wrapper.properties
|-- build.gradle
|-- gradle.properties
`-- settings.gradle
```

## iOS platform runner

```text
ios\
|-- Flutter\
|   |-- AppFrameworkInfo.plist
|   |-- Debug.xcconfig
|   `-- Release.xcconfig
|-- Runner\
|   |-- Assets.xcassets\
|   |   |-- AppIcon.appiconset\         Contents.json plus all iOS icon sizes
|   |   `-- LaunchImage.imageset\       Contents.json plus 1x/2x/3x images
|   |-- Base.lproj\
|   |   |-- LaunchScreen.storyboard
|   |   `-- Main.storyboard
|   |-- AppDelegate.swift
|   |-- Info.plist
|   `-- Runner-Bridging-Header.h
|-- Runner.xcodeproj\                   Xcode project/workspace/scheme metadata
|-- Runner.xcworkspace\                 workspace settings
`-- RunnerTests\
    `-- RunnerTests.swift
```

## Web platform runner

```text
web\
|-- icons\
|   |-- Icon-192.png
|   |-- Icon-512.png
|   |-- Icon-maskable-192.png
|   `-- Icon-maskable-512.png
|-- favicon.png
|-- index.html
`-- manifest.json
```

## Automation and development tools

```text
mcp_server\
|-- claude_desktop_config.json
|-- klipio_mcp_server.py
|-- requirements.txt
|-- setup.bat
|-- test_bridge.py
`-- test_mcp.py

tool\
|-- build_full_windows_installer.ps1
|-- cleanup_old_klipio_artifacts.ps1
`-- requirements-captions.txt
```

## FFmpeg runtime distribution

```text
ffmpeg_extracted\
`-- ffmpeg-8.1.2-essentials_build\
    |-- bin\
    |   |-- ffmpeg.exe
    |   |-- ffplay.exe
    |   `-- ffprobe.exe
    |-- doc\                              35 upstream HTML/CSS documentation files
    |   |-- ffmpeg.html
    |   |-- ffmpeg-all.html
    |   |-- ffmpeg-codecs.html
    |   |-- ffmpeg-filters.html
    |   |-- ffmpeg-formats.html
    |   |-- ffmpeg-protocols.html
    |   |-- ffprobe.html
    |   |-- ffprobe-all.html
    |   |-- ffplay.html
    |   |-- ffplay-all.html
    |   |-- libavcodec.html
    |   |-- libavdevice.html
    |   |-- libavfilter.html
    |   |-- libavformat.html
    |   |-- libavutil.html
    |   |-- libswresample.html
    |   |-- libswscale.html
    |   |-- platform.html
    |   |-- nut.html
    |   `-- additional upstream reference pages and styles
    |-- presets\
    |   |-- libvpx-1080p.ffpreset
    |   |-- libvpx-1080p50_60.ffpreset
    |   |-- libvpx-360p.ffpreset
    |   |-- libvpx-720p.ffpreset
    |   `-- libvpx-720p50_60.ffpreset
    |-- LICENSE
    `-- README.txt
```

This folder is third-party runtime content, not Klipio application source.

## Installer source and historical outputs

```text
installer\
|-- KlipioInstaller\                    [source] .NET 8 self-contained setup
|   |-- KlipioInstaller.csproj
|   |-- Program.cs
|   |-- bin\                            [generated] published .NET runtime/resources
|   `-- obj\                            [generated] MSBuild intermediates
|-- payload\                            [artifact] complete zipped application runtimes
|   |-- KlipioApp-v2.0.12-installer-runtime.zip
|   |-- KlipioApp-v2.0.13-installer-runtime.zip
|   |-- KlipioApp-v2.0.14-installer-runtime.zip
|   |-- KlipioApp-v2.0.15-installer-runtime.zip
|   |-- KlipioApp-v2.0.16-installer-runtime.zip
|   |-- KlipioApp-v2.0.17-installer-runtime.zip
|   |-- KlipioApp-v2.0.18-installer-runtime.zip
|   |-- KlipioApp-v2.0.19-installer-runtime.zip
|   |-- KlipioApp-v2.0.20-installer-runtime.zip
|   |-- KlipioApp-v2.0.21-installer-runtime.zip
|   |-- KlipioApp-v2.0.22-installer-runtime.zip
|   `-- KlipioApp-v2.0.23-installer-runtime.zip
`-- dist\                               [artifact] versioned setup outputs
    |-- v2.0.17-20260901\KlipioSetup.exe + KlipioSetup.pdb
    |-- v2.0.18-20260901\KlipioSetup.exe + KlipioSetup.pdb
    |-- v2.0.19-20260901\KlipioSetup.exe + KlipioSetup.pdb
    |-- v2.0.20-20260901\KlipioSetup.exe + KlipioSetup.pdb
    |-- v2.0.21-20260901\KlipioSetup.exe + KlipioSetup.pdb
    |-- v2.0.22-20260902\KlipioSetup.exe + KlipioSetup.pdb
    `-- v2.0.23-20260902\KlipioSetup.exe + KlipioSetup.pdb
```

The authoritative installer implementation is `installer\KlipioInstaller\Program.cs`. Files under `bin`, `obj`, `payload`, and `dist` are generated or historical artifacts.

## Published release artifacts

```text
release\
|-- Klipio-Windows-Setup.exe
|-- SHA256SUMS.txt
`-- archive\
    |-- Klipio-Windows-Setup-v2.0.19.exe
    |-- Klipio-Windows-Setup-v2.0.20.exe
    |-- Klipio-Windows-Setup-v2.0.21.exe
    |-- Klipio-Windows-Setup-v2.0.22.exe
    `-- installed-app-v2.0.19\
        |-- Klipio.exe
        |-- ffmpeg.exe
        |-- ffprobe.exe
        |-- flutter_windows.dll
        |-- audioplayers_windows_plugin.dll
        |-- desktop_drop_plugin.dll
        |-- video_player_win_plugin.dll
        |-- Uninstall Klipio.cmd
        |-- klipio-language.txt
        |-- native_assets.yaml
        `-- data\                         Flutter AOT code, ICU data, assets, fonts, and shaders
```

Release and installer files are preserved. This tree document does not authorize deleting, rebuilding, moving, or replacing them.

## Documentation images

```text
image\
|-- BUILD_FULL_WINDOWS_INSTALLER\
|   |-- 1786949499580.png
|   |-- 1786949501214.png
|   |-- 1786949503606.png
|   `-- 1786949505443.png
`-- README\
    |-- 1786938305061.png
    `-- 1786938307049.png
```

## Ownership and cleanup boundaries

Authoritative maintained code:

- `lib`
- `test`
- `assets`
- `windows`, `android`, `ios`, and `web`
- `installer\KlipioInstaller`
- `mcp_server`
- `tool`
- root manifests, build entry point, `README.md`, and `Project.md`

Reproducible generated content:

- `.dart_tool`
- `build`
- `assets\scripts\__pycache__`
- `installer\KlipioInstaller\bin`
- `installer\KlipioInstaller\obj`
- generated Flutter plugin registration files

Third-party content:

- `ffmpeg_extracted`

Protected release history:

- `installer\payload`
- `installer\dist`
- `release`

Do not treat generated caches, FFmpeg documentation, zipped runtimes, setup executables, PDB files, DLL files, or AOT output as editable Klipio source. Do not delete protected release history without a separate explicit cleanup request.
