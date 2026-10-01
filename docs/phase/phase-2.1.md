# Phase 2.1 - Common Settings Fold, Font and Reference Driver

status=planned
split_full_test_policy=final-only
split_full_validation_method=local-driver-acceptance
split_validation_bootstrap=none
split_full_validation_driver=scripts/validate-full.sh
validation_ownership=aggregate-final-owner
aggregate_validation_owner=PHASE-2.1
aggregate_validation_sequence=["PHASE-2","PHASE-2.1"]
planned_at=2026-10-01
depends_on=[Phase 2](phase-2.md)
predecessor=Phase 2
reference_application=KnowledgeHubProject/nict-editing-studio-app Phase 3
checklist=phase-2.1-checklist.md

## Goal and provenance

Split from [Phase 2](phase-2.md) on 2026-10-01 through the explicit
`cncf-split-phase phase 2` invocation. Apply the accepted Settings foundation
to adaptive pane/hinge presentation and OS-aware text size, then prove the
behavior through Editing Studio App Phase 3. This is the last resulting Phase
and owns complete framework validation for `PHASE-2 -> PHASE-2.1`.

Status remains planned. Start only after the predecessor's accepted closure.
Consume its setting IDs/defaults, versioned record, View/service/storage and
extension APIs, lifecycle rules, fixtures, platform-shell evidence and release
identity. [Phase 2 architectural rules](phase-2.md#architectural-rules) and
[TFAF-S02 persistence rules](phase-2.md#tfaf-s02-persistence-boundary) remain
authoritative; this Phase does not redesign them.

## Repository and driver ownership

The serial aggregate validation chain contains TFAF only. Editing Studio App
Phase 3 owns app composition, the injected real local-storage adapter binding,
consumer tests and runtime smoke records under its own workflow and validation.
It can consume the Phase 2.1 implementation during development; dependency on
its implementation does not require waiting for this Phase's final closure.
This Phase accepts that identified consumer evidence before its final gate.
No app Phase is started or closed implicitly by the split or this framework
Phase.

TFAF owns reusable resolver, adaptive presentation, text-scaling boundary and
any reusable local adapter API/implementation needed by the reference proof.
Core supplies existing environment primitives; no new Core mutation scope is
implied. Applications do not duplicate Settings Widgets or persistence logic.

## Scope

### TFAF-S04 Fold behavior

Introduce an application-level adaptive policy with at least:

- `automatic`
- `preferSinglePane`
- `preferDualPane`

`automatic` uses current device/display environment supplied by Core. Explicit preferences influence TFAF composition but do not replace environment facts.

The Phase 1 List/Detail reference path is the primary executable proof.

#### Resolution and precedence

First calculate physical layout eligibility using the existing safe regions,
minimum pane dimensions and selected hinge policy. A preference never makes an
ineligible two-pane layout eligible. Preserve Phase 1 selection and compact
navigation state across every settings, window-size and posture transition.

For eligible layouts, an explicit per-tab session choice (split or detail focus)
overrides the persisted pane preference. Otherwise:

| Pane preference | Effective default |
| --- | --- |
| `automatic` | Existing Phase 1 adaptive behavior: split when eligible, sequential otherwise. |
| `preferSinglePane` | Sequential List/Detail even with sufficient space; show detail only when compact-detail intent and a valid selection exist. |
| `preferDualPane` | Split when eligible; ordinary sequential fallback when not eligible. |

Temporary lack of space hides split/focus controls but does not erase the
session choice; restoring space restores that choice. Even under
`preferSinglePane`, an eligible layout offers an explicit switch to split,
so the global default does not trap the user in a single-pane presentation.
Detail focus still requires a valid selection and `allowDetailFocus`.
Session choices are independent per resource tab and are not persisted.

Hinge resolution is independently: per-tab session override -> explicitly saved
global hinge preference -> configuration `defaultHingePolicy` -> framework
`automatic`. Missing pane settings inherit configuration defaults where
provided, otherwise `automatic`; an explicitly saved `automatic` is a real
choice, not a missing value. Preserve the Phase 1 avoid/span viability rules,
continuous-region fallback and physical-gap occlusion warning. A dual-pane
preference must not silently change avoid to span to make a layout fit.

An explicit common pane-setting edit clears only pane session overrides in all
tabs; a hinge-setting edit clears only hinge overrides. This makes a common
setting change immediately observable without changing the other dimension.
Automatic restoration, resizing and capability changes clear neither.
Text-size edits clear neither. Reset clears both as specified above.

#### Availability and retention

Availability is based on layout capability, not Fold hardware or an Android/iOS
name: tablets, desktop and resizable windows can benefit from pane preference.
Keep the pane setting accessible even while compact so the next expanded layout
can be configured. A hinge setting without an applicable separator is disabled
with an explanation rather than deleting its stored value.
When a setting becomes temporarily inapplicable, use a safe effective fallback
without writing that fallback to storage. Re-enable and re-resolve the retained
choice when capability returns. Session toolbar controls keep the Phase 1
eligibility rules; Settings availability is not the same as toolbar visibility.

### TFAF-S05 Font/Text behavior

Introduce a common application text preference.

The design must preserve the system accessibility text scale. The effective text presentation is derived from system preference plus the TFAF/application preference rather than replacing the system setting.

Do not prematurely require arbitrary font-family selection; establish the common text-size/font policy boundary first.

This Phase implements text size only: `1.0` (standard), `1.15`, and `1.30`,
with `1.0` as default. Other persisted multipliers are invalid and fall back to
`1.0`; font-family, weight and line-height customization are out of scope.

For an unscaled logical font size `s`, let `S(s)` be the current OS-provided
scaling function and `m` the selected app multiplier. Effective size is
`m * S(s)`, applied once at the common presentation boundary. Preserve the
OS function rather than replacing it with a fixed scalar; `m = 1.0` must
produce exactly the OS result. Changing system scale recomputes presentation
without changing saved app preferences.

Apply this to app text, navigation, standard Resource List/Detail and Settings,
including its own controls and dialogs. Do not scale icons, images or geometry
by this multiplier, apply it twice in nested screens, or cap away OS enlargement.
At the largest app value combined with enlarged system text, text remains
readable and controls reachable through wrapping/scrolling or safe layout
fallback. Settings must remain usable to return to standard size.

Acceptance includes default-system scaling and enlarged-system scaling for each
app value, a non-linear fake OS scaling function to prove composition order,
live OS changes, and compact/split/Settings navigation without clipping or
unreachable controls. Example: if `S(16) = 24`, `m = 1.30` yields `31.2`.

### TFAF-S06 NICT Editing Studio development driver

Use `nict-editing-studio-app` to prove:

- opening the common Settings UI;
- changing Fold behavior;
- observing the existing List/Detail presentation respond;
- changing text size/font preference;
- observing the application update consistently;
- persistence across application restart;
- no Editing-Studio-specific Widget implementation for the common settings.

Application-specific settings may be added as an extension proof if useful, but are not required for Phase closure.

## Settings versus environment

Keep these concepts separate:

```text
ApplicationSettings
  AppearanceSettings
  AdaptiveSettings
  <application extensions>

DeviceEnvironment
  window/display regions
  display features / hinge
  fold posture
  system text scale
  platform capabilities
```

TFAF resolves effective presentation from both inputs.

## Acceptance criteria

This Phase owns the remaining original Common Settings criteria:

- Fold behavior supports automatic/single-pane/dual-pane preference and continues
  to consume Core environment primitives.
- The resolver separates persisted settings, environment, session overrides and
  effective presentation; setting changes do not recreate Resource Views,
  replace selected resources or issue domain commands.
- Pane/session/hinge precedence, dimension-specific global edits, reset,
  insufficient-space fallback and capability loss/return pass behavior tests.
- Font/Text preference composes exactly once with OS scaling without suppressing
  accessibility; all three multipliers, a nonlinear OS function and live OS
  changes pass tests with reachable controls at enlarged sizes.
- Editing Studio demonstrates both setting groups against the accepted Resource
  List/Detail path, including both tabs, compact/expanded layouts, both hinge
  axes, disabled-to-enabled hinge settings and unchanged resource selection.
- The injected real local adapter restores acknowledged values after app restart;
  consumer/failure evidence follows the predecessor's storage contract.
- Android and iOS runtime smoke records cover opening Settings, changing both
  groups, returning to resources and restoring acknowledged values after restart.
  Platform, environment and limits are recorded; unavailable runtime evidence
  stays pending.
- Web startup, Settings interaction and browser-origin preference restore pass a
  browser smoke check.
- The final owner verifies predecessor accepted ancestry/deferred-validation
  handoff, completes its own focused validation, independent review, Step
  commits, comprehensive Phase review and closure ledger, and runs the configured
  TFAF `scripts/validate-full.sh` once at the frozen final release tree.

Settings model, persistence lifecycle, extension and base Material/Cupertino
shell criteria are owned by Phase 2. Reuse its accepted handoff rather than
claiming those unchecked items twice. This Phase owns any new shell/text
accessibility interaction cases required by its presentation changes.

The shared driver matrix applies to Editing Studio App Phase 3. Evidence may be
shared with exact scenario and ownership rather than duplicate executions;
the app retains its own complete validation. Required iOS runtime access is an
environment prerequisite to plan before the final proof; Command Line Tools
alone do not establish simulator availability.

## Non-goals

- Redefining the accepted Settings record/API or persistence lifecycle.
- Closing Editing Studio App Phase 3 automatically.
- Server synchronization or production server integration.
- Arbitrary font family, weight/line-height customization or persisted Resource
  selection.
- Platform-specific logical schemas or app-owned copies of common UI/runtime.

## Planning and profile transition

Expected 5.5h, uncertainty 5–8h, including coordinated reference-driver proof.
The lower-cost execution region consumes Phase 2's durable public-contract and
behavior handoff. GPT-6.1 Sol medium is suitable only while those contracts and
the specified presentation rules remain settled; reassess if an unresolved
design decision emerges. Parent and agent mode policy is standard.
The source's dated split record owns the pre-split estimate and overhead
evidence. This child receives no genuine semantic split edge; ordinary release
and profile transition remain normal serial dependencies.

## Current structural planning gate

Phase Plan Gate: PROCEED
- target: calibrated expected duration centered on 6h; allowed ceiling 8h
- estimate_calibration: no comparable planned/actual execution evidence; no multiplier
- planning_demand: bounded-settled
- recommended_parent_profile: gpt-6.1-sol / medium
- profile_cost_role: lower-cost execution
- expensive_reasoning_kernel: none; consume accepted predecessor contracts
- frozen_profile_transition_handoff: Phase 2 setting IDs/defaults, versioned record, View/service/storage/extension API, fixtures, platform shell interaction evidence and closure/release identity
- parent_reasoning_mode_policy: standard
- estimated_at_recommended_profile: expected 5.5h; range 5–8h; 0.5h below target and 2.5h below ceiling
- incoming_semantic_handoffs: []
- merge_attempts_for_every_sub_4h_child: none; no expected child below 4h
- rebalance_attempts_for_every_sub_5h_child: none; no expected child below 5h
- adjacent_merge_structural_rejection_evidence: combined original expected 9.5h exceeds 8h
- profile_cost_only_rejection_forbidden: true
- short_child_basis: none
- overhead_tradeoff: about 1h additional split assurance overhead across the chain; lower-cost implementation consumes a proven contract
- agent_reasoning_mode_policy: default standard; consider pro only at an eligible agent launch with supported quality-first evidence
- runtime_suitability: re-evaluate in the Phase execution task; new design choices require a capability reassessment
- source: applied split from Phase 2
