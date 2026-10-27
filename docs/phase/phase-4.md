# Phase 4: Sensitive Interaction Application Framework

Status: PLANNED
Plan date: 2026-10-16
Plan identity reconciled: 2026-10-20
Execution started: false
Predecessor: closed Phase 3 — Background Transfer Status UI
Depends on: textus-flutter-core Phase 3, CNCF Phase 111, Cozy Phase 85

## Goal

Make provider-delegated sensitive interaction the ordinary application-level
Flutter path.

## Planned work

- define application-facing SensitiveInteraction API;
- initial interaction families: payment, identity/authentication, signing and
  provider consent as justified by concrete use cases;
- expose domain-safe Reference/Assertion/Result values rather than provider
  secrets;
- integrate CML/Cozy-generated contracts where Phase 85 defines them;
- ensure UI/application state does not receive excluded sensitive values in the
  ordinary path;
- document fallback/exception behavior for providers without delegated UI.

## Initial direction

Application code requests an interaction and receives a typed result. Provider
selection, platform UI and credential handling belong below the application
framework boundary.

The API remains small until concrete Android/iOS integrations prove the common
abstraction.

## Plan identity

The developer approved this plan's relocation from Phase 3 to Phase 4 on
2026-10-20. Phase 3 remains the completed Background Transfer Status UI with
its existing closure and checklist. This plan retains the Sensitive Interaction
scope and dependencies recorded on 2026-10-16; relocation starts no execution
and grants no new acceptance. See the
[reconciliation decision](../journal/2026/10/2026-10-20-phase-plan-reconciliation.md).

Core dependency identity was reconciled on 2026-10-27: its Sensitive Interaction
proposal is now Core Phase 3, while Core Phase 2 remains completed Background
Transfer. This reference update retains this Phase 4 proposal and starts no work.
