# Klipio Creative Browser

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

One browser shell serves Effects, Transitions, Filters, Text Styles, Caption Styles, Animations, Stickers, Templates, LUTs, Music and Sound Effects through typed adapters.

## Klipio behavior rules

Provide search/categories/tags/filtering, Recommended, Trending only with evidence, New, Favorites, Recents and Downloaded. Cards expose Free/Pro, compatibility, poster, optional animation, install state, download progress, error and retry. Use stable IDs, cursor pagination and virtualization.

## Acceptance and failure checks

Cancel stale search/preview requests. Favorites do not install. Preserve scroll on return. Test offline search, duplicate labels, Khmer input, keyboard selection, failed downloads and off-screen resource release.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

