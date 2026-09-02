# KLIPIO MASTER BLUEPRINT
## From Zero to a Professional Video Editing Platform — English Edition

Edition 1 • 2026-09-07 • Architecture proposal, not an implementation or release certification.

This book designs the future product. It does not describe the current source tree as if every capability already exists. CapCut and Filmora are scope references, not evidence about their private architecture. All Klipio contracts below are original proposals. A proposed test is not a test that has been run.

Read Parts 0–10 first, then build one vertical slice: import → timeline → preview → save → export. Read creative systems before adding a large catalog. Cloud, commerce, and plugins come after the local editor is dependable. Companion specifications in the parent knowledge library turn the book into implementation checklists.

## Knowledge-system correction — 2026-09-07

Klipio is the product identity. Other editors are external research references only, never Klipio module or component names.

This book is the blueprint. [Current implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) records inspected code/test evidence and uncertainty. Partial code and test presence do not establish Verified or Released status.

Continue with the [expanded UI System](../03_UI_UX_DESIGN_SYSTEM/Design-System.md), [persistence](../15_PROJECT_PERSISTENCE/Specification.md), [audio](../16_AUDIO_ENGINE/Specification.md), [text](../17_TEXT_CAPTION_ENGINE/Text-Engine.md), [captions](../17_TEXT_CAPTION_ENGINE/Caption-Engine.md), and [benchmark methodology](../18_PERFORMANCE_BENCHMARKS/Benchmark-Protocol.md). These specify behavior without claiming it is implemented.


## Part 0 — Master vision

A video editor transforms a person's intent into a reproducible audiovisual composition. Its central promise is not “many buttons”; it is that the saved project, preview, and output describe the same work.

Klipio should be local-first: importing, basic editing, saving, and exporting must work without an account. Optional connected services add content delivery, backup, collaboration, and AI. The editor must still explain missing downloaded assets or disconnected source media rather than pretending a project is corrupt.

Platform map:

```text
Desktop / Mobile / eventual Web client
             |
     Commands + Project model
             |
 Timeline / Media / Render / Audio
      |                    |
 Preview                Export
             |
 Content registry — Templates / Fonts / Music / Effects
             |
 Optional service boundary
 Accounts / Sync / AI jobs / Catalog / Creator submissions
             |
 Object storage / CDN / Database / Job workers
```

The product should serve a beginner making a short video before serving a studio collaboration team. Advanced features must compose with the same fundamentals, not create parallel project formats. Success measures include successful reopen/export, preview fidelity, recovery, bounded resource use, and task completion. Library size is secondary.

Exercise: write the smallest complete user journey and list every system it touches. Reject a roadmap item if it cannot explain which user problem it solves.

## Part 1 — Video editing foundations

An asset is reusable source material; a clip is one timed use of that asset. A track orders or layers clips. A sequence is an editable composition with its own dimensions, timebase, and tracks. Two clips can reference the same file but have different crops and source ranges.

A frame is a picture sample. FPS describes frame frequency; variable-frame-rate media requires actual presentation timestamps, not simply frameNumber/FPS. A timebase defines the units of those timestamps. Store exact rational times or integer ticks with an explicit rate; use floating point for display and approximate interaction, not accumulated edit boundaries.

Resolution counts pixels. Aspect ratio describes shape. Codec describes compression; container stores streams and metadata. Bitrate is bits per second, not quality itself. Pixel format describes component storage and subsampling; color space describes how values correspond to color. These must not be conflated.

Decode turns compressed packets into samples; encode compresses samples. Demux separates container streams; mux combines encoded streams. Rendering computes the final composition. A proxy is a lighter representation of source media; a cache is disposable derived data. Neither is the authoritative edit.

Audio is sampled independently: 48,000 samples per second is not 48,000 video frames. A waveform summarizes sample amplitude, not all audible characteristics. GPU processing parallelizes suitable pixel operations but introduces memory, synchronization, and device constraints.

Worked example: a 1920×1080 source placed in an 810×1080 3:4 sequence has a different composition shape. The editor must decide contain versus cover, not infer it from the export label “1080p.” At 30 FPS a ten-second constant-rate sequence has 300 frame intervals. Its endpoint is excluded.

Study [OpenTimelineIO time ranges](https://opentimelineio.readthedocs.io/en/v0.18.1/tutorials/time-ranges.html) for the distinction between timeline placement and source range. Klipio's specific model remains its own design.

## Part 2 — Complete product architecture

Presentation translates interaction into intent. Application services coordinate use cases. Editor Core validates commands and owns project changes. Infrastructure performs file I/O, decoding, network calls, and process execution behind interfaces.

Dependency direction is inward: UI → Application → Domain; adapters implement domain/application ports. Domain must not import Flutter widgets, HTTP clients, FFmpeg process wrappers, or subscription screens. Composition constructs concrete implementations at startup.

```text
Gesture → Command → validation → atomic state revision
                                     |
                              immutable snapshot
                                     |
                          timeline/time-map resolver
                                     |
                                render graph
                              /              \
                       preview backend    export backend
```

Commands return a new revision, change set, and structured failure if rejected. The UI observes selectors, not mutable global maps. Media jobs return results tagged with asset identity and request generation. Stale results cannot overwrite a newer selection.

Boundaries include timeline, media, playback, render, audio, text, captions, effects, animation, color, export, persistence, jobs, and optional cloud. A module owns its data invariants; crossing a boundary uses documented types, not private fields.

Start as a modular monolith, not dozens of network services. Extract a package when independent ownership or reuse justifies it. Splitting a 17,000-line class into shared-state extensions reduces physical size but does not alone achieve isolation.

Test with an in-memory repository and fake decoder. If a split command requires a running window or internet access, the boundary is wrong.

## Part 3 — Professional editor UI

Home owns recent projects, recovery offers, and ongoing job summaries. Project manager owns create/open/duplicate/archive workflows. Workspace combines top toolbar, media browser, source monitor, program monitor, timeline, and inspector. Source monitor shows uncomposed media; program monitor shows the actual sequence.

Specialized browsers cover effects, transitions, text, captions, audio, color, and animation. Export has profile selection, validation, destination, and persistent job details. Settings and shortcut editing are separate from project content.

Panels have minimum sizes, resizable dividers, saved layout, and a reset-layout action. Docking changes workspace preferences, not project rendering. At narrow widths use tabs or drawers rather than invisible overflow. Restore invalid off-screen window positions safely.

Selection must be explicit: selected asset, selected timeline clip, and playhead-active clip are different concepts. Inspector heading names the edited target. Multiselect displays mixed values and changing one property preserves other differences. Context menus and keyboard shortcuts call the same commands as toolbar actions.

Drag sessions preview placement; release commits one transaction. Escape cancels. Snapping is visible, configurable, and temporarily bypassable. Hover is not the only way to discover an action.

Test a full edit by keyboard, with a narrow window, with large text, and with a screen reader. A cancel button must remain reachable while a worker is busy.

## Part 4 — Design system

Use semantic tokens: surface/base, surface/raised, text/primary, text/muted, border/default, action/primary, state/error, state/warning, selection, focus. Tokens reference palette values; feature widgets do not invent colors.

Proposed starting scale: spacing 4/8/12/16/24/32 logical pixels, compact and comfortable density, consistent corner radii, and text roles for body, label, heading, and timecode. Values are design decisions to validate, not universal standards.

Build Button, IconButton, NumericField, SliderField, Dropdown, Tabs, Menu, Dialog, Tooltip, DockPanel, InspectorRow, AssetCard, and TimelineHandle. Each defines default, hover, focus, pressed, disabled, loading, and error behavior. Icons need labels or accessible names.

Numeric fields must support precise input, units, clamp/error policy, reset, and keyboard changes. A slider emits transient updates during dragging and one committed history entry. Asset cards distinguish loading, unavailable, downloading, installed, and premium states.

Keep a component gallery and screenshot tests for light/dark themes, localization, and error states. Use [WCAG 2.2](https://www.w3.org/TR/WCAG22/) as an accessibility reference, while also testing native desktop semantics; using these tokens does not itself certify conformance.

## Part 5 — Timeline engine

Represent intervals as [start, end). The beginning belongs to a clip; its endpoint belongs to the next clip or a gap. For a clip placed at T, source in-point S, positive constant speed r, source time at sequence t is S + (t − T)r. A source span D lasts D/r on the sequence.

Example: source [10,18), speed 2, placed at sequence 5 lasts [5,9). Split at sequence 6.5 maps to source 13. Left uses [10,13), right [13,18). Do not split at source 11.5 or reset the second clip to zero.

Trim changes a boundary and its mapped source endpoint. Move changes placement only. Slip changes source range while retaining placement/duration. Roll moves a shared boundary while retaining total duration. Slide moves one clip while adjusting neighbors. Ripple delete closes a chosen interval and shifts eligible downstream material. Duplicate and paste create new instance IDs.

Linked audio/video share edit intent but remain distinct clips. Groups organize selection; compound clips reference nested sequences. Reject nested-sequence cycles. Markers may be sequence-time or attached to media; choose and store the distinction.

Magnetic mode is a policy over commands, not a second engine. Define which tracks participate, how attached items follow, and how locked tracks respond. Safer default: reject the whole edit if required linked changes touch a locked track, explaining why.

Screen conversion: x = originX + (t − scrollTime) × pixelsPerSecond. Snap distance in time = snapPixels / pixelsPerSecond. Use the same mapping for ruler, playhead, drag, and hit testing. Virtualize off-screen clips and thumbnail samples.

Tests: boundary split is rejected without zero-length clips; undo restores IDs and timing; ripple preserves linked offsets; speed-aware trim never exceeds media handles; locked tracks stay unchanged. Property-based tests should generate long command sequences.

## Part 6 — Command and history engine

A command is a named request with explicit inputs: MoveClip(clipId, destinationTrackId, newStart, expectedRevision). The handler checks identity, lock, overlap policy, source limits, and revision before committing.

Store before/after patches or invertible operations. SplitClip records original clip plus replacement clips and link changes. DeleteClip retains enough information to restore placement and effects. AddEffect records stack position and parameters. Undo must not regenerate IDs randomly.

Transactions group related edits. Dragging through 200 pointer events should create one undo step, not 200. Only merge adjacent compatible commands belonging to the same interaction. Starting another action ends the merge window.

External actions such as uploading or purchasing are not automatically reversible. History can remove a generated caption layer, but cannot “unspend” an AI request. Explain that boundary.

History memory is bounded. Persist project snapshots separately from ephemeral UI selection. Redo is cleared after a new branch unless an explicit branching-history product is designed.

Test execute→undo→redo equality, including links, order, and metadata. A failed command creates no partial state and no history entry.

## Part 7 — Media engine

Import is a pipeline: validate input → register stable asset ID → probe → publish metadata → enqueue poster/waveform/proxy work. Do not block import completion on all thumbnails. Each asset has independent pending/ready/failed status.

Store original locator, managed relative path when copied, file size, fingerprint, stream IDs, duration, rotation, sample aspect ratio, codec, dimensions, and color metadata. File names are labels, not identity. Fingerprints should be computed incrementally without freezing the UI.

Thumbnail keys include asset fingerprint, stream, source timestamp, decoder version, rotation policy, and requested size. Clip strips sample the clip's mapped source interval. Video 2 must never inherit Video 1's cache key. Cache jobs deduplicate; failures expose retry rather than a permanent empty strip.

Waveforms use multiresolution peak data. Proxies retain a mapping to original timestamps; they cannot silently change the edit. Relinking validates candidate duration/streams and warns on mismatch. Offline media retains timeline state and a useful placeholder.

Video, images, GIF, audio, SVG, subtitles, fonts, and template packages need different validators. Rasterize untrusted vector content safely; do not execute embedded code. Animated media must have bounded decode resources.

Test seven imports, quick switching, cancellation, relink, duplicate filenames, Unicode paths, missing drives, and cache eviction. Reconstructing caches must not change the project.

## Part 8 — Playback engine

Playback is a clock-driven state machine: idle, preparing, ready, playing, seeking, buffering, failed, disposed. The UI cannot infer readiness from a non-null player reference.

Use an audio clock when audio is playing; otherwise a monotonic clock. Resolve sequence time, choose the active scene, map to source times, and schedule frames. Decoder time and sequence time are not interchangeable.

Seek requests have generations. A later seek supersedes an earlier result. Scrubbing may use reduced-quality frames; releasing the pointer requests an accurate frame. Frame stepping advances one sequence frame interval, not one arbitrary source frame.

Preload nearby media with a bounded queue. Drop preview frames when necessary while preserving the clock; export must render all required output frames. Buffering feedback should name the operation and offer retry/cancel.

Preview resolution and proxy choice are quality policies. They must not change geometry, captions, or edit timing. Loop endpoints use the same interval convention as timeline commands.

Test repeated seek bursts, track boundaries, speed changes, device loss, and long playback A/V drift. Track dropped frames separately from actual timeline discontinuities.

## Part 9 — Rendering engine

A scene is the resolved visual/audio description at time t. A render graph is a dependency graph of decode, transform, color, mask, effect, text, transition, and composite operations. Nodes declare input formats, output formats, temporal dependencies, and cacheability.

Compile immutable project revision + content versions + output profile into a RenderPlan. Preview and export consume the same plan semantics. Different backends are acceptable only with a documented conformance suite; merely sharing JSON does not guarantee equal pixels.

Evaluate only dirty subgraphs. A text color change should invalidate that overlay and downstream composites, not every source decoder. Cache keys include parameters, time, upstream identity, color policy, and engine version.

GPU nodes are good for parallel image operations; CPU paths provide portability and specialized processing. Transfers can dominate cost. Reuse textures, bound intermediate surfaces, and handle device loss. Do not promise GPU speedup without measuring.

Define alpha representation, blend order, working color space, pixel center convention, sampling, and effect border policy. Export comparison should use uncompressed reference frames or a tolerance appropriate to encoding.

Acceptance: compare identical timestamps at 3:4, 9:16, 1:1, and 16:9 with nonuniform scale, crop, blur canvas, rotation, and captions.

## Part 10 — Transform system

Distinguish source pixels, normalized source coordinates, composition pixels, normalized composition coordinates, and screen logical pixels. A pointer belongs to screen space; export belongs to composition space. Never persist a widget's measured width as a caption or video size.

Proposed column-vector transform: M = Translation(position) × Rotation × Scale × Translation(−anchor). Apply crop in the declared source coordinate space before fitting. Flip can be a signed scale, but the UI should expose it independently.

Contain scale is min(canvasW/sourceW, canvasH/sourceH); cover uses max. For 1920×1080 into 810×1080, contain is 0.421875 and cover is 1.0. Additional user scale multiplies the fit, not an unrelated preview-size ratio.

Canvas background is a separate layer. Blur background uses the declared source and fit policy; foreground transform does not accidentally reposition that background. Opacity combines predictably with masks.

Store anchors and units explicitly. Perspective requires a homography or mesh contract and its own hit testing. Gizmos transform pointer positions through the inverse matrix and commit one command.

Test transform round trips, rotated drag handles, mirrored clips, off-center anchors, and export parity. Reset transform must restore documented defaults for the selected clip, not stale global state.

## Part 11 — Text engine

Text rendering has several stages: Unicode text → segmentation and shaping → glyph layout → raster/vector representation → stroke/shadow/background → animation → composition. Font selection alone is insufficient for Khmer or other complex scripts.

Store font asset/version, size in composition units, paragraph constraints, alignment, line/letter spacing, fill, stroke, shadow, and background. Font fallback must be deterministic or explicitly warned about when portability is impossible.

A TextStyleDefinition is reusable content; a TextInstance contains user text and overrides. Hundreds of styles combine supported primitives without hundreds of widgets. New rendering primitives still require engine implementation—JSON cannot invent a shader.

Curved text and text paths map shaped glyph placement to a curve while preserving cluster boundaries. Entrance, exit, and loop animation reference property tracks; text edits retain stable animation policy.

Build plain text, wrapping, and shaping first; add backgrounds and strokes; then presets; then per-word/per-cluster animation. Catalog thumbnails are generated through the same style resolver.

Test Khmer clusters, emoji, mixed scripts, missing fonts, multiline text, extreme sizes, and preview/export glyph metrics. A golden screenshot alone does not test editability or accessible text.

## Part 12 — Effect engine

An effect definition describes supported implementation ID, version, parameter schema, categories, preview assets, and capabilities. An instance stores definition reference, enabled state, parameter values, and animation tracks. Stack order is meaningful.

Parameters have types, units, ranges, defaults, and interpolation rules. UI controls are generated from this schema. Unsupported definitions remain preserved but disabled with explanation, rather than silently deleted.

Reusable primitives can build blur, distortion, glitch, glow, retro, lens, motion, light, noise, stylize, color, VHS, camera, party, dream, and comic presets. Categories are catalog metadata, not separate UI code.

A shader declares texture inputs, sampling, color expectations, and output alpha. CPU fallback may be slower; if it is not equivalent, the UI must disclose that. Temporal effects declare required neighbor frames, expanding cache and decode dependencies.

Random effects need a stored seed. Thumbnails run in constrained jobs. Avoid running downloaded native code as an “effect preset.”

Test parameter validation, stack reordering, disabled nodes, deterministic noise, absent capabilities, and backend image comparisons.

## Part 13 — Filter system

A filter is a reusable color look, usually a parameter preset or LUT plus metadata. Keep it distinct from the general effect stack in UX while reusing compatible render primitives.

A LUT maps input color values to output values. Its input color assumptions, dimensions, domain, and interpolation matter. Applying a look intended for one transfer function blindly to another can produce incorrect results.

Store definition/version, intensity, input policy, and LUT digest. Define intensity blending in the documented working representation. Do not mix an arbitrary percentage in encoded output space by accident.

Catalog features include categories, favorites, downloads, and reference thumbnails. Generate thumbnails from consistent reference media so users can compare looks. A favorite refers to stable content identity, not a list position.

Start with a few validated looks. Test neutral intensity, identity LUT, clipping behavior, unsupported LUTs, and cached downloads. Larger catalogs follow after compatibility and licensing work.

## Part 14 — Transition engine

A transition consumes outgoing and incoming scenes over a defined interval. It is not just a visual sticker over a cut. Store endpoint clip IDs, duration, alignment, definition/version, and parameter tracks.

Transitions need source handles outside visible clip boundaries. If handles are missing, choose an explicit policy: shorten, reject, or repeat boundary frames with disclosure. Do not silently read unrelated source time.

Normalized progress u = (t − transitionStart)/duration. A dissolve can mix A and B with weights 1−u and u in the declared working space. Audio transitions use separately defined envelopes.

Reusable transition implementations accept data-driven presets for direction, softness, color, or motion. GPU acceleration is an implementation detail; duration and time mapping belong to the core.

Test first/last transition frames, adjacent speed changes, nested sequences, missing handles, and undo after trimming. Hundreds of transitions require curated definitions and previews, not hundreds of bespoke dialogs.

## Part 15 — Stickers and overlays

Sticker assets may be static images, animated images, constrained vector animations, shapes, icons, frames, or decorations. Each declares intrinsic dimensions, duration, loop behavior, alpha, dependencies, and license.

Treat stickers as timeline instances with transforms and timing. Do not maintain a second overlay list that bypasses project serialization. Animation support should be a documented subset if importing Lottie-like data; unsupported features need warnings.

Images with alpha must follow the render graph's alpha convention. Cache rasterization at useful scales; unlimited high-resolution surfaces can exhaust memory.

User-installed assets are validated for decompression size, frame count, and path traversal. Decorative fonts and music have their own rights and dependencies.

Build static shapes and images first, then bounded animation playback. Test transparent edges, loops after trimming, missing assets, and deterministic exported duration.

## Part 16 — Caption system

A caption document stores language, timed segments, words, speaker labels when available, and provenance. Caption styling is separate from transcript content. SRT/VTT interchange may lose advanced styling; warn rather than pretending full fidelity.

Choose a time domain explicitly. Proposed generation transcribes the rendered program audio for a captured sequence revision. Returned timestamps are sequence-relative to that snapshot. Later structural edits either transform captions through commands or mark their analysis stale.

A caption job produces reviewed data, not direct widget mutation. Results carry revision and input fingerprint. If the project changed, offer apply-to-original revision or review; do not overwrite newer captions automatically.

Templates define wrapping, word grouping, active-word color, animation, font, safe area, and line count. Karaoke highlighting maps timing to shaped text clusters, not raw byte offsets.

Batch state tracks each selected video independently. Show item 2 of 7 and that item's 0–100%; completed documents remain saved if item 3 fails. Allow precise selection expressions such as 1,2,4 to 7.

Test cut boundaries, speed changes, missing speech, overlapping speakers, Khmer text, partial completion, cancellation, and caption position/size in exported reference frames.

## Part 17 — Animation engine

A property track contains typed keyframes in an explicit local or sequence time domain. Each key has time, value, and interpolation. Numeric interpolation differs from colors, rotations, booleans, and enum changes.

Linear interpolation is a + (b−a)u. A cubic easing curve maps time progress to value progress; evaluating the y coordinate requires solving its x progression, not assuming the curve parameter equals time.

Position, scale, rotation, opacity, effect values, audio gain, mask geometry, and text properties share evaluation infrastructure. Unsupported type combinations must be rejected.

Entrance/exit/loop presets expand into a versioned animation definition. Define how they combine with user keyframes—override, additive, or multiplicative—per property. Never rely on incidental widget animation order.

Test exact keys, zero-duration ranges, rotations crossing 360°, loops at endpoints, trimmed clips, and deterministic seeking backwards. Playback must evaluate from time, not accumulate animation deltas.

## Part 18 — Speed engine

Speed is a time mapping, not just a player setting. For varying positive speed v(t), source progression is S(t) = S0 + integral(v(u), du) over output-local time. Cache a monotonic lookup/inversion structure when needed.

Reverse uses a decreasing source map and requires reverse-capable decode buffering or intermediates. Freeze holds one source time across a positive sequence duration. Neither should mutate the original file.

Speed ramps need defined curve integration and audio behavior. Pitch-preserving stretching differs from changing sample playback rate. Optical flow estimates motion to synthesize frames; occlusions and scene cuts can create artifacts.

Start with positive constant speed, then freeze, reverse, and piecewise ramps. Add optical flow only after correctness and resource budgeting.

Test source endpoints, A/V duration, captions after retiming, ramp continuity, reverse limits, and export parity. A speed map must be captured with the export snapshot so inspector changes cannot alter a running job.

## Part 19 — Masks and compositing

A mask supplies coverage, usually from 0 to 1. Rectangle, ellipse, custom path, feather, and inversion are parameterized sources. Tracking creates a time-varying transform or path.

Combine mask coverage with layer alpha according to a documented convention. Blend modes describe color interaction, not just opacity. For premultiplied source-over, output color is Cs + Cd(1−As), and output alpha is As + Ad(1−As).

Chroma key estimates transparency from color; spill suppression is separate. AI background removal returns a matte with quality limitations. Both must be editable and reversible.

Store masks on instances with stable IDs and animatable properties. Define whether feather is measured in composition or source pixels. Nested groups may need isolated compositing surfaces.

Test transparent edges against dark/light backgrounds, inverted masks, feather under scaling, track loss, and nested opacity. Start with static masks and source-over before advanced blend modes.

## Part 20 — Color engine

Color management gives image values meaning throughout decode, processing, preview display, and output. Store source primaries, transfer, matrix, and range when available; unknown metadata requires an explicit assumption and warning policy.

Exposure, contrast, highlights, shadows, saturation, temperature, tint, curves, HSL, wheels, and LUTs operate in defined representations. Their order matters. A temperature slider is not simply “add blue.”

Scopes—histogram, waveform, vectorscope—analyze the selected processing point. They must label whether they show source, working, or output values. Compute them asynchronously and at reduced sampling when necessary.

Begin with a documented SDR pipeline and reference charts. HDR and tone mapping require separate engineering, display capability detection, and test media. Do not claim HDR because a file decodes.

Test neutral adjustments, known color patches, full/limited range, metadata round trips, and GPU/CPU agreement. Store look versions to prevent future catalog updates changing old projects.

## Part 21 — Audio engine

Audio has its own graph: source decode → time mapping → gain/pan/effects → bus mix → output. Use sample time, not video frame indices. Allocate realtime buffers ahead of time and keep blocking I/O away from the audio callback.

Volume, pan, fades, detach, and voiceover are core. EQ shapes frequency response; compression changes dynamics; reverb models persistence; noise reduction and pitch processing may add latency. Effects must report latency so the graph can compensate.

Waveforms summarize audio for editing; they do not replace loudness or peak measurement. Music assets include rights and duration. Beat detection produces editable markers with confidence.

Detaching audio preserves a stable relationship until the user explicitly unlinks it. Apply source volume must not modify an independent music instance using the same path.

Test silent sources, mono/stereo, mixed sample rates, clipping, long sync, latency compensation, fades at cuts, and cancellation during voiceover capture. Save recordings atomically before adding their clip.

## Part 22 — Content platform

Large libraries are combinations of reusable engines and versioned content. A catalog entry identifies what exists; an installed package supplies validated files; an instance records how a project uses that version.

Manifest fields include contentId, version, type, localized names, tags, category, engine requirements, files/digests, dependencies, preview, license reference, and entitlement category. Stable IDs must not depend on translated names.

Download → verify integrity/authenticity → validate schema/capabilities → stage → atomically install → index. Failures do not replace a working version. Content hashes detect changes; signatures and trust policy establish who published them.

Search, favorites, recents, collections, downloads, and offline cache operate on this registry. Premium labels are catalog metadata; access decisions come from a policy service outside the renderer.

Pin project-used versions. Updating a glow preset must not alter an existing export silently. Allow explicit upgrade with preview and undo. Garbage collection must preserve project-pinned dependencies or offer portable packaging.

Start with ten authored packages through the complete pipeline before importing thousands. Test interrupted downloads, digest mismatch, missing fonts, dependency cycles, license expiry policy, and offline reopening.

## Part 23 — Template engine

A template is a parameterized project fragment, not a flattened video. It declares sequence structure, placeholders, text fields, effects, transitions, music, animation, and required assets.

Placeholders specify accepted media type, minimum duration, aspect expectations, and fit policy. Replacement may trim, loop, stretch, or reject; the chosen rule must be visible.

Instantiation creates fresh instance IDs while preserving references within the fragment. Content definition IDs remain stable. Expose only intended controls; keep an “expand to editable composition” operation for advanced users.

Template updates should not mutate existing instances automatically. Retain version and replacement choices for reopening. Validate all dependencies before download completion.

Test short media replacement, multiline text, missing premium dependencies, nested templates, and save/reopen equality. Authoring tools should use the same schema as consumption.

## Part 24 — Project file format

A project is durable intent, not a dump of UI controller objects. Use a versioned manifest with project identity, schema version, sequences, assets, track/clip IDs, effects, keyframes, captions, audio settings, content pins, and timestamps.

Store relative paths for managed media plus optional external locators. Never assume G: exists on another machine. Project format versions are independent from app marketing versions.

Time values need an explicit rate. References must resolve, IDs be unique, intervals valid, and nesting acyclic. Unknown optional metadata can round-trip; unknown essential features should open read-only or with a compatibility warning.

Migrations are ordered pure transformations on copies. Validate before and after. Keep the original until the new project has been safely persisted. Downgrading is not automatically supported.

Test every historical schema fixture, missing dependencies, corrupted JSON, huge declared counts, and round-trip structural equality. See the companion contract examples for a minimal format.

## Part 25 — Save, autosave, and recovery

Save captures a consistent revision, serializes to a sibling temporary file, flushes as supported, validates, then replaces the destination using platform-safe atomic operations where available. Cross-volume moves are not assumed atomic.

Autosave should debounce commands but also have a maximum delay. Show saved revision/time; “Autosave active” alone does not prove the latest edit reached disk. Serialize jobs so an older save cannot overwrite a newer one.

A journal can record incremental commands between snapshots. Include checksums and revision sequence; recovery replays only complete valid records. Keep bounded backups with explicit retention.

On startup offer recovery choices with dates and previews. Disk-full, permission failure, and unavailable external drives must keep the in-memory edit intact and offer Save As.

Test process termination during each save phase, truncated journals, disk-full simulation, and competing save requests. Recovery is successful only when the restored project renders the expected result.

## Part 26 — Export engine

Export is a durable job over an immutable snapshot:

```text
Project revision → validated timeline → RenderPlan
→ frames/audio → encoder → muxer → verified temporary output
→ final destination
```

Profiles include exact width/height, rational FPS, codec, pixel/color format, quality/bitrate policy, audio format, and container. “1080p” is insufficient for portrait dimensions.

Queue items capture target composition IDs and resolved output names, not current selection indexes. Persist numbering separately from batch position: selected videos 6–10 may display “item 1 of 5 — 6.Title.mp4.”

Maintain per-item progress and optional overall progress as separate values. Processing reaches less than 100% until finalization/verification succeeds. At the next item reset item progress; preserve completed item records.

Cancel stops only owned workers, awaits exit, and cleans only that job's temporary files. A timeout reports the stalled phase and logs. Do not display success because a progress stream ended.

Verify output streams, dimensions, duration tolerance, and existence before publishing. Test partial batch failure, destination collision, disk full, cancellation, and project edits during export.

## Part 27 — FFmpeg and media processing

FFprobe inspects media; FFmpeg provides processing and encoding building blocks. Neither should own selection, history, or product rules. Use a process adapter with structured arguments, captured diagnostics, cancellation, and tested capability detection.

Learning commands, for trusted local files and a compatible build:

```text
ffprobe -v error -show_format -show_streams -of json input.mp4
ffmpeg -i input.mp4 -vf scale=640:-2 -an preview.mp4
```

These are learning examples, not the complete Klipio export renderer. Consult the [FFmpeg command documentation](https://ffmpeg.org/ffmpeg.html) for option scope and progress output, and the [filter reference](https://ffmpeg.org/ffmpeg-filters.html) for trim, timestamps, crop, scale, overlay, audio, and concatenation behavior.

Klipio should compile a validated plan to a bounded worker invocation. Avoid shell command concatenation. Large filter descriptions may need supported file-based input or staged graphs; detect the exact bundled version's capabilities rather than assuming every online example works.

Stream copy is not a substitute for rendering edited effects. Hardware encode availability does not imply hardware support for every graph operation. Record selected backend and fallback.

Exercise: probe a sample, export a small scaled file, then compare stream metadata. Next test a path containing spaces and Khmer characters. Never debug by deleting the user's source.

## Part 28 — Performance

Performance is a budget, not a collection of optimizations. Define a reference device and workload, then measure input latency, frame deadlines, memory, CPU/GPU load, queue wait, and disk throughput.

Use bounded queues by job class. Interactive seek outranks speculative thumbnails; export and AI must respect shared CPU/RAM/GPU limits. Limit native worker thread counts as well as process counts.

Proxy, frame, render, thumbnail, and waveform caches have different keys and eviction costs. Estimate raw surface memory: width × height × bytesPerPixel × concurrentSurfaces. One 3840×2160 RGBA8 surface is about 31.6 MiB; dozens are expensive.

Virtualize timeline elements and lazily decode catalog previews. Debounce speculative work, not essential command commits. Cancel superseded requests with generation tokens. Avoid decoding an entire reverse clip into RAM.

Proposed targets must be benchmarked: keep pointer interaction responsive during background work and maintain bounded memory over repeated open/close cycles. No claim of universal FPS is valid without hardware/workload details.

Test long media, thousands of clips, seven simultaneous imports, low disk, device loss, cancellation, and cache pressure. Resource limits reduce risk but do not diagnose every whole-PC freeze.

## Part 29 — AI video editing

AI services are optional analysis/generation adapters. Define AIJob(input snapshot/hash, operation, model/version, parameters, consent, budget). Output is a reviewable artifact with provenance, not an instruction to mutate the project invisibly.

Auto captions, translation, segmentation, tracking, silence suggestions, beat sync, auto reframing, noise cleanup, and speech enhancement each have different data and evaluation needs. Generative video/assets need moderation and provenance policies as well as compute.

Local and remote backends share the contract but differ in privacy, latency, cost, and hardware limits. Show whether media leaves the device. Never upload silently.

Silence removal suggests edit ranges; acceptance becomes ordinary timeline commands. Tracking yields keyframes plus confidence and lost-track intervals. Users can correct results.

Test cancellation, retry without duplicate charges, stale revisions, multilingual accuracy, empty audio, model download failure, and low-memory fallback. AI quality should be evaluated on consented representative data, not one impressive demo.

## Part 30 — Cloud platform

Cloud adds optional project backup, sync, cross-device availability, comments, and eventually collaboration. Sync metadata separately from large media blobs.

Use immutable blob identities and resumable uploads. A project revision references assets by identity; a device maps them to local files. Conflict handling must preserve both edits rather than silently applying last-writer-wins to an entire project.

Start with single-user snapshot backup and explicit restore. Add optimistic revision checks, conflict copies, and comments. Real-time multi-user editing requires operation semantics, presence, ordering, permissions, and offline reconciliation; it is a later product.

A local save must not wait indefinitely for cloud acknowledgement. Display local saved and cloud synced separately. Define deletion, retention, and restoration behavior.

Test disconnected editing, duplicate upload retries, partial media availability, account switching, and conflicting revisions. A cloud outage must not prevent local export with available assets.

## Part 31 — Backend

Begin with a modular backend application rather than premature microservices. Domains include auth, users, projects, catalog, assets, templates, downloads, AI jobs, subscriptions, licenses, payments, and consented analytics.

The relational store owns metadata and authorization relationships. Object storage owns large immutable media. A queue owns asynchronous work, but the database owns durable job state. CDN delivery is not authorization by itself.

APIs use stable IDs, revision checks, pagination, idempotency keys, and structured errors. Workers must tolerate at-least-once delivery without applying results twice.

Core editing, undo, local caching, and offline export remain local. Accounts, purchase verification, remote jobs, and sharing require services.

Test tenant isolation, retry duplication, expired credentials, object access, and worker restart. Keep payment-provider integration behind a boundary; never put payment logic into clip evaluation.

## Part 32 — Desktop, mobile, and web

Share project schema, commands, time math, validation, content definitions, and conformance fixtures. Platform adapters own file picking, filesystem access, decoders, GPU surfaces, audio devices, background execution, and installation.

Windows/macOS use desktop workspace conventions. Android/iOS need touch-first interaction, lifecycle interruption handling, and thermal budgets. Web has browser storage, permissions, codec, and memory constraints; it should have an explicit capability profile.

Do not promise identical native code paths everywhere. A shared UI toolkit does not guarantee identical codecs or text rendering. Publish a capability matrix and protect unsupported projects from silent loss.

Release one dependable desktop target first, then validate core portability on a second platform. Test suspend/resume, device rotation, interrupted export, missing fonts, and project transfer between machines.

## Part 33 — Plugin architecture

Plugins may contribute effects, transitions, importers, exporters, AI adapters, and panels through versioned capabilities. A panel requests commands; it cannot directly mutate private editor state.

Prefer declarative packages first. Executable plugins need isolation, permission declarations, resource quotas, IPC validation, lifecycle handling, and compatibility negotiation. A signed plugin is identifiable, not automatically safe.

Host crashes must not destroy the project. Out-of-process execution reduces some risks but is not a full sandbox without OS restrictions. Never grant filesystem/network access by default.

Define plugin ID/version, supported API range, permissions, entry point, and uninstall behavior. Projects retain unavailable plugin metadata for restoration.

Test malicious messages, timeouts, denied permissions, dependency incompatibility, and missing plugins during export. Do not ship arbitrary native execution simply to advertise extensibility.

## Part 34 — Creator ecosystem

Creators publish packages through draft, validation, review, approved, suspended, and retired states. Each submission needs provenance, rights information, previews, compatibility, and dependency validation.

Automated checks catch malformed manifests, unsafe archives, missing files, and incompatible parameters. Human moderation addresses misleading claims and content policy. A report/appeal workflow is part of the product.

Publishing creates immutable versions. Takedown policy must distinguish blocking new downloads from the handling of existing project dependencies; legal/licensing review is required before commercial release.

Start with internally authored content and invited creators. Revenue sharing, payouts, and tax handling are later specialized integrations, not editor-core concerns.

Test package rollback, creator account compromise, broken dependency updates, and continuity of saved projects.

## Part 35 — Free and Pro platform

Define entitlements outside the editor core: feature access, content downloads, cloud quota, and AI credits. A policy service answers whether an action is allowed; the renderer evaluates an already authorized plan.

Avoid letting commercial flags become dozens of conditional branches inside clip math. Separate access checks from technical capability checks. “Unavailable GPU feature” is not “upgrade to Pro.”

Offline behavior must be explicit: what works, what cached proof is accepted, and when a network check is required. Do not invent subscription promises in code before product/legal decisions.

Use a server-side ledger for billable usage with idempotent settlement. Refund/retry policy needs a durable job identity. Protect users from duplicate charges after disconnects.

Test account logout, expired access, offline reopen, purchase restoration, and clear messaging. Existing user media must never be deleted because an entitlement changes.

## Part 36 — Search and discovery

Catalog discovery combines indexed localized text, categories, tags, compatibility, recent use, favorites, collections, and optional recommendations. Stable content IDs connect all views.

Separate editorial “featured” from measured “trending.” Do not invent popularity counts. Ranking should consider availability and supported engine version so search does not primarily return unusable assets.

Local search indexes installed content for offline use. Remote search paginates with stable cursors. Cancel stale queries and preserve scroll state when returning from a detail page.

Recommendations should be optional and privacy-conscious. A useful initial implementation is recents + category filtering, not a complex behavioral model.

Test Khmer queries, typo policy, empty results, duplicate localized names, unavailable downloads, and keyboard navigation through virtualized results.

## Part 37 — Localization

Externalize interface messages with pluralization, number formatting, and context. Do not concatenate translated fragments into sentences. Keep stable internal IDs independent of language.

Support bidirectional layout and mixed-direction text. Khmer requires correct shaping, fallback, and line-breaking behavior; reversing strings is not localization. Asset metadata may have fallback language rules.

Project text is user content and must not be auto-translated when UI language changes. Caption translation creates another reviewable document or track.

Test long translations, RTL layouts, Khmer fonts, mixed scripts, dates/numbers, and shortcuts that conflict with text input. Include pseudo-localization early.

## Part 38 — Accessibility

Every actionable control needs a name, role, state, and keyboard path. Timeline clips should expose their label, start, duration, selection, and available actions without requiring pixel-perfect dragging.

Offer numeric alternatives for drag/resize, visible focus, sufficient contrast, reduced motion, and non-color-only status. Tooltips supplement labels but do not replace accessible names.

[WCAG 2.2](https://www.w3.org/TR/WCAG22/) is a useful reference for keyboard, focus, contrast, and motion-related review. Native desktop assistive technology also requires platform testing; passing a visual checklist is not enough.

Build a keyboard-only import→trim→caption→export exercise. Test focus restoration after dialogs and background-job announcements that do not repeatedly interrupt the user.

## Part 39 — Testing

Use layers: pure domain tests, command properties, serialization fixtures, render conformance, media integration, widget interaction, end-to-end workflows, and resource stress.

Create synthetic assets with frame numbers, colored quadrants, audio ticks, known durations, and deliberate rotation. They make wrong source time, crop, and sync visible. Keep real-media tests consented and reproducible.

Compare preview and export at the same composition timestamp, not two unrelated screenshots. Store expected dimensions, caption bounding boxes, and tolerance. Lossy encode comparisons need reasonable thresholds.

Failure injection covers disk-full, missing fonts, worker hangs, denied access, corrupt packages, and stale jobs. Test cancellation by observing owned process exit.

CI should publish failures with fixture identity and engine version. A passing short test suite is not proof that a one-hour 4K project is safe on every PC.

## Part 40 — Observability

Logs explain operations: job ID, project revision, phase, backend, elapsed time, exit code, and sanitized failure category. Progress describes work advancement; a heartbeat describes liveness. Neither substitutes for the other.

Metrics include queue wait, decode/render latency, dropped preview frames, memory peaks, cache hits, and cancellation latency. Use bounded logs with retention.

A diagnostics bundle should redact paths, tokens, transcript text, and personal media by default. Upload is opt-in. Developer tools can show render graph, selected source time, active settings, and cache keys.

Test redaction and log rotation. For a stuck export, diagnostics should answer whether it is probing, decoding, rendering, encoding, or finalizing rather than only “0%.”

## Part 41 — Security

Treat project files, media, fonts, templates, plugins, and remote responses as untrusted. Bound sizes, nesting, duration, decompression, and parser work. Validate archive paths before extraction.

Keep secrets in platform credential storage and avoid recording tokens in logs. Backend authorization checks resource ownership on every relevant request; authenticated does not mean authorized.

Use signed updates/packages where appropriate, digest verification, dependency review, and a vulnerability response process. Isolate native media workers and restrict access where the platform permits.

Security tests include archive traversal, huge metadata values, crafted dependency cycles, cross-account access, and malformed IPC. Security and licensing policies require specialist review before marketplace launch.

## Part 42 — Professional folder architecture

Organize by ownership and dependency, not by arbitrary line count. Proposed future structure:

```text
apps/
  desktop/   mobile/   web/
packages/
  editor_core/        # IDs, project, commands, invariants
  timeline/           # time maps, edit policies
  render_contract/    # scene and plan types
  content_schema/     # definitions, manifests
  project_format/     # codecs and migrations
  ui_system/          # visual components only
adapters/
  media_native/  render_gpu/  render_ffmpeg/
  storage_local/ cloud_client/ ai_local/
services/
  platform_api/  job_workers/  catalog/
content/
  authoring/  validation/  reference_packages/
tests/
  conformance/  fixtures/  integration/  performance/
docs/
  decisions/  contracts/  runbooks/
```

This is a target map, not a claim that these folders already exist or should be scaffolded empty. Add modules with a real vertical slice. Each has an owner, public API, tests, and dependency policy.

Avoid shared “utils” becoming a hidden global engine. Use narrow named interfaces. Refactor one boundary at a time while comparing behavior.

## Part 43 — Development rules

Use names that reveal intent and units: sequenceStart, sourceIn, durationTicks, compositionPixels. IDs are typed or clearly distinguished. Avoid ambiguous “currentVideo.”

Prefer small cohesive functions and files. Investigate a file around 500–800 lines, but do not split a coherent type mechanically just to satisfy a number. Shared-state fragments can hide coupling.

Immutable project revisions and explicit commands are the default. Async work needs cancellation, ownership, disposal, stale-result handling, and structured errors. Never swallow a media failure into an empty thumbnail indefinitely.

Every behavior change includes tests and documentation. Reviews check timing, state ownership, persistence, cancellation, and compatibility—not only formatting.

Record consequential choices in architecture decision records: context, options, decision, consequences, and revisit trigger. A rejected alternative helps future developers avoid repeating the same mistake.

## Part 44 — Feature development template

For every feature write: problem; user journey; requirements/non-goals; architecture owner; data/units; API; UI states; commands/history; render semantics; persistence/migration; tests; budgets; diagnostics; documentation; Definition of Done.

Worked example: “Apply selected frame and canvas.”

Problem: copying settings uses stale inspector state. Requirement: capture selected clip's live revision and copy only checked groups to exact target IDs. Non-goal: copy independent music layers.

Command: ApplySettings(sourceId, targetIds, groups, expectedRevision). Handler validates all targets and locks, captures once, applies atomically, records inverse patches, and emits one revision. UI shows target count and mixed state.

Tests: apply, change source, apply again; excluded groups unchanged; locked policy explicit; undo restores all; preview/export use new values. Done means tests pass, errors are understandable, docs name the source of truth, and no installer claim is made without a release test.

## Part 45 — Product roadmap

Stage 0: clean foundation—stabilize IDs, time model, state ownership, diagnostics, tests, and recovery. Gate: repeatable save/reopen and deterministic commands.

Stage 1: basic editor—import, one sequence, trim, preview, audio, export. Gate: one complete offline workflow with matching output.

Stage 2: strong timeline—split, ripple, links, snapping, multiselect, history. Gate: randomized command/inverse tests and boundary fixtures.

Stage 3: professional editing—transforms, captions, text, color basics, precise inspector. Gate: preview/export conformance and multilingual tests.

Stage 4: creative content—schemas, curated presets, templates, registry. Gate: ten real packages installed, upgraded, and reopened offline safely.

Stage 5: performance—profiling, bounded scheduling, proxies, virtualization. Begin basic budgets earlier; this stage deepens them. Gate: published benchmark on reference hardware, stable long-run memory.

Stage 6: advanced editing—masks, ramps, nested compositions, multicam synchronization/switching. Gate: complex fixtures and capability disclosure.

Stage 7: AI—reviewable, cancellable analysis and generation. Gate: quality evaluation, privacy controls, idempotent jobs.

Stage 8: cloud—backup, sync, comments, later collaboration. Gate: offline/conflict/security tests.

Stage 9: creator ecosystem—submission, moderation, versioned distribution, business controls. Gate: rights and operational review.

Stage 10: master platform—mature cross-platform delivery, supported plugins, reliable operations. Gate: sustained reliability and maintainable ownership, not “all ideas implemented.”

Do not assign confident calendar dates before measuring team capacity. The detailed companion roadmap defines dependencies, risks, tests, and exit criteria for every stage.

## Part 46 — Complete feature matrix

The companion feature matrix is the planning inventory, not a claim of implementation. Columns are System, Feature, Sub-feature, Priority, Required engine, Dependencies, Difficulty, Platform, Stage.

Priority P0 protects correctness/data; P1 completes core workflows; P2 expands creativity; P3 is strategic/advanced. Difficulty is relative engineering complexity, not a time estimate. Platform lists intended reach, not certified support.

A feature moves through proposed → specified → prototyped → implemented → verified → released. Avoid replacing all these states with a single “done” checkbox.

Use the matrix to plan vertical slices. “Captions” is too broad: import, transcription, timing correction, shaping, styling, export, cancellation, and recovery require different tests and dependencies.

## Part 47 — Study roadmap

Beginner: variables, functions, types, files, Git, and tests. Exercise: parse a clip list and calculate duration. Klipio project: a read-only timeline table. Explain asset versus clip before advancing.

Intermediate: immutable data, commands, async, time mapping, and widgets. Exercise: implement split/undo in memory. Klipio project: synthetic three-clip editor. Explain why source time differs from sequence time.

Advanced: media processing, matrices, rendering, caching, and profiling. Exercise: transform labeled test frames. Klipio project: preview/export parity harness. Explain cache invalidation and color/alpha contracts.

Professional: migrations, failure injection, accessibility, observability, and architecture tradeoffs. Exercise: recover an interrupted save. Klipio project: tested vertical feature with budgets and documentation. Explain safe cancellation and compatibility.

Master: platform ownership, distributed systems, content governance, security, and operational economics. Exercise: design sync conflict handling and plugin permissions. Klipio project: limited creator pilot. Explain which complexity should deliberately remain unbuilt.

Study by implementing and testing small examples, not memorizing every term. The companion study book supplies additional exercises and assessment questions.

## Part 48 — Master dictionary

The separate dictionary supplies English terms, plain explanations, Khmer explanations, professional meanings, and Klipio examples. Read the time, rendering, and state terms first.

A dictionary is not a substitute for an invariant. Knowing the word “snapshot” matters less than ensuring the export worker cannot read mutable inspector values. Knowing “GPU” matters less than measuring its memory and transfer costs.

Keep terminology consistent in schemas, UI, tests, and reports. When a term is ambiguous—frame, scale, time, selected—qualify it. Future contributors should not need to guess which coordinate space or identity a field means.

## Part 49 — Professional Product Experience Gap

### From a Functional Editor to a Professional Creative Platform

Added 2026-09-07. Status: proposed product and engineering standard. This chapter incorporates the supplied requirements; it does not certify the current application or repeat the attachment's claims of a complete repository/screenshot audit.

A working engine operation is not a finished feature. A professional editing experience combines correct media processing with discoverable tools, consistent controls, useful content, predictable state, reversible actions, and recovery. A beautiful screen cannot compensate for incorrect exports; a correct renderer cannot compensate for controls users cannot understand.

The [official CapCut beginner tutorial](https://www.capcut.com/resource/capcut-tutorial-for-beginners) describes importing, editing on a timeline, adding creative content, and exporting. It also presents template and media libraries. This is a workflow reference—not evidence of its internal architecture, a performance benchmark, or permission to copy its assets. The Klipio design below is an original proposal.

Read this chapter with Parts 3–4, 11–16, 22–25, and 39–44. The [Klipio Editor Improvement Plan](../04_EDITOR_ARCHITECTURE/Klipio-Editor-Improvement-Plan.md) concerns implementation and performance; this chapter concerns the complete experience built on top of a reliable engine.

### 1. Feature completeness: define the entire lifecycle

A function answers “can the engine perform this operation?” A complete feature answers “can a person discover, use, revise, preserve, and recover this operation?”

Use this lifecycle:

```text
Discover → Open → Configure → Preview → Apply → Edit
                           ↓
              Undo / Redo → Save → Reopen → Export
                           ↓
                    Failure / Recovery
```

Each transition has an owner, observable state, and acceptance test. Not every action supports undo: cancelling a download or spending remote AI compute is different from undoing a timeline edit. Document exceptions rather than forcing misleading reversibility.

Caption example:

1. Discover AI Captions from the creative browser.
2. Select language, backend/model where appropriate, and exact target videos.
3. Validate media availability and explain whether audio leaves the device.
4. Capture edited audio and project revision.
5. Show the current video, processing phase, progress, and cancellation.
6. Save each completed caption document even if a later item fails.
7. Display caption blocks on the correct timeline.
8. Edit transcript, word timing, line grouping, and speaker labels.
9. Browse styles, temporarily preview one, and explicitly apply it.
10. Apply chosen style groups to chosen targets without replacing transcript text.
11. Support undo/redo for committed editing changes.
12. Save/reopen with pinned fonts/styles and preserved timing.
13. Verify export geometry and text at the same composition timestamps.
14. Offer retry for failed items without duplicating successful captions.

Acceptance is not “the caption service returned text.” It is the successful lifecycle, including a failed third item after two successful items, stale-job results after an edit, and missing fonts after reopening.

### 2. One authoritative Klipio design system

A design system is a set of reusable visual and behavioral decisions. Its purpose is to prevent every feature from inventing a slightly different editor.

Foundation: semantic colors, typography, spacing, radius, elevation, iconography, motion, and density. Components: Button, IconButton, NumericField, SliderField, Dropdown, Tabs, SegmentedControl, Menu, Tooltip, Dialog, Panel, InspectorRow, PropertySection, AssetCard, CreativeAssetCard, TimelineClip, and TimelineHandle.

Every component documents default, hover, focus, pressed, selected, disabled, loading, and error behavior where applicable. Success feedback may be a short status message rather than a permanent green control. Components should not combine contradictory states such as enabled-and-blocked without a clear explanation.

NumericField contract: value, unit, bounds, precision, mixed state, transient change, commit, cancel, reset, and accessible name. A scale slider and its numeric field must represent the same value. Dragging produces one history transaction; typing invalid input preserves the last committed value until corrected or cancelled.

Maintain a gallery showing states, themes, Khmer text, long labels, and keyboard focus. Review components there before using them across the app. Tokens should be shared; project rendering colors remain user content and must not change when the UI theme changes.

### 3. Stable professional workspace architecture

```text
┌────────────────────────────────────────────────────────────┐
│ Project / Save status / Undo / Workspace / Export           │
├────────────────┬─────────────────────────┬─────────────────┤
│ Creative       │ Program Monitor         │ Contextual      │
│ Browser        │                         │ Inspector       │
│ Media / Audio  │ Source Monitor optional │                 │
│ Text / Captions│                         │ Selected target │
│ Effects        │                         │ properties      │
│ Transitions    │                         │                 │
├────────────────┴─────────────────────────┴─────────────────┤
│ Timeline / Track headers / Playhead / Zoom / Edit tools     │
└────────────────────────────────────────────────────────────┘
```

Regions retain conceptual ownership when resized, collapsed, or rearranged. Changing a browser tab does not change the selected clip's render settings. Showing source media does not replace the program composition.

Store panel sizes and docking in workspace preferences, separately from the project. Restore invalid layouts safely when monitors disappear. Small windows should switch to tabs/drawers with clear navigation, not place essential buttons off-screen.

Home job cards reopen job details; a separate cancel control requests cancellation. Closing the detail dialog does not cancel a persistent export. Focus returns to the originating control.

Tests: resize during playback; switch browser while a clip remains selected; reopen job details; reset layout; keyboard navigation with a narrow window; no project revision change from docking alone.

### 4. Context-sensitive inspector

The inspector derives its sections from selection type and capabilities, not from whichever global values were last visible.

| Selection | Main sections | Important guard |
|---|---|---|
| Video | Basic, transform, crop, mask, animation, speed, adjustment, effects | Explain unsupported or locked operations |
| Text | Content, font, style, layout, transform, animation, effects | Preserve shaping and composition units |
| Audio | Volume, fade, pan, voice/noise, speed, effects | Do not modify unrelated source instances |
| Caption | Transcript, timing, style, layout, animation | Separate transcript and style copying |
| Multiple objects | Shared applicable properties and mixed values | Preserve unedited differences |
| Nothing | Selection guidance or clearly labeled sequence properties | Never imply a clip is selected |

InspectorController should expose a view model and submit commands. It should not hold a second mutable copy of authoritative transform values. A text field may own an uncommitted editing buffer; commit must validate against the current selection/revision.

If selection changes during input, use an explicit policy: commit valid input to the original target before switching, or cancel the buffer with predictable behavior. Never apply buffered values to the newly selected object accidentally.

### 5. Progressive disclosure without hiding precision

Progressive disclosure shows common actions first and specialist controls when requested. It is not a license to make advanced tools undiscoverable.

Transform primary controls: position, linked scale, rotation, opacity. Advanced controls: anchor, independent axes, flip, blend, precise coordinates, and supported compositing options. Keep the section name, units, reset, and search discoverable.

Preset-first text workflows help beginners; the same text remains editable through font/layout controls. An advanced edit should show a “customized” indication rather than pretending the preset remains unchanged.

Remember expanded sections as a workspace preference. Do not reset project values when a section collapses. Search should reveal matching advanced controls. Tooltips explain consequences, such as “changes the pivot used for rotation,” rather than simply repeating “Anchor.”

Test a beginner journey without opening advanced settings and an expert journey using exact values. Both must produce the same underlying commands.

### 6. Data-driven creative libraries

Separate three things:

- Definition: immutable versioned description of supported content.
- Instance: project-owned use with parameters, timing, overrides, and references.
- Installation state: local download/validation availability.

Definition fields include ID, version, type, localized names, category, tags, thumbnail/preview references, implementation ID, parameter defaults, dependencies, compatibility, license reference, and access class. Download state is runtime metadata—not a permanent property of a published definition.

The same registry can serve effects, transitions, filters, text/caption styles, animations, stickers, LUTs, templates, music, and sound effects. Different types retain their own schemas and validators.

An engine implements reusable primitives. A definition configures those primitives; it cannot create an unsupported shader by naming it. A library of thousands is possible only when validation, discovery, version pinning, and resource limits work first.

Example: ten text presets can share shaping, fill, stroke, shadow, background, and animation primitives. A new curved-text primitive still requires engineering and tests. Do not count parameter variations as independent engine capabilities.

### 7. Creative browser and reusable asset cards

Use one browser pattern: search, categories, recents, favorites, downloaded, new, and optional editorial/recommendation sections. “Trending” requires real ranking evidence; with a small catalog use “Featured,” not invented popularity.

A CreativeAssetCard shows poster, name, selected/favorite state, availability, compatibility, and Free/Pro indication where applicable. Animated preview is optional and bounded. Keyboard focus offers an equivalent preview action; touch uses an explicit preview control.

States are separate axes:

```text
Interaction: idle / hovered / focused / pressed
Selection: unselected / selected
Availability: remote / downloading / installed / failed
Access: allowed / locked
Capability: supported / unsupported
Preview: stopped / preparing / playing / failed
```

A card can be favorite and unsupported simultaneously. Model these combinations rather than one enormous enum that loses information.

Download failure exposes retry. Unsupported exposes a reason and preserves selection context. Favorites do not automatically install content. Applying remote content waits for validated availability; double-clicking during download must not create duplicate timeline instances.

Virtualize large lists, cancel off-screen preview jobs, preserve scroll/filter state, and show a meaningful empty state. Search result keys use content identity/version, not row index.

### 8. Separate UI state from durable editing state

```text
EditorSession — lifecycle and coordination
├── ProjectController       revision and persistence coordination
├── TimelineController      command-facing edit operations
├── SelectionController     selection identity
├── PlaybackController      clock, seek, preparation
├── InspectorController     derived properties and input sessions
├── MediaLibraryController  import and availability
├── HistoryController       undo/redo transactions
└── WorkspaceController     panels and layout
              ↓ commands
         Editor Core
              ↓
    Immutable Project Revision
```

Controllers are not eight competing sources of project truth. The core owns the durable revision; controllers coordinate their responsibilities through contracts. Playback time and panel layout normally do not create saved edit revisions.

Workers carry input identity, revision, generation, and ownership. A stale thumbnail or caption result cannot overwrite a newer target. Export consumes a captured revision, not live inspector buffers.

Extract one responsibility at a time from shared widget state. Verify call sites and tests before removing the old path. Small files alone do not demonstrate clean ownership; adding controllers without removing duplicated authority makes the problem worse.

### 9. Interaction quality standard

Every feature specification addresses hover, focus, selection, keyboard, context menu, tooltip, cursor, drag feedback, drop validity, snapping, cancellation, loading, empty state, error, retry, disabled reason, progress, and success. Mark genuinely irrelevant states “not applicable” with a reason.

Examples:

| Situation | Required feedback | Recovery/behavior |
|---|---|---|
| Drag over locked track | Invalid target and reason | Release makes no edit |
| Snap near cut | Visible alignment cue | Temporary bypass available |
| Empty text library | Explain no installed/matching styles | Clear filters or import/download |
| Missing font | Identify affected style | Choose replacement or install |
| Export finalizing | Phase distinct from rendering | Do not report completion early |
| Network retry | Keep prior successful items | Retry failed item only |
| Cancel requested | Cancelling state | Complete only after owned work stops |

Polish includes predictability, not merely animation. Reduced-motion preferences should disable nonessential motion. Progress announcements should be useful without repeatedly interrupting screen-reader users.

### 10. Preview-first workflow with safe temporary state

Hover or explicit preview should let users evaluate a creative choice without altering durable content.

Proposed lifecycle:

```text
Start preview → capture target/revision → apply transient overlay
       ├── Leave / Escape / selection change → discard overlay
       └── Apply → validate target/revision → commit one command
```

Transient preview is not implemented by mutating the project and hoping to undo later. Otherwise autosave, export, or another command may accidentally capture the preview.

Use a preview token tied to target identity. A late-loaded effect cannot appear on another selected clip. If project revision changes while previewing, cancel or rebase through explicit validation. Export reads durable state and excludes the transient overlay.

Apply works for effects, transitions, filters, text/caption styles, animations, LUTs, and templates with type-specific rules. Template preview may use an isolated miniature composition rather than replacing the main project.

Tests: hover then leave changes no revision; Escape restores the display; click commits once; undo restores; download completes after selection change without stale application; export during preview uses committed content.

### 11. Content quality is a delivery track

Engineering and content production have different outputs but shared gates.

Engineering: timeline, render/audio primitives, text, animation, export, scheduling, compatibility.
Content: original presets, title/caption designs, templates, stickers, licensed music/sounds, thumbnails, and preview media.

A proposed pilot is ten carefully authored assets spanning several supported types—not an arbitrary requirement for a thousand items. Each asset needs:

- owner and provenance;
- stable ID/version and dependencies;
- supported implementation/parameters;
- accurate thumbnail and optional preview;
- localized label, category, and useful tags;
- rights/access metadata reviewed for the intended distribution;
- offline/reopen/export validation.

Good content density means useful, distinguishable choices. Duplicated presets with different names inflate a counter but reduce trust. Do not preview a look that the installed engine cannot export.

Schedule content work after the required primitive is stable. Review content quality and engineering correctness together before publication.

### 12. Definition of Done for UI features

| Gate | Required evidence |
|---|---|
| Functional | Success and validation tests |
| Design system | Approved shared components and state gallery |
| Keyboard/accessibility | Named controls, focus path, non-drag alternative |
| Undo/redo | Round-trip state checks where applicable |
| Save/reopen | Fixture preserving values, identity, dependencies |
| Preview/export | Same-time geometry/text/render comparison |
| Responsive behavior | Narrow layout, large text, panel resize |
| Failure states | Empty/loading/error/retry and cancellation tests |
| Performance | Measured workload, hardware, budgets and results |
| Regression | Automated coverage of the reported failure |
| Documentation | Contract, limitations and recovery steps |
| Release | Separately authorized build/install/smoke evidence |

Use proposed, specified, implemented, verified, and released as distinct statuses. A documentation chapter supplies specifications—not green checkmarks for the running app. A waived gate needs a reason and owner.

### 13. Feature development process and first ten workflows

Use: user problem → complete experience → owning system → data/units → command contract → UI states → engine behavior → shared components → persistence → render/export → tests → measurements → documentation → release.

First complete these existing/core workflows before adding another hundred functions:

| Workflow | Completion target |
|---|---|
| Import | Independent posters, offline/retry behavior |
| Select and inspect | Correct target, mixed values, no stale buffer |
| Trim/split | Exact time mapping and undo |
| Reframe | Gizmo/numeric agreement and export parity |
| Apply selected | Latest values, exact targets, checked groups only |
| Add text | Useful preset, editable content, shaping, reopen |
| Generate captions | Edited range, per-item progress, partial recovery |
| Apply creative style | Temporary preview, one commit, undo |
| Save/recover | Latest revision, failure handling, restore |
| Export batch | Exact files, per-item status, reopen details, cancel |

Sequence the work: baseline fixtures first; shared controls next; workspace/inspector; creative browser; text/caption journey; curated content. Preserve working core behavior and keep each step testable. These priorities complement rather than replace the playback/export correctness plan.

### 14. Product quality rule and review ritual

Klipio should develop its own identity through consistency, clarity, predictability, speed, hierarchy, content quality, polished interaction, correctness, persistence, rendering agreement, and accessibility. Copying a competitor's colors or layout does not deliver these qualities.

At each milestone, perform one complete user journey without developer assistance. Observe where the user hesitates, loses selection context, cannot undo, or cannot recover. Record the issue, owning system, expected behavior, test, and measurable result.

Review three independent questions: does it work correctly; can someone understand it; does it stay reliable under failure and load? None substitutes for another.

The immediate objective is ten coherent experiences, not a claim of competitor parity. This chapter is documentation only. No app code, assets, installer, or EXE was changed to implement these proposals.


## Maintenance and evidence

This first edition covers every requested part as an architecture handbook; it is not a claim that a mature editor can be delivered from a document alone. Expand chapters with implementation experiments and measured decisions as the product evolves.

Sources checked on 2026-09-07: linked official FFmpeg, OpenTimelineIO, and W3C references. Most architecture, schemas, acceptance criteria, and roadmap material here is proposed Klipio design rather than a factual description of another product. Recheck version-specific commands against the bundled runtime.
