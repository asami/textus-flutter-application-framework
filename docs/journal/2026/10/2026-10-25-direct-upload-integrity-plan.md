# Direct-upload integrity development plan

Status: planned; no implementation or live acceptance performed.

The user requested a plan for server-authorized new-file direct upload into an
allowed Drive folder, followed by independent content-hash verification. The
selected route uses backend service-account credentials and per-file resumable
URLs, never a general Google token on the phone.

TFAF-TKL01 binds Core verification states. TFAF-TKL02 presents hashing/preparation, byte transfer, server verification, registration and integrity failure separately from Editing Studio acknowledgement. TFAF-TKL03 tests truthful progress/actions and secret redaction. No Google login for the selected server-service-account route; retain user-delegated sign-in only for routes requiring it. UI does not compute trust or finalize registration.

[Contract, sequence and pending acceptance](../../../../../../Project2026/nict-editing-studio-app/docs/notes/direct-upload-integrity-plan.md).

Existing App Phase 6.3/direct-provider work is reused. Current tests and live
observations do not by themselves prove SHA-256 validation. No active worktree,
queue, credentials, deployment, live allowance, commit or release was changed
by this documentation update.
