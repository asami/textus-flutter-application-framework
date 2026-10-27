# TKL-managed Material delivery — TFAF follow-on

status=planned
planned_at=2026-10-24
spec=../notes/tkl-managed-material-delivery.md
consumer=nict-editing-studio-app Phase 6.3

This bounded follow-on consumes accepted Phase 3 public facades. It neither
reopens Phase 3 nor folds the unrelated Phase 4 Sensitive Interaction programme
into mobile delivery. Integrate relevant App-consumed TFAF worktree changes at
entry; preserve existing accepted behavior and evidence.

| ID | Delivery | Status |
| --- | --- | --- |
| TFAF-TKL01 | Bind Core's TKL destination, consent, delivery and registration projections to shared public facades. | OPEN |
| TFAF-TKL02 | Replace manual Google destination setup for this route with TKL-derived presentation; connect progress and supported actions. | OPEN |
| TFAF-TKL03 | Verify fixture branches and hand the complete UI to App real-device acceptance. | OPEN |

- [ ] Both supported Drive target kinds use the same facade/UI.
- [ ] No drive/folder ID entry or hidden app-owned destination provisioning.
- [ ] Sign-in/consent remains available when required, with no secrets in display.
- [ ] Upload and TKL registration have distinct truthful states; existing Studio
  acknowledgement is not confused with either.
- [ ] Missing TKL configuration, revoked access, offline waiting and retry have
  actionable UI without a physical-folder fallback.
- [ ] Legacy queued work remains visible; screen initialization causes no upload.
- [ ] Relevant widget/consumer tests and one integrated independent review pass;
  owning release validation follows existing rules at the affected scope.

Dependencies: [Core plan](../../../textus-flutter-core/docs/phase/tkl-managed-material-delivery-plan.md),
[App Phase 6.3](../../../../Project2026/nict-editing-studio-app/docs/phase/phase-6.3.md).


## Direct new-file upload and SHA-256 verification — planned delta

Contract and connected acceptance: [direct-upload integrity plan](../../../../Project2026/nict-editing-studio-app/docs/notes/direct-upload-integrity-plan.md).

TFAF-TKL01 binds Core verification states. TFAF-TKL02 presents hashing/preparation, byte transfer, server verification, registration and integrity failure separately from Editing Studio acknowledgement. TFAF-TKL03 tests truthful progress/actions and secret redaction. No Google login for the selected server-service-account route; retain user-delegated sign-in only for routes requiring it. UI does not compute trust or finalize registration.

- [ ] Implement the owning DU items and affected contract/behavior specifications.
- [ ] Hand off actual evidence and limitations; this planning addition claims no implementation, live upload or Phase closure.
