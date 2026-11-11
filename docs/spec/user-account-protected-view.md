# Shared authenticated presentation entry

2026-11-07 — TFAF-UA03 / App Phase 7 ESA7-01 implementation.

`UserAccountProtectedView` borrows `UserAccountAuthenticationFacade`. It shows
the existing Japanese common login/account page until Core accepts an account.
It creates the protected subtree only for that accepted account. It grants no
server permission and receives no tokens, passwords or session identifiers.

During an in-progress authentication update, the prior subtree is hidden,
excluded from focus/semantics and has its tickers disabled. Successful refresh
for the same account retains its widget/draft state. An idle unauthenticated
result, logout or closed facade removes the subtree; a replacement facade or
different accepted account receives fresh state. The caller still owns durable
draft retention, explicit unsaved-work leave handling and authenticated request
lifetimes. The view itself neither saves nor sends domain data.

App wraps the complete Web Navigator, including pushed routes, rather than just
the initial Home. Authentication withdrawal therefore cannot leave a previous
protected route visible above the login screen. Native composition retains its
existing local input/editor ownership and wraps each server-reference destination
and editor-pushed reference with the same protected view. Logout retires remote
reference contents while leaving the underlying local editor and explicit return
action available. Web and native reuse the same facade and Japanese form.

An unavailable/notConfigured login explicitly says the connection cannot be
used and asks for its settings to be checked. It is not labeled as ongoing
preparation when no request or initialization is active.

Controlled tests verify initial entry, accepted login, logout, borrowed ownership
and retaining unsaved text across a pending successful refresh. Actual Web
participant/Material editing and joined mobile/server acceptance remain open.
