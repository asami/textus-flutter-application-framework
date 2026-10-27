# ESA5-07 formal supplied presentation context

Date: 2026-10-27

Status: accepted for App ESA5-07 by independent protected Step review on 2026-10-28.
No App Phase 5 or dependency Phase closure is claimed.

Authority: frozen `ESA5-07-TFAF-FORMAL-PRESENTATION-001` within the original
Phase 5/ESA5-07 connected plan, ledger 11/control 35 PLAN. Accepted inputs are
Core `0230b159`, TFAF `a819f469`, App `50f0bf0a`, and server `ae214739`.
The implementation owns only the selected nine TFAF paths; authority, binding,
epoch, bases and workflow counters remain parent-owned.

## Authored behavior

Added public `CncfDisplayPresentationRegistry`,
`CncfDisplayPresentationResolution` and `CncfDisplayPresentationFailure`
(`incompatibleDisplay`, `unknownVariant`). The registry freezes trusted
configuration entries through their existing codec and re-admits complete
formal Display wire against its independent `CncfDisplayReadProfile`.
Profile pins cover component/resource/screen/definition/semantic/provenance
identity; flattened resource revisions do not select or authenticate variants.

Only `cncf.presentation/1.data.variant` indexes the exact declared map.
`cncf.locale/1` and `cncf.display-flow/1` remain generic Core families.
Absent supported presentation means frozen neutral; unknown registered-family
values mean explicit unavailable configuration, with no silent neutral or other
variant substitution. Optional unsupported family/version filtering remains
Core-owned. Local key validation uses nonblank strings of at most 128 Dart
characters without trimming or imposing ASCII allocation names.

The data source now retains `lastDisplay` after complete successful Resource
projection in accepted successful completion order, preserving existing
`lastQuery` and `lastDetail`. Core may retire an older GET when a new read starts;
the superseded response is not accepted or projected and cannot replace
`lastDisplay`. A fresh explicit query can become latest after successful acceptance
and complete projection. Read/projection failures, descriptor responses and
command ACKs cannot replace this presentation observation.

The existing common `CncfDisplayResourceView` optionally uses that registry and
listens to its borrowed VM as well as its borrowed mutation controller. Known
configuration changes update common List/Detail visual labels and the Business
presentation allowlist without replacing the common State, borrowed layout,
selection or semantic owner and without scheduling extra reads. Listener
replacement/disposal respects borrowed lifetimes.

Unknown or incompatible presentation retains the common child under a full
opaque surface with semantics, focus and pointer exclusion. Its fixed generic
message and `cncf-display-presentation-reload` action disclose no raw context.
Captured old Edit/Business callbacks re-check current availability and ownership
before dispatch. Explicit retry uses existing exclusive controller reconciliation
when required, otherwise a VM query; no PUT/POST replay is introduced.
Already committed Business still performs its existing post-ACK safe reload.
An already opened Editor retains captured descriptor/profile/semantic edit
bindings, draft and Cancel/Back behavior until the user completes or cancels it;
presentation changes do not automatically pop or discard it.

## Executable specification scope

Authored pure registry contracts cover neutral/other/future families, exact
List/Detail variant resolution, unavailable unknown values, independent pin
mismatches, immutable declarations and invalid keys/configuration. Data-source
scenarios cover a superseded older query preserving newer Detail, a fresh accepted
query becoming latest, and preservation on projection/read failure, descriptor
and command ACK.

Authored actual common Widget contracts cover compact and expanded first-query
visual realization, common Edit revision 1→2, ordinary Business 2→3, receipt and
fresh stage visibility, generic Core family header transport on all subsequent
requests, retained common State/layout/selection, neutral/legacy paths,
configuration changes without extra reads, opaque unavailable keyboard/semantics
and callback blocking, GET recovery, wrong profile, already opened Editor,
post-ACK safe reconciliation, exclusive retry, and borrowed listener lifecycle.
The fixture adds only optional controlled `presentationContext` decoration with
default null. Genuine local baselines and existing helper behavior remain the
reference inputs; controlled family values are not new golden/live authority.

## Boundaries and pending work

This is formal `cncf.display-model.v1` binding. It is separate from Phase 4's
`textus.display.prototype.v1` and `textus.presentation.arm`; no prototype alias,
context conversion, experiment allocation, nominal A/B assignment, clock,
credential/session policy or remote lookup was added. Core owns context decoding,
credential use, command contracts and automatic
`X-CNCF-Presentation-Context` carriage. The App declares configurations and domain
bindings, and the trusted server supplies context. No manual UI header copying,
Core/controller/standard ListDetail production change, dependency change, or
server/native environment mutation belongs to this implementation.

At authoring on 2026-10-27, parent-owned focused specs, analysis and format checks, affected formal/common
mutation/Business regressions, downstream App configuration, fresh private bearer
and trusted native server Session, current bounded flow/clock, native revision
and independent write-count proof, full Step 7 gates and independent protected
review remain pending. Old static example dates must not be treated as live
authority. Local commit/release and Phase full review remain separate parent
transitions; no push, publication or deployment occurred here.

No separate follow-up debt was admitted in this implementation boundary.

## Current validation — 2026-10-28

Parent-owned presentation/context focused specs passed 31 and full TFAF passed
816; analysis/format and affected App 21 PASS supersede the authoring-time
pending checks. App-owned `esa5-07-native-002` completed/admitted with readiness,
clients and owned cleanup PASS. A fresh trusted server Session/resolver, private
bearer, bounded flow and actual-start clock supplied live authority. Production
App entry with real Core encrypted Android configuration and common TFAF UI
realized the Japanese variant, common Edit 1→2, ordinary Business 2→3 and
automatic read/query with actual generic context carriage. Core remains the
generic carrier, TFAF resolves only supplied variants, App declares bindings.

Original native001 remains FAIL/exit 1 for its wrong seed-trace oracle, with
limited UI/context/cleanup PASS. The harness alone was corrected; native002
validated fresh operational trace/correlation identities independently of flow
UUIDs and exact native write/unchanged-row bounds. This is App-owned integration
evidence, not TFAF-owned server proof or TFAF Phase closure. Raw logs, credentials
and receipts remain ignored local artifacts. Independent protected Step 7
review, local acceptance commits, the sole comprehensive App Phase full review
and distinct local release remain pending. Earlier authority/history is retained.


## ESA5-07 Step acceptance — 2026-10-28

Independent protected Step conformance passed without blockers, Hygiene or
Development Candidate additions across the complete 25-path/18-program
boundary. The preceding validation-time pending review statements are
superseded by this acceptance record. Actual native002, host 33 and the owning
Core 1331 / TFAF 816 / App 1210 PASS with 3 optional skips / server 774 results
remain the validation basis; native001 remains failed with its stated limits.

ESA5-07 is accepted; its exact local Step commits are the next management
action. All seven Steps are accepted, while the sole comprehensive Phase
review and distinct local Phase release remain required. Phase 5 is still
in progress. No dependency Phase is closed by this App Step acceptance.
