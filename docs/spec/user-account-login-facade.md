# Common User Account login facade and navigation

Decision date: 2026-10-31
Status: shared presentation and explicit Core restoration forwarding implemented;
native/server and whole-Phase acceptance pending

Provide common login/account/logout presentation and authenticated navigation
through the [Flutter Core authentication client](../../../textus-flutter-core/docs/spec/user-account-authentication-client.md).
The backend authority is textus-user-account through CNCF; Framework owns no
user database, credential verification, token issuance or second session system.

Applications compose the facade with an authenticated target route and their
domain content. The facade handles signed-in account display, sign-in progress,
cancel/failure/re-authentication and logout outcome consistently across small
and large layouts. Preserve the intended resource/work when returning from login
where the user remains authorized. Collection/editing modes grant no rights.

Raw access/refresh credentials do not enter widgets, generic settings or App
state. Core handles platform transports/protected credentials. Prefer supported
provider/OS-hosted interaction when the selected producer contract offers it;
any necessary credential entry stays in the bounded common authentication
surface, not a Book-specific form or a generic sensitive-value editor.
Do not require implementing new passkey/federation mechanisms for the demo.

Logout clears authenticated views without silently losing unsaved work or
changing its owner. Show local/remote logout outcomes accurately through the
Core result. TKL/Drive connection consent is presented as a separate operation,
not as proof of a Textus user login. Endpoint/profile selection is deployment
configuration, not a request for participants to configure storage or tokens.

## Implemented common presentation foundation

Import `package:textus_flutter_application_framework/textus_flutter_application_framework.dart`
for `UserAccountAuthenticationFacade`, `UserAccountAuthenticationPanel` and
`UserAccountAuthenticationPage`. They consume the real Core client and safe
account/result types. No production backend, credential verifier, session
issuer, HTTP decoder or separate account store is provided by Framework.

Construct `UserAccountAuthenticationFacade(client: client)` with an explicitly
configured Core owner, or an honest `UserAccountAuthenticationClient.unavailable()`
while the real adapter is absent. Construction subscribes to safe notifications
and performs zero IO. Core's constructor also performs zero IO. The facade
retains the client privately; public getters expose only `snapshot`, `busy`,
`isClosed` and `canSignIn`, `canVerifyChallenge`, `canRefresh`, `canRestore`, `canCancel`,
`canSignOut`. It stores no credential or independent account/session state.

The command methods forward exact sign-in identifier/password and challenge
code, explicit restore, refresh, cancel and logout to Core. Admission follows Core status and
busy state: sign-in requires idle signed-out/failure state, verification idle
email challenge, refresh idle authentication. A failed local logout blocks
sign-in until explicit logout retry succeeds. Cancel remains available during
sign-in/verification/refresh and an idle challenge; cancelling/signing-out admit
no new action. Logout may retire accepted authentication work. All admission
flags are false once the facade/client is closed or the client is unavailable.
Local admission errors contain fixed safe text. Core owns serialization,
challenge references, retirement, account validation and refresh semantics.

`canRestore` delegates to the current borrowed Core client's restoration
admission while the facade remains open. Explicit `restore()` requires that
admission, forwards once to `client.restore()` and publishes the normal safe
change notification. Core uses the existing refreshing state, so its current
progress rendering and cancellation capability apply without new status values.
The facade, panel and page never restore in constructors, mounting, rebuilding,
navigation or disposal. The application owner may explicitly restore after
selecting its configured authority; it alone owns that startup policy. Restored
account identity must come from Core's server-authorized account lookup, never
from a locally cached display label. Active restore uses the same cancellation,
close drain, borrowed/owned lifetime and reentrant notification rules as other
Core work.

The facade borrows its client by default. `close()` immediately unsubscribes
and withdraws the visible account into a stable safe closed snapshot; a
borrowed client continues its owner's work. `ownsClient: true` closes the client
exactly once after retiring the facade. Close/dispose never implicitly log out,
delete retained work or change its owner. Close failure exposes only fixed
`StateError('Authentication close failed')`; disposal observes asynchronous
cleanup errors. Disposal is idempotent and safe from notification listeners.
The narrowly scoped `must_call_super` annotation documents deferred superclass
disposal after active notification calls, following Core's settled pattern.

The panel borrows its facade. Its only credential buffers are private local
text controllers. The form labels are `ログインID`, `パスワード` and `ログイン`;
password entry is obscured with autocorrection/suggestions disabled. Exact
password/code values are read and their controllers cleared before forwarding
the command. Sensitive fields are also cleared on observed authentication,
logout/challenge lifetime changes, replacement and disposal. Replacement and
disposal clear every controller. An identifier may remain for a normal failed
login retry. Immutable Dart strings do not permit a memory-zeroing guarantee.
No caught exception or server body is reflected into participant copy.

Unavailable state shows `ログインの接続を準備中です。` with no credential form.
Authenticated state shows only the authoritative nonblank display name (or
exact `userAccountId` fallback), and `アカウントID` labels the exact safe opaque
identity. Typed login ID is never used as the account name. Email challenge is
unauthenticated: `メールに届いた確認コードを入力してください。`, `確認コード`,
`確認する` and `キャンセル` do not expose the private reference retained by Core.
Busy states show fixed progress copy and prevent duplicate primary actions;
cancel remains reachable during accepted authentication. Refresh is a facade
capability for transport integration, with no participant-facing technical button.

Logout immediately withdraws the account when Core enters signing-out. A
confirmed result says `ログアウトしました。`; local-only/not-attempted says only
`この端末からログアウトしました。`. Local success with failed/unknown remote
revocation says `この端末からログアウトしました。サーバー側の失効は確認できていません。`.
Failed local clearance says
`この端末のログアウトを完了できませんでした。もう一度ログアウトしてください。`
and offers `ログアウトを再試行`, with no account label or new-login form.

The panel uses wrapping actions and unconstrained-height text for composition
inside a scroll host, including 320 logical pixels and large text. The page
adds Scaffold/AppBar title `アカウント`, SafeArea, a single scroll view and padding.
It borrows the facade and has no construction/build/unmount authentication or
business action. Standard back returns to the retained caller route without
resetting its draft controller. Async panel effects require the same facade,
widget generation and latest action ID; replacement/unmount or superseding
cancel cannot apply an old error, clear replacement input or trigger navigation.

## Composition and remaining integration gates

App composes `UserAccountAuthenticationPage(facade: sharedFacade)` as a normal
route while retaining its caller-owned draft/work outside that route. It must
not create a Book-owned auth store or implement Core's backend as an application
credential verifier. The owner decides the facade/client lifetime; the shared
page/panel never dispose, cancel or log out a borrowed owner on back/unmount.
Merely presenting this route neither protects a business route nor resumes a
protected submission. Real protected navigation, authenticated transport and
account-safe queue ownership remain explicit App/Core integration requirements.

Historical foundation evidence (2026-10-31): the
[Core client specification](../../../textus-flutter-core/docs/spec/user-account-authentication-client.md)
and [Core foundation handoff](../../../textus-flutter-core/docs/journal/2026/10/2026-10-31-user-account-authentication-foundation.md)
record normalized backend semantics and source-only server-owner findings:
Studio `5ca141b`, user-account `fab35a1`. ESS5-01/02 participant HTTP/ownership
specimens, endpoint/envelope/opaque EntityId binding and runnable endpoint are
still absent. The fixed development Service Material guard does not establish
participant ownership. Framework supplies no guessed URL, wire envelope,
credential vault or session substitute. Controlled test backends establish only
foundation behavior, not real login or device/server acceptance.

Core now provides the concrete HTTP/native protected-storage connection and
explicit restoration contract consumed by App; Framework supplies no additional
transport or credential store. Source integration does not establish native or
server acceptance. Participant ownership, App/queue binding and genuine Android login, refresh,
correct-owner submission and logout remain required. Android-first work does
not reduce iPhone acceptance; iPhone-specific development waits until
2026-11-03 or later. Large-screen Web/browser-adapter acceptance remains required.
UA01/02/03 and ESA610-08 are not complete. The original authority and every
real-provider/native/App/queue/Web acceptance gate below remain in force.

Executable foundation scenarios are authored in
`test/user_account_authentication_presentation_test.dart` using the real Core
client with a controlled test-only backend and adjacent Given/When/Then clauses.
Validation and integrated acceptance are separate parent-owned gates.

## Acceptance

- App 6.10 composes the shared facade on actual iPhone and Android, displaying
  the server-authenticated account and supporting logout without Book auth code.
- App 7 uses the same facade/state contract in large-screen Web with a browser
  adapter; mode/layout changes do not change the user or confer permissions.
- Cancel/failure returns to an understandable state, and guarded navigation
  resumes the selected work only when authorized by the server.
- Logout/account changes preserve the existing unsaved/pending-work policy and
  do not expose another user's private authenticated views.

Delivery: [integration plan](../phase/user-account-authentication-integration-plan.md).
