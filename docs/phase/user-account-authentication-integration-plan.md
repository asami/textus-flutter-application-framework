# User Account common login UI integration

Status: IN_PROGRESS; implementation qualification does not close acceptance
Decision date: 2026-10-31
Consumers: App Phase 6.10 ESA610-08, then Phase 7 ESA7-01

2026-11-07: App's user selected advance Phase 7 work while remaining Phase 6.10
acceptance is held. TFAF-UA03's [protected entry](../spec/user-account-protected-view.md)
reuses the shared Japanese login facade with Core's browser adapter. Actual
participant/Material/adaptive editing acceptance remains open below.

Implement the [login facade contract](../spec/user-account-login-facade.md)
using the [Core workstream](../../../textus-flutter-core/docs/phase/user-account-authentication-integration-plan.md).
Preserve closed Phase 3 and planned Phase 4 Sensitive Interaction. This bounded
login integration supplies reusable pieces for that broader direction; it does
not require all payment/signing/consent features or claim their completion.

| ID | Work | Acceptance |
| --- | --- | --- |
| TFAF-UA01 | Agree safe account/state/action facade with Core and ESS5-01/02 | Producer authority remains user-account/CNCF; App consumes results rather than credentials |
| TFAF-UA02 | Shared login/account/logout and navigation for native collection | App 6.10 accepts actual iPhone/Android use with no per-App auth implementation |
| TFAF-UA03 | Adaptive Web presentation and protected editing entry | App 7 reuses facade with browser Core adapter and same-user Material route |

- [ ] TFAF-UA01 public contract aligned with Core and actual server capability.
- [ ] TFAF-UA02 common/native presentation accepted with ESA610-08.
- [ ] TFAF-UA03 browser/adaptive presentation accepted with ESA7-01.

Hand off UA02 before UA03 so mobile completion does not wait for Web. Apply
the selected capability's existing dependency and sensitive-interaction rules;
record missing producer support explicitly. Do not expand into a new identity
provider or assume planned passkey/Google federation is already deployed.
Shared milestone targets (JST): TFAF-UA01 with the actual server/Core contract
by Nov 2; TFAF-UA02 with App 6.10 mobile acceptance by Nov 4; TFAF-UA03 with App 7's
basic phone → Web → persisted Information route by Nov 6. Framework owns common
login/navigation presentation; App owns consumer composition. New Fold editing
and media-input integration follow that working basic route. Dates are targets,
not acceptance or additional review gates; report gaps and revised forecasts.
See the [milestone schedule](../../../../Project2026/nict-editing-studio/docs/milestone/2026-11-10-nict-demo.md#intermediate-delivery-targets-jst).
Verify common behavior and actual consumer routes with proportionate tests and
integrated review under normal owner validation/release rules.

## Runtime-mode facade allocation — 2026-11-02

Consume the [common profile presentation contract](../spec/user-account-login-facade.md#runtime-profiles-and-presentation--2026-11-02).

- [ ] TFAF-UA01: align CNCF/User Account/Core mode semantics; no second profile
  parser, authentication provider or authorization policy in widgets.
- [ ] TFAF-UA02 / MODE-01/04/05: native common account/environment display and
  ordinary demo participant login; preserve owner/draft/queue boundaries.
- [ ] TFAF-UA03: Web and Fold presentation reuse the same state; layout or
  collection/editing switches cannot change identity, mode or permissions.

Retain the existing delivery order and integrated review. The November demo
uses the real participant profile, not a development login shortcut.

## External providers and provider-managed Passkey — 2026-11-05

Status: PLANNED; separate extension, not a November 10 demo gate.

Implement shared provider selection and login lifecycle UI, locale-based recommendations and Other login methods; consume Core state without implementing token verification or storing provider secrets.

Follow the [shared delivery decision](../notes/external-provider-login-and-passkey.md).
Google is first; Microsoft/GitHub/LINE follow without blocking its acceptance.
Existing active work, accepted phases and direct Textus WebAuthn plans remain intact.

- [ ] TFAF-FED-01: Agree the begin/callback/completion/session and provider-capability contracts with the other two owners; preserve existing identity/authorization boundaries.
- [ ] TFAF-FED-02: Deliver the owner responsibility above on the connected Google Web/native route, then qualify other enabled providers separately.
- [ ] TFAF-FED-03: Accept provider-managed Passkey on supported real account/device/browser combinations; distinguish actual ceremony from reused sessions and unverified assurance. No Textus Passkey enrollment is required.
- [ ] TFAF-FED-04: Verify Japanese/default recommendations and Other access to all remaining enabled providers with Framework/Core; locale does not restrict authentication.
- [ ] TFAF-FED-05: Record connected success, cancellation, rejection/replay, account isolation, logout and redaction evidence; normal owner tests/review/release apply.
