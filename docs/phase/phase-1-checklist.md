# Phase 1 acceptance checklist

status=closed

closed_at=2026-09-29

phase=[Phase 1](phase-1.md)

## Scope and stages

This checklist consolidates the original Phase plan and the accepted
implementation evidence. It does not invent historical Step commits or replace
the original plan. The seven original work areas are complete:

- [x] TFAF-01: executable Flutter package, public entry point, Core dependency.
- [x] TFAF-02: serializable Resource, navigation, action, adaptive, realization models.
- [x] TFAF-03: reusable configured Resource List and selection.
- [x] TFAF-04: reusable configured Resource Detail and view-intent dispatch.
- [x] TFAF-05: compact/split/focused presentation and independent hinge policy.
- [x] TFAF-06: Editing Studio's Collecting and Candidate fake-resource bindings.
- [x] TFAF-07: documented configuration schema and Cozy compiler handoff.

## Acceptance criteria

- [x] Executable package foundation: public library and Flutter tests.
- [x] Declarative List/Detail: real app JSON assets control fields and actions;
  replacement scenarios use the same framework Widget.
- [x] Realization vocabulary: framework/generated/hybrid/custom round-trip;
  framework is default and unsupported realizations are not silently rendered.
- [x] Same semantic configuration across compact, expanded, and foldable layout:
  Core geometry is consumed by TFAF composition; both hinge axes are tested.
- [x] Compact selected detail expands to List | Detail with the same selection;
  focus/restore controls appear only where split layout is viable.
- [x] Reference application: both resource tabs use TFAF; a Candidate view
  action reaches an application-owned fake Aggregate and refreshes projections.
- [x] Core/TFAF boundary: geometry in Core, application presentation in TFAF.
- [x] Cozy target contract: schemas, defaults, binding ownership, examples,
  compatibility, and current limits are documented and exercised.
- [x] Specialized realization escape: public policy and application page
  bindings define extension without weakening the configuration-first default.

## Evidence and limits

The [closure record](../journal/2026/09/2026-09-29-phase-1-closure.md) binds
review, validation, implementation revisions, and physical observations.
The existing independent acceptance review found all nine criteria satisfied
and no Current Boundary Blocker; its three nonblocking maintenance findings
remain open in the [Hygiene ledger](../journal/2026/09/2026-09-29-phase-1-hygiene.md).

Physical acceptance covers vertical Fold expansion, avoid/span selection,
detail-only/split selection, shrinking to detail, and retention of each
explicit display mode when reopened. Selected resource identity, both tabs,
and horizontal geometry also have automated evidence.

This does not claim physical horizontal-posture testing, cross-process
preference persistence, production server Operations, complete CRUD/workflow
semantics, arbitrary multi-hinge partitioning, or a completed Cozy generator.
Phase 2 remains planned.
