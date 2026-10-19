# Resource List/Detail lifecycle repair delivery

Recorded: 2026-10-08. Owner: TFAF maintainer, coordinated by App parent /root.
Identity: App PHASE-6 / ESA6-05 / ESA6-05C pre-review validation repair.
Status: authoring complete; parent revalidation and independent acceptance pending.
Update rule: append attributable executed validation/review evidence separately;
retain this factual authoring record and the App's earlier ESA6-05 A+B history.

The parent supplied F-ESA6-05C-BUILD-NOTIFY-001: ResourceListDetail's synchronous
initState/didUpdateWidget load notified already mounted borrowers during sibling
build. Actual App N2/N3/N6/N7 and consumer failures exhibited build-phase setState
errors. The settled repair changes only widget-owned automatic scheduling;
semantic collection/detail ownership, notification and started-operation
completion remain in their existing owners.

The source now reserves automatic reads in post-frame callbacks with a captured
ResourceViewModel, private increasing generation and mounted/identity checks.
Replacement supersedes old reservations; disposal invalidates them before
listener detachment. Same-model rebuilds reserve no read. Explicit Refresh is
immediate. External models/displays remain borrowed. Existing same-file
control-flow bodies use braces without changing their semantic behavior.

## Authored paths and regression evidence

| TFAF path | Authored change |
| --- | --- |
| lib/src/widgets/resource_list_detail.dart | Automatic scheduling, attachment generation cancellation and dispose invalidation; mechanically braced existing control-flow bodies |
| test/resource_list_detail_lifecycle_test.dart | L1 shared sibling/post-frame source entry; L2 same-model/explicit Refresh; L3 replacement/detached owner reuse; L4 removal and A-to-B replacement before frame; L5 actual held read after unmount; L6 actual empty/failure and explicit recovery |
| docs/notes/resource-list-detail-lifecycle.md | Decided common scheduling and borrowed lifetime contract, public scenario map and pending acceptance |
| docs/journal/2026/10/2026-10-08-resource-list-detail-lifecycle.md | This factual delivery history |

Eight widget scenarios use genuine adjacent Given/When/Then clauses and public
expect assertions. The source fixture records actual schedulerPhase/read entry,
exact ResourceRecord IDs and finite held entry/release/completion. Pre-frame
cases use public attachRootWidget/buildOwner.buildScope/rootElement/finalizeTree
with a localized Directionality/MediaQuery/Theme root. Teardown releases
operations, unmounts widgets and observes settlement before fixture-owner
disposal. No private State assertions or source-text/management assertions are
used as behavior evidence.

## Supplied failed history and pending gates

The parent supplied initial App representative 19 passed / 7 failed, App
17-suite accumulator 155 passed / 27 failed, and default App analysis with
25 info diagnostics; each validation exited 1. All three previously executed
repository diff checks exited 0. These are initial failed checks, not acceptance
or evidence that the newly authored lifecycle repair passes.

No test, analyzer, runtime, server, device operation, Git mutation, commit,
publication or Phase transition was performed by this repair editor. The parent
owns new lifecycle validation, affected common suites/default analysis, App
representative/accumulator/default analysis, diff/mechanical inspection and a
fresh independent complete ESA6-05 conformance review. Full software validation
and physical/native Settings write/restore prerequisites remain pending.

This is an App Phase dependency delivery and does not close a TFAF project Phase.
No new separate Hygiene or Development Candidate record is admitted here.
