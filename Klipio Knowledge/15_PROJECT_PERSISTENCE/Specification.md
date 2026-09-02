# Klipio Project System and Persistence

Document: Klipio Project System and Persistence
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

Status: Specified target contract. Existing serialization does not prove all requirements below are implemented.

## Durable schema

Project envelope: schemaVersion, projectId, revision, metadata, sequences, assetReferences, contentPins and optional extensions. Sequences own tracks and output settings; clips own source ranges/time maps, transforms, effects, keyframes and links. Text, caption and audio documents have versioned references.

Project ID identifies a document lineage; clip ID identifies one use; asset ID identifies media. Display names and paths are not interchangeable with identity. Time fields carry explicit units/rates. Do not serialize Flutter widgets, controllers, scroll positions or player instances as durable edit state.

## Paths and portability

Managed media uses validated relative paths inside the bundle. External locators retain identity/fingerprint and offline state. Resolve paths against the project root, never the app source directory. Reject traversal and unsafe archive paths. A portable package copies permitted media and pinned dependencies, verifies them, then publishes; do not delete original external media.

Relinking is explicit: inspect candidate fingerprint, duration, streams and rotation; warn on mismatches. Offline clips retain editing intent and support undo. Missing media is not project corruption.

## Schema evolution

Schema versions differ from app versions. Each migration maps N to N+1 on a copy, validates before/after and retains the original until safe save. Unknown essential features require read-only/compatibility handling; optional opaque extensions should round-trip. Historical fixtures must include older paths, source ranges, captions, links and unavailable content.

## Save and Save As

Save captures revision, writes a sibling temporary file, validates and flushes where supported, then performs a platform-safe replacement. Never assume cross-volume moves are atomic. Serial saves prevent older revisions overwriting newer ones.

Save As must explicitly choose duplicate versus relocate semantics. Proposed default: duplicate with new project identity, preserve original, and clarify whether media is copied or referenced. Only switch active destination after success.

## Autosave and recovery

Debounce frequent changes but enforce a maximum unsaved interval. Display last saved revision and failure state. Snapshots are consistent durable revisions; a journal is an optional ordered record of validated changes between snapshots. Journal records include sequence/checksum and replay stops before an incomplete record.

Startup recovery shows dates/revisions and preserves alternatives until the user chooses. Corruption detection includes parse, checksum where present, references, IDs, ranges and version validation. Backups have explicit retention; cache cleanup cannot remove recovery history.

## Required evidence

Interrupt at every save phase; simulate disk full and access denial; reopen historical fixtures; retry failed autosave; recover truncated journal; relink wrong media; package on another drive and reopen without original location. A JSON round-trip test alone does not verify crash recovery.



## Independent version identities

App Version identifies the executable release. Project Schema Version identifies serialized structure and migrations. Content Package Version pins creative definitions/assets. Effect Implementation Version identifies processing semantics and compatibility. None is inferred from another. A project can use an old content package with a newer application.

An unsupported future schema opens read-only if safe interpretation is possible, otherwise fails with an explanatory message and preserves the original bytes. Never automatically downgrade or overwrite an unreadable project.
