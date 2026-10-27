# TKL-managed Material delivery presentation

Decision: 2026-10-24. Status: specification; implementation pending.

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
