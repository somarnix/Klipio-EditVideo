# Klipio Editor Improvement Plan

Date: 2026-09-07
Status: source-review findings and proposed work; not implemented fixes.

## Scope and conclusion

Relevant Klipio Playback Engine, Klipio Render Engine, media caching, and Klipio Project State code was reviewed. External research is isolated below. This was not a complete audit or side-by-side runtime benchmark. Smoothness reported by the user is important feedback, but the exact cause has not been measured.

Recommendation: retain Flutter for Klipio's interface. Improve playback correctness, rendering agreement, cache behavior, and state ownership before considering a framework rewrite. More files or a different programming language do not automatically make an editor faster.

## Priority 1 — Precise clip-boundary playback

Observation: reviewed playback logic advances near sourceEnd minus 0.10 seconds. Other skip logic contains approximately 0.12-second boundary margins.

Risk: an early-switch policy may omit visible material or disagree with exported cuts. This is a hypothesis requiring reproduction, not a proven diagnosis of every cutting problem.

Proposed work:

1. Add a labeled-frame fixture before modifying the thresholds.
2. Trace sequence time, mapped source time, active clip ID, and requested switch.
3. Separate preparation of the next clip from its actual presentation time.
4. Resolve boundaries using the canonical timeline interval convention.
5. Test speed changes, adjacent clips, gaps, and end-of-sequence behavior.

Do not simply replace every tolerance with zero: decoder latency and timestamp granularity still need an explicit policy. Prefetch can happen early; presenting the next clip must respect sequence timing.

Acceptance: no unintended missing/duplicated boundary frames in reference output; preview presents the correct clip for the tested sequence times; audio continuity is checked.

## Priority 2 — Preview/export agreement

Observation: Klipio has ProgramRenderSnapshot, but sharing timing/state does not itself prove that preview and export produce matching geometry or text.

Proposed work:

- Capture immutable project revision and exact output dimensions.
- Define transform order, crop space, contain/cover, canvas placement, and caption units.
- Resolve fonts and styles consistently.
- Compare actual rendered frames at the same sequence timestamps.
- Reject or disclose unsupported processing rather than omitting it silently.

Acceptance: test 3:4, 9:16, 1:1, and 16:9; nonuniform scale; zoom; position; rotation; blur canvas; English/Khmer captions. Check dimensions and geometry separately from lossy color differences.

## Priority 3 — Bounded frame preparation

Proposal: the Klipio Playback Engine should evaluate bounded current/next-frame preparation through its own backend and contracts.

Proposed work:

- Determine which frame/controller reuse operations the existing native backend supports.
- Reuse active playback resources where safe.
- Prepare upcoming media with a strict memory/controller limit.
- Tag seek and load requests so stale results cannot replace newer ones.
- Release resources when evicted, cancelled, or no longer needed.
- Retain a fallback for codecs or devices that cannot use the preferred path.

Acceptance: repeated scrubbing and clip switching do not grow memory indefinitely. Upcoming preparation does not starve interactive playback, export, or cancellation.

## Priority 4 — Narrow UI updates

Observation: multiple operation files still share _EditorScreenState, and _updateEditor wraps setState. This is a coupling concern; it does not prove that the entire editor rebuilds on every frame. The existing live-playhead path should be measured before replacing it.

Proposed work:

1. Profile a release-like/profile workload, not just debug behavior.
2. Record which widgets rebuild during playback, dragging, and thumbnail completion.
3. Keep playhead/time readouts on narrow observable paths.
4. Extract independently owned controllers where actual responsibilities justify them.
5. Avoid restructuring unrelated screens during a performance fix.

Reference: [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices) explains localizing state updates and avoiding unnecessary build work.

Acceptance: a performance trace demonstrates reduced unnecessary work without broken selection, undo, or playback. Record hardware and workload with every claim.

## Priority 5 — Clip identity for independent speed

Observation: ProgramRenderSnapshot receives playback speeds keyed by media path.

Risk: if two instances of the same media need distinct speeds, a path-level setting alone cannot express both independently.

Proposed contract:

- Asset ID identifies source media.
- Clip ID identifies one edited use of that media.
- Clip-level speed is authoritative when present.
- Legacy per-media speed may remain an explicit migration/default policy.
- Apply selected resolves exact target clip/composition identities.

Acceptance: duplicate one source into two clips; set different speeds; save/reopen; verify preview/export duration and source mapping. Older project fixtures retain their previous intended speed after migration.

## First milestone — Two-video correctness harness

Use synthetic media A and B with frame labels and identifiable audio ticks.

1. Place A followed by B.
2. Trim both and apply different speeds.
3. Use a 3:4 canvas with nondefault transform and captions.
4. Play across the boundary and scrub repeatedly in both directions.
5. Save/reopen and export.
6. Compare preview/reference/export at identical sequence times.
7. Repeat using two clips from the same source to test instance identity.

Record: source digest, app/backend version, project revision, exact dimensions/FPS, frame labels, caption bounds, audio alignment, seek latency, dropped frames, memory peak, and errors.

Exit gate: correctness failures are resolved with regression coverage. Performance numbers are documented rather than guessed.

## Second milestone — Seven-video stress test

After the first milestone passes:

- Import seven different videos, including long media.
- Verify each poster and timeline strip belongs to its own source.
- Switch clips and scrub while background jobs are active.
- Run a batch export and inspect per-item progress separately from overall progress.
- Cancel during processing and confirm owned workers exit.
- Reopen the saved project and verify completed artifacts remain available.

Record machine CPU/GPU/RAM, free disk, media formats/durations, build mode, worker limits, memory trend, and cancellation latency. Stop safely on resource pressure rather than intentionally reproducing a whole-PC freeze.

## What not to do

Do not rewrite the entire app in Rust or React based only on perceived smoothness.
Do not assume OffscreenCanvas automatically means execution in a background worker.
Do not claim GPU effects guarantee low memory use.
Do not replace all playback tolerances without a timing fixture.
Do not add hundreds of effects before export parity is verified.
Do not copy external implementation code without reviewing its license and compatibility.

## សេចក្តីសង្ខេបជាភាសាខ្មែរ

ឯកសារនេះផ្តោតលើ Klipio Editor និងការកែលម្អរបស់ Klipio ផ្ទាល់។ External references នៅក្នុងផ្នែកដាច់ដោយឡែកខាងក្រោម។

សម្រាប់ Klipio ខ្ញុំណែនាំឱ្យរក្សា Flutter ហើយកែ engine តាមលំដាប់៖

1. ពិនិត្យ clip boundary ដើម្បីកុំឱ្យប្តូរ video មុនពេលត្រឹមត្រូវ។
2. ធ្វើ test ថា preview និង export មាន size, zoom, canvas និង caption ដូចគ្នា។
3. រៀបចំ frame/controller prefetch ដែលមាន memory limit។
4. វាស់ UI rebuild មុនបំបែក state ឬ controllers បន្ថែម។
5. ប្រើ clip identity សម្រាប់ speed ឯករាជ្យ ពេល source ដូចគ្នាមាន clips ច្រើន។

ធ្វើ two-video test ឱ្យត្រឹមត្រូវមុន seven-video stress test។ នេះជាផែនការកែលម្អ មិនមែនជាការអះអាងថាបានកែ code រួចទេ។ ការអាន source មិនជំនួស runtime benchmark។

## Completion status

This document records recommendations only. Application code and installer files were not modified. No runtime benchmark, Flutter test run, or EXE build was performed for this documentation update.



## External Reference Findings

GSMediaCut is an external research reference only, not a Klipio module, product name, or architectural dependency. Observations below are historical source-review notes, not current runtime benchmarks.

### Reference observations

| Area | GSMEDIACUT observation | Klipio implication |
|---|---|---|
| UI | Web dependencies include React, Next.js and TypeScript | Do not confuse UI framework with the media engine |
| Media frames | VideoCache uses Mediabunny CanvasSink, per-media entries, current/next frames, and prefetch | Evaluate bounded prefetch and reuse rather than repeated preparation |
| Playback | PlaybackManager advances from elapsed wall time with requestAnimationFrame | Keep playback scheduling separate from broad UI state changes |
| Rendering | CanvasRenderer composes nodes; SceneExporter uses CanvasRenderer | Align actual rendering semantics, not just saved settings |
| GPU helpers | Rust/WASM effect helpers are called when available | Measure backend capability and fallback; GPU is not a universal guarantee |
| Desktop | Reviewed GPUI main entry displays a basic window | Do not attribute the full editor's smoothness to that shell |

These are implementation observations, not proof that GSMEDIACUT is always faster or free of bugs. Its GPU effect adapter can return the original source when GPU support is unavailable; copying that behavior without explicit user feedback could hide missing effects.

### Reviewed paths

External reference checkout: paths in the following list are relative to that external repository.

- apps/web/package.json
- apps/web/src/core/managers/playback-manager.ts
- apps/web/src/services/video-cache/service.ts
- apps/web/src/services/renderer/canvas-renderer.ts
- apps/web/src/services/renderer/scene-exporter.ts
- apps/web/src/services/renderer/gpu-renderer.ts
- apps/desktop/src/main.rs

Klipio source references: paths in the following list are relative to the Klipio repository root.

- lib/features/editor_shell/presentation/operations/preview_monitor_chrome_color.dart
- lib/features/editor_shell/presentation/editor_screen.dart
- lib/features/composition/domain/program_render_snapshot.dart
- lib/features/preview/engine/preview_controller_io.dart
- pubspec.yaml

Paths identify the reviewed source, not permanent line numbers. Recheck implementations before changing them.
