# Phase 5 — Presentation for Firebase-backed services

status=planned
planned_at=2026-11-08
execution_started=false
owner=textus-flutter-application-framework

Progress: [Phase 5 checklist](phase-5-checklist.md). Scheduling is deferred. The first item on selection is TFAF5-01.

## Goal

Provide common notification permission and navigation UI and consumer-selected presentation settings through the public Flutter Core services. See the [Framework architecture](../notes/architecture.md).

## Delivery groups

| Subphase | Step | Observable outcome |
| --- | --- | --- |
| 5.1 Notification permission | TFAF5-01 | Present Core's support and permission state with a user-initiated request. |
| 5.2 Authenticated navigation | TFAF5-02 | Open a notification using the current account and the ordinary domain API. |
| 5.3 Presentation options and handoff | TFAF5-03 | Apply a Core setting to a screen with a concrete display choice. |

## Dependencies and completion

Use a Core double for deterministic UI behavior. Qualify one real push-to-resource route with Core and the server on a supported platform. The application maps the action to its domain screen. Add attestation guidance only when a protected endpoint requires a user-facing response. Coordinate the relevant capabilities with [CNCF Phase 121](https://github.com/asami/goldenport-cncf/blob/main/docs/phase/phase-121.md) and [textus-flutter-core Phase 4](https://github.com/asami/textus-flutter-core/blob/main/docs/phase/phase-4.md).

The checklist records each Step's acceptance criteria and the Phase closure decision.
