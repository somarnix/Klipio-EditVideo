# Klipio contextual inspector

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Video: Basic/Transform/Crop/Mask/Animation/Speed/Adjustment/Effects. Text: Content/Font/Style/Layout/Transform/Animation/Effects. Audio: Volume/Pan/Fade/Voice/Noise/Speed/Effects. Caption: Text/Timing/Style/Layout/Animation/Apply selected.

## Klipio behavior rules

Derive properties from selected IDs. Multiselect shows mixed values and common supported controls. Primary controls appear first; advanced sections expand. Input buffers retain original target identity and validate revision before commit. No selection shows clearly labeled guidance or sequence settings.

## Acceptance and failure checks

Test selection changes during numeric entry, locks, mixed targets, unsupported capabilities and reset. Applying one field must preserve unrelated differences.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

