# Common formal Display Editor

PHASE-5 / ESA5-03, initial implementation contract.

`CncfDisplayResourceView` composes the existing `ResourceListDetail` with the
same configuration, View Model and optional borrowed display model. The common
framework owns Edit, modal form, Save, discard confirmation, receipt and safe
Reload presentation. The App owns trusted profile selection, composition and
disposal; it supplies no CRUD handler. Core owns descriptor and wire admission,
authenticated commands, exact observed revision, receipt and structured failure
taxonomy. The producer remains the domain validator. The prototype is separate.

`CncfDisplayMutationController` requires the identical source borrowed by its
View Model. It borrows source, client and View Model, starts idle, and never
disposes any of them. Public observable state consists of `busy`, `editorOpen`,
`canSave`, `needsReconciliation`, `descriptor`, `observation`, `draftValues`,
`initialValues`, `receipt`, `failure`, `fieldErrors` and `isDisposed`. Failure is
the redacted Core exception with optional admitted structured failure. Collections
are immutable snapshots; draft edits copy on write. Listener reentrancy cannot
start another activity. Disposal retires asynchronous publication and never
claims to roll back a dispatched command.

Edit pushes a framework-private modal route immediately and schedules its single
`beginEdit` after the first route frame. The existing List/Detail stays mounted
with its layout, chrome and selection. The controller synchronously captures a
ready formal `source.lastDetail` matching selected identity before its first
await. Descriptor completion must still match that exact observation/selection.
Fields match complete `(sectionId, fieldId)` identities against read sections,
never flattened `ResourceRecord` keys. Producer order and read labels survive.
Both supported update capability and enabled update availability are necessary.
Only bound editable accepted Text with all hidden/system/readonly/multiple flags
false becomes an input. Missing and unsupported values cannot be coerced. Other
fields remain readable. Required, placeholder, help and raw descriptor hints
remain producer metadata; no pattern or hint authorizes a command.

`setText` retains exact String code units without trimming or normalization and
clears only the matching field error. Save emits changed inputs in descriptor
order. Equal drafts emit all writable inputs once so the producer decides
unchanged. Core receives the captured descriptor and formal observation;
`ResourceRecord.revision` has no mutation meaning. Busy state is established
before awaiting transport; concurrent actions and Text edits are blocked.

The admitted receipt is retained and notified **before** any read refresh.
Ready receipts trigger at most one sequential explicit Detail refresh followed
by List load. Both base View flags and newly obtained formal source observations
must show the exact selected ID, matching List/Detail revision and a revision at
least the receipt floor. An old retained observation or successful transport
alone cannot establish coherence. Coherence closes the accepted editor while
retaining its receipt. Failed reads preserve receipt and reconciliation state.

Pending receipts require explicit Reload and disable Save. Unknown delivery,
malformed result, timeout, unclassified failure and structured conflict retire
the original draft and require reconciliation. Conflict comes from Core taxonomy,
not HTTP status. The exact Core editable rejection alone permits correction;
its approved diagnostic maps only to its matching scoped field. The UI renders
fixed local text and the approved code, never raw Conclusion prose.

Reload performs safe Detail then List reads, never update. Unknown/conflict
coherence uses at least the original observation floor; receipt coherence uses
its receipt floor. Reconciled unknown/rejected drafts remain pinned and disabled
until explicit discard followed by a fresh Edit. A coherent pending receipt clears
its accepted draft. Discard cannot erase receipt or pending/unknown reconciliation
obligation. Common Detail retains receipt and safe Reload after modal closure,
including a failed Detail diagnostic.

For an active Editor, Back/Cancel is blocked while busy. Idle dirty drafts require
an explicit discard decision; declining keeps exact Text. Only the current modal
route may pop after save/reload/discard. Route controllers are owned/disposed by
that route; framework views detach listeners when replaced or removed and do not
dispose borrowed owners. Retired opener sessions and disposed controllers ignore
late UI business futures.

Replacing the opener's controller/View Model or removing the opener retires its
private route reference and schedules one post-frame presentation rebuild if the
route is still active. This does not pop a route, cancel transport or dispose any
borrowed owner, and does not depend on an old busy controller notifying. The
retired presentation suppresses its loading ticker and disables Save, Reload and
inputs while enabling Cancel. Once that retired Editor is current, explicit
Back/Cancel closes only its own route, even with retained busy state, without
discarding or invoking either the old or replacement controller. An unrelated
current route survives old completion; returning from it exposes the dismissible
retired Editor. A disposed controller likewise permits explicit current-route
Back without a terminal controller notification. These route-dismissal rules do
not change the active Editor's busy protection or dirty-draft decision.

Stable keys are `cncf-display-edit`, `cncf-display-editor`, `cncf-display-save`,
`cncf-display-cancel`, `cncf-display-reload`, and the scoped TextField
`ValueKey(('cncf-display-field', sectionId, fieldId))`.

Executable specifications use the public controller and actual common Widget,
real Core client, and portable copied producer goldens. Controlled MockClient
responses derive updates, failures, revisions and timing from those baselines.
They are local controlled evidence, not native runtime or producer validation.
Validation, review and Step transition belong to the parent workflow.
