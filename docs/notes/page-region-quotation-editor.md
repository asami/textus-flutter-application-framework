# Page-region quotation editor

`ImageRegionEditorController` and `ImageRegionEditorPanel` provide a reusable,
explicit image-area quotation and comment interaction. Core owns canonical image
decoding, crop/mask generation, stored PNG derivations, recognition and immutable
region history. TFAF owns transient selection, text drafts and interaction lifetime.
The application owns the original image, shared capture store, domain persistence
and the separate map of audio reviews.

## Composition

Compose one controller for one exact original. Its constructor and the panel's
mount are inert. The user explicitly loads the source, draws and confirms an area,
previews its actual stored crop, and requests recognition. No provider, model,
microphone or storage read starts in a constructor, drawing callback or build.

```dart
final regions = await openDefaultImageRegionFacade(store: sharedCaptureStore);
final editor = ImageRegionEditorController(
  facade: regions,
  source: originalImage,
  initialWorkspace: savedRegionWorkspace,
  initialAudioReviews: savedAudioReviews,
  audioFacade: sharedAudioFacade,
);

ImageRegionEditorPanel(
  controller: editor,
  interactionAllowed: () => originalBookOwnerIsLive,
  onChanged: (change) {
    // Immutable adopted workspace plus separate audio reviews; not a file save.
    showDomainDraft(change);
  },
  onSave: (change) async {
    // The application atomically persists these together under the original Book.
    await saveBookPassage(change.workspace, change.audioReviews);
  },
);
```

The application supplies its own functions in this example. TFAF does not define
a Book schema, file transaction, route, capture-store ownership or save adapter.
The public facade exactly forwards Core's load, derive, read, recognize,
availability and preparation APIs. It never disposes borrowed services.

## Geometry and history

The canonical upright Core frame is both the displayed image and the selection
coordinate system. Rectangle and ellipse masks use normalized source geometry.
The circle tool chooses equal axes in raster pixels, which generally means
different normalized width and height for a non-square image. Core saves the
derived PNG and its exact provenance; the preview reads those actual saved bytes.
Ellipse pixels outside the selected mask are white according to Core's algorithm.

`ImageRegionSelector` uses explicit Select area and Move image modes. Its bounded
zoom and pan belong only to the viewport. Each drawing point passes through
`TransformationController.toScene` once, then through contain-offset normalization.
Letterbox starts and zero-area gestures are ignored, while endpoints are clamped.
Reopening or resizing a viewport never changes retained source geometry.

Confirming changed geometry appends the next revision of that stable region.
Starting another area allocates another region identity. Neither action relabels
old quotations, comments, extractions or audio. Other exact originals in a restored
workspace are preserved but cannot be selected by this source's editor.
Quotation and comment buffers are separate for every exact region/revision,
including Unicode, whitespace and intentional empty clears. Switching areas keeps
unsaved buffers. Save passage validates all dirty buffers before adopting any text
revision; one missing quotation source check prevents partial text adoption.

The pure `hasUnsavedText` getter inspects dirty quotation/comment buffers across
all existing region targets, including exact empty clears. `hasUnconfirmedSelection`
reports a drawn area that differs from its confirmed snapshot or has no confirmed
snapshot yet. `hasPendingInput` combines those states with owned work, a dirty
common transcript, an original awaiting durable import, and actual child/retained
audio reviews not yet represented by equal published reviews. Reading these flags
creates no buffers and starts no IO, provider work or notifications. The caller
can use them for save/back navigation and inspect retained pending reviews after
detach for the initiating original owner.

## Recognition and human adoption

Recognize selected area requests standard local OCR only. It stores and displays
raw output without replacing a dirty manual editor. Use OCR text is a separate
action that prefills the quotation editor and preserves its extraction source
association through manual correction. The human source-check checkbox is required
before recording a quotation, including manually entered text.

Local AI is an explicit secondary action under Advanced. It is never prepared or
invoked implicitly. Only actual executed interpretation/candidate output can be
selected; selection still requires a subsequent human source check. Interpretation
and summary output do not silently become quotations. Raw inputs, provider state,
fallbacks, reports and histories remain available in collapsed details. Provider
unavailability leaves manual quotation and comment editing usable. Check availability
and Prepare are separate explicit operations, with no remote fallback added here.

Only one region service command is admitted at a time. Geometry selection and
manual text remain usable during OCR. Cancel pending result retires adoption but
does not claim provider cancellation: the actual command must settle before another
service command is admitted. Actual durable derivations and reports are inspectable
through `retainedDerivations` and `retainedExtractions` even if selection retirement
prevents workspace adoption. Failed commands expose their real error and release
busy state.

## Spoken comments and original retention

Add spoken comment explicitly opens an existing `AudioCaptureController` for the
captured immutable region snapshot. `AudioCapturePanel` and `TranscriptReviewPanel`
remain the authoritative recording, playback, transcription and correction controls.
Opening the controls does not record or prepare anything. Existing linked originals
can be reopened from the same workspace/review map. Owned recording, durable save,
playback and transcription prevent region switching until their operation settles.

If Stop cannot import its original, the initiating child and immutable region
target stay in place while the existing common Retry save recovers the same bytes.
Pending import prevents selection, geometry changes and audio-child replacement.
`ownsPendingAudio` is a pure read that requires this exact child's observed
successful local recording and the identity of its retained pending original;
shared service state alone does not establish ownership. Common audio commands
deny a foreign pending original, including Retry on an idle child opened by another
borrower before the failure. Opening audio rejects preexisting pending bytes.
A fresh editor without an audio target can still use its manual region/text route.
Terminal retirement clears local capture ownership without deleting borrowed
pending bytes; a new source owner cannot infer their target or claim recovery.

An audio original is linked once to one exact region revision. Subsequent reports
and corrections update only that original's separate append-only review map.
`ImageRegionEditorChange` transfers the workspace and reviews together without
duplicating audio bytes or reports inside the workspace. Common-panel callbacks
capture their controller, common child and immutable target; a retired callback
cannot rebind an original to a replacement area or route owner. New commands and
text edits always recheck the current caller policy. Already accepted audio work
settles to the same live controller, child and selected source-bound target even
when that policy temporarily denies new input or regional result admission changes.
An actual immutable adoption still reaches `onChanged` for its same mounted live
owner; settlement starts no additional provider command.

Use transcript as comment explicitly copies text into the independent comment
buffer. A dirty common transcript is first recorded as a common correction, and
the comment retains its actual correction index (or successful report identity).
The quotation editor is unaffected. Further manual comment edits preserve this
source association and never rewrite raw transcripts.
Copy captures its generation, selected snapshot, common child and audio target.
After recording a dirty correction and again after publishing its review, it
rechecks that exact live ownership before resolving or editing the captured
target's comment draft. Synchronous navigation, detach or child replacement stops
the copy with the existing ownership error while retaining the actual correction
or adopted review. No transcript or provenance is copied into a replacement or
terminal text buffer.

Live region navigation and audio-child replacement first retain an idle child's
dirty transcript through the common correction API under its original audio and
region target. Reopening that original uses the updated review. This preserves
typed whitespace and clears without committing unrelated quotation/comment drafts
or copying transcript text into either field. Full Save likewise retains a dirty
common correction together with the prepared region text after all quotation
source checks pass.

Before retiring the route, await `editor.detach()`. It terminally fences result
adoption, settles admitted region operations and awaits the owned audio child's
detach. A durable audio stop that actually completes during retirement is retained
in `editor.retainedAudioReviews`, even when it was too late to create a region
link. The original application owner must inspect and retain these reviews under
the original Book before discarding the route, including when detach reports an
actual cleanup failure. No review is published to a replacement owner and no
original is deleted. Finally call `editor.dispose()` to release listener resources.
The editor never disposes borrowed facades, services or the shared capture store.
Terminal cleanup also records an already-entered idle dirty transcript before
detaching its child and retains the resulting actual review for original-owner
handoff. It publishes no region change to the retired route. If active audio work
prevents safe correction, cleanup keeps the existing actual settlement and review
retention behavior without inventing text or provider results.

## Qualification boundary

The Core producer supplied clean analysis and 26 passing focused Core region
scenarios. TFAF scenarios are authored with real PNG fixtures, actual public Core
services and controlled provider ports. TFAF validation, integrated Step acceptance,
owning Phase full suites and native lifecycle qualification remain separate parent
gates. An in-memory fixture does not prove native microphone interruption or device
behavior. Existing Phase 4 SensitiveInteraction controls and policy remain unchanged.

## Shared Step acceptance

ESA65-02 completed its shared host boundary on 2026-10-28 under Editing Studio App Phase 6.5. Independent Step conformance and focused closure accepted the current common contract. Earlier implementation-stage qualifications above remain historical. Book integration, native provider/device qualification, owning full validation and complete Phase acceptance remain separate pending gates. No existing Core/TFAF Phase is reopened or closed by this delivery.
