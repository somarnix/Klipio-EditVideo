# Klipio visual identity

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Klipio uses quiet neutral work surfaces, restrained violet action accents, and a cyan playhead. Color roles are proposals, not proof of current compliance. Video content is the visual focal point; chrome must not compete with it.

## Klipio behavior rules

Primary hierarchy is project → workspace regions → selected target → properties. Keep destructive actions visually separate. Prefer one primary action per dialog. Use consistent interaction patterns instead of competitor-derived component names.

## Acceptance and failure checks

Review one import-to-export journey at narrow and wide widths. A user must identify selection, pending work, and recovery actions without developer explanation.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

