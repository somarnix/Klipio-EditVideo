# Editor architecture and contracts

Document: Editor architecture and contracts
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

Status: original proposed contracts; illustrative JSON/pseudocode, not production schemas.

## Ownership

| Module | Owns | Must not own |
|---|---|---|
| Editor Core | Project revisions, IDs, command validation | Widgets and subprocesses |
| Timeline | Ranges, links, editing policies, time maps | Inspector selection |
| Render | Scene semantics and plan validation | Subscription screens |
| Media | Asset metadata and derived-media jobs | Clip transforms |
| Content | Definitions, versions, dependencies | User clip state |
| Persistence | Serialization and migrations | Render behavior |
| UI | Selection, layout, interaction previews | Durable edit truth |
| Adapters | Native/network/storage mechanisms | Hidden edit policy |

## Minimal project example

```json
{
  "schemaVersion": 1,
  "projectId": "project-a",
  "revision": 12,
  "assets": [{
    "id": "asset-a",
    "locator": "Resources/Media/source.mp4",
    "fingerprint": "example-not-a-real-digest"
  }],
  "sequences": [{
    "id": "sequence-a",
    "width": 810,
    "height": 1080,
    "frameRate": {"numerator": 30, "denominator": 1},
    "tracks": [{
      "id": "track-v1",
      "kind": "video",
      "locked": false,
      "clips": [{
        "id": "clip-a",
        "assetId": "asset-a",
        "start": {"ticks": 150, "rate": 30},
        "duration": {"ticks": 120, "rate": 30},
        "sourceIn": {"ticks": 300, "rate": 30},
        "speed": {"numerator": 2, "denominator": 1},
        "transform": {
          "position": [405, 540],
          "anchorNormalized": [0.5, 0.5],
          "scale": [1, 1],
          "rotationDegrees": 0,
          "fit": "contain"
        }
      }]
    }]
  }],
  "contentPins": []
}
```

This clip lasts four sequence seconds and consumes eight source seconds. Production schema additionally needs stream selection, source bounds, color, links, effects, audio, validation limits, and migration fixtures.

## Command contract

```text
CommandEnvelope:
  commandId, expectedRevision, type, arguments, interactionId

execute(project, command):
  validate expectedRevision
  resolve stable IDs
  validate all affected objects and policies
  calculate new state and inverse patch
  validate resulting invariants
  commit exactly one revision
  return revision + changeSet + undoRecord
```

No I/O inside pure command calculation. External work begins after a committed request or in an application coordinator. Failed validation commits nothing.

## Worker contract

```text
JobRequest: jobId, kind, inputFingerprint, revision, generation, limits
JobUpdate: jobId, phase, itemIndex, processedTime, heartbeat, diagnostics
JobResult: jobId, inputFingerprint, revision, artifacts, status
```

Reject stale results or offer review. A UI widget disposing does not automatically own cancellation of a persistent export; ownership belongs to the job coordinator.

## Incremental migration

First introduce typed time/IDs and tests around existing behavior. Then route one command through a pure handler. Next extract snapshot construction. Replace one UI feature's direct mutations. Add adapter interfaces where tests need them. Remove old paths only after call-site verification and regression tests. Do not perform a wholesale rewrite based only on file size.
