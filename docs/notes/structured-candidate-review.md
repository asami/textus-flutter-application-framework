# Structured candidate review

`StructuredCandidateReviewPanel` consumes the public Core workspace and takes
application field labels/current values and an explicit decision callback. It
owns compact field cards, conflict visibility, source-span disclosure and
accept/edit/discard controls. Edited empty text is an intentional clear.

The parent owns domain validation, atomic decision/value persistence and durable
source resolution. Display and source disclosure never select a value. The live
interaction policy is checked on action; owner replacement during an edit cannot
publish the old dialog into the replacement. Source disclosure includes exact
OCR report/attempt or transcript revision, and a region revision when present.

The initial consumer is Editing Studio App Phase 6.6. No Book-specific labels,
provider orchestration, camera/microphone activation or external AI fallback
belongs in this widget.
