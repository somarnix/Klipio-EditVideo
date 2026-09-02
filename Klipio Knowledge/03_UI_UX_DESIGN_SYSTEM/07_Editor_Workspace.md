# Klipio workspace

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Top bar owns project/save/undo/export. Left creative browser owns discovery. Center owns source/program viewing. Right owns selected-target properties. Bottom owns timeline interaction.

## Klipio behavior rules

Docking, panel width and last-open browser are workspace preferences, not project edits. Closing job details leaves the job running. Home job card opens details; its cancel button is separate. Restore off-screen windows safely.

## Acceptance and failure checks

Test keyboard region navigation, reset layout, display removal, resizing during playback, and project revision unchanged by layout edits.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

