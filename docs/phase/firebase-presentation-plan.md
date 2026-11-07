# Presentation for optional Firebase-backed services

Status: planned, unscheduled. Contracts: [Framework architecture](../notes/architecture.md) and [Flutter Core provider boundary](https://github.com/asami/textus-flutter-core/blob/main/docs/design/firebase-provider-boundary.md).

| Work | Delivery and acceptance |
| --- | --- |
| Notification permission and entry | Present Core's platform support, permission state and user-initiated request. Verify an app with push disabled can open the ordinary inbox, and declining permission leaves the user in their current activity. |
| Authenticated navigation | Connect one neutral notification prompt to an application-supplied resource action. Use the current account and ordinary authenticated read after open, including after an account switch. Qualify allowed, unavailable and denied resources, repeated taps and navigation from a cold start on one supported platform. |
| Presentation options | Consume a Core presentation setting when a screen has a concrete use for it. Verify the local default offline, a supported override, and normal domain authorization under both values. |

The first connected route uses [Core push registration](https://github.com/asami/textus-flutter-core/blob/main/docs/phase/firebase-provider-plan.md) and the [server notification delivery plan](https://github.com/asami/goldenport-cncf/blob/main/docs/phase/firebase-integration-plan.md). Core and the deploying application handle diagnostics independently of UI delivery. Add Framework interaction for attestation only when an endpoint refusal needs user-facing guidance. Verify platform-neutral Framework behavior with a Core double and real delivery through the participating application.
