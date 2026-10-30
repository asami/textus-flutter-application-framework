# User Account common login UI integration

Status: PLANNED; execution not started
Decision date: 2026-10-31
Consumers: App Phase 6.10 ESA610-08, then Phase 7 ESA7-01

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
