# Semantic color system

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Proposed dark roles: base #17191F, raised #222630, primary text #F2F4F8, muted text #B4BCCB. Proposed light roles: base #F4F5F8, raised #FFFFFF, primary text #19202B. Action accent #7052A3; playhead #00AFC8. These are candidate tokens requiring contrast measurement, not certified pairs.

## Klipio behavior rules

Use selection border plus a shape/label, not color alone. Focus is a separate outline and remains visible on selected controls. Errors use an icon and message. Disabled controls retain readable labels and expose a reason. Theme tokens never change project colors.

## Acceptance and failure checks

Measure contrast for each actual foreground/background pair and selected/hover combination. Check grayscale, themes, transparency and video-backed overlays before approving tokens.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

