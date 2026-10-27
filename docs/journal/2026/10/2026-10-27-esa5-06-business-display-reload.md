# ESA5-06: common Business ACK followed by explicit Display reload

Date: 2026-10-27

Authored under the existing Phase 5 / ESA5-06 authority. This entry records
implementation and executable-specification authoring only; it claims no
validation, review, acceptance, live producer or native execution result.

The common `CncfDisplayResourceView` now handles a trusted Business button with a
small private asynchronous callback. It checks the captured controller and its
View Model against the current mounted Widget before invocation, captures the
opener session, and awaits the existing ACK-only `executeBusiness`. Only a
successful ACK on that same mounted session, controller and View Model, with a
live controller, proceeds to the existing explicit `reload`. Core, controller
public APIs and App declarations are unchanged.

The controller continues to store and notify the ordinary ACK before any
automatic Detail/read and List/query. Successful current common UI intent needs
no second tap. Busy ownership, selection identity, generation and BigInt revision
floor remain owned by Reload. Failed or incoherent reads keep the known ACK and
manual recovery, and unknown/conflicting/malformed commands do not start
automatic reads. Reload never replays the POST.

The existing common Widget matrix is authored for held POST followed by held
automatic read at compact and wide widths, exact GET/GET/POST/GET/GET transport,
borrowed layout/State preservation, blank/Missing title fallback, and Business
revision 3 after standard mutation revision 2 with automatic-read failure and
manual recovery. Existing authority, failure, selection and retired-route cases
remain within the same scope.

The dedicated reload specification authors ACK-before-GET notification ordering,
stale callback competition during automatic read, selection change during that
read followed by explicit manual recovery, and rejection of a callback captured
before controller replacement. A further case awaits actual GET gate entry for
the held automatic Detail/read, then disposes the controller directly from the
test outside all notifier callbacks. Retirement therefore occurs during an
already-entered read without assuming ACK microtask precedence. Releasing the
borrowed read after retirement waits for Detail loading to finish and checks
known receipt preservation and absence of a following query, further I/O or
navigation, plus borrowed-owner survival after unmount. All held gates have
teardown release and held progress uses a finite
pump budget derived from the public client timeout plus 500ms.

ESA5-05's manual Widget Reload behavior remains dated history in the product
specification. Parent-owned focused validation, analysis, formatting checks,
protected Step review and local acceptance commits are still outstanding.
ESA5-07 actual context, native/full validation, Phase full review and release
work remain explicitly outstanding.

## Parent acceptance — 2026-10-27

Current TFAF129 (eight files) and App18 (four files) passed; analysis of the four
current target programs, formatting and exact-path static checks passed. One
independent GPT-6.1 Sol high protected Step review accepted all nine paths/four
programs with no blockers and no new Hygiene/Development Candidates. The
production change is confined to the common Widget: await ordinary ACK, retain
it, check current owner/session, then invoke existing safe reload. Core,
controller, App production APIs and producer remain unchanged.

Earlier new-test scheduling failures remain in local history. The final
retirement test waits for actual GET entry, disposes outside notifier callbacks
and observes borrowed Detail completion without a following query or navigation.
It does not assume ACK microtask precedence or require cancellation of borrowed
Core reads. The bounded selection test waits within the published client timeout
plus a finite margin and retains terminal, identity and recovery assertions.

ESA5-06 is accepted for exact local Step commits. ESA5-07 actual supplied-context
realization, native update/Business roundtrip, owning full validations, the sole
comprehensive Phase review and final release remain open. Original authority,
bases, epoch and prior repair history are preserved. No push, cloud operation,
publication or deployment is implied.
