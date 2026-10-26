# TKL-managed Material delivery presentation

Current disposition, 2026-10-27: the bounded TKL follow-on is accepted and closed
with App Phase 6.3's ordinary completion. The source is locally committed;
original phases remain closed. Earlier dated authoring/pending statements below
retain their historical scopes. Current requirements and selected evidence are
indexed by the owning delivery plan; no execution report, new grant, public
release or main integration is added by this management update.

Decision: 2026-10-24; clarified 2026-10-25. Status: implementation in progress;
live acceptance pending.

ESA63-01 now publishes the passive `TklMaterialDeliveryFacade` over Core's
borrowed TKL client, using only public package imports. Its constructor and
query surface start no upload, registration, consent or retry. Concrete status
widgets now project the existing durable Core queue. The TKL-specific setup
asks for authenticated service bootstrap without Google destination fields and
preserves legacy definitions for retained requests. The standard detail displays
confirmed Material references, the actual direct/mediated route and its safe
reason, pending TKL confirmation and a separate absent Studio receipt. The
24 focused common settings/status specifications pass, including both actual
routes and the capability reason. No widget issues raw transfers.

Use [Core's TKL contract](../../../textus-flutter-core/docs/notes/tkl-managed-material-delivery.md)
and [TKL's configuration authority](../../../textus-knowledge-lake/docs/spec/tkl-managed-mobile-material-delivery.md).
TFAF provides the common facade and UI; Core owns IO, background work, queue,
credentials and recovery. Apps compose this functionality rather than defining
their own Google settings or upload service.

## User experience

- Display the TKL-provided logical destination and relevant account/connection
  status. Never require drive IDs, folder IDs, Lake paths or raw/prepared rules.
- If TKL offers multiple permitted destinations, display those supplied choices.
  The first delivery needs only one configured destination, not a folder browser.
- Offer sign-in/consent when Core reports it is required. Consent is not storage
  configuration and must not be simulated by a successful settings save.
- Show queued/waiting/transferring/registering/completed/failure states from
  Core's actual projection. Keep subsequent Studio submission separately visible.
- Present supported retry/reconnect actions and operator-action messages when
  TKL configuration/access is missing. Do not prompt users to fix provider IDs.
- Preserve local editing and pending work while offline. Screen mounting or
  rendering must not itself start upload or authorize another account.

## Test configuration and production discovery

The user permits explicit configuration for tests (2026-10-24). Test composition
may inject a configured Core client/facade and display its fixture states. This
is not a production settings screen or evidence of a real registration.

In production, use Core's TKL-provided integration information and logical
destination. Widgets do not select physical storage or fall back to a test
configuration when TKL is unavailable. Service bootstrap/authentication remains
separate; the existing production status/action contract is unchanged.

## Migration and acceptance

The existing manual Drive/HTTP configuration UI describes the earlier direct
submission route. Replace manual Google destination setup in the new TKL route;
do not simply hide fields while still requiring consumers to provision them.
Preserve legacy pending-work visibility and delegate its disposition to Core/TKL.
Workspace Shared Drive and My Drive shared-folder targets use the same UI and
facade. Do not embed physical mapping or fallback selection in widgets.

Test no-ID setup, consent required, TKL unavailable, permission failure, progress,
targeted retry and registration distinct from upload. Widget fixtures prove UI
behavior; the App's live Shared Drive scenario proves device integration.

Plan: [delivery workstream](../phase/tkl-managed-material-delivery-plan.md).

## DU-03 five-stage common status authoring (2026-10-25)

The selected TFAF consumer now authors one common stage summary: Preparation,
Upload, Integrity verification, TKL registration and Studio receipt. Counts use
Core's actual completed/total values. Unreported verification remains `Not recorded`;
upload completion and legacy Registered never manufacture SHA proof. Actual TKL
registration alone exposes its Material reference; absent Studio acknowledgement
remains `Not received` and does not increment overall completed submissions.
The overview includes preparation, verification and registration in its disjoint
attention/running buckets. A retained TKL registration without Studio receipt is
waiting for a separate submission outcome, not a complete submission.

Safe integrityMismatch, verificationUnavailable and integrityUpgradeRequired
instructions retain originals for operator review/upgrade. Other safe reasons
retain generic reconciliation. Mixed per-original proof distinguishes a verified
sibling from a failed one without repeating all five stages. Existing generic
non-TKL presentation, common selection/navigation/fencing/detach and Core-owned
actions remain in place. Mounting and status refresh perform observation only.
No provider/session identifiers, digests or raw errors are added to diagnostics.

Authored executable scenarios use actual temporary SQLite records, pure Core
projections and common widgets at compact and split sizes. They cover partial
digest checkpoints, placed originals without proof, verification pending/running,
verified-before-registration, Registered without Studio ACK, old no-digest
Registered, retained mismatch/unavailable/upgrade and verified/failed siblings.
Binding scenarios reopen the queue and exercise only actual requestRun; summary
scenarios assert disjoint counts and no invented downstream completion. Existing
non-TKL/lifecycle specifications remain the regression authority.

This is source/specification authoring, pending parent analysis, affected tests
and independent review. No worker test/analyze/pub/build/format/runtime/network,
self-review, Git mutation, commit or delegation occurred. This record claims no
live SHA verification, device acceptance or Phase closure. Existing six-photo
offline evidence and consumed 7/7 live-create allowance remain unchanged.
