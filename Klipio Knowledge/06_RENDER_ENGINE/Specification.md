# Render engine specification

Document: Render engine specification
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

## Canonical inputs

RenderPlan captures revision, sequence dimensions/FPS, clip time maps, transforms, canvas layers, color policy, effects, text/captions, audio graph, and content versions. Preview uses a quality policy; export uses an output profile. Neither rebuilds edit intent from inspector values.

## Coordinate contract

Source dimensions include orientation/sample-aspect handling.
Crop is defined in source-normalized coordinates.
Fit maps cropped source to composition.
User transform applies anchor, scale, rotation, and position in declared order.
Canvas is independently composed.
Text uses composition pixels, not preview-widget pixels.
Display scales the completed composition to the monitor viewport.

For a 810×1080 sequence displayed at 270×360, a 36-composition-pixel caption appears nominally 12 screen pixels high before glyph metrics. Export at 810×1080 uses 36, not 12 and not 108. Font shaping still determines actual glyph bounds.

## Cache contract

Node cache identity includes implementation version, upstream hashes, evaluated parameters, time, dimensions, color/alpha policy, and quality. Temporal effects add their neighborhood. Invalidating a caption should not invalidate unrelated decoding.

## Conformance fixture

1. Use a source with labeled quadrants and frame numbers.
2. Place in 3:4 canvas with contain plus 1.2 X and 0.8 Y scale.
3. Add noncentral position, 15-degree rotation, blur background.
4. Add Khmer/English caption with known composition font size.
5. Add constant speed and a cut.
6. Capture preview/reference render at exact sequence timestamps.
7. Export and decode those timestamps.
8. Assert dimensions, source-frame labels, transform bounds, caption layout, and permitted color difference.

Record engine, fonts, source digest, profile, and comparison tolerance. Shared snapshots alone do not prove parity; backend implementations must pass this fixture.

## Failure policy

Unsupported effects produce preflight errors or an explicit user-approved fallback. Device loss can retry on a verified backend; it must not silently omit layers. Final outputs publish only after verification. Temporary surfaces and files belong to the job and have bounded lifetime.
