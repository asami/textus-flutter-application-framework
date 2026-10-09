# Resource List/Detail automatic reads and borrowed lifetime

Recorded: 2026-10-08. Owner: TFAF maintainer, coordinated by the App PHASE-6 parent.
Status: authoring complete; parent validation and independent acceptance pending.
Update rule: update this note with the decided common lifecycle contract and its
public executable scenarios; append actual validation and acceptance separately
in the [delivery journal](../journal/2026/10/2026-10-08-resource-list-detail-lifecycle.md).

## Automatic scheduling

Each mounted ResourceListDetail presentation initiates exactly one automatic
collection read per ResourceViewModel attachment. The reservation is made on
initial attachment and on replacement with a different model. An ordinary
same-model rebuild does not reserve another read. Existing data in a shared
collection does not suppress a new presentation's automatic read.

The read starts in a WidgetsBinding post-frame callback. A private increasing
generation and the captured model identity require that the presentation is
still mounted and that its attachment remains current. Replacement supersedes
the previous reservation; disposal invalidates reservations before listeners
detach. Removal before the callback starts no read. Replacing A with B before
the callback starts only B's read.

Collection loading immediately notifies its observers under the existing
semantic API. Scheduling the widget's automatic read after the build frame lets
already mounted sibling presentations observe that read without build-phase
setState errors. The collection/detail source and notification semantics remain
owned by their existing semantic models.

Explicit caller Refresh actions and public reads start immediately through
their existing APIs. Their errors, selected-read generations and retry policies
remain in their semantic owners. Empty results and failed reads remain distinct;
an ordinary rebuild retries neither. A successful explicit Refresh can recover
actual source data.

## Started operations and ownership

Once a read starts, its semantic owner owns completion. Widget removal does not
cancel a started service operation. Detaching listeners and mounted publication
guards prevent a removed presentation from receiving late UI updates or being
resurrected. Externally owned ResourceViewModels and supplied display models are
borrowed; ResourceListDetail never disposes them. Its internally created display
model retains its existing widget-owned disposal.

Separate presentation adapters may borrow the exact same root collection/detail
through ResourceViewModel.fromViews. Their adapter and display identities stay
distinct while resource results and semantic selection remain shared. Replacing
one presentation's model detaches observation of the old model and leaves both
externally owned models usable. Layout, configured detail, actions and selection
retain their existing public behavior.

## Authored public executable scenarios

[resource_list_detail_lifecycle_test.dart](../../test/resource_list_detail_lifecycle_test.dart)
uses public package imports, Flutter binding/scheduler APIs and actual source
operations, with adjacent Given/When/Then clauses and expect assertions.

| Group | Authored observable evidence |
| --- | --- |
| L1 | A mounted sibling and a newly mounted borrower share exact root views; actual source entry occurs in postFrameCallbacks; exact results, separate adapters/displays and no Flutter exception |
| L2 | Same-model reconstruction reads once; the actual explicit Refresh reads once more immediately; configured selected detail remains exact |
| L3 | Same keyed State attaches B, reads B once and stops observing A; A remains usable without rebuilding B or replacing B's selection |
| L4 | Public binding build/update/finalize operations before frame drawing remove a reservation without reading, or replace A with B and read only B |
| L5 | Actual held source entry, removal, release and completion leave root results and owners usable for a further explicit read without UI resurrection |
| L6 | Actual held empty and failed outcomes remain distinct; ordinary reconstruction does not retry; actual Refresh recovers source IDs and configured detail |

Held operations have finite release/completion gates and operation ceilings.
Fixture teardown releases held work, unmounts widgets, observes read settlement,
then disposes only fixture-owned semantic and display models.

This common dependency delivery belongs to App PHASE-6 / ESA6-05C. Authoring does
not close a TFAF project Phase or supply software/physical acceptance. Parent
selected validation, complete-Step independent conformance, upstream full
validation and the App's physical/native prerequisites remain pending.
