# TFAF background transfer status design note

Recorded: 2026-10-10. Planning note; public types and implementation are not frozen.

## Selected responsibility

TFAF owns a reusable transfer-status list/detail screen through Core's public
API. Application configuration supplies work-item labels, operation/destination
labels, screen entry and domain navigation. Do not embed Book, TKL or Editing
Studio identities in the common component, and do not create another queue or
transport state machine.

- Show storage-upload and data-submission states separately for each work item
  in both list and detail. An overall summary must not hide either state.
- Detail shows destination, last update, waiting reason, available progress,
  failure and retry information; show per-file outcomes when Core supplies them.
- Present dependency waiting, offline/policy waiting, no-upload-required and
  unknown/interrupted outcomes accurately. Never infer submission from upload.
- Show indeterminate progress when no measurable progress exists. Offer only
  actions Core supports in the current state; trigger no transfer during build,
  navigation or state restoration.
- Provide composition hooks for Home waiting/attention summaries and navigation
  back to the consumer's Material without losing its editing context. A new
  main tab is not required.

## Interface decisions before implementation

Reuse existing public contracts first. Settle work-item/operation association,
durable state observation, optional progress and per-file outcomes, and action
availability with the counterpart owner. Stable consumer identity links the two
operations; do not introduce a content hash to identify work. Successful results
must correspond to the same committed content; changed content or inaccessible
references use the existing queue/material contract rather than silent reuse.

For unknown acknowledgement after interruption, distinguish uncertain completion
from definitive failure. Select supported reconciliation/retry behavior with the
transport owner; do not manufacture idempotency or implement a UI-only resend rule.
The app decides Book eligibility and presentation terminology. The two runtime
operations remain separately observable regardless of their display labels.

The common screen's first consumer displays:

```text
Book Material
  TKL material upload: complete (photos/audio)
  Editing Studio data submission: failed (connection unavailable)
  Retry submission
```

This illustrates state separation, not an actual execution result. The app's
existing plan spells material storage KTL/Google Drive; the user's TKL label does
not select a new backend. Actual endpoint, access and acknowledgement contracts
must be taken from the selected configuration and adapter handoff.

See the [development plan](../phase/phase-3.md),
[consumer note](../../../../Project2026/nict-editing-studio-app/docs/notes/background-material-transfer-status.md) and
[decision journal](../journal/2026/10/2026-10-10-background-material-transfer-status.md).

Execution owner: repository Phase 3; its checklist and release own upstream
acceptance. App Phase 6.1 remains the consumer/integration owner.
