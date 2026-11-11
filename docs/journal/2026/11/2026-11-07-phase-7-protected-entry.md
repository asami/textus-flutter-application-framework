# Phase 7 protected Web entry

The user selected advance App Phase 7 work while mobile acceptance remains open.
TFAF-UA03 now supplies [UserAccountProtectedView](../../../spec/user-account-protected-view.md),
reusing the existing Core client/facade and Japanese login/account/logout UI.
It keeps draft widgets hidden during refresh and retires previous account views
on logout or rejected authority. App owns its Web Navigator composition.

This is shared presentation implementation, not proof of server authorization,
same-user phone Material discovery, adaptive editing or actual participant
acceptance. Every remaining UA01/02/03 and App Phase 6.10/7 gate remains open.

The shared [document workspace](../../../spec/document-editing-workspace.md)
adds adaptive source/editor/navigation panes, explicit input/reference vs editing
entry, visible save/read/status commands and Ctrl/Cmd+S. Width changes suspend
editing and preserve the caller's buffer; widening alone never resumes editing.
App owns Book fields, source selection and Candidate/Information commands.

The actual shared test selection passed 32 tests (existing authentication
presentation, protected entry and two new workspace behaviors). An earlier
selection used a nonexistent historical test filename; that command failed to
load that input while its four real tests passed. The corrected selection uses
`user_account_authentication_presentation_test.dart`; no product repair or
acceptance waiver was needed. Local command logs are not versioned.
