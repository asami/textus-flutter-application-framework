# Common ordinary Business action — ESA5-05

Status: authored implementation and executable specifications; no validation or
acceptance result is claimed here. This is the Phase 5 Step 5 manual Reload
boundary. Step 6 immediate client reload and Step 7 full/native context gates
remain pending.

## Trusted declarations and command ownership

`CncfDisplayMutationController` borrows its existing source, Resource View Model,
and Core client. Its optional `businessBindings` constructor argument defaults
to an empty list. The public final list is an unmodifiable copy. Every entry must
match the client's component; action IDs and binding IDs must each be unique.
The existing source/View Model identity guard still applies. Construction performs
no I/O. Only an identical binding object in that declared list is admitted;
equivalent unregistered objects cannot acquire execution authority.

Public additions are `businessBindings`, `businessOperation`, `businessReceipt`,
`businessRunning`, `businessAvailability(binding)`, `canInvokeBusiness(binding)`,
and `executeBusiness(binding)`. Availability comes only from a ready, nonfailed,
nonloading, one-resource formal `source.lastDetail` matching the actual selected
Resource identity. Exactly one wire action must match both action and binding ID.
Its enabled/disabled/hidden metadata is available during busy presentation; a
missing or mismatched binding/read yields null. Invocation additionally requires
the common idle owner, no Editor, no reconciliation, and enabled availability.
No mutation descriptor is fetched for Business.

Execution captures that actual formal Detail synchronously, marks the single
busy/current Business owner and command start, clears current failure, field
errors, draft and Editor state, and invokes Core exactly once. Business, Edit,
Save, Reload and Discard cannot reenter the busy/publishing owner. Core owns
transport, authentication/context admission and ordinary command encoding. The
common controller never constructs a REST request or uses a remote action as a
route. `ResourceViewModel.performAction` is not the Business execution path.

## Ordinary ACK and explicit reconciliation

The reference trusted test binding routes to
`reference-business/requestReview.json`. Core sends an ordinary POST with only
form `resourceId` and the formal observation's exact `If-Match` revision. An
ordinary successful response has exactly `resourceId`, integer `revision`, and
`outcome` under `data`; the controlled test outcome is `review-requested`.
The Core `CncfDisplayBusinessResult` is separate from Display. The controller
stores and notifies its ACK before any safe read and returns true at ACK.
This Step performs no automatic read, command replay, or inferred Display update.
Fields and stage retain the old projection until explicit common Reload.

Known ACKs require reconciliation; failed, stale or incoherent reads retain the
ACK and block commands. Reload uses only safe Detail/query reads for the captured
resource. A different selected ID causes no I/O and preserves the observation.
Selection changed during a read cannot fabricate closure or overwrite a different
selected Resource. Explicitly selecting the affected Resource and choosing Reload
can recover. Both fresh formal projections must be nonfailed, nonloading, identify
the actual selected Resource, have matching revisions, and reach the BigInt floor
from the current Business ACK. Unknown commands without ACK use the formal
observation floor. They can resolve through safe reads, with no automatic replay;
a later enabled explicit intent can execute again.

`businessOperation` chooses the current receipt kind. An older standard-update
receipt remains immutable history while Business is current and cannot be labelled
as its ACK. Fresh normal Edit after reconciliation clears the Business marker and
older mutation receipt slot, retaining the latest Business receipt and any
externally held immutable receipts. Existing retired Text drafts and explicit
Editor Back/Cancel behavior remain intact. Clearing Editor work preserves an
outstanding reconciliation obligation and current Business evidence.

## Generic UI and lifecycle

The existing common `CncfDisplayResourceView` retains `ResourceListDetail` State
and borrowed layout. Business buttons intersect trusted declarations, formal
availability and `configuration.detailActions`: null uses the wire label, empty
hides all, and an explicit allowlist matches action ID and replaces the label.
Null/hidden/unregistered bindings are omitted; disabled remains visible disabled.
The stable key is `cncf-display-business-<actionId>`. The callback invokes the
common controller directly. No App action handler, domain field mapping or raw
Conclusion prose is introduced.

Current Business results show ordinary outcome/revision and the captured title-role
Text as-is when it is nonblank, falling back to the captured resource ID only when
the title is Missing or blank. Resource values, identity and receipts remain
unchanged. A failed Detail keeps that same result and common Reload in the toolbar. A captured
selection mismatch shows exactly `Select the affected resource before Reload.`
The mutation-only pending-projection message is not used for Business.

While `businessRunning && !isDisposed`, pointer absorption, progress and a current
route PopScope protect underlying selection and Back. The existing compact Back
interception is inactive during that busy ownership. No async Business completion
navigates or touches a replacement controller. Replacing/removing the opener
rebuilds its current layout; late completion has no common-view callback or
implicit read. Disposal retires publication and marks in-flight delivery unknown,
without disposing borrowed owners or claiming command cancellation.

Disposal emits no notifier. An explicit Back attempt on the current disposed busy
route refreshes stale UI and pops only when its Navigator can pop. A root remains
visible; a pushed route may leave; an unrelated current route cannot be forcibly
popped by old work. The existing retired Editor escape remains preserved.

## Executable specification and evidence provenance

`test/display/cncf_display_business_controller_test.dart` authors trust/default
compatibility, availability, actual Core POST and captured formal observation,
withheld/reentrant ownership, ACK notification before safe GET, explicit coherent
Reload, failure/stale/mismatch retention, exact BigInt floors, mutation2/Business3
history, unknown/conflict/malformed responses, selection change/recovery, and
borrowed-owner disposal scenarios.

`test/display/cncf_display_business_resource_view_test.dart` authors actual common
widget clicks at widths 400 and 1000, busy pointer/Back protection, unchanged stage
at ACK, explicit Reload to Japanese review stage and hidden action, retained
ResourceListDetail/layout identity, label/allowlist/availability intersections,
Business3 after mutation2 with failed Detail, fixed failure messages, captured
selection guidance, replacement/removal under unrelated routes, and finite
root/pushed disposed-busy escape. Given/When/Then comments accompany expectation
boundaries. Finite gates are explicitly released; held spinners are not awaited
with unbounded settling.

The portable fixture uses the existing genuine reference Display/descriptor
baseline from `test/fixtures/cncf_display_reference_v1`. New Business ACKs,
review-stage/availability transitions, revisions, held requests and failures are
explicitly controlled MockClient responses through the real Core client. They
are not new genuine producer goldens and do not prove live producer or native
execution. Existing substantive legacy specifications are preserved. Parent-owned
focused tests, analyzer, formatter checks, review and later acceptance remain to
be performed.
