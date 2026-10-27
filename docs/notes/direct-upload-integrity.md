# Direct-upload content integrity

Status: planned; not accepted.

TFAF-TKL01 binds Core verification states. TFAF-TKL02 presents hashing/preparation, byte transfer, server verification, registration and integrity failure separately from Editing Studio acknowledgement. TFAF-TKL03 tests truthful progress/actions and secret redaction. No Google login for the selected server-service-account route; retain user-delegated sign-in only for routes requiring it. UI does not compute trust or finalize registration.

Canonical cross-project contract: [plan](../../../../Project2026/nict-editing-studio-app/docs/notes/direct-upload-integrity-plan.md).

SHA-256 here verifies transferred binary content only. Do not use it for update
tracking, management-state identity or unchanged-input certification. Preserve
existing runtime work and completed evidence; implement only the remaining delta.
