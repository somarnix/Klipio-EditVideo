# Effect system specification

Document: Effect system specification
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

## Definition versus instance

Definition describes a supported operation and UI schema. Preset selects parameters. Instance belongs to a clip and stores overrides/keyframes. Updating a definition does not silently upgrade old instances.

```json
{
  "id": "klipio.blur.soft",
  "version": "1.0.0",
  "implementation": "gaussianBlur",
  "implementationApi": 1,
  "category": "blur",
  "parameters": {
    "radius": {"type": "number", "unit": "compositionPixel", "min": 0, "max": 64, "default": 8}
  },
  "capabilities": ["rgba", "animatedParameters"],
  "temporalRadiusFrames": 0
}
```

UI derives a numeric slider from radius metadata. The engine still needs a tested gaussianBlur implementation. Downloading a definition with an unknown implementation does not add new native functionality.

## Text style example

```json
{
  "id": "klipio.text.clear",
  "version": "1.0.0",
  "fontRef": "font.example@1",
  "fontSizeCompositionPixels": 36,
  "fill": "#FFFFFFFF",
  "stroke": {"color": "#000000FF", "width": 2},
  "shadow": {"offset": [0, 2], "blur": 3, "color": "#00000080"},
  "alignment": "center",
  "animationRef": null,
  "tags": ["readable", "caption"]
}
```

Font reference is illustrative, not a bundled real font. Use explicit color-channel notation and validate it consistently.

## Authoring workflow

Implement one primitive → add parameter tests → render references → author several presets → generate thumbnails → validate package → publish version. Build category views from metadata. Do not add a custom panel for every look.

## Test gates

Bounds/type validation; deterministic seed behavior; input/output alpha; backend agreement; persistence; missing implementation; animated parameter evaluation; content pinning. New effect types cannot ship with preview-only support unless the product explicitly labels them nonexportable.
