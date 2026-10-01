# Phase 2.1 Checklist - Fold, Font and Reference Driver

Phase: [Phase 2.1](phase-2.1.md).
Status: closed on 2026-10-01
Owner: TFAF; the parent owns validation, independent acceptance and commits.
Update rule: authoring alone cannot accept a Step. Closure requires focused
validation, independent Step acceptance and exact commits. All gates below
are complete; the distinct release commit containing this checklist binds closure.

## TFAF-S04 - Adaptive pane/hinge preference

- Current status: ACCEPTED
- Owner: TFAF
- Update rule: record implementation now; accept only after focused validation, independent review and exact commit.
- [x] Consume accepted Settings IDs/API and freeze the pure resolver/session consumer map. See the [S04 consumer contract](../notes/settings-adaptive-presentation.md); this check records the frozen map, not behavioral acceptance.
- [x] Prove automatic/single/dual preferences respect physical eligibility and selection.
- [x] Prove session overrides, configuration fallbacks, explicit automatic and both hinge axes.
- [x] Prove dimension-specific global edits, reset and capability loss/return preserve unrelated state.
- [x] Prove split controls remain available when physically eligible under a single-pane default.
- [x] Record focused validation, independent Step acceptance review and commit.

Focused evidence: 206 selected tests passed, scoped analysis and formatting clean.
The complete independent S04 acceptance review and repair-cycle-1 review resolve
both findings and returned PASS; no current blocker remains. Exact accepted S04
Step commit: `f4fbb4b5403dc060409958876adde1eacf8afd28`. Aggregate closure is complete in the distinct Phase release.

## TFAF-S05 - OS-aware text size

- Current status: ACCEPTED
- Owner: TFAF
- Update rule: authoring started under the frozen S05 manifest; accept only with focused validation, independent review and exact commit.
- [x] Apply multipliers 1.0/1.15/1.30 once at the common text presentation boundary.
- [x] Prove nonlinear OS scaling composition and live OS changes without rewriting preferences.
- [x] Prove resources/navigation/Settings/dialogs remain readable and controls reachable.
- [x] Preserve icon/image geometry and prevent nested double scaling.
- [x] Record focused validation, independent Step acceptance review and commit.

Authoring contract: [application text presentation](../notes/settings-text-presentation.md).
TS01/TS02, TB01–TB04 and TP01–TP06 executable specifications are authored, with
adjacent Given/When/Then clauses and observable text/interaction assertions.
Parent focused validation passed 18 repaired presentation cases; the final
276-case framework suite includes the full scaler/boundary/presentation matrix.
Independent review and focused re-review resolved CB-TFAF-S05-01.
Exact accepted S05 Step commit: `13c5fcf3ae76ebb2da8a1f267b05a2b5b34c439a`.

## TFAF-S06 - Reference-app and runtime proof

- Current status: ACCEPTED
- Owner: TFAF; Editing Studio App Phase 3 owns app composition and runtime records.
- Update rule: explicitly resumed by the completion request; bind completed driver evidence and framework acceptance to exact commits.
- [x] Identify app Phase 3-owned adapter/composition and consumer evidence without duplicating TFAF logic.
- [x] Verify both tabs, compact/expanded, both hinge axes and unchanged selected resource.
- [x] Verify actual adapter restart after acknowledged saves and contract-aligned failure recovery.
- [x] Record Android runtime opening/edit/back/restart smoke.
- [x] Record iOS runtime opening/edit/back/restart smoke.
- [x] Record Web startup/Settings/browser-origin restore smoke.
- [x] Name each environment, actual proof and limitations; unavailable evidence remains pending.
- [x] Record focused evidence and independent Step acceptance review/commit for framework-owned work.

Accepted framework S06 commit: `2d6cdabcc505a21062475bedfd3691b6ccbc2c2b`.
Reference-driver commit: `2464c8326409b8aeb00ff3b6350edf336587566f`. Five adapter
and fourteen Settings consumer cases pass; full app analysis and 55 tests pass.
Android API 36 emulator and iOS 18.3.1 simulator each pass retained write and
separate-process restore; final Web common UI/resource/reload proof passes.
Both-axis hinge/posture behavior is fixture evidence; failed Pixel wireless
attempts are excluded from acceptance.

## Aggregate final closure

- Current status: CLOSED
- Owner: PHASE-2.1 final validation owner
- Update rule: close only after accepted Steps, comprehensive Phase review and the single frozen-tree full validation, then exact release commit.
- [x] Verify Phase 2's committed deferred-validation handoff and accepted ancestry.
- [x] Complete the mandatory comprehensive Phase review and any bounded closure repairs.
- [x] Execute TFAF scripts/validate-full.sh once on the frozen final release tree.
- [x] Bind shared driver evidence and retain app Phase 3's separate complete-validation ownership.
- [x] Persist final closure/journals and normal Phase release commit.

## Completion continuation evidence

See the [2026-10-01 execution record](../journal/2026/10/2026-10-01-phase-2.1-completion.md).
S05 independent review/repair/re-review is complete without a remaining blocker.
S06 local adapter and app composition have focused tests, independent review
and committed Android/iOS/Web runtime proof. The whole-Phase review and bounded
closure check pass with no unresolved finding. The exact framework aggregate
driver passed once: analysis clean, 276 tests pass. All Step/closure boxes above
are complete; the distinct release commit binds this final record. The user
selected the ordinary local Git route after the registered-history stop.
Application Phase acceptance remains separate; Core is unchanged.
