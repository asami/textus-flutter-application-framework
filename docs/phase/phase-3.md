# Phase 3 - Background Transfer Status UI

status=planned
planned_at=2026-10-10
execution_owner=textus-flutter-application-framework
phase_owner=textus-flutter-application-framework
consumer_phase=nict-editing-studio-app Phase 6.1
validation_ownership=standalone-full-owner
predecessor=Phase 2.1
execution_started=false
related_steps=ESA6-06, ESA6-07, ESA6-08

## Boundary

Connected upstream delivery for [app Phase 6.1](../../../../Project2026/nict-editing-studio-app/docs/phase/phase-6.1.md).
This is the repository-owned Phase 3, with its own Steps, checklist,
validation, review and release closure. App Phase 6.1 ESA6-06/07/08 is the
consumer/integration owner, not a substitute for upstream acceptance. Existing
accepted work and app aggregate-validation ownership remain unchanged. Entry
selects the actual repository/worktree, available predecessor APIs and missing
bounded capabilities; this document does not start implementation or redirect
an already-running checkout. See [the completion checklist](phase-3-checklist.md).


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

## Work Stack

| ID | Step | Outcome | Status |
| --- | --- | --- | --- |
| TFAF3-01 | Core handoff and view contract | Consume accepted Core APIs and freeze configuration/state/action mapping. | planned |
| TFAF3-02 | Common screen and composition | Implement list/detail, supported actions, summary and navigation hooks. | planned |
| TFAF3-03 | Consumer acceptance | Verify fixtures and app composition, including failure/restart presentation. | planned |

## Entry and validation

Before execution, identify the current accepted predecessor/public APIs and the
exact remaining delta. Preserve already implemented connected app work and reuse
its relevant evidence; do not reimplement or claim it accepted merely by creating
this Phase. Freeze repository scope, dependencies and a calibrated execution
estimate at entry; no unsupported PROCEED/time estimate is asserted here.

Each Step receives focused behavioral validation and independent acceptance under
the execution workflow. Phase closure requires the complete package analysis/test
suite, affected-consumer evidence, one comprehensive Phase review, resolved current
blockers and a distinct release commit with the checklist/journal handoff. App-only
validation does not replace this package's full checks. Fake results do not prove
real adapter or server execution. No full-validation deferral is selected here.

## Coordination

Delivery order: Core public state/action contract -> TFAF common screen -> app
composition -> ESA6-07 integration acceptance -> ESA6-08 handoff documentation.
Missing cross-owner capabilities are addressed by their owner before dependent
integration; do not add temporary app implementations for later extraction.
No hash ledger, generic revision framework, public-sharing default or unrelated
storage migration is introduced by this request.

- [Other upstream plan](../../../textus-flutter-core/docs/phase/phase-2.md)
- [Design discussion](../notes/background-material-transfer-status.md)
- [Decision journal](../journal/2026/10/2026-10-10-background-material-transfer-status.md)

## Upstream dependency

Core Phase 2 supplies the accepted public state/action and fixture handoff before
runtime binding is accepted. View design may proceed against a reviewed contract,
but fake UI evidence alone cannot establish upstream runtime readiness. App Phase
6.1 owns its domain integration and end-to-end acceptance; this Phase owns reusable
UI acceptance and supplies its handoff without waiting for app Phase closure.
