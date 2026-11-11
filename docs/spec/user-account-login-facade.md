# Common User Account login facade and navigation

Decision date: 2026-10-31
Status: accepted integration direction; implementation/acceptance pending

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

## Runtime profiles and presentation — 2026-11-02

Follow [shared runtime-mode defaults](https://github.com/asami/goldenport-cncf/blob/main/docs/spec/runtime-mode-security-defaults.md) through Core. Present account and
a non-secret environment indicator consistently; development fixtures and local
synthetic demonstrations must not look like authenticated participant evidence.
UI collection/editing, Fold posture and Flutter build mode cannot change server
mode, identity or permissions. The common facade owns login/account/environment
presentation; Book-specific screens do not implement conditional auth bypasses.

Participants need ordinary login only, not mode selection, Bearer strings or
provider folder IDs. Switching an operator-configured environment follows Core's
credential/pending-work boundary and must not silently discard or reassign work.
