# Backend and cloud specification

## Local-first boundary

Local commands, save, preview and export continue offline. Cloud sync runs independently. UI shows local saved revision and remote synced revision separately.

Initial backend is a modular service: identity, projects, catalog, job coordination, billing boundary. Split deployment only when operations or scaling evidence requires it.

## Proposed API surface

POST /projects — idempotent creation.
GET /projects/{id}/revisions/{revision} — authorized snapshot.
PUT /projects/{id}/head — expected revision precondition.
POST /uploads — resumable asset upload session.
POST /jobs — idempotent remote processing request.
GET /jobs/{id} — durable state.
POST /jobs/{id}/cancel — cancellation request, not immediate completion.
GET /catalog — cursor-paginated compatible content.

These are proposed endpoints, not live services.

## Sync example

Devices A and B both open revision 10. A commits 11 remotely. B submits based on 10. Server rejects head replacement with conflict metadata. B preserves its local branch and offers compare/duplicate/reconcile. Do not overwrite B's edit and do not merge arbitrary JSON arrays by index.

Media blobs upload independently using verified identity. A metadata revision may be locally valid while some remote blobs are pending; expose this.

## Operations

Use durable job records and idempotent workers. Scope authorization by account/project membership. Signed download URLs, if used, expire and must not appear in logs. Backups require restore drills. Define deletion retention and account export before public launch.

## Progression and tests

Start backup/restore → single-user sync → comments → controlled collaboration. Test offline edits, partial upload, duplicate requests, permission revocation, account switching, and server restart. Real-time collaboration requires separate operation convergence design; it is not an extra websocket alone.

