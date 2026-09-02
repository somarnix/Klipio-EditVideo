# Asset and content platform specification

Document: Asset and content platform specification
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

## Manifest example

```json
{
  "contentId": "klipio.example.caption-pack",
  "version": "1.0.0",
  "manifestVersion": 1,
  "type": "textStylePack",
  "names": {"en": "Clear captions", "km": "អក្សររត់ច្បាស់"},
  "tags": ["captions", "readable"],
  "engineApi": {"min": 1, "max": 1},
  "dependencies": [{"id": "font.example", "version": "1.0.0"}],
  "files": [{"path": "styles/clear.json", "sha256": "example-replace-with-real-sha256"}],
  "preview": "preview/poster.png",
  "licenseRef": "license.example",
  "accessClass": "free"
}
```

This demonstrates shape, not a valid distributable package: example digests and license/font references must be replaced and verified.

## Lifecycle

Draft → validate → review → immutable publication.
Client: discover → download temporary package → verify → dependency resolve → install atomically → index → use pinned version.
Retirement stops new discovery according to policy; project compatibility needs an explicit plan.

## Storage and safety

Separate downloaded package store from disposable thumbnails. Use content ID + version + digest identity. Validate archive entries remain under the staging directory and enforce expanded-size limits. Reject duplicate/conflicting manifest paths and dependency cycles. Do not trust a filename extension.

Maintain project pins and reference counts. Evict unpinned content according to policy; never delete user-created assets as a cache cleanup. Provide portable project packaging with license-aware warnings.

## Catalog and rights

Localized metadata, categories, tags, search, favorites, recents, collections, preview video, download state, compatibility, and access class belong to catalog views. Rights metadata should describe source/provenance and intended permitted uses; commercial policy requires review rather than assumptions.

## Acceptance

Ten representative packages—effect, transition, filter, font, text style, music, sound effect, sticker, animation, template—must install, resolve dependencies, reopen offline, fail safely when corrupt, and support version pinning before scaling the catalog.
