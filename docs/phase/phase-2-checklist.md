# Phase 2 Checklist - Common Settings Foundation

Phase: [Phase 2](phase-2.md).
Owner: TFAF Phase 2 workflow parent.
Update rule: mark a Step accepted only after its focused validation and independent
acceptance review pass, in the commit containing that Step. Phase closure requires
all three accepted Steps, the comprehensive Phase review and a separate release commit.

## TFAF-S01 - Settings model, registry and observable View

- Current status: ACCEPTED
- [x] Freeze stable IDs/groups/defaults/validation, versioned record and extension contract.
- [x] Implement the observable Settings View and service ownership/disposal boundary.
- [x] Prove loading/effective/unsaved/error/retry/reset state through behavioral tests.
- [x] Prove settings/environment separation and a synthetic extension setting.
- [x] Record focused validation, independent Step acceptance review and commit.

Acceptance basis (2026-10-01): 29 registry/View behavior cases and 19 existing
ApplicationViewModel/ListDetail consumer cases passed; focused analysis, format
and diff checks passed. Independent protected-focused review accepted all 16
frozen foundation decisions with no blockers, Hygiene or Development Candidates.
The acceptance commit is the commit introducing this record, titled
`Support typed settings registry and observable Settings View`.
The View tests use a fake service: concrete persistence lifecycle is not accepted
by S01 and remains S02. Repository-full validation is deliberately deferred to
PHASE-2.1; S01 does not establish Phase closure or runtime acceptance.

## TFAF-S02 - Persistence lifecycle

- Current status: ACCEPTED
- [x] Inject the abstract local-installation/browser-origin storage boundary.
- [x] Prove late-load/retry protection for edited/reset fields and immediate session edits.
- [x] Prove serialized/coalesced revision-aware saves, latest-value durability and failure/retry.
- [x] Prove invalid/missing fallback, unknown-key retention and protected future versions.
- [x] Prove reset preserves extension data and restart reflects acknowledged/failed save outcomes.
- [x] Record focused validation, independent Step acceptance review and commit.

Acceptance basis (2026-10-01): 10 versioned-record and 40 concrete-controller
behavior cases passed, together with 31 registry/Settings View/ApplicationViewModel
consumer cases. Focused analysis, format and diff checks passed. Independent
protected-focused review accepted the frozen R1-R4, C1-C6 and W1-W6 contracts
with no blockers, Hygiene or Development Candidates.
The acceptance commit is the commit introducing this record, titled
`Preserve settings through revision-aware persistence and explicit retry`.
Storage remains injected and caller-owned: concrete platform adapters and
runtime assurance are not accepted by S02. Material/Cupertino shell interaction
remains S03. Repository-full validation is deliberately deferred to PHASE-2.1;
S02 does not establish Phase closure.

## TFAF-S03 - Material/Cupertino Settings shell

- Current status: ACCEPTED
- [x] Implement common Settings navigation and platform visual realizations with shared IDs and values.
- [x] Prove standard controls, synthetic capability availability and extension interaction.
- [x] Keep Widgets on the Settings View and use no Editing-Studio-specific common Widgets.
- [x] Record focused validation, independent Step acceptance review and commit.

Acceptance basis (2026-10-01): 40 Material/Cupertino shell and 17 navigation
behavior cases passed, together with 81 registry/View/record/controller and
ApplicationViewModel accumulator cases. Focused analysis, format and diff checks
passed. Independent protected-focused review accepted the complete six-path
accumulator against U1-U10 with no blockers, Hygiene or Development Candidates.
The acceptance commit is the commit introducing this record, titled
`Provide shared Material and Cupertino settings screens and navigation`.
Shells borrow the Settings View; restoration and ownership remain explicit.
Concrete storage adapters, presentation effects and runtime assurance remain
outside S03. Repository-full validation is deliberately deferred to PHASE-2.1;
S03 does not establish Phase closure.

## Foundation closure and successor handoff

- Current status: CLOSED
- [x] Seal the public Settings record/API, lifecycle and fixture handoff to Phase 2.1.
- [x] Complete the mandatory comprehensive Phase review and bounded closure repairs if required.
- [x] Persist closure, Hygiene/Development Candidate records and normal Phase release commit.
- [x] Record focused assurance and repository-full validation deferred-not-run to PHASE-2.1.
- [x] Keep Phase 2.1 planned and app Phase 3 outside this aggregate chain.

Closure basis (2026-10-01): all three accepted Step commits and their focused
evidence are recorded above. The mandatory epoch-1 full review of the original
Phase-base through S03 accepted HEAD returned PASS across all 21 paths and
cross-Step consumer edges, with no blockers or ledger candidates; no repair
cycle was needed. Verified review disposition:
`bfb327358b682be60af272342d4edfcacbff84cb1160c564ca2794bdbbb1955e`.
Both unpersisted accepted-ID sets are empty; absent canonical journals remain
absent rather than being populated with empty files.

This closed checklist is release content: closure is authoritative only with
the separate normal release commit containing this record and its verified
`Phase-Closure-Binding: PHASE-2` receipt. See the
[Phase closure and handoff](phase-2.md#closure-and-frozen-handoff--2026-10-01).
Repository-full validation is deliberately deferred-not-run to PHASE-2.1,
whose configured `scripts/validate-full.sh` remains pending. Concrete
adapters, preference effects and platform runtime assurance are not accepted
by this foundation closure.
