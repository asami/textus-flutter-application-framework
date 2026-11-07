# Shared document editing workspace

`DocumentEditingWorkspace` presents caller-owned navigation, original source,
editor and commands. It owns adaptive layout and explicit mode presentation,
not domain documents, lifecycle, authentication or persistence. App supplies
Book composition; Core owns authenticated transport and device capabilities.

Small width exposes list/source/content tabs in input/reference mode. A medium
width uses a navigation drawer and source/editor panes; a larger width retains
navigation beside those panes. A width increase does not select editing. After
narrowing, editing remains suspended until the participant explicitly chooses
it again. No resize invokes a save, lifecycle or media operation. The caller
retains controllers and selection and decides any draft disposition on explicit
navigation/mode change.

The toolbar exposes save, explicit read/confirmation and caller status. Save
and Ctrl/Cmd+S are admitted only while explicitly editable and the caller supplies
an enabled command. Buttons remain available to touch users. Caller status and
commands must describe the active document/panel; a Candidate action is not
silently replaced with a Book save or Information admission.

Shared widget tests verify buffer retention, no resize writes, explicit reentry
and keyboard dispatch. App tests verify the connected Book and Candidate route.
Actual participant discoverability, Fold posture and deployed browser acceptance
remain App Phase 7 requirements; the shared shell alone does not accept them.

## Shared non-server extensions — 2026-11-07

The workspace reuses Core's separated-display geometry and the existing shared
approved-viewport paint measurement. It avoids measured hinge rectangles for
source/editor panes, suspends editing on posture changes, and supports source
collapse and pointer/keyboard pane resizing on ordinary desktop layouts.
An asynchronous caller-owned mode/navigation guard cannot resume editing after
a rejected draft decision. `AdaptiveEditingEntry` offers an explicit entry only
at a viable wide layout; mounting/resizing never invokes the action.

`MediaInputPanel` consumes Core observations and supplies explicit acquisition,
preview and attachment. It retains pending preview state while scrolled away
and explains disabled configuration/device/permission states. App owns original
association, local save, Commit and delivery state. A panel preview is not a
saved original, registration or ACK. Actual device/browser acceptance stays open.
