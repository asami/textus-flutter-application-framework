# Document, media and Fold controls — Phase 7 client work

The App user prioritized non-server development. Extended the common document
workspace with the existing Core separated-display geometry and the viewport
paint/measurement mechanism extracted from ResourceListDetail. Source/editor
panes avoid the actual measured hinge; compact/posture changes suspend editing
without changing the caller's buffer, saving or acquiring media. An explicit
wide-screen entry opens editing; resizing never invokes that entry.

Explicit navigation/mode changes support an asynchronous caller-owned draft
guard. A pending decision coalesces duplicate clicks; refusal preserves the
current selection and suspension. Desktop panes support resizing and source
collapse; command/keyboard access uses the caller's enabled command. Framework
owns presentation, while App owns Book association and domain decisions.

Added a common media-input panel over Core capability observations. It shows
reasons and an explicit passive recheck path for unavailable actions. Selected
images preview before explicit attachment; cancellation/attachment failure
retains input. The retained panel/controller survives scroll and same-account
session renewal. It owns no credentials, queue, Book lifecycle or storage.
Camera/audio actions require actual adapter support and a supplied callback;
unsupported configuration does not imply absent hardware.

Controlled widget qualification covers draft/navigation guards, actual hinge
rectangles, posture/width retention, explicit edit reentry, keyboard save and
visible capability reasons without acquisition on mount/resize. Integrated
review's two App state/receipt findings were fixed and independently closed;
no Framework blocker remained. Actual Fold, browser permissions and joined
acceptance remain open in the existing plan. Execution logs stay local.

Qualification: full Framework regression 1285 passed; full static analysis
clean. The final optional entry-padding presentation adjustment is covered by
App's native-root entry/return and existing localization/navigation/capture
regressions; focused workspace static analysis remains clean. It keeps the
entry in Home's app bar so existing primary capture actions retain their
reachable position rather than being pushed below the viewport.

Actual unconfigured release-page observation later found that the idle
unavailable login copy said preparation was in progress. It now explicitly
says login is unavailable and requests checking connection settings. The enum,
command admission, private credential ownership and native behavior are
unchanged; the shared presentation suite passed 28 and affected native App
tests passed 15. The App default production root without injected configuration
or storage is also covered by a real Chrome test with no account request.

App now consumes the protected view for compact and editor-pushed server
references, retiring all visited remote views on logout while preserving local
editing. Its reference consumers also borrow the existing common Settings
binding. The consumer review/fix remains App-owned; Framework introduces no
Book lifecycle, duplicate Settings owner or new authentication contract.
