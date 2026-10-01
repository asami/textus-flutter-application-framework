# Development phases

| Phase | Status | Boundary |
| --- | --- | --- |
| [Phase 1](phase-1.md) | closed | Configuration-driven Resource List/Detail reference path, fake bindings, adaptive/Fold presentation |
| [Phase 2](phase-2.md) | closed | Accepted common Settings model, persistence lifecycle and Material/Cupertino shell |
| [Phase 2.1](phase-2.1.md) | active; S04 ready for commit | Fold/hinge policy, OS-aware text size and reference-app proof; depends on accepted Phase 2 |

Phase 1 completed on 2026-09-29 by normal acceptance, without a waiver.
See its [checklist](phase-1-checklist.md) and
[closure record](../journal/2026/09/2026-09-29-phase-1-closure.md).
No successor implementation is started by this closure.

On 2026-10-01, the planned Common Settings scope was split into the serial
Phase 2 / Phase 2.1 sequence. That dated planning recommendation selected
GPT-6.1 Sol high for Phase 2 and Sol medium for Phase 2.1 after consuming
the accepted Settings handoff. Current S04 implementation executes under the
user-selected GPT-6.1 Sol high profile for the frozen presentation boundary.
Complete framework validation uses `scripts/validate-full.sh` once at Phase
2.1's final release; focused validation, independent review, Step commits and
closure/release remain required in each member. Editing Studio App Phase 3 is
the separately owned reference driver. Phase 2 closed on 2026-10-01 with
focused evidence, three accepted Steps, one comprehensive PASS review and a
normal release; complete validation is explicitly deferred-not-run.
See its [closure and handoff](phase-2.md#closure-and-frozen-handoff--2026-10-01)
and [checklist](phase-2-checklist.md). Phase 2.1 started under explicit invocation
on 2026-10-01; S04 is validated and independently reviewed against the
[adaptive-presentation contract](../notes/settings-adaptive-presentation.md).
Focused validation and independent acceptance have passed; the exact Step commit remains pending.
S05/S06 and aggregate closure are OPEN. Editing Studio App Phase 3 remains
separately planned and is not implicitly started by this framework work.
