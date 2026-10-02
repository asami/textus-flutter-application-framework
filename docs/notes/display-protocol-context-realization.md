# Context-driven Display Protocol UI realization proposal

Date: 2026-10-02
Status: non-normative proposal; no implemented or frozen protocol is claimed
Consumer/parent: nict-editing-studio-app Phase 4
History: [responsibility decisions](../journal/2026/10/2026-10-02-display-protocol-context-responsibilities.md)

## Purpose and inputs

Extend the [Display realization direction](../journal/2026/09/2026-09-29-display-model-visual-realization.md)
and [standard mutation direction](../journal/2026/09/2026-09-29-standard-display-mutation-ui.md)
with the [app UI-driven protocol/server-model proposal](../../../../Project2026/nict-editing-studio-app/docs/notes/display-protocol-presentation-context-proposal.md).
Use the accepted fake List/Detail UI and server sample to propose the contract
needed for generic realization before waiting for completed server code.

## Layer responsibilities

| Owner | Proposed role |
| --- | --- |
| CNCF/server/Experiment | Project presentation-relevant ExecutionContext, admit context/arm assignment and continuation, own domain projection/mutation and experiment lifecycle/evaluation |
| [Core](../../../textus-flutter-core/docs/notes/display-protocol-presentation-context.md) | Decode/transport/runtime models, context lifetime/propagation and common loading/failure/refresh/dispatch |
| TFAF | Context-driven arm/variant selection and standard UI realization, editor draft/error/navigation and adaptive composition |
| App | Resource/configuration/assets, declarative available UI definitions, domain bindings, public-API composition and integrated scenario acceptance |

TFAF consumes Core models/context through public contracts. The existing CRUD
adapter alone is not an implemented Display Protocol/context runtime. App
screen code has no experiment/arm branch, assignment logic or manual context
copying. Standard UI must not directly parse server JSON or reconstruct domain
meaning from display values.

## Context-driven selection

A/B and multi-arm information, including supplied arm identity, travels inside
a generic Presentation Context projected from CNCF ExecutionContext. The
framework treats the admitted arm/variant identity as a presentation selection
key. It resolves the corresponding registered, versioned UI definition and
realizes its List/Detail/Editor/action/navigation choices.

An app can register available definitions declaratively; it is not required to
know experiment purpose, allocation ratios, metrics, lifecycle or winner
selection. Experiment/server owners retain those decisions. Supplied-arm
selection remains a framework responsibility even when the server also varies
its Display projection; sending only an already selected Display without any
arm context does not capture the requested client selection capability.

Resolve the correspondence between experiment namespace, arm/variant identity
and definition version through an explicit registration contract. Scope keys
so identical arm labels from different admitted contexts cannot collide.
Exact key/API/codec spelling requires joint review and is not frozen here.
Missing or unknown arms, incompatible definitions and unavailable capabilities
follow an explicit policy. A neutral default requires admitted policy; no
implicit change of experiment behavior is allowed. A live definition change
needs rules for selection, navigation and unsaved drafts.

## Generic context and lifecycle

Arm selection is one context consumer. The same typed, versioned structure can
carry admitted locale/presentation and correlation families. Core retains and
propagates context; TFAF provides the normal navigation/action integration with
Core-owned flow state rather than requiring app forwarding code.

Declare scope/lifetime for each family, including read/query, mutation, direct
Business Operation and reload. Expired or unsupported context has an explicit
required/optional outcome. Cross-operation continuation must reconcile CNCF
admission and nested-operation inheritance; it is not automatically guaranteed
by the present runtime. Context never replaces resource revision or grants
operation authority.

## Standard UI and server-model evolution feedback

The initial proposal covers List -> Detail -> Edit -> Save and an admitted
Business Operation -> Reload, with title/description updates and read-only
derived stage. TFAF needs typed input-ready values, scoped field locators,
constraints, availability and field-addressable errors from server metadata.
Display label/value formatting must not imply an inverse semantic update.

CNCF/server feedback includes a versioned Display definition/projection,
explicit writable semantic bindings, source revision/freshness and a bounded
ExecutionContext projection. Core exposes committed-write/projection-pending
state so TFAF can preserve the draft or show refresh status appropriately.
Standard mutations and direct REST Business Operations keep distinct boundaries;
post-operation reload uses Core context propagation.

## Proposed verification and acceptance

- Fixed-context/arm fixtures select the expected UI for A/B and additional arms.
- Compact/expanded, locale and common Settings preserve declared UI behavior.
- Resource identity, selection, navigation and draft rules survive definition
  changes only as permitted by the selected transition policy.
- Unsupported/expired context and missing/incompatible definitions are visible
  according to policy rather than silently choosing a different arm.
- Standard update/error/conflict and Business Operation/reload use Core's
  context-aware public APIs without app experiment branches or JSON handling.
- A fixture for a non-experiment context demonstrates the generic structure.

These are proposed specifications, not test executions or a client experiment
measurement subsystem. Exposure/metric capture needs a separate explicit
handoff if later required. Dependency handoffs use focused verification; app
Phase 4 owns client prototype feasibility, and Phase 5 owns real-server
aggregate/E2E acceptance. Owning TFAF Phase bindings are settled
with the minimum protocol. This note reopens no accepted Phase 1/2/2.1 work.

## Client prototype scope update — 2026-10-02

The user clarified that app Phase 4 ends at provisional client implementation
and feasibility exploration. It uses development-only sample models and
controllable fake transport/Operations to prove the Core/TFAF/app boundary,
context continuation and supplied-arm UI. Findings revise protocol/server-model
proposals. Completed server implementation and frozen wire contracts are not
prototype closure prerequisites; simulation does not prove real CNCF admission.
App Phase 5 consumes this prototype and owns real-server integration and final
aggregate/E2E acceptance. Dependency contracts/Phases retain separate acceptance.
