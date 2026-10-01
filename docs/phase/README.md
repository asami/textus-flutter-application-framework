# Development phases

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
