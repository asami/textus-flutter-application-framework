# Common voice-assisted text input delivery

Status: PLANNED; implementation not started
Decision date: 2026-11-08 (Asia/Tokyo)
Owner: textus-flutter-application-framework, with platform capabilities in Core

Implement the [common voice-text input contract](../spec/voice-text-input.md).
The selected user interaction is one dialog with automatic transcript display,
explicit conversion, review, and explicit application to the calling field.
Eligible framework-standard text fields expose the action by default.

The subsequent November 8 user decision selects this workstream for the
November 10 demo under [App Phase 7.2](../../../../Project2026/nict-editing-studio-app/docs/phase/phase-7.2.md).
Preserve closed Phases, existing media/authentication work and planned Phase 4/5
identities. Core/Framework contributions can be prepared alongside App 7.1;
do not reopen earlier closure. This is required for the expanded demo P1;
planning does not start implementation.

| ID | Delivery | Acceptance |
| --- | --- | --- |
| TFAF-VOICE01 | Core capability and operation selection | Map existing recording/transcription and generated-draft contracts; define the transient voice-cleanup operation without changing annotation/quotation semantics. Record actual Android/iPhone gaps. |
| TFAF-VOICE02 | Common dialog and caller binding | Recognized text appears automatically; Convert produces a separate editable proposal; Apply alone returns text. Cancellation and stale-result cases preserve the calling field. |
| TFAF-VOICE03 | Standard field defaults and configuration | Integrate the common framework text-field/editor realization, including the standard Display Editor, without changing its domain-save authority. Default-on natural-language fields, opt-out and eligibility rules work without per-app microphone implementations. |
| TFAF-VOICE04 | Android and iPhone native delivery | Implement needed Core/native adapters and qualify real Japanese speech, cleanup, unsupported states and field application on both platforms. Retain actual support limitations. |

- [ ] TFAF-VOICE01 runtime contracts and platform gaps resolved for the selected scope.
- [ ] TFAF-VOICE02 common dialog/controller behavior verified.
- [ ] TFAF-VOICE03 default field integration and opt-out verified.
- [ ] TFAF-VOICE04 actual Android/iPhone consumer behavior accepted.

## Demo handoff and targets

TFAF-VOICE01 maps to ESA72-01/02, TFAF-VOICE02/03 to ESA72-03/04, and
TFAF-VOICE04 to ESA72-05..07. App Phase 7.2 owns joined progress; these IDs retain
producer delivery obligations rather than duplicate acceptance.

- Nov 8 JST: settle Core contracts and actual Japanese/native capability gaps;
  prepare the common dialog/controller and standard-field integration.
- Nov 9 JST: join providers and Book fields; qualify default/opt-out, cancel/stale
  behavior, both devices and integrated regression.
- Nov 10: smoke qualified builds and the short audience interaction.

Show transcript and cleaned text for comparison. Explain the qualified native
benefits: prepared-model cleanup works offline and calls no commercial AI API,
avoiding per-call/token API charges for this stage. Speech, model download and
upload have their own actual requirements. Never silently substitute cloud AI.
Keep fields/dialog reusable outside Books; App owns note cardinality and media
association. Record gaps/forecast rather than silently reduce selected scope.

Use focused behavioral/controller/widget specifications for the interaction and
field ownership, plus native and real-device checks for platform adapters. Verify
representative filler words, meaningful `あと`, names/numbers/negation, spoken
self-correction and long-input handling. Controlled tests and real-device results
remain distinct; authoring this plan establishes neither implementation nor a
working on-device model.
