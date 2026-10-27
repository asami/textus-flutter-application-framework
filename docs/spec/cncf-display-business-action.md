# Common ordinary Business action — ESA5-06

Status: ESA5-06 accepted after TFAF129/App18 focused tests and independent
protected Step conformance review on 2026-10-27. Step 6 adds immediate client reload
in the common Widget after a successful ordinary ACK. Step 7 actual context,
full/native validation and release gates remain pending.

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
Core and the controller remain ACK-only. The common Widget awaits that command
completion, checks that its mounted session, controller and View Model are still
current and that the controller is not disposed, then explicitly awaits the
existing controller Reload. That client-initiated Detail/read followed by
List/query updates fields and stage without a second user tap. The ordinary
response itself is never treated as Display and no command is replayed.

Known ACKs require reconciliation; failed, stale or incoherent reads retain the
ACK and block commands. Reload uses only safe Detail/query reads for the captured
resource. A different selected ID causes no I/O and preserves the observation.
Selection changed during a read cannot fabricate closure or overwrite a different
selected Resource. Explicitly selecting the affected Resource and choosing Reload
can recover. Failed automatic reads leave the same manual Reload recovery
available. Both fresh formal projections must be nonfailed, nonloading, identify
the actual selected Resource, have matching revisions, and reach the BigInt floor
from the current Business ACK. Unknown commands without ACK use the formal
observation floor. They can resolve through safe reads, with no automatic replay;
a later enabled explicit intent can execute again. Unknown, conflicting and
malformed ordinary responses do not trigger automatic reads because they do not
produce a successful ACK. Reload retains its existing exclusive busy owner,
generation, identity and revision-floor checks; a competing Reload cannot start
duplicate reads while another Reload owns that controller.

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
The stable key is `cncf-display-business-<actionId>`. A small private common
callback captures the controller and binding, verifies current controller/View
Model identity before dispatch, then awaits the ACK and explicit reconciliation.
No public API, constructor flag or alternate mode is added. No App action handler, domain field mapping or raw
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
rebuilds its current layout and retires the opener session. A captured callback
from a replaced controller cannot dispatch. After ACK, a retired session or
disposed controller cannot start follow-up reads. A selection mismatch is rejected
by the existing Reload selection guard without I/O. Disposal retires publication
and marks in-flight delivery unknown,
without disposing borrowed owners or claiming command cancellation.

Disposal emits no notifier. An explicit Back attempt on the current disposed busy
route refreshes stale UI and pops only when its Navigator can pop. A root remains
visible; a pushed route may leave; an unrelated current route cannot be forcibly
popped by old work. The existing retired Editor escape remains preserved.

## Dated Step 5 contract history — 2026-10-27

ESA5-05 defined the manual Reload boundary: the controller stored and notified an
ordinary ACK without automatic reads, and the common Widget left the old Display
visible until the user chose Reload. ESA5-06 preserves that ACK-only Core and
controller contract and adds the current Widget's explicit post-ACK read/query.
The earlier boundary is historical; current successful common Business clicks
do not require a second user tap.

## Executable specification and evidence provenance

`test/display/cncf_display_business_controller_test.dart` authors trust/default
compatibility, availability, actual Core POST and captured formal observation,
withheld/reentrant ownership, ACK notification before safe GET, explicit coherent
Reload, failure/stale/mismatch retention, exact BigInt floors, mutation2/Business3
history, unknown/conflict/malformed responses, selection change/recovery, and
borrowed-owner disposal scenarios.

`test/display/cncf_display_business_resource_view_test.dart` authors actual common
widget clicks at widths 400 and 1000, busy pointer/Back protection, known ACK
notification before a held automatic read, Japanese review stage and hidden
action after automatic reconciliation without another tap, retained
ResourceListDetail/layout identity, label/allowlist/availability intersections,
Business3 after mutation2 with failed automatic Detail and manual recovery, fixed failure messages, captured
selection guidance, replacement/removal under unrelated routes, and finite
root/pushed disposed-busy escape. Given/When/Then comments accompany expectation
boundaries. Finite gates are explicitly released; held spinners are not awaited
with unbounded settling.

`test/display/cncf_display_business_reload_test.dart` authors three actual common
Widget scenarios: ACK publication before GET with a competing captured callback,
selection changed during a held automatic Detail read with no following query
and explicit affected-resource/manual-Reload recovery; controller retirement
directly from the test outside all notifier callbacks after the held automatic
Detail/read has actually entered its GET gate. Releasing that borrowed read after
retirement waits for Detail loading to finish, preserves the known ACK and
prevents a following query, further I/O or navigation; borrowed read owners
survive unmount. The third scenario rejects
a captured old button callback after replacement has
completed `didUpdateWidget`. These exercise the existing public view and genuine
Core transport fixture rather than source-shape or metadata-only assertions.

The portable fixture uses the existing genuine reference Display/descriptor
baseline from `test/fixtures/cncf_display_reference_v1`. New Business ACKs,
review-stage/availability transitions, revisions, held requests and failures are
explicitly controlled MockClient responses through the real Core client. They
are not new genuine producer goldens and do not prove live producer or native
execution. Existing substantive legacy specifications are preserved. Parent-owned
focused tests, analyzer, formatter checks, review and later acceptance remain to
be performed.
