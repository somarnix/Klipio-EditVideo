# Text browser adapter

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Offer Default Text, Presets, Titles, Caption Styles, Minimal, Social, Gaming, Cinematic, News, Favorites and My Presets as curated categories where content exists. Do not display fake empty collections as finished libraries.

## Klipio behavior rules

Preview cards demonstrate actual font/layout. Insert text and apply style are different actions. Applying style preserves user content unless explicitly replacing a template slot. Show customized status after overrides.

## Acceptance and failure checks

Test missing fonts, Khmer shaping, wrapping, style undo, save/reopen, and composition-size export. A thumbnail is not evidence that editable text works.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

