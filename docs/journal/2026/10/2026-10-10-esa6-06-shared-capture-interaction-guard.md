# ESA6-06-D2G — shared capture interaction guard

- Current status: Authored under `esa61-submission-tfaf-d2g-manifest-20261010@1`. Parent software validation completed on 2026-10-10 with the receipts below. Fresh independent producer source conformance, App D2B binding, native/Drive runtime, whole ESA6-06 Step and PHASE-6.1 acceptance remain pending.
- Owner: PHASE-6.1 parent for authority, validation and acceptance; TFAF implementation editor for the exact eight-path D2G authoring scope.
- Update rule: Append actual parent validation and independent review receipts when supplied. Preserve prior accepted source histories and all separate consumer/runtime/Step/Phase obligations. Do not promote authored host scenarios to executed or native acceptance.

The [shared capture interaction guard note](../../../notes/shared-capture-interaction-guard.md) documents the optional `bool Function()? interactionAllowed` API on the existing audio, transcript and photo widgets. It is a borrowed pure caller decision, with null preserving prior behavior and false or evaluation failure denying entry. This slice retains the original human participant authority and authorizes no App/Core/controller/facade changes.

Each rendered callback captures its controller and widget generation. Admission checks current mounted identity/generation and evaluates the current caller policy before any user action. Audio/transcript also check detached/disposed state. Configuration and transcript buffer changes are guarded alongside asynchronous capture/provider/settings commands. A denied same-owner text event restores only the local canonical draft; stale callbacks after unmount, replacement or A→B→A touch no current state.

Already admitted commands retain durable work, actual original/report/error outcomes and the existing operation-start owner completion fences even when later user admission is false. Temporary denial neither cancels nor disposes borrowed resources. Existing owner controller calls, including explicit correction flushing for accepted Save intent, remain available under their existing controller rules.

G1–G6 were authored in the three exact owned test files using production callbacks, actual common controllers and private filesystem/provider/settings fixtures. G1 covers exact dirty Unicode/whitespace/empty correction, latest/older selection and direct owner flush. G2 covers all audio commands, live denial, failed evaluation and reenable. G3/G4 join accepted stop/ASR/camera/preparation success/failure during suspension. G4 additionally covers photo settings/configuration/provider/saved-image effects. G5 covers controller retirement and A→B→A in every widget. G6 covers disabled actual gestures and scrollable scaled 320px presentation, alongside retained omitted-gate W/T compatibility scenarios.

Adjacent semantic Given/When/Then clauses describe admission, local restoration, accepted settlement and observable fixture effects. Same-file mechanical brace/format debt in the photo widget and photo fixtures is completed; the six Dart targets receive canonical write formatting. Existing assertions and scenarios are retained. No outside helper, dependencies, Phase/workflow records, submission schemas or runtime engines are authored by this slice.

The editor executes no tests, analysis, dry validation or self-review. Only the exact manifest-authorized six-file write formatter is run. The parent owns the G1 representative, TFAF nine-suite accumulation, App three-suite compatibility check, analysis, dry format, diff checks, independent protected producer conformance and any subsequent acceptance/transition. No D2G-only commit or whole Step/Phase completion is claimed.

## 2026-10-10 Parent software validation receipt

The parent supplied actual completed software results from `.codex-workflow/phases/PHASE-6.1/validation/submission-tfaf-d2g-20261010` in the primary App repository. Each listed command exited 0:

- G1 representative: 1 passed (`representative-final.log`).
- Focused G2 cancellation scenarios: 2 passed (`cancellation-focused-final.log`).
- TFAF accumulator: 163 passed across 9 suites (`accumulator-final.log`).
- Legacy App compatibility: 47 passed across 3 suites (`app-legacy.log`).
- Analysis: `No issues found` (`analysis-final.log`).
- Dry formatting: 6 files, 0 changed (`format-dry-final.log`).

Initial G1 failed because the test host omitted forwarding `interactionAllowed` to `TranscriptReviewPanel`. The exact M1 helper wiring correction retained the scenarios and assertions, and the representative then passed. The initial accumulator had 161 passes and 2 failures because interrupted playback and transcription originals emitted the authoritative cancellation `StateError` without immediate observers. The exact M1 repair attached `expectLater(..., throwsStateError)` to both originals and retained their joins; the focused 2 scenarios and final accumulator then passed. Both corrections changed test fixtures only; production source was unchanged by these repairs.

The parent also recorded an actual `git diff --check` exit 0 before this documentation amendment; the final documentation diff check remains parent-owned and pending. Historical authoring paragraphs above retain their original boundary. Fresh independent producer source conformance, App D2B binding, native/Drive runtime, whole ESA6-06 Step and PHASE-6.1 acceptance remain pending. These software receipts imply no independent acceptance, D2G-only commit or whole Step/Phase completion.
