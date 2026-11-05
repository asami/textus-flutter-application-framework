# Photo role preview readiness and Japanese presentation

Recorded: 2026-11-05. Scope: PHASE-6.10 /
ESA610-PHOTO-ROLE-JAPANESE-PREVIEW-001 in the consuming App.
Status: implementation and executable specifications authored; parent validation,
independent review and native acceptance pending.
Owner: Framework common photo presentation; App supplies cached readiness,
role meaning, status content and domain commands.

`PhotoRoleCaptureImage.previewReady` is an optional nullable boolean, defaulting
to null. It describes the App's already-cached preview readiness independently
of `readStatusLabel`. When true, a localized label such as `読み込み済み` can
accompany a preview. When false, neither the overview nor Inspect constructs a
`CaptureImagePreview` or invokes `readBytes`, even if the label is `Loaded`.
Omitting the flag preserves the exact legacy readiness rule:
`readStatusLabel == 'Loaded'`. The English literal remains a compatibility
fallback and is not translated.

Readiness is a synchronous cached-only predicate. Build and Inspect add no IO
and do not invoke `readBytes` to decide readiness. Actual byte borrowing stays
inside `CaptureImagePreview`, with the existing original/source identity,
512 decode bound, local decode retry, private snapshot/provider and disposal
semantics. The panel gains no controller, service, byte cache or stored state.
The Book App passes the same existing cached predicate used for its read label:
`sameDisplay && book!.originalBytesFor(evidence.material.id) != null`.
Its ownership checks and borrowed byte closure remain intact.

Common participant words now default to Japanese: `追加写真`, `未撮影`,
`撮影済み（N枚）`, `認識に使用（N枚）`, `撮影`, `写真を確認`, `写真を閉じる`,
`写真を追加`, `撮り直し`, `原画像:`, `認識に使用`, `読み込み:`,
`読み込みエラー:`, `再読み込み`, `認識:`, and `添付した原画像`.
Additional-photo collapse is `追加写真を閉じる`; actual decode failure and local
retry are `写真を表示できませんでした` and `表示を再試行`.
Keys, IDs, callback guards and programmer validation are unchanged. Attached
counts remain independent of read, decode or recognition success.

The App remains responsible for supplied role/guidance/status/error content.
The Book App supplies Japanese read labels and role-correction dialog/history
words. Its `_recognitionStatus` values, imported integrated statuses,
acquisition enum `.name` values and raw error diagnostics remain existing open
full-Phase Japanese coverage; this batch does not accept that coverage as
complete or reclassify it as an optional candidate.

Executable specifications retain legacy omitted-flag decoding and add real PNG
painting for localized explicit readiness, plus false-readiness suppression of
all byte reads despite `Loaded`, with explicit read retry still reachable.
The App's acquired-original RawImage assertions remain in place. Parent-selected
tests, source analysis, independent review and native acceptance are pending;
this note records no validation result or Phase completion. Existing completed
Framework Phase3 and planned Phase4 identities remain unchanged.
