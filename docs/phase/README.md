# Development phases

| Phase | Status | Boundary |
| --- | --- | --- |
| [Phase 1](phase-1.md) | closed | Configuration-driven Resource List/Detail reference path, fake bindings, adaptive/Fold presentation |
| [Phase 2](phase-2.md) | closed | Accepted common Settings model, persistence lifecycle and Material/Cupertino shell |
| [Phase 2.1](phase-2.1.md) | planned | Fold/hinge policy, OS-aware text size and reference-app proof; depends on Phase 2 |

Phase 1 completed on 2026-09-29 by normal acceptance, without a waiver.
See its [checklist](phase-1-checklist.md) and
[closure record](../journal/2026/09/2026-09-29-phase-1-closure.md).
No successor implementation is started by this closure.

On 2026-10-01, the planned Common Settings scope was split into the serial
Phase 2 / Phase 2.1 sequence. Phase 2 uses GPT-6.1 Sol high and Phase 2.1
uses GPT-6.1 Sol medium after consuming the accepted Settings handoff.
Complete framework validation uses `scripts/validate-full.sh` once at Phase
2.1's final release; focused validation, independent review, Step commits and
closure/release remain required in each member. Editing Studio App Phase 3 is
the separately owned reference driver. Phase 2 closed on 2026-10-01 with
focused evidence, three accepted Steps, one comprehensive PASS review and a
normal release; complete validation is explicitly deferred-not-run.
See its [closure and handoff](phase-2.md#closure-and-frozen-handoff--2026-10-01)
and [checklist](phase-2-checklist.md). Phase 2.1 remains planned/not-started;
this release does not start it or Editing Studio App Phase 3.
