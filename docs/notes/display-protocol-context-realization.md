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

## Provisional public Core consumer mapping — 2026-10-02

App ESA4-02 / S01 authors the additive
[Core candidate contract v1](../../../textus-flutter-core/docs/design/display-prototype-contract-v1.md).
Validation and independent Step acceptance remain pending. TFAF's forthcoming
ESA4-03 realization imports `package:textus_flutter_core/textus_flutter_core.dart`;
it consumes DisplayListData/DisplayDetailData and their presentation models,
DisplayEditBinding/DisplayFieldLocator/DisplayValue for semantic drafts and
scoped errors, and DisplayMutationResult for committed versus pending evidence.
Bindings stay beside fields; stage is never reverse-parsed into semantic input.

PresentationContextPolicy admits bounded PresentationContext families with an
injected UTC clock. LocalePresentationPayload and
CorrelationPresentationPayload are generic presentation/continuation inputs.
SuppliedArmPresentationPayload supplies the full registration key
`(namespace, presentationSet, armId, definitionVersion)`; assignmentReference
is fixed flow provenance. A/B/C examples supply identities without allocation
or screen branches. No arm uses an explicitly registered neutral policy;
unknown/incompatible definitions must preserve selection/draft and expose the
incompatibility under the later framework/session policy. These UI behaviors
remain ESA4-03/04 proof obligations.

DisplayTransport takes typed query/read/update/create/delete requests with
DisplayRequestMetadata; OrdinaryOperationTransport.execute accepts a separate
OrdinaryOperationRequest. OrdinaryOperationResponse has only context/result
and cannot imply a refreshed Display. Explicit Reload uses a separate Display
read after Operation success. Scripted ports are raw FIFO playback with immutable
call observation, no policy execution, semantic source changes, retry or implicit
reload. They establish consumption rather than successful semantic execution.
Existing ResourceDetailView action behavior retains its accepted legacy contract;
the later Display session composes this separate candidate Operation/Reload path.

## ESA4-02 acceptance and public semantic source handoff — 2026-10-02

The proposal and pending-consumer wording above are historical. ESA4-02 is now
accepted and locally committed: Core `7a38c67e165cceb25f85a310ed5582491553d64f`,
TFAF `0b3ebaab0f33762c371c21cd2aabbecf716e4810`, app
`739d4694811a46f21ee80cb92fe67a4461e2adc2`; the
[acceptance journal](../journal/2026/10/2026-10-02-display-prototype-esa4-02-acceptance.md)
retains native FINDINGS and independent resolution/M0 lineage.

ESA4-03 is in_progress/OPEN. S01 authors Core's publicly exported
[FixtureDisplaySource contract](../../../textus-flutter-core/docs/design/display-fixture-source-v1.md)
and separate FixtureOrdinaryOperationTransport, with app-owned mappings and
public consumer specs. Parent validation and fresh independent review are pending.
Future TFAF realization consumes Core common session APIs after S02; registry,
Editor/draft/navigation and adaptive UI belong to S03. Existing
ResourceDetailView legacy action behavior has its accepted contract; this
additive source handoff changes no legacy refresh behavior or package Phase
acceptance. Runtime UI, SC01–SC20, Web and Phase closure remain pending.

## ESA4-03 / S02 public session consumer mapping — 2026-10-02

Current status: S01 accepted; S02 authored awaiting parent checks/review; S03 required; Step OPEN
Owner: TFAF under app Phase 4
Update rule: Append actual public consumer evidence; preserve historical proposals/accepted lineage and legacy behavior.
Closure basis: Accepted source/session, framework realization, public consumers, independent Step acceptance and commit; package/Phase closure is separate.

S01 now has 139 actual targeted successes, clean selected analyzers, independent
review `esa4-03-s01-review-20261002-root-01`, eligible authoring M0 amendment
`esa4-03-s01-gwt-parent-m0-amendment-20261002-root-01` and ledger9. Earlier
pending-source sentences are historical. [The Slice journal](../journal/2026/10/2026-10-02-display-prototype-esa4-03-slices.md)
retains S02 pending scope.

S03 imports only `package:textus_flutter_core/textus_flutter_core.dart` and consumes
[DisplaySession v1](../../../textus-flutter-core/docs/design/display-session-v1.md)
through ChangeNotifier snapshots. `state.list`/`detail` carry loading/failure and
last accepted projections; `selectedResourceId` is accepted focus. `context` supplies
fixed definition/locale/continuation inputs, `diagnostics` visible optional omission,
and `contextFailure` visible incompatible admission. `canMutate`/`canCreate` are
local projection eligibility; TFAF additionally checks definition availability
and unsaved draft/navigation policy. It does not interpret those getters as server
authority. `minimumRevisions`/`committedRevisions`, `projectionPending` and
`commandUncertain` preserve receipt versus projection/reconciliation semantics.

TFAF owns scoped semantic draft values, definition identity and observed revision.
On a new accepted changed/noOp update receipt identified by command sequence, it
clears only the submitted draft even if projection stays pending. Rejected/conflict
or delivery/admission failure retains draft/observed revision. Safe reads never
replay, merge or rebase a draft; explicit reconciliation/discard belongs to TFAF.
Ordinary Operation result is separate, and only explicit common Reload requests
Display afterward. Definition or resource switching under unsaved edits needs
explicit cancel/discard; incompatible context keeps accepted focus/draft until
explicit discard/dispose/new supplied session. There is no persisted restart.

Full `(namespace, presentationSet, armId, definitionVersion)` registration remains
S03; neutral policy is explicitly registered and unknown/incompatible definitions
block editing. App composition constructs a configured session and calls public
methods, with no per-request context forwarding/arm allocation. S02 changes no
Widget or legacy ResourceDetailView action behavior. Its 98 Core/four App cases
await parent checks/review; they prove no TFAF draft/UI or SC01–SC20 acceptance.
Web400/1200, feedback and final Phase validation/review/release remain required.

## Current S02 acceptance / S03 authoring projection — 2026-10-03

Current status: S01 and S02 accepted; S03 authored pending parent validation and independent review; ESA4-03 and SC01–SC20 OPEN.
Owner: Core session/source, TFAF presentation and app public consumers under the original app Phase 4 authority.
Update rule: Retain historical authoring/pending statements and native failure/review/M0 lineage; this dated projection supersedes their current-status wording.
Closure basis: Actual selected SDK evidence, complete-Step independent review and separate Step commit; ESA4-04/05 and all final Phase gates remain mandatory.

S02 has 237 actual selected successes with clean selected analyzers/format and
independent protected review `esa4-03-s02-review-20261003-root-01` revision 1
PASS at review ledger revision 10. The closed constructor batch and exact 41
captured accepted inputs are preserved. Earlier S02 pending/check/review sentences
record the historical authoring point and no longer describe the current boundary.

S03 authors public `DisplayDefinitionRegistry`, immutable `DisplayDraft` and
`DisplayPresentationState`, owned `DisplayPresentationController` and borrowed
`DisplaySessionView`. Full namespace/set/arm/version lookup has explicit neutral
policy and visible incompatibility. Typed scoped input retains the observed
revision; matching changed/noOp receipt clears submitted input before refresh.
Failure/conflict retains input until explicit reconciliation. Reset adopts only
an explicit pristine new fixed-flow session; late UI/dialog actions retain their
captured session identity. Owned Core disposal is immediate; notifier release
uses one microtask. Ordinary Operation has no implicit Display reload.

The new authored matrix contains RG01–RG12 (23 expanded cases), ED01–ED25
(48), VW01–VW20 (32), plus AF01–AF04 (four actual unchanged-asset public widget
consumers). Standard/cards/sections, locale, Common Settings and400/1200 adaptive
choices use generic public composition. Authored specifications provide no SDK
result or composed SC/Web acceptance. Parent validation and independent review
are pending. No Core source/specification, fixture/configuration, legacy framework
Settings/action/adaptive implementation or app product screen change is included.

ESA4-03 remains OPEN. Product screen composition and complete SC01–SC20 belong
to ESA4-04; Web400/1200, protocol/model feedback, final full validation, one
comprehensive Phase review and distinct release remain ESA4-05/Phase obligations.
Real-server admission remains Phase 5 work. Step repairs 3/3 stay consumed and
closed; Phase repairs 0/3 stay separate, without a new S03 repair allowance.
Accepted findings are empty; no Hygiene/Development Candidate or design promotion
record is introduced by this authoring projection.

The [presentation design](../design/display-presentation-v1.md) records the exact public contract.

## ESA4-03 independent acceptance / commit preparation — 2026-10-03

Current status: S01–S03 implementation and complete ESA4-03 independent review accepted; local Step commits prepared, not yet recorded; Phase 4 and SC01–SC20 OPEN.
Owner: app Phase 4 with Core/TFAF and app public consumers.
Update rule: This dated evidence supersedes earlier current-status wording; retain historical failures and authoring projections. Record actual native Step revisions only after commit success.
Closure basis: Complete-Step independent review PASS and selected validation; the separate local Step commit remains required. ESA4-04/05 and final Phase gates remain required.

Review `esa4-03-review-20261003-root-01` revision 1 is PASS at review ledger
revision 11, covering all 30 Step paths with zero CPB/HYG/DEV findings.
S03's six selected checks passed: 102 framework, four App public-consumer and
55 existing framework tests (161 actual executions), both targeted analyzers
clean and nine-file formatting unchanged. Retained S02 evidence is 237 successes.
The separate approved S03 four-file batch closed at one of three attempts;
original Step repairs 3/3 and Phase repairs 0/3 remain unchanged.
These results do not establish composed SC01–SC20, Web400/1200, a package Phase,
final full validation, comprehensive Phase review/release or real-server E2E.

## Current ESA4-03 commits / App composition authoring — 2026-10-03

Current status: ESA4-03 accepted-and-committed; App ESA4-04 AUTHORED_ONLY pending parent checks/review; SC01–SC20 OPEN; app Phase 4 in_progress.
Owner: TFAF registry/draft/controller/view under app Phase 4; App owns route/configuration/asset and borrowed Settings composition.
Update rule: Preserve historical authoring/precommit, failure and independent review/M0 lineage; project actual acceptance only from native parent receipts.
Closure basis: Combined scoped CP/package evidence, parent focused checks, independent Step review and separate commit; Web/final drivers/sole Phase review/release remain pending.

Actual ESA4-03 commits are Core `33f99d4e2a86ba4827092876d56e53bb6307f34d`,
TFAF `b4d23403f3a82033d4c392b5e174218b976ec9ea`, App
`da5cf4e3ef26221788314b190edb5d27b7624d3f`. Retain independent review
`esa4-03-review-20261003-root-01` revision1 PASS, selected S02 successes237
and S03 executions161, original repairs3/3 and closed approved S03 batch1/3.
ESA4-04 repairs0/3 and Phase repairs0/3 are separate.

[App composition v1](../../../../Project2026/nict-editing-studio-app/docs/notes/display-client-composition-v1.md)
declares the fixed full-key A/B/C registry and neutral locale-only definition,
transfers a pristine public Core session to the unchanged controller and borrows
the unchanged generic DisplaySessionView. TFAF retains supplied-key resolution,
typed scoped draft/validation, observed revision, explicit reconciliation,
resource discard and adaptive semantic UI. App configuration/reset never
reimplements freshness/context/arm selection. Its Settings binding remains
across reset and is disposed before its owned controller, with one inherited
text scaling boundary. CP01–CP20 are authored/pending; complete RG/ED/VW and
existing Settings evidence remain necessary for SC requirements. This Slice
changes no TFAF product/spec/config, package Phase or real-server acceptance.
See the [documentary handoff journal](../journal/2026/10/2026-10-03-display-prototype-esa4-04-composition.md).

## ESA4-04 independent acceptance / commit preparation — 2026-10-03

Current status: Complete ESA4-04 implementation and independent Step review accepted; local Step commits prepared, not yet recorded; Phase 4 and SC01–SC20 OPEN.
Owner: app Phase 4, consuming unchanged public Core/TFAF prototype APIs.
Update rule: This dated evidence supersedes earlier current-status and repair0 wording; retain historical authoring and failure records. Record native Step revisions after actual commit success.
Closure basis: Complete-Step independent review PASS and selected execution evidence; separate local Step commit remains required. ESA4-05 Web400/1200, protocol/model feedback, final full validation, sole Phase review and distinct release remain required.

Review `esa4-04-review-20261003-root-01` revision 1 is PASS at review ledger
revision 13, covering all 15 owned Step paths and 98 captured inputs, with
zero CPB/HYG/DEV findings. Actual final App execution passed 35 representative
CP01–CP20 cases and 45 regression tests. Six-target fatal-info analysis had
zero issues and the nonwriting six-target formatter reported zero changes.
Historical package evidence was reused after proving 49 package inputs unchanged:
Core runtime98 and five-suite accumulator135 (including protocol/context),
TFAF representative102 and regression55. These are retained executions, not new tests.
The combined SC map uses typed/scoped/context package proof as well as App cases;
actual Web observations for SC02/04/11/12/20 and final Phase gates remain pending.

ESA4-04 repairs3/3 are independently accepted and closed. Original ESA4-03
repairs3/3 and its separately approved S03 batch1/3 remain closed, without
budget transfer; Phase repairs0/3 and PLAN epoch1 remain unchanged.
This is Step evidence, not Phase completion, a package Phase closure,
real-server E2E, CNCF admission, experiment allocation or evaluation.
