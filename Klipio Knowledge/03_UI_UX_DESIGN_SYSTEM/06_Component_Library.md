# Reusable Klipio components

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

All named components use the contracts below; feature-specific wrappers configure them rather than duplicating their behavior.

## Klipio behavior rules

Common state contract: Default baseline; Hover affordance; Pressed active input; Focused visible keyboard outline; Selected persistent choice; Disabled reason/no command; Loading bounded progress/cancel policy; Error message/recovery. Mark inapplicable states explicitly, never invent misleading selection for a plain action button.

## Acceptance and failure checks

Use a gallery across themes, density, localization, input methods and errors. Test event semantics separately from screenshots.

## Ownership

## Component contracts

Every component inherits the relevant eight-state contract above. Hover/pressed/focus describe input, selected describes a persistent choice, disabled prevents commands, loading belongs to owned work, and error provides recovery. For decorative components, nonapplicable input states are explicitly omitted. Do not simulate fake loading for an instantaneous control.

| Component | Inputs | Behavioral contract |
|---|---|---|
| KlipioButton | label, command, enabledReason, busy | Enter/Space invokes once; busy prevents duplicate command; error belongs to operation feedback |
| KlipioIconButton | icon, accessibleName, shortcut | Tooltip and focus required; no icon-only ambiguous destructive action |
| KlipioSlider | value, range, unit, mixed, interactionId | Transient drag; release commits once; Escape restores; disabled shows reason |
| KlipioNumericField | value, precision, bounds, unit, buffer | Validate before commit; preserve original target while editing; error labels invalid input |
| KlipioDropdown | options, selectedId, availability | Keyboard navigation; unknown saved value remains visible with warning |
| KlipioTabs | items, activeId | Arrow navigation; selected tab differs from focus; loading belongs to panel |
| KlipioSegmentedControl | options, selectedValue | Single documented choice mode; mixed selection explicit; no hidden immediate destructive action |
| KlipioMenu | actions, scope | Registry-driven actions; escape and focus return; unavailable items explain reason |
| KlipioContextMenu | targetIds, revision, actions | Validate target on execution; no stale-target command |
| KlipioTooltip | description, shortcut, anchor | Available on focus; nonessential; does not trap pointer/focus |
| KlipioDialog | title, content, actions, dismissPolicy | Focus containment/return; busy dismissal policy explicit; error does not erase form |
| KlipioPanel | title, regionId, minSize | Resize/collapse only workspace state; visible loading/error region |
| KlipioInspectorSection | title, expanded, capability | Disclosure never resets values; unavailable capability explained |
| KlipioInspectorRow | label, unit, valueControl, reset | Aligned labels; mixed/reset/keyframe indicators have accessible names |
| KlipioAssetCard | assetId, poster, availability | Selection independent from loading; retry/relink on error |
| KlipioCreativeAssetCard | contentId, version, preview, access, compatibility | Independent state axes; preview token; explicit apply; download idempotency |
| KlipioSearchField | query, filters, requestGeneration | Cancel stale results; clear action; no results distinct from failed search |
| KlipioTimelineClip | clipId, range, selection, lock | Time mapping shared; drag transient; offline styling preserves identity |
| KlipioTimelineHandle | edge, clipId, constraints | Keyboard alternative; valid range clamp; one trim commit |
| KlipioPlayhead | sequenceTime, viewportTransform | Observation not project edit; accessible seek; no expensive broad rebuild requirement |
| KlipioTrackHeader | trackId, name, mute, visible, locked | Distinct toggles with state labels; confirmation/undo for removal |


Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.


## Shared authority and preview rule

KlipioCreativeAssetCard plus content-type configuration is the shared browser primitive. Feature adapters may supply labels, preview providers and typed intents, not incompatible selection/download contracts. All component contracts here take precedence over informal generic names in teaching examples.

UI submits typed editing intents. The owning Klipio editor system validates and commits durable changes. Temporary preview never enters undo history or autosave; an accepted editing command creates a revision and undo record where reversible. Leaving preview discards the overlay and displays committed state; it does not write an old snapshot back over newer edits.
