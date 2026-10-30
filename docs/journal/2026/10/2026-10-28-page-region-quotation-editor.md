# Page-region quotation editor implementation

PHASE-6.5 / ESA65-02 / ESA65-02B adds the common TFAF interaction over the accepted
Core region contract. The original source, canonical geometry and append-only
revision histories remain in Core. TFAF supplies explicit source loading,
rectangle/ellipse/circle drawing, actual crop preview, recognition/adoption controls,
per-target quotation/comment drafts and one immutable domain-save input.

The readable primary route is load image, confirm area, preview, recognize, Use OCR
text, check quotation source, optionally add a spoken comment, then Save passage.
Raw recognition/provider detail and history are collapsed. Local AI remains an
explicit advanced action. Manual editing remains available when local providers are
unavailable and while OCR is in progress.

Audio composition reuses the existing common recording and transcript panels.
Original audio links remain bound to one exact selected region revision; audio
reports and corrections remain in the separate common review map. Explicit transcript
copy targets only comment text and retains the actual correction index/report id.
The original application owner must await detach and retain recoverable late audio
originals from `retainedAudioReviews` before discarding its route. No original
deletion, Book schema or domain persistence is implemented here.

The executable scenarios cover public Core frame/crop pixels, inert construction
and mounting, exact source selection, geometry revisions, manual/OCR/AI adoption,
atomic draft validation, unavailable-provider manual entry, stale/canceled results,
shared audio exact targets, late durable audio retention, viewport transforms,
owner/policy callback admission and narrow scaled layouts. They use real PNGs and
actual Core services with controlled provider ports. They do not claim native device
or interruption acceptance.

Core producer evidence reports clean analysis and 26 focused scenarios passing.
The TFAF implementation worker did not execute validation. Parent-owned focused
TFAF validation and independent integrated Step acceptance remain required, followed
by the owning Phase release gates. Existing Phase 4 SensitiveInteraction behavior
is outside this addition and remains unchanged.

Public composition and original/live ownership details are described in
[page-region quotation editor](../../../notes/page-region-quotation-editor.md).

## Shared Step acceptance

ESA65-02 completed its shared host boundary on 2026-10-28 under Editing Studio App Phase 6.5. Independent Step conformance and focused closure accepted the current common contract. Earlier implementation-stage qualifications above remain historical. Book integration, native provider/device qualification, owning full validation and complete Phase acceptance remain separate pending gates. No existing Core/TFAF Phase is reopened or closed by this delivery.
