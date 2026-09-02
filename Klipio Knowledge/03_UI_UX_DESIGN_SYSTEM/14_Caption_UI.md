# Complete caption experience

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Flow: select targets/language → validate edited audio → generate → review → transcript/timing → style/animation → apply selected → save/reopen/export. Exact target expressions resolve to IDs and visible counts.

## Klipio behavior rules

Progress is per video plus item N of total. Completed items persist when later jobs fail. Cancel waits for owned work. Separate style copying from text replacement. Stale results require review.

## Acceptance and failure checks

Test partial completion, retry without duplication, timing after speed/cuts, unsupported language/model, font fallback, undo and export bounds.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

