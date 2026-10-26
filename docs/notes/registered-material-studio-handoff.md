# Registered material Studio handoff

`SubmissionFacade.supportsRegisteredMaterialHandoff` advertises the borrowed
Core capability. Missing capability rejects typed commands explicitly. The
common status page remains passive on mount, selection and refresh.

Consumers supply optional `handoffRegisteredMaterial` and
`reconcileRegisteredMaterial` callbacks. The binding reserves their work before
reading fresh source status, shares single-flight with ordinary actions and
joins accepted callbacks on detach. Consumers must also fence their own domain
awaits when their owner retires. Neither binding nor page closes Core.

The initial action requires a saved Registered source with no handoff. Failed,
unknown or expired sending observations offer explicit reconciliation with a
warning that the same request can be submitted if not previously received.
Pending observations offer `Resume queued Studio handoff` through the existing
reconciliation callback. This explicitly wakes the unchanged saved pending
intent, packet and frozen target. The page retains this presented intent and
rejects a fresh nonpending observation before invoking the caller, then refreshes
the current selected detail to show its actual warning. A callback receiving
pending must use Core's safe idempotent enqueue with the saved target, rather
than generic uncertainty reconciliation, including across its own awaits;
queued guidance does not describe uncertain
POST replay. Mount, query and duplicate creation never wake it. Active sending
has no action. Accepted observations show
only the actual Core ACK and server ID. The source TKL transport and frozen
Studio target are displayed separately. Summary totals still count the source
once; registration, scheduling and stored originals do not count as Studio ACK.

After an explicit action the current page refreshes once through its view model.
Scheduling failure reports queued intent needing attention, without claiming
acceptance. Selection, replacement and retirement fence dispatch and UI results.
Zero-original sources make no claim about original access or physical storage.
