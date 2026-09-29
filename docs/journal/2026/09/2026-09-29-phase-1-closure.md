# Phase 1 normal closure

Date: 2026-09-29

Phase: [Configuration-driven UI Reference Path](../../../phase/phase-1.md)

Disposition: closed by ordinary acceptance; no force release or assurance waiver.

## Accepted implementation

The framework provides serializable Resource List/Detail and bottom navigation,
an application-session View space, collection/detail Views, transport-neutral
read adapters, and view-action dispatch into application-owned Aggregate
commands. The fake Editing Studio driver exercises Collecting and Candidates.
Core supplies display regions; TFAF owns compact, split, focused, and hinge
avoid/span presentation. Explicit display choices survive resize in-session.

Implementation revisions:

- TFAF: `ad6d74c891d773610247f8b02d8e89ee1eff92ac`.
- Reference application: `0263ede8d9b9fb35b551e2f4bbc124afd3f3820c`.
- Core dependency: `53294dccf774fe467d886a6a1db10b2d86bd0434`.

The release commit adds this closure projection and a reusable full-validation
driver; it does not change runtime behavior or start successor work.

## Review and verification

Independent review `TFAF-PHASE1-INDEPENDENT-ACCEPTANCE-20260929-01`
found the nine criteria satisfied with no Current Boundary Blocker.
Its original report and immutable disposition are retained in the reference
application's ignored local workflow evidence under
`.codex-workflow/goals/TFAF-PHASE1-ACCEPTANCE-AUDIT-20260929-01/`.
The ordinary release binds a current-tree full closure review and final
validation receipts separately; it does not relabel the earlier audit as a
formal release result.

The accepted source audit passed 73 TFAF and 39 reference-application tests.
TFAF analysis was clean. App analysis with `--no-fatal-infos` retained only
two existing Book Capture deprecation infos. Earlier Core verification passed
25 tests. Final release validation runs `scripts/validate-full.sh` against
the unchanged runtime source and binds its actual completion to the release tree.

User physical reports confirmed: compact detail expands to List | Detail;
the hinge avoid/span switch and detail-only toggle work; both expanded modes
shrink to detail; reopening restores the explicit detail-only or split choice.
This is vertical Fold acceptance, not a physical horizontal-posture or
cross-process persistence claim.

## Legacy evidence migration

The shared workflow skill lacked a recovery path for a Phase established
before canonical checklists. That tooling defect was repaired and tested;
it is not a product acceptance exception.

The verified migration derives the conservative Phase comparison base
`e5d73b32473c5286474ab311e218f27eb719e56a` from the sole parent of the first
planned Phase document commit
`9e9c9b844f7448dd975280f0e2065fef98028f4c`
(plan blob `1c7a3803ad6b96c0e4bb40f3a14f78fea8554380`).
The base contains only documentation/metadata, so no framework implementation
is excluded. This establishes a verified migration base; it does not claim
to recover a missing original execution snapshot.

The original reviews/tests remain intact. Normal closure still requires the
complete acceptance scope, current-tree review, final validation, and a
distinct release commit.

## Remaining work

Three exact nonblocking Hygiene records are retained in the
[Phase 1 Hygiene ledger](2026-09-29-phase-1-hygiene.md), with their original owners.
No new Development Candidate was identified by the acceptance audit.
Existing limits are unchanged: production transport/Operations, broader CRUD
and action surfaces, full generation, persistent Settings, and more complex
hinges are not accepted by this Phase.

TFAF Phase 2 remains planned. Editing Studio Phase 2 remains closed;
this release does not start or accept any application successor.
