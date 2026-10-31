# Shared account presentation foundation and successor handoff

Date: 2026-10-31
Scope: PHASE-6.10 / ESA610-08B, common facade/panel/page
Status: foundation authored; validation and integrated acceptance pending

## Authority and foundation boundary

The foundation consumes the real Core `UserAccountAuthenticationClient` and its
normalized safe account, challenge and logout outcomes. The
[Core client specification](../../../../../textus-flutter-core/docs/spec/user-account-authentication-client.md)
defines that API; the
[Core foundation handoff](../../../../../textus-flutter-core/docs/journal/2026/10/2026-10-31-user-account-authentication-foundation.md)
records server-owner source evidence from Studio `5ca141b` and
`textus-user-account` `fab35a1`. Those findings cover credential login, email
challenge, authoritative account projection, rotating refresh and current-session
logout. They are source findings, not accepted participant HTTP deployment.

ESS5-01/02 participant HTTP/ownership specimens and runnable endpoint remain
unprovided. The fixed development Service guard for Material intake/editor
does not prove participant ownership. No endpoint, wire envelope, EntityId
interpretation, expiry policy or credential issuer is inferred by this UI.
Core retains the challenge reference and owns eventual authority communication,
native protected storage and authenticated transport. Framework owns no vault,
token/session store, credential verifier or parallel user authority.

## Delivered consumer surface

The [facade specification](../../../spec/user-account-login-facade.md) describes
`UserAccountAuthenticationFacade`, `UserAccountAuthenticationPanel` and
`UserAccountAuthenticationPage`, exported from Framework's public entrypoint.
Construction performs zero IO. An unavailable client shows preparation copy
without credential entry. Configured interaction forwards exact ephemeral
identifier/password/code to Core, clears sensitive controllers before calls,
and displays only authoritative safe account identity. Email challenge remains
unauthenticated. Japanese failure copy is fixed; backend/private details are
never rendered. Refresh remains a nonvisual facade capability.

The facade borrows by default and can explicitly own its client's lifetime.
Retirement immediately withdraws its account and listener; borrowed owner work
continues. Owned close is idempotent and sanitized, with reentrant notification
disposal and observed cleanup errors. Panel/page always borrow. Replacing or
unmounting a widget clears its controllers without implicit cancel/logout.
Retained facade identity, generation and action ID guard async UI completion.
Only explicit Cancel retires accepted authentication work. Logout withdraws
account display immediately and distinguishes local clearance from remote
revocation; failed local clearance requires retry before new login.

The behavior specifications use actual Flutter test groups with semantic
`should` scenarios and adjacent Given/When/Then clauses. A controlled test-only
backend feeds the real Core state engine; no production substitute is supplied.
Scenarios cover command admission/forwarding, credential clearance, authority
identity, private challenge, cancellation/late results, logout facts, ownership,
replacement/unmount, narrow large-text layout and retained caller drafts.
They are authored evidence of intended foundation behavior, not an execution
receipt or real-provider/device acceptance claim.

## App composition and remaining gates

The App owner supplies a shared facade backed by the genuine Core client and
pushes `UserAccountAuthenticationPage(facade: sharedFacade)` as a normal route.
Keep the caller-owned draft/controller and retained work outside this route;
ordinary back returns to that caller. Do not introduce a Book-owned auth store
or use a test backend in production. Until a genuine adapter is configured,
use Core's honest unavailable state. A displayed account does not itself grant
server permissions, guard a business route or authorize submission.

Required successor inputs/work remain:

- Authority owners provide accepted participant HTTP login/challenge/refresh/
  logout/account specimens and runnable endpoint, including exact envelope,
  opaque identity and participant Material ownership semantics.
- Core binds real HTTP results and Android protected storage, with retirement
  before credential commit and bounded cancellation/close drain. Framework/App
  must not replace this missing producer/native capability.
- App/Core integrate real protected navigation, authenticated submission
  capability and account-safe queue ownership. Preserve offline capture and
  caller drafts; logout/account change must not reassign pending work.
- Complete genuine Android login, refresh/refusal, owner-correct Material
  submission and logout. iPhone-specific work starts no earlier than
  2026-11-03; genuine iPhone acceptance still remains required. Web/browser
  adaptation retains the same account semantics and its original acceptance.
- Parent performs focused Framework validation and integrated protected-boundary
  review with Core consumer evidence, followed by the original Phase full
  suites/recovery-full review/local commit gates.

The original `esa610-authority@1` binding/epoch remains; the authorized Framework
addition is `esa610-tfaf-android-auth@1`, ledger `esa610-reviews@4`.
UA01/02/03 and ESA610-08 remain open. This successor records the shared
foundation and missing integration inputs without closing those gates.
