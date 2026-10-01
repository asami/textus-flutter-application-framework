# Phase 2 - Common Settings Model, Persistence and Shell

status=closed
closed_at=2026-10-01
closure_binding=PHASE-2
repository_full_suite=deferred-not-run
split_full_test_policy=final-only
split_full_validation_method=local-driver-acceptance
split_validation_bootstrap=none
split_full_validation_driver=scripts/validate-full.sh
validation_ownership=aggregate-deferred
aggregate_validation_owner=PHASE-2.1
aggregate_validation_sequence=["PHASE-2","PHASE-2.1"]
planned_at=2026-09-29
predecessor=Phase 1
successor=PHASE-2.1
reference_application=KnowledgeHubProject/nict-editing-studio-app
checklist=phase-2-checklist.md

## Goal

Establish TFAF's reusable Settings model/registry, observable Settings View,
persistence service contract, platform-adaptive Settings shell and application
extension point. Prove the foundation through controllable storage and
Material/Cupertino widget interaction.

[Phase 2.1](phase-2.1.md) applies this accepted foundation to Fold/hinge
presentation, OS-aware text scaling and the Editing Studio development driver.
Both documents preserve the original Common Settings scope. The Settings
foundation is accepted through TFAF-S01/S02/S03 and the comprehensive Phase
review recorded below. Phase 2.1 remains planned and has not started.

## Architectural rules

1. TFAF owns application-level common settings and their standard UI.
2. `textus-flutter-core` owns low-level device/environment observations such as display features, fold posture, window metrics, platform capability, and system text scale.
3. Environment observations are not persisted as user settings.
4. Fold policy is expressed in terms of adaptive presentation, not device model names.
5. Font/Text settings augment rather than erase system accessibility preferences.
6. Applications may contribute application-specific settings through an explicit extension point.
7. NICT Editing Studio is the development driver and must not introduce Editing-Studio-specific concepts into TFAF.
8. The Settings model is platform-neutral; Android/iOS conventions are visual realization concerns.
9. The standard Settings shell is platform-adaptive: Android should follow the platform's Material conventions and iOS should follow the platform's native/Cupertino conventions where practical.
10. Setting availability is capability-driven. A setting that is meaningless on the current device/environment may be hidden or otherwise made unavailable according to an explicit availability policy.
11. Platform-specific rendering must not fork the semantic setting identity, stored value, validation, or application extension contract.
12. Persisted preferences, observable Settings Views, environment observations,
    and resolved presentation are separate concerns. Widgets use the Settings
    ViewModel; they do not read or write storage directly.

## Scope

### TFAF-S01 Settings model and registry

Define stable contracts for common settings, setting groups, defaults, validation, effective values, and application-contributed settings.

Initial groups:

- Appearance
- Layout / Adaptive behavior
- Accessibility-ready extension boundary
- Application extensions

The initial persisted common values are pane preference (default
`automatic`), hinge preference (default `automatic`), and text-size
multiplier (default `1.0`). Pane preference and hinge preference are independent
settings, not alternative meanings of one Fold enum.

The common value catalog is pane preference `automatic` / `preferSinglePane` /
`preferDualPane`, hinge preference `automatic` / `avoid` / `span`, and text-size
multiplier `1.0` / `1.15` / `1.30`. Other persisted multipliers are invalid and
fall back to `1.0`. Keep saved-value presence distinguishable from defaults:
an explicitly stored `automatic` is different from an absent value. Phase 2.1
uses that distinction when applying configuration fallbacks.

Expose an observable Settings View through the application-session View space,
with loading, effective values, unsaved/save-error state, retry and reset
intents. The Settings service owns validation and persistence. Phase 2.1 owns
the pure resolver that combines preferences with environment and presentation-session overrides.
Existing `ResourceListDetailDisplayModel` remains session state and is not
serialized wholesale. Setting changes must not recreate Resource Views,
replace resource selection, or issue Resource/Aggregate domain commands.

### TFAF-S02 Persistence boundary

Provide a framework-owned settings repository/service contract.

The UI and adaptive runtime must not bind directly to a concrete storage package. Persistence implementation may initially be local-device storage.

Storage is local to the application installation/browser origin, shared by its
resource tabs, and not a server profile. The storage adapter is injected at
application composition; the app does not duplicate framework persistence logic.

Required lifecycle:

- Before the initial load finishes, render using configuration/framework defaults
  and expose loading state. Settings remain editable.
- Restore validated saved values only for settings not edited/reset since that
  load began. A late load or retry must not overwrite newer user intent.
- Apply a valid edit immediately and mark it unsaved until storage acknowledges
  that revision. Serialize/coalesce writes so an older completion cannot mark a
  newer value saved or become the final stored value.
- On read failure, keep defaults/current edits, expose a nonfatal error and
  explicit retry; do not automatically overwrite unread storage with defaults.
- On save failure, retain the effective in-session value, expose unsaved/error
  state and retry the latest value. Restart restores the last successfully saved
  value; failed persistence must never be reported as durable.
- Use a versioned record and stable setting IDs. Missing values inherit defaults;
  invalid known values fall back per setting without discarding valid siblings.
  Unknown keys are not interpreted or silently deleted by ordinary edits.
  Unsupported future record versions are not automatically rewritten; report
  unsupported storage and allow an explicit reset.
- Reset restores all common defaults and persists that intent through the same
  revision/error rules while preserving application-owned extension data.
  Expose the reset intent for Phase 2.1 to clear presentation-session overrides;
  resource selection remains outside Settings ownership.

Test with a controllable fake storage adapter: delayed reads, out-of-order
completion, read/write failure, invalid/missing values, unknown keys, unsupported
versions, reset, and restart after successful/failed saves.

### TFAF-S03 Standard Settings shell

Provide reusable Settings navigation and presentation so applications can expose common settings without handwritten settings screens.

Initial conceptual structure:

```text
Settings
├─ Appearance
│  └─ Text size / Font
├─ Layout
│  └─ Fold behavior
└─ <Application Settings>
```

The shell edits the common setting IDs and values defined above through the
Settings View. Phase 2.1 owns their effect on Resource List/Detail and application
text. Availability is supplied through the common contract and tested with
synthetic capabilities here; actual hinge/window capability wiring is Phase 2.1.
Use one synthetic application setting to prove extension without adding a
production Editing Studio preference.

## Acceptance and validation ownership

This Phase owns these closure criteria:

- stable Settings IDs, groups, defaults, validation and effective values;
- an observable Settings View in the application-session View space, with
  loading, unsaved/error, retry and reset state/intents;
- the injected storage service/adapter boundary and every lifecycle/record rule
  in TFAF-S02, including acknowledged durability and preserved unknown keys;
- common Material and Cupertino shells using the same semantic IDs, values,
  validation and storage contract;
- an extension setting that can be added without changing TFAF internals;
- tests that distinguish stored preferences from environment/capability input;
- controllable-storage behavior tests for delayed reads, newest-intent
  preservation, serialized/coalesced saves, failure/retry/reset, malformed or
  missing values, unknown keys, future versions and acknowledged/failed restart;
- widget/interaction tests for both platform shells and synthetic availability.

Run narrow behavior suites and the affected-consumer accumulator for each
Step. Every Step retains its independent acceptance review and commit; this
Phase retains the mandatory comprehensive review, closure ledger and release
commit. The repository-full validation is deliberately deferred to Phase 2.1,
which owns `scripts/validate-full.sh` for the entire serial framework chain.
Do not claim repository-full or three-platform runtime assurance at this
intermediate closure.

The aggregate chain has one Phase-base repository: TFAF. Editing Studio App
Phase 3 remains a separate application Phase with its own authority, validation
and commits. It supplies the consumer/runtime evidence required by Phase 2.1;
it is not a member of this aggregate chain. Framework and app evidence may be
shared with explicit ownership. A future execution PLAN must not silently add
another Phase-base repository to this single-repository aggregate contract.

## Frozen successor handoff

Produce setting IDs/defaults, the versioned record and compatibility rules,
the View/service/storage and extension APIs, asynchronous ownership/disposal
rules, controllable-storage fixtures, Material/Cupertino interaction evidence,
and the accepted Phase closure/release identity. Phase 2.1 consumes these
artifacts without redefining persistence behavior.

## Non-goals

- Applying preferences to Resource pane/hinge composition or app text.
- The real local-storage implementation and reference-app runtime wiring.
- Android/iOS/Web runtime smoke acceptance, owned by Phase 2.1.
- Server preference synchronization, arbitrary typography or persisted Resource
  selection.

## Split record — 2026-10-01

Explicit invocation: `cncf-split-phase phase 2`, following the same task's
pre-entry Phase gate. Source goal/status: `none / no-goal-pre-entry`.
The source was planned and contained no completed Step, Slice, validation or
commit history to move. Existing 2026-09-29 architectural decisions remain
background for this serial split.

**Pre-split gate evidence:** `SPLIT_REQUIRED`, `split_reasons=[time-bound]`,
expected 9.5h with an 8–12h range. The critical path included new storage
lifecycle/record contracts, both platform shells, adaptive precedence,
accessibility scaling, consumer integration, focused validation, independent
reviews, platform smokes and release. No comparable measured calibration was
available; no multiplier was applied.

Ordered children are Phase 2 (TFAF-S01/S02/S03, expected 5h) and Phase 2.1
(TFAF-S04/S05/S06, expected 5.5h including driver coordination). Both fit the
8h ceiling and neither expected duration is below 5h. Their combined original
scope cannot fit the ceiling; no short-child exception or profile-cost-only
rejection is used. Added planning/handoff/review/commit overhead is about 1h.
No total wall-time saving is claimed. The accepted Settings contract supports
a lower-cost successor without repeating lifecycle/API design.

Phase 2 uses GPT-6.1 Sol high for its interacting public record/API and
asynchronous lifecycle decisions; its routine implementation is necessary to
prove that same foundation. Phase 2.1 uses GPT-6.1 Sol medium for the specified
presentation and consumer work after the frozen handoff. Both use standard
parent/agent mode. Incoming semantic handoffs are `[]` for both: ordinary
review, local release and profile transition do not create a semantic split
reason. Final-only complete validation belongs to Phase 2.1.

## Current structural planning gate

Phase Plan Gate: PROCEED
- target: calibrated expected duration centered on 6h; allowed ceiling 8h
- estimate_calibration: no comparable planned/actual execution evidence; no multiplier
- planning_demand: protected-decision
- recommended_parent_profile: gpt-6.1-sol / high
- profile_cost_role: expensive reasoning kernel
- expensive_reasoning_kernel: public Settings record/API, asynchronous read/write ordering and service/View lifecycle ownership
- frozen_profile_transition_handoff: produces the accepted Settings contract and behavioral evidence for Phase 2.1
- parent_reasoning_mode_policy: standard
- estimated_at_recommended_profile: expected 5h; range 4.5–6.5h; 1h below target and 3h below ceiling
- incoming_semantic_handoffs: []
- merge_attempts_for_every_sub_4h_child: none; no expected child below 4h
- rebalance_attempts_for_every_sub_5h_child: none; no expected child below 5h
- adjacent_merge_structural_rejection_evidence: combined original expected 9.5h exceeds 8h
- profile_cost_only_rejection_forbidden: true
- short_child_basis: none
- overhead_tradeoff: about 1h additional split assurance overhead; no total wall-time saving claimed; bounded closure and durable contract reduce downstream rediscovery
- agent_reasoning_mode_policy: default standard; consider pro only at an eligible agent launch with supported quality-first evidence
- runtime_suitability: re-evaluate in the Phase execution task
- source: applied split from Phase 2

## Closure and frozen handoff — 2026-10-01

This is a normal Phase release with focused assurance and an explicit pending
aggregate validation gate, not full-repository or platform-runtime assurance.
The closed status becomes authoritative only with the distinct release commit
containing this record and its verified `Phase-Closure-Binding: PHASE-2` receipt.

The original Phase base is `5b779fe151a8c9cd21feb6c076038729381cde83`.
The independently reviewed and accepted Step commits are:

| Step | Acceptance commit | Focused behavioral and consumer evidence |
| --- | --- | --- |
| TFAF-S01 | `0f73dc61cc706a696c3b8814120dc85f15162571` | 29 registry/View cases; 19 existing ApplicationViewModel/ListDetail cases |
| TFAF-S02 | `6b495e7e23d17bd760bb7248d17a618174ac80f0` | 50 record/controller cases; 31 registry/View/ApplicationViewModel cases |
| TFAF-S03 | `830b673dd89ddfcaa92d0f360d522baf4d44cb62` | 57 Material/Cupertino shell/navigation cases; 81 accumulated Settings/ApplicationViewModel cases |

Each Step also passed its focused analysis, no-change formatting and diff
checks. These are executed cases, not a claim of distinct aggregate case
counts. The canonical [checklist](phase-2-checklist.md) records the separate
Step acceptance basis.

The mandatory epoch-1 comprehensive review inspected the entire original-base
through accepted-head range: all 21 changed paths, 18 whole target programs,
the controllable storage fixture, normative contract and canonical checklist,
plus the affected consumer and cross-Step integration edges. It returned PASS
with no Current Phase Blockers, Hygiene or Development Candidates. Review
identity: `/root/tfaf_phase2_full_review`. Verified V3 disposition SHA-256:
`bfb327358b682be60af272342d4edfcacbff84cb1160c564ca2794bdbbb1955e`.
No post-review product repair or second comprehensive review was required.

The reusable handoff consists of the stable common IDs/defaults and finite
typed extension registry; immutable snapshots and explicit intent/presence;
the version-1 record and compatibility/unknown-data rules; injected,
caller-owned storage; revision-aware read/write/retry/reset behavior; owned
and borrowed Settings Views; controllable-storage fixtures; and shared native
Material/Cupertino shell/navigation. See the
[accepted Settings contract](../notes/application-settings.md). Phase 2.1
consumes these APIs and fixtures without redefining persistence.

Repository-full validation was deliberately not run:
`repository_full_suite=deferred-not-run`. The reciprocal serial chain is
`PHASE-2 -> PHASE-2.1`; final owner `PHASE-2.1` must verify this release's
accepted ancestry and generated aggregate-validation commit audit, then run
`scripts/validate-full.sh` once on its own frozen final release tree.
The method remains `local-driver-acceptance`, timing `final-only`, bootstrap
`none`. No SBT or CAR-lint requirement applies to this Flutter package.

Both accepted follow-up ledgers are empty: Hygiene `[]` and Development
Candidates `[]`, with no unpersisted records and no empty journal files
created. Closure binding retains the absent canonical targets
`docs/journal/2026/10/2026-10-01-phase-2-hygiene-follow-up.md` and
`docs/journal/2026/10/2026-10-01-phase-2-development-candidate-follow-up.md`.

Phase 2.1's plan/checklist and shared Phase projections are saved as one
planned/not-started management set. No successor is executed by this release.
The existing architecture-note planning change is preserved outside the
release payload. App Phase 3 and Core remain outside this mutation boundary.
Concrete adapters, resolved pane/hinge/text effects and Android/iOS/Web runtime
proof stay owned by Phase 2.1 and the separately authorized app driver.
