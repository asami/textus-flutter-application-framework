# Common voice-assisted text input

Decision date: 2026-11-08 (Asia/Tokyo)
Status: selected direction; implementation and device acceptance pending

## Standard field behavior

Framework-standard editable natural-language text fields show a voice-input
button by default. Applications should not implement a microphone button and
dialog for each field. Single-line and multiline fields share the interaction;
field constraints still apply. Configuration may disable voice input for an
application or an individual field. Password/secret fields do not offer it;
readonly, disabled and currently inadmissible fields cannot launch it.

The default belongs to the common framework field/editor realization. It does
not intercept arbitrary Flutter `TextField` instances or third-party widgets.
Existing framework-owned field builders are explicit integration targets;
application-specific fields can adopt the same public component. Preserve field
labels, validation, accessibility, text scaling and ordinary manual editing.

## One dialog, explicit conversion and application

1. The field's voice-input button opens one common dialog bound to that field.
2. The user starts and stops speech input in the dialog. Recognized text appears
   there automatically; stopping requires no separate Transcribe command.
   Interim text may be shown when the provider supplies it, but only an actual
   final transcript is treated as final.
3. The user reviews or edits the transcript and presses `変換する`. This explicitly
   requests on-device Japanese text cleanup; recognition alone does not start
   generation or change the calling field.
4. The dialog displays the generated text and permits inspection/editing. The
   original transcript remains accessible. Conversion progress and failure are
   visible, and a failed conversion preserves the transcript.
5. The user presses `入力欄に反映` (the requested registration action). Only then
   does the selected text enter the calling field through its ordinary edit
   path. Application save, submission and business registration remain separate.

Cancel leaves the calling field unchanged. Recording, transcription and
generation never independently apply text. Closing the dialog retires its
callbacks and releases its owned microphone/inference work. A late result cannot
change a field after cancellation, disposal, field replacement or owner change.

Application follows the common field's insertion/selection policy and existing
validation. Preserve text outside the selected insertion range. If the calling
field changes while the dialog is open, do not silently overwrite that edit;
retain the dialog's text and expose the need to reselect the insertion target.

## Cleanup semantics

The requested transformation removes contextually unnecessary hesitation words,
repetition and resolved spoken self-corrections, and improves punctuation,
line breaks and Japanese grammar while preserving intended meaning. Retain
names, numbers, negation, uncertainty and meaningful list/conjunction words.
Do not remove every occurrence of a word such as `あと`, add unstated facts,
summarize away content, or silently truncate long input. Generated text is a
proposal until the user applies it.

## Runtime and capability ownership

### On-device value selected for the November 10 demo

The selected cleanup uses smartphone-local AI. After model preparation, it must
be demonstrable without network access and without commercial AI API calls, so
repeated cleanup incurs no per-call/token commercial API charge. Show actual
transcript and polished text for comparison; label native processing only when
the selected capability is qualified. Do not describe unavailable or cloud
processing as local success. Speech recognition, initial model download and
later Material upload have their own actual requirements/costs. This promise
concerns cleanup, not zero total application cost.

### Layer responsibilities

Framework owns the field action, dialog, interaction state and explicit return
to the caller. Core owns platform audio/speech, language/model availability,
permission and model preparation, on-device inference and resource cleanup.
Apps supply field binding and domain constraints, not platform-name branches.

The Book application's [multimedia annotations](../../../../Project2026/nict-editing-studio-app/docs/spec/book-multimedia-annotations.md)
are a concrete consumer: each independent annotation text field uses this same
default action. Book cardinality, media associations and persistence remain App
responsibilities. Binding a result to its original annotation/field is part of
the ordinary caller-ownership contract, not a separate Book-specific dialog.

Reuse the existing public audio/transcript and generated-draft capabilities
where their contracts fit. The existing saved-original audio workflow is not
itself this transient input interaction. Do not require a document Material,
upload destination or durable audio registration merely to enter field text.
Keep ordinary capture/transcript provenance behavior unchanged.

Generic voice cleanup must not silently reuse the annotation-only meaning of
`textReadability`, nor redefine quotation-preserving proofreading. Select or
extend the appropriate Core operation explicitly during implementation.

Apple Foundation Models and Android AICore/Gemini Nano are candidate native
adapters. Existing Android code and generated-draft UI do not establish iPhone
support, filler-removal quality or actual device acceptance. Probe each requested
capability and Japanese support. Explain unavailable or downloadable features
and preserve manual text input. When recognition works but cleanup is unavailable,
the user may explicitly apply the unconverted transcript. No silent cloud
fallback or fabricated successful conversion is part of the default.

## Acceptance boundary

- A standard eligible field gets the voice action without per-field opt-in;
  application/field opt-out and secret/readonly/disabled cases are respected.
- The complete dialog sequence works for two independent calling fields and
  both single-line and multiline input. Only explicit Apply changes a field.
- Cancel, failed recognition/cleanup, unavailable AI and field/owner changes
  preserve the caller's work; stale completion never applies text.
- The same UI consumes Core capabilities on Android and iPhone. Device evidence
  separately qualifies transcription, Japanese cleanup and the final field edit;
  provider doubles do not establish native acceptance.

Delivery: [bounded implementation plan](../phase/voice-text-input-plan.md).
