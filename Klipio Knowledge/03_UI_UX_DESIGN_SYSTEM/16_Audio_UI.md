# Klipio Audio UI

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Show volume, pan, fades and meters first; voice/noise/EQ/dynamics behind advanced sections. Waveform identifies source/clip and unavailable analysis. Record voiceover with clear input device and recording state.

## Klipio behavior rules

Mixer changes issue commands; meters are transient observations. Detach preserves link policy. Warn before replacing recorded takes; keep original recordings. Music preview should not unexpectedly interrupt program audio.

## Acceptance and failure checks

Test keyboard exact gain, mute versus visibility, device loss, recording failure, independent music and source-audio copying.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

