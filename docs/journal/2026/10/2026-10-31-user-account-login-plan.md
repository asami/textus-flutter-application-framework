# Shared User Account login presentation

Date: 2026-10-31
Status: planning only

The developer requested reusable authentication processing for smartphone and
Web. The [specification](../../../spec/user-account-login-facade.md) supplies
login/account/logout presentation and navigation over Core's user-account
client. The [workstream](../../../phase/user-account-authentication-integration-plan.md)
delivers native App 6.10 first and adaptive Web App 7 next. Studio Server 5
composes textus-user-account with CNCF; Framework does not authenticate passwords
or issue sessions. Book-specific apps consume safe state/actions and compose UI.

Planned Phase 4 Sensitive Interaction and closed phases retain their status;
reuse accepted login pieces there without requiring its whole program for the
demo. No implementation, tests, runtime, commit or deployment was performed.
