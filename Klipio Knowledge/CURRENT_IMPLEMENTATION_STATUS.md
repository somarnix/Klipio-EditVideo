# Current Klipio Implementation Status
Document: Klipio Current Implementation Status
Product: Klipio
Status: Evidence Register
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: Yes, evidence-based only

Reviewed 2026-09-07 against working tree at commit ce52d76b6140cacaced820e61956904ff065a493. This is a bounded source/test inspection, not a complete audit. No tests, benchmark, installer or runtime were executed for this documentation update. Existing tests are evidence of intended coverage, not passing results today. All source paths in this document are repository-relative paths. The future book must not be read as this status report.

Evidence Commit is conservatively recorded as Not verified per row: the earlier review recorded a working-tree base revision, but did not establish row-by-row commit-level provenance. The header SHA must not be treated as a fresh verification of every row. No source tests were rerun during this consistency cleanup.

## Status vocabulary

New source work is recorded separately in
[Source implementation report — 2026-09-07](SOURCE_IMPLEMENTATION_REPORT_2026-09-07.md).
It verifies two bounded render-snapshot corrections with automated tests; it
does not upgrade every historical feature row below to Verified or Released.

- Proposed: idea or roadmap item only.
- Specified: expected behavior is documented; implementation is not confirmed.
- In Development: active implementation exists but is incomplete.
- Partial: meaningful behavior exists but the full feature contract is not satisfied.
- Implemented: expected implementation exists in source; this does not imply successful tests.
- Verified: relevant tests or explicit manual evidence have checked the implementation.
- Released: the verified feature exists in a shipped Klipio release.
- Needs Refactor: existing behavior violates architecture or maintainability expectations.
- Needs Verification: insufficient source evidence for a stronger claim.
- Blocked: a concrete unresolved dependency prevents implementation.

Statuses describe the named feature scope, not the entire system. Partial never means all remaining behavior is known missing. No row is marked Verified or Released based on filenames or past conversational claims.

| System | Feature | Status | Current Implementation | Evidence | Evidence Commit | Known Problems | Next Action |
|---|---|---|---|---|---|---|---|
| Project System | Serialization | Partial | ProjectSerializer delegates JSON conversion | lib/features/projects/data/project_serializer.dart; test/projects/project_serializer_test.dart | Not verified | Round-trip test is not migration/recovery proof | Trace active save path and historical fixtures |
| Media Import | Probe and asset registration | Needs Verification | Probe repository and media operation files located | lib/features/media/data/media_probe_repository.dart; lib/features/editor_shell/presentation/operations/media_set_picked_videos.dart | Not verified | Complete active import lifecycle not audited | Verify seven imports and failure recovery |
| Timeline | Track/clip editing | Partial | Timeline model and magnetic tests present | lib/features/timeline/domain/timeline_models.dart; test/timeline_model_test.dart; test/timeline/magnetic_track_resolver_test.dart | Not verified | Tests identified, not rerun | Run boundary and randomized invariant tests |
| Clip Operations | Split/trim/move | Partial | Tests specify linked edits, keep-before/after and source timing | test/timeline_model_test.dart; test/dynamic_timeline_view_test.dart | Not verified | Playback boundary parity still unverified | Compare exact source frames across edits |
| Selection | Multiple clip IDs | Partial | Controller implements selectOnly/toggle/replace/range | lib/features/timeline/application/timeline_selection_controller.dart; test/timeline/timeline_controller_test.dart | Not verified | All active inspector consumers not traced | Verify mixed values and stale input |
| Undo / Redo | History integration | Needs Verification | Undo call sites and history snapshot file located | lib/features/editor_shell/presentation/editor_support_widgets_editor_history_snapshot.dart | Not verified | Full command coverage not established | Trace execute/undo/redo across feature groups |
| Playback | Boundary advancement | Needs Refactor | Reviewed listener advances near source end with margins | lib/features/editor_shell/presentation/operations/preview_monitor_chrome_color.dart | Not verified | Timing risk is hypothesis, not reproduced result | Add labeled-frame boundary fixture before changing margins |
| Preview | Native controller | Partial | VideoPlayerController initialization exists | lib/features/preview/engine/preview_controller_io.dart; test/preview/program_timeline_mapper_test.dart | Not verified | Readiness/long playback not tested this review | Measure seek and clip switching |
| Rendering | Snapshot/scene contract | Partial | ProgramRenderSnapshot and geometry tests exist | lib/features/composition/domain/program_render_snapshot.dart; test/preview/render_scene_test.dart | Not verified | Shared state does not prove equal rendered output | Create backend conformance comparisons |
| Transform | Interactive geometry | Partial | Overlay and settings regression tests exist | test/preview/interactive_transform_overlay_test.dart; test/editor_workflow_regression_test.dart | Not verified | Real export parity unverified | Test ratios, crop, rotation and caption bounds |
| Text | Overlay model | Needs Verification | Text overlay model and editor operations located | lib/features/text/domain/text_overlay.dart | Not verified | Font/shaping pipeline not fully audited | Verify Khmer layout and font fallback |
| Captions | ASS/SRT and worker | Partial | Generation entry points and formatting tests located | lib/features/captions/services/caption_service_io.dart; test/captions/srt_document_test.dart; test/export_service_io_test.dart | Not verified | Batch/reopen/real-media behavior unverified | Test partial batch and timing/style parity |
| Audio | FFmpeg mixing helper | Partial | buildFilter creates trim/gain/fades/delay/amix chain | lib/features/audio/services/audio_mixer_service.dart; test/audio/audio_mixer_service_test.dart | Not verified | Test checks graph strings, not rendered sync or realtime DSP | Render audio fixtures and test active integration |
| Effects | Filter mapping | Partial | EffectShaderBuilder maps selected effects to FFmpeg strings | lib/features/effects/engine/effect_shader_builder.dart | Not verified | Fallback emits null; name does not prove GPU shader engine | Audit unsupported types and parity |
| Filters | Preset definition | Partial | FilterPreset stores ID/category/LUT path/values | lib/features/filters/domain/filter_preset.dart | Not verified | Model alone does not establish applied LUT rendering | Trace preset application/export |
| Transitions | Model exposure | Needs Verification | Feature file re-exports timeline transition types | lib/features/transitions/domain/transition.dart | Not verified | Renderer/handle behavior not audited | Trace transition rendering and tests |
| Animation | Clip animation model | Needs Verification | Domain file located | lib/features/animations/domain/clip_animation.dart | Not verified | Playback/export use not established | Trace evaluation and fixtures |
| Keyframes | Numeric interpolation | Partial | Interpolator implements linear/ease numeric values | lib/features/keyframes/application/keyframe_interpolator.dart | Not verified | Active path and all property types unverified | Test endpoint and export behavior |
| Masks | Shape data | Partial | MaskShape stores type, geometry, feather and invert | lib/features/masks/domain/mask_shape.dart | Not verified | No full rendering proof from model | Trace mask backend and edge tests |
| Color | Basic effect mapping | Partial | Brightness/contrast/saturation/gamma string mapping inspected | lib/features/effects/engine/effect_shader_builder.dart | Not verified | Not evidence of managed color/HDR/scopes | Specify color pipeline and chart tests |
| Speed | Snapshot speeds and curve data | Needs Refactor | Snapshot receives media-path speed map; curve holds points | lib/features/composition/domain/program_render_snapshot.dart; lib/features/speed/domain/speed_curve.dart | Not verified | Per-clip independent speed/ramp integration unverified | Test duplicate source instances; plan compatibility migration |
| Export | Worker and regression suite | Partial | Export/cancellation/ASS test cases identified | lib/features/export/services/export_service_io.dart; test/export_service_io_test.dart | Not verified | Tests not executed; installed artifact not checked | Run output and cancellation fixtures |
| FFmpeg | Processing adapter | Needs Verification | Platform and export adapters located | lib/services/platform/platform_support_io.dart; lib/features/export/services/export_service_io_prepared_ffmpeg_arguments.dart | Not verified | Bundled capabilities not inspected this task | Record executable version and test supported filters |
| Autosave | Serial coalescing | Partial | AutosaveManager delays and serializes save callback | lib/features/projects/services/autosave_manager.dart | Not verified | Failure retry and active wiring require verification | Inject save failure and concurrent edits |
| Recovery | Backup helpers | Needs Verification | Backup and bundle functions located | lib/features/projects/data/backup_service.dart; lib/features/projects/services/editor_project_bundle.dart | Not verified | Crash/journal recovery not demonstrated | Interrupt saves on copies and verify restore |
| Cache | Thumbnails/waveforms | Partial | Cache wrappers and media analysis test cases located | lib/features/media/services/thumbnail_cache_service.dart; test/audio_waveform_test.dart; test/timeline_thumbnail_test.dart | Not verified | Eviction and source identity not fully audited | Test seven assets, stale results and bounded storage |
| Proxy | Background source jobs | Partial | Operation references generateProxyMedia and per-source job map | lib/features/editor_shell/presentation/operations/media_parse_video_target_expression.dart | Not verified | Mapping and resource limits need runtime evidence | Test proxy/original parity and cancellation |
| Performance | Scheduling and virtualization | Needs Verification | Tests cover concurrency and off-screen clip construction | test/media_job_manager_test.dart; test/dynamic_timeline_view_test.dart | Not verified | No benchmark measurements collected | Run defined Small/Medium/Large workloads |
| AI | Centered reframe helper | Partial | centeredCrop computes geometric crop | lib/features/ai/services/auto_reframe_service.dart | Not verified | Not AI tracking; broader AI capability not established | Label capability accurately; evaluate separate analysis adapters |
| Cloud | Sync/backends | Needs Verification | Knowledge specifications exist; source inventory insufficient | Klipio Knowledge/09_BACKEND_CLOUD/Specification.md | Not verified | No production service evidence in this review | Audit source/services before claiming absent or implemented |
| Content Library | Versioned registry | Needs Verification | Preset/model paths exist; registry lifecycle not established | lib/features/filters/domain/filter_preset.dart; Klipio Knowledge/08_ASSET_CONTENT_SYSTEM/Specification.md | Not verified | Package/download/pinning evidence insufficient | Trace registry or implement after specification |
| Templates | Parameterized composition templates | Needs Verification | Target specification exists | Klipio Knowledge/01_KLIPIO_MASTER_BLUEPRINT/English.md | Not verified | Working template engine not established | Audit instantiation and dependency support |
| UI System | Named component specification | Specified | Expanded documentation only | Klipio Knowledge/03_UI_UX_DESIGN_SYSTEM/06_Component_Library.md | Not verified | No claim named controls exist in code | Map existing widgets before implementation |

## Promotion rule

Before Verified, record functional correctness, UI compliance, keyboard/accessibility, undo, save/reopen, parity, loading/empty/error/retry, cancellation, performance where relevant, automated results and documentation. A waiver needs owner/reason. Before Released, record version, artifact digest, installation smoke tests and approval. Update this report with evidence after implementation, not merely after editing a blueprint.
