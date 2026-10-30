# Common local material retrieval UI

`CaptureStorageFacade.createMaterialRetrievalService(corpus:, corpusId:)`
creates a fresh `LocalMaterialRetrievalService` with the facade's exact existing
capture store. Construction performs no IO or provider/device initialization.
The application supplies current source authority through Core's corpus port
and closes the returned service. Closing it leaves capture storage borrowed.
Core owns lexical matching, source reconciliation, strict derived-index schema,
durability, source availability and explicit rebuilding.

`MaterialRetrievalController(service:)` borrows that service. Construction and
`setQuery` are inert with respect to retrieval IO. Query text is retained exactly;
explicit `search()` invokes Core's bounded query validation. The default lexical
provider uses literal Japanese and normalized fullwidth ASCII, with all terms
required within one source. No semantic retrieval, model rewriting or query
assistance is implied. Actual capability and result counts come from Core.

The observable controller status is idle, loading, ready, empty, resolving,
rebuilding, canceled, unavailable or error. `error` retains the original failure
for callers; there is no cached-success fallback. `rebuildCompleted` is a notice
that an explicit rebuild succeeded. Rebuild clears prior evidence and requires
another explicit Search; it never silently runs on mount or error display.

One controller reserves one command at a time. Input changes and Cancel retire
only its own cancellation token. `busy` remains true until the original future
settles, including borrowed IO cleanup; cancellation does not claim IO was
interrupted. Query input remains editable while busy. Listener and public-service
callback boundaries recheck the original reservation before work or publication.
Ordinary repaint does not retire a command. `detach()` synchronously retires
the owner and joins only its original pending command; `close()` aliases it.
`dispose()` also retires immediately, observes that cleanup and defers notifier
disposal until any active notification stack unwinds. Neither closes the service,
store or corpus.

Only an identical hit within the current result and query can resolve.
`resultVersion` is an opaque rendered evidence/action admission generation. It
advances at every command reservation, including resolve, as well as when
evidence is invalidated. A resolve retains its own captured admission generation;
a successor reservation invalidates that original admission even on the same hit.
An available
resolution grants only the exact equal source document, including its address.
Stale or unavailable resolution disables all old result openings. Unavailable
includes denied access and clears old result text. Retained stale snippets
are explicitly labeled search-time reference information; replacement
content is never automatically opened. A fresh Search is required to restore
opening permission. The application must check current domain/report/media and
region links again immediately before actual navigation because source authority
can change after resolution.

`MaterialRetrievalPanel(controller:, onOpen:, interactionAllowed:)` borrows its
controller and renders the Japanese query field, explicit Search, Cancel and
Rebuild controls. It displays exact selectable snippets, title/source label,
Core scalar omission indicators and truthful counts/has-more information.
Errors are friendly and do not display raw filesystem paths or opaque error IDs.
Controller errors remain inspectable separately.

Rendered actions retain controller, query, result/version, callback, policy,
widget lifetime and initiating route witnesses. They recheck current ownership
and the pure interaction policy before commands and before navigation after
resolution. False, throwing or reentrant policies deny stale authority. Covered,
popped, removed or replaced owners cannot navigate. An isolated host with no
ModalRoute is allowed. A legitimate `onOpen` may push a route and await its return;
the panel does not retire that callback merely because its own navigation covers
the panel. Callback failures are observed and displayed only by their still-current
widget owner. Controller replacement removes only the old widget listener and
adopts the new query buffer; it never disposes a borrowed controller. Ordinary
updates preserve the text buffer and cursor. Panel disposal removes its listener
and buffer and observes pending callback errors.

The panel owns only retrieval interaction. It never saves, commits, discards or
adopts the application's pending manual editor content. App corpus composition,
navigation integration and an immediate final source check belong to Phase 6.9 S2.

Executable specifications are in `test/retrieval/material_retrieval_controller_test.dart`
and `test/widgets/material_retrieval_panel_test.dart`. Controller integration uses
actual Core/FileCaptureStore and gated current corpus ports; widget integration
uses `tester.runAsync` for actual file IO. Controlled typed widget services qualify
painted UI/lifecycle behavior only. Parent-owned analysis, execution, independent
review and acceptance remain pending after this authoring slice.

ESA69-S1 received independent protected-focused acceptance and focused repair closure on 2026-10-31 JST. The synchronous successor/retained Cancel case is covered by real Core/FileStore and widget specifications. All253 focused TFAF checks and analysis passed; local Step commits are next. App source wiring and final Phase gates above remain pending.
