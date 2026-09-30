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

- Current status: OPEN
- [ ] Inject the abstract local-installation/browser-origin storage boundary.
- [ ] Prove late-load/retry protection for edited/reset fields and immediate session edits.
- [ ] Prove serialized/coalesced revision-aware saves, latest-value durability and failure/retry.
- [ ] Prove invalid/missing fallback, unknown-key retention and protected future versions.
- [ ] Prove reset preserves extension data and restart reflects acknowledged/failed save outcomes.
- [ ] Record focused validation, independent Step acceptance review and commit.

## TFAF-S03 - Material/Cupertino Settings shell

- Current status: OPEN
- [ ] Implement common Settings navigation and platform visual realizations with shared IDs and values.
- [ ] Prove standard controls, synthetic capability availability and extension interaction.
- [ ] Keep Widgets on the Settings View and use no Editing-Studio-specific common Widgets.
- [ ] Record focused validation, independent Step acceptance review and commit.

## Foundation closure and successor handoff

- Current status: OPEN
- [ ] Seal the public Settings record/API, lifecycle and fixture handoff to Phase 2.1.
- [ ] Complete the mandatory comprehensive Phase review and bounded closure repairs if required.
- [ ] Persist closure, Hygiene/Development Candidate records and normal Phase release commit.
- [ ] Record focused assurance and repository-full validation deferred-not-run to PHASE-2.1.
- [ ] Keep Phase 2.1 planned and app Phase 3 outside this aggregate chain.
