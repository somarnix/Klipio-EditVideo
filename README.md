# Klipio

Klipio is a Flutter video editor for Windows and Android. The active source tree is `G:\Klipio`. The current package version is `2.0.24+63`.

The 2.0.24 Windows setup is built from the repaired source. Its runtime includes Flutter, FFmpeg/FFprobe, Python, Faster-Whisper dependencies, and the default English base.en speech model. Other speech models may require an initial download. Setup offers an installation drive and folder selector. Source and projects must not be used as the installation folder.

This document is the canonical project guide and repair report. It replaces the obsolete `PROJECT_STRUCTURE_AND_FLOW.txt`, which described version `2.0.7+46` and an old source path.

## Current repair status

The source repair described below is complete and validated on 2026-09-06. No installer or application EXE was built, replaced, moved, or deleted during this repair. Existing files in `release`, `installer/payload`, and the installed application remain untouched.

Validation result:

- `flutter analyze`: no issues
- `flutter test`: 83 tests passed
- focused timeline/editor interaction tests: 24 tests passed
- `git diff --check`: no whitespace errors
- Windows installer build: intentionally not run

## What Klipio supports

- Multiple imported videos and one timeline per composition
- Independent speed, scale, zoom, position, flip, canvas, and source-audio settings
- Explicit application of selected settings to chosen videos
- Timeline trim, split, delete, move, transitions, effects, keyframes, text, and captions
- AI caption generation from the edited program range
- Local FFmpeg video export
- CapCut draft export
- Project autosave, backups, thumbnails, proxies, and recovery metadata
- Self-contained Windows setup with selectable installation drive

## The six-part repair

### 1. Correct settings when changing videos

Problem: the inspector changed to another video, but the preview controller could retain speed or volume from the previously selected video.

Repair:

- Selecting a video now applies that video's saved playback speed and source-audio volume to the preview controller.
- Seeking, playing, and crossing a program-timeline clip boundary now resolve settings from the active clip.
- Program playback no longer depends on whichever inspector values happened to be visible last.

Primary implementation: `lib/features/editor_shell/presentation/editor_application.dart` and `lib/features/composition/domain/program_render_snapshot.dart`.

### 2. Canonical independent settings and Apply selected

Problem: Apply selected could reuse stale global canvas values, and audio matching could affect an unrelated audio layer with the same file path.

Repair:

- Added immutable `VideoRenderSettings` as the captured setting contract.
- Apply selected reads frame and canvas values from the actual selected timeline clip.
- Frame, canvas, and linked source audio can be copied independently.
- Locked tracks are preserved.
- Only linked source-audio clips receive the copied source volume; independent audio layers are not changed.
- A later edit followed by Apply selected captures the new live values instead of replaying an old application.

Target selection accepts:

- `all`
- `1,10`
- `1 to 10`
- `1,2,4 to 7,9,10`
- hyphen, en dash, and em dash ranges

Primary implementation: `lib/features/editor/domain/video_render_settings.dart` and `lib/features/editor/domain/video_target_selection.dart`.

### 3. One render snapshot for preview and export

Problem: program preview and export rebuilt timing separately. That allowed speed, source time, canvas, crop, scale, zoom, position, and audio to disagree between the editor and exported file.

Repair:

- Added `ProgramRenderSnapshot`, an immutable snapshot built from the authoritative timeline and the per-video speed map.
- Both program preview and both local export paths consume the same retimed output timeline.
- Scene resolution uses the same playback speed when converting output time back to source time.
- Linked audio volume is selected by exact clip link first, with a safe same-media fallback for older saved projects.
- Export begins from captured timeline state, so changing another inspector selection cannot mutate a running export.

Canonical flow:

```text
Imported media
    -> per-video edit state
    -> TimelineModel (source time)
    -> ProgramRenderSnapshot
       -> output TimelineModel (retimed)
       -> clip playback speed and linked volume
       -> RenderScene composition coordinates
    -> Program Monitor and FFmpeg export
```

Primary implementation: `lib/features/composition/domain/program_render_snapshot.dart`, `lib/features/composition/domain/render_scene.dart`, and `lib/features/editor_shell/presentation/editor_application.dart`.

### 4. Regression coverage

Added editor workflow regression tests for:

- exact mixed video selection syntax
- picture, canvas, and linked-audio setting propagation
- independent audio preservation
- latest Apply selected values replacing older applied values while locked tracks remain protected
- different speeds and volumes for consecutive videos
- retimed output duration
- source-frame resolution at non-1x speed

Existing tests also cover timeline interactions, trim handles, program mapping, caption documents, waveforms, export processing, export cancellation, media job scheduling, home/export UI, narrow layouts, and startup.

Primary test: `test/editor_workflow_regression_test.dart`.

### 5. Long-video responsiveness, thumbnails, and cancellation

Problem: long media could create many simultaneous or repeated FFmpeg workers. A stalled worker could keep CPU, memory, disk, or GPU resources occupied after the UI appeared canceled.

Repair:

- Reduced the global media worker default from three concurrent jobs to two.
- Limited thumbnail and probe work to one worker each.
- Timeline thumbnails are generated four samples per FFmpeg process instead of one process per frame, reducing Windows process churn by up to 75%.
- Export cancellation waits for tracked workers to exit.
- If graceful cancellation exceeds eight seconds, Klipio force-terminates its media worker process trees and waits again before reporting completion.
- Export workers that make no progress for 90 seconds are stopped.
- Caption workers that make no progress for three minutes are stopped.
- Background media tasks remain lower priority than interactive/export work.

These controls reduce the risk of the black-screen or whole-PC slowdown reported with long videos. A real-device stress run with the user's longest media is still required before publishing a release installer.

Primary implementation: `lib/services/tasks/media_job_manager.dart`, `lib/services/platform/platform_support_io.dart`, `lib/features/export/domain/export_models.dart`, `lib/features/export/services/export_service_io.dart`, `lib/features/captions/services/caption_service_io.dart`, and `lib/features/editor_shell/presentation/editor_application.dart`.

### 6. Dead-code and documentation cleanup

Removed verified unreachable code:

- legacy blocking caption settings dialog
- legacy compact controls panel
- older duplicate controls panel
- obsolete combined effects controls section
- unused folder-opening helper
- unused platform wrapper functions and fake media metadata placeholders from `main.dart`
- duplicated export retiming implementation
- obsolete project structure report with the wrong path and old version

The main editor is still a large integrated widget. It is production code, not safe to delete wholesale. Further extraction should be incremental and test-backed.

Binary cleanup was intentionally not performed. Old payload ZIPs and the existing setup EXE were preserved because deleting release artifacts is destructive and the repair request explicitly said not to remove the EXE.

## Professional editor interaction upgrade

The second repair pass completes four interaction systems that were only partial in the older integrated editor.

### Magnetic primary timeline

`MagneticTrackResolver` is now the single immutable ripple-edit engine for the primary video story:

- Trimming the start or end closes or restores the resulting timeline space.
- Deleting a primary clip removes its exactly linked source-audio clip and closes the gap.
- Inserting on the primary track places the clip between story clips and pushes later content right.
- Later primary clips, exact linked audio, and unlocked secondary items anchored after the edit boundary move by the same delta.
- Locked video, text, overlay, and audio tracks do not move.
- Start trims advance source time and rebase keyframes; end trims discard keyframes beyond the new edge.
- Every operation returns a new normalized `TimelineModel` and recalculates duration.

`TimelineEditor` delegates primary trim, delete, and insert operations to this resolver. The visual trim gesture keeps one immutable start model for the complete drag, previews the ripple live, and commits one undoable edit on release.

Primary implementation: `lib/features/timeline/domain/magnetic_track_resolver.dart` and `lib/features/timeline/application/timeline_editor.dart`.

### Coalesced 60 FPS timeline scrubbing

The playhead is no longer driven by root-widget `setState` calls during every pointer movement:

- `TimelineScrubController` publishes `Duration` through a `ValueNotifier` immediately.
- The blue playhead repaints through a local `ValueListenableBuilder`.
- Only one approximate media seek can run at a time.
- Rapid pointer updates are coalesced to the newest pending target and throttled to a 16 ms interval.
- A render snapshot is captured once for the drag instead of rebuilding timeline timing for every pixel.
- Releasing the pointer waits for pending approximate work, then performs one exact final seek and inspector synchronization.
- Approximate seeks avoid paused-frame priming and unnecessary inspector/root rebuild work.

Primary implementation: `lib/features/timeline/application/timeline_scrub_controller.dart`, `lib/features/timeline/presentation/dynamic_timeline_view.dart`, and `lib/features/editor_shell/presentation/editor_application.dart`.

### Direct Program Monitor transform controls

The old four-corner-only frame overlay was removed. The selected video frame now uses the same `ClipTransform` contract stored in the timeline and consumed by export:

- Drag inside the frame to move it.
- Drag four corner handles for uniform scaling.
- Drag four edge handles for independent X or Y scaling.
- Drag the rotation handle above the frame to rotate.
- Snap to horizontal or vertical center within five pixels, with visible yellow guides and haptic feedback where supported.
- Show a 10% safe-margin guide.
- Preview opacity, flip, position, scale, and rotation from the active timeline clip.
- Persist changes to the selected clip, per-video editor state, autosave data, undo history, and the export render snapshot.

Primary implementation: `lib/features/preview/program_monitor/interactive_transform_overlay.dart` and `lib/features/editor_shell/presentation/editor_application.dart`.

### Multi-selection and contextual batch actions

Timeline selection now has a complete action flow:

- Click selects one item.
- Ctrl-click toggles individual clips.
- Shift-click selects a range on the same track.
- Dragging empty timeline space creates a marquee across video, audio, text, caption, and music items.
- A contextual toolbar appears above the timeline for selected video clips.
- Available quick actions are Split, Speed 0.5x/1x/1.5x/2x, Delete Ripple, and Sync Settings.
- Sync Settings copies the active selected clip's current frame, rotation, opacity, blend, canvas, speed, and linked source-audio level to the exact selected clips.
- Exact-clip synchronization does not modify an unselected split's frame or linked audio, independent music, or locked tracks. Speed remains a per-imported-video setting, matching Klipio's existing render contract.

Primary implementation: `lib/features/timeline/presentation/timeline_quick_actions.dart`, `lib/features/editor/domain/video_render_settings.dart`, `lib/features/timeline/presentation/dynamic_timeline_view.dart`, and `lib/features/editor_shell/presentation/editor_application.dart`.

### Interaction regression coverage

New tests cover:

- ripple start/end trim, delete, insert, linked audio, anchored secondary layers, and source-time rebasing
- coalesced approximate seeks and one exact release seek
- all eight scale handles, move control, and reachable rotation control
- contextual toolbar callbacks and speed presets
- exact selected-clip setting synchronization without touching an unselected split or independent audio
- existing Ctrl/Shift selection, cross-track marquee, off-screen virtualization, and one-commit trim behavior

Primary tests: `test/timeline/magnetic_track_resolver_test.dart`, `test/timeline/timeline_scrub_controller_test.dart`, `test/preview/interactive_transform_overlay_test.dart`, `test/timeline/timeline_quick_actions_test.dart`, `test/dynamic_timeline_view_test.dart`, and `test/editor_workflow_regression_test.dart`.

## Project architecture

`lib/main.dart` is a five-line entry point. `editor_application.dart` declares the imports and Dart library parts. `app/editor_app_shell.dart` owns application startup UI; home, settings, project storage, support widgets, and editor operations live in separate files. `editor_screen.dart` owns the editor fields and Flutter lifecycle methods (833 lines).

The running editor uses 45 named operation files, grouped by captions, export, timeline, preview, projects, media, audio, workspace, text, and controls. Dart library parts preserve private state access and existing call behavior. Home and timeline rendering also separate operations from their parent widgets. Export workers, CapCut draft serialization, settings dialogs, and support classes have been split at complete Dart declaration boundaries.

All production Dart files under `lib` are below 1,000 lines. The largest is currently `multi_track_filter_builder.dart` at 881 lines. Twenty-two empty placeholder directories were removed; no files were inside them. Run `powershell -File tool/check_source_structure.ps1` to check the size limit, empty folders, and accidental truncated source.

This is physical modularization of the existing runtime, not full state decoupling: the editor operation parts still share `_EditorScreenState`. The separate `ModularEditorWorkspace` is a staged composition example and is not the default runtime. Wiring its independent controllers into the mature editor requires further behavior tests. File splitting alone does not establish a playback or export performance improvement.

The previous interrupted extraction had inserted a truncation marker into `editor_screen.dart`. Its complete source was recovered from the Flutter test kernel cache produced by the earlier successful test run before applying this split.

```text
lib/
  main.dart                         five-line startup entry point
  app/                              bootstrap, routing, dependencies
  core/                             theme, localization, storage, utilities
  features/
    editor_shell/                   parent workspace and compatibility editor
    composition/domain/             shared render snapshot and scene resolver
    editor/                          selection, exact batch settings, workspace UI
    timeline/                        magnetic editing, scrub state, tracks and widgets
    preview/                         source/program engines and transform controls
    inspector/                       selected-clip properties and settings tabs
    media_library/                   import controller and asset browser
    captions/                        caption models and worker service
    export/                          export models, coordinator, FFmpeg filters
    media/                           probe and thumbnail cache
    projects/                        project serialization, autosave, backups
    audio/, text/, effects/, ...     specialist editing features
  services/
    platform/                        desktop/mobile platform media operations
    tasks/                           bounded worker scheduling
    process/                         Windows process-tree ownership
    capcut/                          CapCut draft generation
    automation/                      automation bridge and jobs

test/                               unit, integration, and widget regression tests
assets/                             branding and packaged runtime assets
ffmpeg_extracted/                   FFmpeg source/runtime staging
installer/KlipioInstaller/          self-contained Windows setup source
installer/payload/                  packaged historical/current runtimes
tool/                               build and maintenance scripts
release/                            published installer and checksum
```

## Runtime and project data

Klipio source code may live on `G:` while an installed app lives on any drive selected during setup. A correctly built setup contains the complete Windows runtime and FFmpeg tools; the installed app must not depend on the source drive.

Managed projects are stored by default at:

```text
C:\Users\<user>\Klipio Drafts\<project name>\
  project.klipio.json
  project-meta.json
  Resources\
    Media\
    Audio\
    Images\
  Timelines\timeline.json
  Cache\
    Thumbnails\
    Proxies\
  Backups\project.previous.klipio.json
```

Source media can remain on another drive, but that drive must be connected while editing or exporting unless the media was copied into the project resources. If an installed app reports that `G:` is unavailable at startup, the installed runtime is stale or incomplete and should be replaced only after a new self-contained setup is built and verified.

## Editing workflow

1. Create or open a project.
2. Import files, a folder, or dropped media.
3. Select an imported video or timeline clip.
4. Edit its own speed, frame, canvas, and source-audio values.
5. Ctrl-click, Shift-click, or marquee-select timeline items when a batch edit is needed.
6. Use the contextual toolbar for split, speed, ripple delete, or exact Sync Settings.
7. Use Apply selected when settings should instead be copied by imported-video number.
8. Enter target video numbers or ranges and choose which setting groups to copy.
9. Continue editing any target independently after the copy.
10. Save or allow autosave to write the project bundle.

Reset frame affects the current frame transform. It does not silently restore an older Apply selected snapshot.

## Caption workflow

1. Edit the timeline first: trim, split, delete, move, speed-change, or create hooks.
2. Open AI Captions.
3. Choose one video, all videos, or an exact target expression.
4. Generate captions. Each video reports its own 1-100% progress, while the batch reports the current item such as `5 of 10`.
5. Regenerate a video's captions after materially changing that video's edited duration.
6. Move or style caption clips on the text track; locked caption tracks are protected.

Caption generation uses the edited program range rather than blindly transcribing the entire original source. Removed videos and their caption state must not be reintroduced into a new active composition.

## Export workflow

Local export and CapCut draft export use the selected compositions, not just the currently highlighted inspector item.

- Separate export: each selected video creates its own output.
- One timeline video/draft: selected videos are kept together.
- Number range: a start of `6` and five selected videos produces `6` through `10` automatically.
- Explicit end: the number of selected outputs must match the inclusive range.
- Rename tokens: `{n}`, `{index}`, `{title}`, and `{name}`.

During a batch, each video has its own 0-100% progress. The dialog also shows `Exporting N of total`; this is deliberately per-video progress, not one ambiguous percentage across all files.

Cancel is complete only after the current worker process tree has exited. If a worker stalls, Klipio escalates from graceful stop to process-tree termination.

## Development

Requirements:

- Flutter compatible with Dart SDK `^3.5.3`
- Windows desktop development tools for Windows builds
- .NET 8 SDK for the setup project
- FFmpeg and FFprobe in the packaged runtime or `ffmpeg_extracted`

Common commands from `G:\Klipio`:

```powershell
flutter pub get
flutter run -d windows
dart format lib test
flutter analyze
flutter test
```

Do not run the installer build for a source-only validation.

When a release is approved, the full setup builder is:

```powershell
.\BUILD_FULL_WINDOWS_INSTALLER.bat
```

It restores packages, builds the Windows release, verifies FFmpeg and FFprobe, packages the complete runtime, publishes a self-contained setup, and writes `release\SHA256SUMS.txt`. The setup lets the user choose a drive and install folder.

## Release checklist

Before creating a new setup EXE:

- Run `flutter analyze` and the full `flutter test` suite.
- Test video selection changes with different speed and volume values.
- Test Apply selected twice after changing the source video's settings.
- Verify an independent music/audio layer is not modified by source-audio copying.
- Compare program preview and export for 9:16, 3:4, 1:1, and 16:9 compositions.
- Compare canvas blur/color/pattern, crop, scale, zoom, position, flip, caption position, and caption size.
- Export at least two different source videos as one batch.
- Confirm each item progresses from 0-100% and advances to the next item.
- Cancel a long export and a long caption job; confirm no Klipio FFmpeg or caption worker remains.
- Stress-test the longest real video while watching CPU, memory, GPU, and disk usage.
- Install the setup to `C:` and a second drive, disconnect the source drive, and launch the installed app.
- Verify setup version, app version, checksum, shortcuts, upgrade, and uninstall behavior.

## Known remaining engineering work

- The editor's operation parts still share state. Further architectural work should move state ownership into tested feature controllers; the new file boundaries make those migrations easier to review.
- Automated tests use generated short media. Long-video and GPU behavior must also be verified on the target Windows PC.
- Historical installer payload ZIPs consume repository space. Remove or archive them only in a separately approved release-artifact cleanup; do not mix that destructive operation with source repair.
- The current repaired source is not a published version until a new version is chosen, built, installed, and smoke-tested.

## Troubleshooting

### Preview is blank or says it is preparing

- Confirm the source drive is connected and the media path still exists.
- Wait for the lightweight proxy to finish.
- Check free space in the project cache drive.
- Reopen the project after removing only disposable cache files, not project JSON or source media.

### Export stays at 0%

- Allow up to 90 seconds for initial probing/filter setup on difficult media.
- If there is still no worker progress, Klipio stops the worker and reports an error.
- Use Cancel and wait for the canceled status before closing Klipio.
- Check that the output folder exists, is writable, and has sufficient free space.

### Installed app asks for `G:`

The old installed package likely references source-drive files or was launched from an incomplete runtime. The repair in this source tree does not modify the existing installation. Build a new full setup only after the release checklist passes, then install its complete runtime to the chosen drive.

### Export looks different from preview

Reproduce with one short clip and record the aspect ratio, scale X/Y, zoom, position, canvas mode, caption style, and speed. The repaired path shares timing and render state, so a remaining mismatch should be isolated as a specific FFmpeg filter or overlay conversion instead of being hidden by different timeline snapshots.

## Safety notes

- Project JSON, source media, exports, and user settings were not deleted by this repair.
- Existing EXE/setup files were not deleted or overwritten.
- No new EXE was generated.
- Generated build folders, logs, caches, and historical payloads are not authoritative source code.
- The authoritative repair is the Dart/C#/script source plus passing analyzer and test results.
