# Common voice fields and retained media contribution

Date: 2026-11-08 (Asia/Tokyo)
Record consolidated: 2026-11-11
Status: delivered contribution; not whole-Phase closure

The user authorized App Phase 7.2 common dictation and multimedia annotations.
Additional spoken instructions against converted or manually revised text remain
planned in Phase 9. Domain save and submission stay with the consuming App.

VoiceTextField exposes a default voice action for eligible natural-language
fields, preserving explicit opt-out and secret/readonly/disabled behavior.
The shared dialog separates the actual transcript, explicit local Convert,
editable proposal and explicit Apply. Apply uses the captured selection and
ordinary formatters/onChanged; cancellation, replacement, disposal or intervening
caller edits prevent stale insertion. Each dialog owns a fresh Core session.
Display integrations keep normal editable keys and require ordinary domain Save.

Retained image/video/audio input is separate from text dictation. Attachment
audio records an original without transcription or cleanup. Opaque recovery
selectors, explicit recover/cancel and foreign-target refusal preserve the
original association; metadata errors are not treated as an empty capture slot.
Adding a returned reference does not claim domain persistence. Exact ready-intent
acknowledgement follows the consumer's actual save through CaptureStorageFacade.
The original viewer owns playback cleanup and does not replace stored originals.

The transcription dialog gained an explicit stop-and-close control. The portrait
video repair CB-ESA72-VIDEO-VIEWPORT-001 reserves reachable playback controls
while preserving aspect ratio and both bounded and scrolling layouts. Its
focused review passed. HYG-ESA72-MEDIA-ALIGN-001 retains the operator's overall
left-alignment feedback for later visual consideration; no global layout change
is inferred from it.

Historical controlled field/Display/media qualification and the complete
1,309-test Framework run passed with clean analysis. Two independent fields
were actually dictated, converted and applied on iPhone. Native playback was
confirmed for retained media, while the earlier finite helper's deadline failure
remains a failure distinct from the operator's later successful observation.
These results do not establish native interruption recovery, connected delivery,
offline Apply/save or whole Phase acceptance. Earlier failures and the actual
normal-App/data restoration records remain retained.

Detailed validation/review and device observations are retained locally:
`asamiair:~/backup/journal/2026/11/nict-editing-studio-app/github-sync-20261111/shared-media-document-evidence-001/`.
Review after 2026-12-11; unresolved native qualification retains its evidence.
The owning App retains the original private execution records. This journal and
its synchronization do not reopen already completed Framework Phases or run
new native/cloud operations.
