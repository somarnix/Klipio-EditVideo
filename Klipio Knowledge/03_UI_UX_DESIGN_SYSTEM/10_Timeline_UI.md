# Klipio Timeline UI

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Time ruler, playhead, clip positions and hit tests share one time-to-pixel mapping. Clip body shows identity, filmstrip/waveform and status; handles show edit boundaries; selection remains distinct from playback position.

## Klipio behavior rules

Virtualize visible buffered intervals. Snap threshold uses screen pixels. Drag creates a transient proposal and one command on release; Escape cancels. Locked and invalid targets explain why. Track header exposes visibility, mute and lock independently.

## Acceptance and failure checks

Test zoomed split boundaries, marquee, Ctrl/Shift selection, linked clips, scroll during drag, keyboard trim and seven distinct filmstrips.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

