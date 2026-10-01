# Phase 2.1 Checklist - Fold, Font and Reference Driver

Phase: [Phase 2.1](phase-2.1.md).
Current status: active from 2026-10-01 after Phase 2's accepted foundation closure.
Owner: TFAF; the parent owns validation, independent acceptance and commits.
Update rule: authoring alone cannot accept a Step. Closure requires focused
validation, independent Step acceptance and the exact acceptance commit; full
Phase validation/review/closure remains pending.

## TFAF-S04 - Adaptive pane/hinge preference

- Current status: READY_FOR_COMMIT
- Owner: TFAF
- Update rule: record implementation now; accept only after focused validation, independent review and exact commit.
- [x] Consume accepted Settings IDs/API and freeze the pure resolver/session consumer map. See the [S04 consumer contract](../notes/settings-adaptive-presentation.md); this check records the frozen map, not behavioral acceptance.
- [x] Prove automatic/single/dual preferences respect physical eligibility and selection.
- [x] Prove session overrides, configuration fallbacks, explicit automatic and both hinge axes.
- [x] Prove dimension-specific global edits, reset and capability loss/return preserve unrelated state.
- [x] Prove split controls remain available when physically eligible under a single-pane default.
- [ ] Record focused validation, independent Step acceptance review and commit.

Focused evidence: 206 selected tests passed, scoped analysis and formatting clean.
The complete independent S04 acceptance review and repair-cycle-1 review resolve
both findings; no current blocker remains. These facts do not assert a commit
before it succeeds. The parent records the exact Step commit separately and
projects final committed status after verification; Phase closure remains open.

## TFAF-S05 - OS-aware text size

- Current status: OPEN
- Owner: TFAF
- Update rule: remain OPEN until explicitly started; accept only with focused validation, independent review and exact commit.
- [ ] Apply multipliers 1.0/1.15/1.30 once at the common text presentation boundary.
- [ ] Prove nonlinear OS scaling composition and live OS changes without rewriting preferences.
- [ ] Prove resources/navigation/Settings/dialogs remain readable and controls reachable.
- [ ] Preserve icon/image geometry and prevent nested double scaling.
- [ ] Record focused validation, independent Step acceptance review and commit.

## TFAF-S06 - Reference-app and runtime proof

- Current status: OPEN
- Owner: TFAF; Editing Studio App Phase 3 owns app composition and runtime records.
- Update rule: remain OPEN until explicitly started; bind identified driver evidence and framework acceptance to exact commits.
- [ ] Identify app Phase 3-owned adapter/composition and consumer evidence without duplicating TFAF logic.
- [ ] Verify both tabs, compact/expanded, both hinge axes and unchanged selected resource.
- [ ] Verify actual adapter restart after acknowledged saves and contract-aligned failure recovery.
- [ ] Record Android runtime opening/edit/back/restart smoke.
- [ ] Record iOS runtime opening/edit/back/restart smoke.
- [ ] Record Web startup/Settings/browser-origin restore smoke.
- [ ] Name each environment, actual proof and limitations; unavailable evidence remains pending.
- [ ] Record focused evidence and independent Step acceptance review/commit for framework-owned work.

## Aggregate final closure

- Current status: OPEN
- Owner: PHASE-2.1 final validation owner
- Update rule: close only after accepted Steps, comprehensive Phase review and the single frozen-tree full validation, then exact release commit.
- [ ] Verify Phase 2's committed deferred-validation handoff and accepted ancestry.
- [ ] Complete the mandatory comprehensive Phase review and any bounded closure repairs.
- [ ] Execute TFAF scripts/validate-full.sh once on the frozen final release tree.
- [ ] Bind shared driver evidence and retain app Phase 3's separate complete-validation ownership.
- [ ] Persist final closure/journals and normal Phase release commit.
