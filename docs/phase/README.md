# Development phases

[Phase 5 — Presentation for Firebase-backed services](phase-5.md) is planned for later delivery. Progress is recorded in the [Phase 5 checklist](phase-5-checklist.md).

## Planned common media actions — 2026-10-31

[Media action integration](media-input-actions-plan.md) supplies one import-first
Web/tablet/Fold screen composition for App Phase 7 ESA7-08. Core supplies
support/device/permission states; Framework renders enabled or disabled actions
with accessible reasons and an explicit check for unknown/requestable states.
No Book-specific permission logic or blanket Web camera prohibition is added.

## Planned Fold/mode consumer integration — 2026-10-31

App [Phase 7 ESA7-07](../../../../Project2026/nict-editing-studio-app/docs/phase/phase-7.md)
reuses the accepted adaptive/pane/hinge foundation for native Pixel 11 Pro Fold
and Web. Small viewports offer input/reference; large viewports offer input/
reference and editing. Unfold preserves input mode; a visible user action
switches to editing. Shared mode/layout handling retains selection/draft across
posture changes and does not trigger save/admission. Framework owns reusable
behavior, App owns domain composition and actual-device acceptance. Add only
identified gaps; do not reopen Phase 2.1 or treat old layout proof as acceptance
of the new two-mode behavior. General tablet qualification remains later.

## Planned User Account login integration — 2026-10-31

[Common login facade](user-account-authentication-integration-plan.md) consumes
Core's textus-user-account authentication client for shared login/account/logout
UI and navigation. Native App 6.10 precedes Web App 7; Studio Server 5 connects
user-account with CNCF. This bounded workstream preserves planned Phase 4
Sensitive Interaction and closed phases; no execution or acceptance is claimed.

## Accepted TKL delivery follow-on — 2026-10-27

[TKL-managed Material delivery](tkl-managed-material-delivery-plan.md) extends
the accepted Phase 3 facade/UI for App Phase 6.3. TKL provides destinations;
TFAF presents connection/consent and progress without Google folder-ID setup.
This bounded follow-on is accepted and closed with App Phase 6.3. It remains
separate from planned Phase 4 Sensitive Interaction; neither existing Phase is
reopened or newly accepted by this integration.

| Phase | Status | Boundary |
| --- | --- | --- |
| [Phase 1](phase-1.md) | closed | Configuration-driven Resource List/Detail reference path, fake bindings, adaptive/Fold presentation |
| [Phase 2](phase-2.md) | closed | Accepted common Settings model, persistence lifecycle and Material/Cupertino shell |
| [Phase 2.1](phase-2.1.md) | closed on 2026-10-01; S04/S05/S06 ACCEPTED | Fold/hinge policy, OS-aware text size and Android/iOS/Web reference-driver proof |

Phase 1 closed on 2026-09-29; see its [closure record](../journal/2026/09/2026-09-29-phase-1-closure.md).
On 2026-10-01 the Common Settings scope was split into the serial Phase 2 /
Phase 2.1 sequence. Phase 2 closed with three accepted Steps, focused evidence
and one comprehensive PASS review; full framework validation was deliberately
deferred to Phase 2.1. Its [accepted handoff](phase-2.md#closure-and-frozen-handoff--2026-10-01)
is preserved as history. Phase 2.1 now discharges that deferred obligation.

| Phase 2.1 Step | Accepted commit |
| --- | --- |
| TFAF-S04 adaptive pane/hinge | `f4fbb4b5403dc060409958876adde1eacf8afd28` |
| TFAF-S05 OS-aware text | `13c5fcf3ae76ebb2da8a1f267b05a2b5b34c439a` |
| TFAF-S06 real local adapter | `2d6cdabcc505a21062475bedfd3691b6ccbc2c2b` |

The reference application driver is committed at `2464c8326409b8aeb00ff3b6350edf336587566f`.
Its full analysis and 55 tests pass, together with retained Android/iOS restart
and final Web reload proof. The one comprehensive framework Phase review and
focused documentary closure check pass with no unresolved finding. The exact
`scripts/validate-full.sh` ran once: clean analysis and 276 tests passed.
See the [closed checklist](phase-2.1-checklist.md) and
[completion record](../journal/2026/10/2026-10-01-phase-2.1-completion.md).

The user selected exact-path ordinary local Git after the registered runner's
native-history delivery failure. The distinct Phase release binds closure.
Editing Studio App Phases 2/3 retain separate pending acceptance; Core is
unchanged. No successor work starts from this closure.

## Phase 3 — closed on 2026-10-11

| Phase | Status | Boundary |
| --- | --- | --- |
| [Phase 3](phase-3.md) | closed; distinct release binding and verified native closure receipt required | Background Transfer Status UI, public Core facades, common settings/status/Commit/summary and shared capture admission |

All three native owning Steps are accepted and committed:
TFAF3-01 `19998a2b188e9df2332b7389a8a523f78e1fb699`,
TFAF3-02 `b80b739f3457c71f50ab4f7605a5e891f1ed4bea`, and
TFAF3-03 `21ec7e50df33ae9a0938e8ed0c53e7f5b8cee226`.
The sole comprehensive review `tfaf3-full-review-20261011@1` passed.
The owning complete `scripts/validate-full.sh` reported clean analysis,
all 621 tests passed and driver exit 0. See the
[closed checklist](phase-3-checklist.md) and
[completion journal](../journal/2026/10/2026-10-11-phase-3-completion.md).

The distinct release is bound to `tfaf3-phase3-closure-20261011@1`;
native Phase acceptance requires its successful commit and verified closure
receipt. No pending operation is represented as an already created commit.
App Phase 6.1 owning acceptance, aggregate validation and release remain
separately pending. No successor Phase starts here.

## Planned successor — reconciled on 2026-10-20

| Phase | Status | Boundary |
| --- | --- | --- |
| [Phase 4](phase-4.md) | planned; execution not started | Sensitive Interaction application API; provider-delegated payment, authentication, signing and consent, consuming the declared Core/CNCF/Cozy dependencies |

The formerly overlapping Sensitive Interaction Phase 3 plan is now Phase 4.
The completed transfer-status Phase 3, its checklist and dated closure history
retain their identity and scope. See the
[approved decision](../journal/2026/10/2026-10-20-phase-plan-reconciliation.md).
