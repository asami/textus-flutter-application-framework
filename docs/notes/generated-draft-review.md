# Generated draft review

`GeneratedDraftController` borrows the public Core `GeneratedDraftService` and
owns one owner's additive `GeneratedDraftWorkspace`. `GeneratedDraftReviewPanel`
borrows that controller and provides common image-description, text-summary,
text-proofreading and personal-annotation readability commands with explicit
accept, edit, clear and discard review. These products are
generated drafts. Original text, images, transcripts and human commentary remain
caller-owned sources; a generated draft never overwrites them.

```dart
final controller = GeneratedDraftController(
  service: service,
  ownerId: ownerId,
  initialWorkspace: retainedWorkspace,
  interactionAllowed: () => mayReview,
  sourceIsCurrent: sourceResolver.isCurrent,
  contextRevision: () => humanContextRevision,
  onWorkspaceChanged: persistForThisOwner,
);
controller.selectSource(exactSource, imageBytes: exactImageBytes);
// For an explicit text revision, choose the semantic target in the caller:
controller.selectSource(exactTextSource,
  operation: GeneratedDraftOperation.textProofreading);
// Render GeneratedDraftReviewPanel(controller: controller).
// On owner retirement: await controller.detach(); then inspect its workspace.
// When the owner no longer needs it: controller.dispose();
```

The caller chooses the exact source and supplies image bytes for an image source,
or exact text in a text source without bytes. Bytes are defensively copied and
read-only. Source metadata is generic provenance; domain validation, source
resolution and persistence belong to the caller. Source IDs must retain their
exact semantic value under Core's workspace identity contract. The caller must
advance its context revision whenever a human change invalidates an in-flight
draft, even when its selected source does not change.

`selectSource` accepts the optional named `GeneratedDraftOperation? operation`.
Omitting it or passing null retains the existing defaults: `imageDescription`
for images and `textSummary` for text. An explicit operation is admitted through
Core's public `GeneratedDraftRequest` before any selection state changes or
provider call. Image operations still require nonempty exact image bytes; text
operations require text without image bytes. A null source requires both null
bytes and null operation. Invalid combinations leave selection, operation,
generation, readiness, errors and provider activity untouched. The read-only
`controller.operation` exposes the admitted selection, or null without a source.

Text proofreading is labeled `原文の校正`; readability is labeled
`個人注釈の文章改善` and explicitly describes its rewrite as something other than
a verbatim quotation. The caller must restrict `textReadability` to personal
annotations. The shared controller/panel cannot resolve Book semantic targets,
choose eligible fields or decide whether source text is a quotation. No dropdown,
automatic generation or automatic conversion between these intentions is provided.

Construction, selection and mounting perform no service IO. Checking readiness
is explicit. Model preparation is a separate action offered for downloadable
availability; Core preserves unavailable, unsupported and preparing reasons and
guards preparation. Generation uses a fresh inference ID and the common service
with Japanese output. The provenance disclosure shows the actual operation,
provider, model, prompt and terminal diagnostics.

The controller marks work busy before notifying listeners and rechecks admission
before launching. Only one owned command may run at a time. Source changes retire
the selected generation and request cancellation of owned inference. Changing
only the operation on the same source/bytes is also a selection change: it
advances the generation, clears readiness/errors, notifies and retires owned
inference through the same cancellation/cleanup path. An equivalent source,
bytes and admitted operation is a no-op, including when the old operation was
selected by the default. Each command captures its exact admitted operation
before notifications; probe, preparation and generation retain that operation
even if listeners or later caller actions replace the selection. Probe and
preparation cannot be canceled. Cancel remains available for owned inference even
when human interaction is disabled. Busy lasts until the service finishes both
inference and cancellation cleanup. Provider failure/cancellation and cleanup
diagnostics remain terminal history with any actual raw output.

An otherwise successful late result becomes `contextChanged` cancellation when
its owner, exact source, selection generation, human context or admission has
changed. Terminal evidence remains on the original controller. `detach()` is a
terminal fence, returns the same settlement future on repeated calls and awaits
owned work. Detached/disposed owners never publish callbacks or listener events;
their local workspace remains inspectable after settlement. `dispose()` starts
detach and safely releases its private notifier, including from inside a
listener. Neither operation disposes the borrowed service.

Decisions require the exact rendered generation/context and a pending successful
attempt. Accept/edit additionally require that attempt's source to remain current;
the source need not be the presently selected source. An obsolete source can
still be discarded. Empty edited text is an intentional derived clear. Decisions
append history and preserve the original/raw generation evidence. Injected clocks
must return actual UTC times at or after completion; invalid time fails explicitly.

Every proposal and adopted result is labeled from its own attempt's operation,
independently of the current selection. A still-current proofreading proposal
can be adopted after readability or another source is selected, using fresh
render authority. Selecting another intention never relabels retained history.

Proofreading/readability review shows exact original and unedited raw proposal.
Adopted review also shows the selected adopted text, including an explicit empty
edit. Both use public Core `TextRevisionComparison.between` to inspect the exact
original against the pending proposal or selected adopted whole text. The panel
labels unchanged boundaries, removed/replaced original text and inserted proposed
text; equal strings explicitly say `変更なし`. Whitespace, newlines and Unicode
remain exact. This is one inspection window, with whole-text adoption; it promises
neither minimal differences nor individually selectable hunks. Existing image and
summary routes keep their labels, action keys and uncluttered presentation.

Stale source/context results retain their actual raw output. The panel explains
that changed current text/context requires regenerating from current text and
reviewing, or manually reconciling content. Canceled output cannot be adopted;
obsolete pending source evidence permits discard while accept/edit remain disabled.
Caller `sourceIsCurrent` and `contextRevision` guards must reflect concurrent human
edits. The generic panel never applies text to or overwrites caller-owned sources.

The panel subscribes to the current controller without owning its lifecycle.
Retained button closures and edit dialogs capture the original controller, owner,
render epoch, selection generation and context. Replacement or live-policy changes
cannot redirect those actions to another owner. Readiness and terminal evidence
are visible while unrelated manual input remains available. Adopted derived text
is displayed separately, including an explicit clear; discarded history is counted.

Each edit-dialog opening also captures its exact Flutter route. Both Adopt and
Cancel require that opening's context to remain mounted and its captured route to
remain active and current before popping through that route's own navigator.
A canceled dialog can remain mounted during its reverse transition; its retained
buttons cannot close a newer edit dialog or an unrelated covering route, or submit
its old text as the newer dialog's result. Existing controller/source/context
checks still apply after the owned result, and an empty edited result still means
an explicit derived clear.

The `CPB-ESA67-FULL-001` regression scenarios use real Flutter routes and the real
controller/service with an explicit host fake provider. They cancel edit A, drain
its result without advancing reverse-animation time, open edit B while A remains
mounted and replay A's retained Adopt or Cancel. Direct and unrelated-cover
variants assert exact route authority, unchanged B text and pending workspace,
then physically adopt B and assert only B's own edit is recorded while both raw
attempts and sources survive. These are authored regression cases; execution and
independent closure remain parent-owned.

Publication stores local history before invoking the original owner's synchronous
callback. A callback error is exposed on the controller and in the panel without
claiming that data was saved. Local raw evidence remains available for caller
recovery. Reentrant publication/selection is rejected. Native Flutter executable
specifications connect the real Core service to controlled fake providers; they
describe common lifecycle and review behavior and make no native-model quality
claim.
