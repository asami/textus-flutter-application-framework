# Submission authentication guidance

Core reports durable submission facts; TFAF presents those facts with fixed
Japanese guidance. This contract is part of the connected Phase 6.10
`ESA610-UA-SUBMISSION-001` Step. It does not establish native, server or whole
Phase acceptance.

## Responsibility and authority

`SubmissionTransferStatus.hasAuthenticationBinding` is true exactly when the
immutable local `SubmissionRequest.authenticationBinding` is present. Both the
ordinary and TKL projections derive it from that same saved request. A separate
Studio handoff must match the Registered source before projection. The flag is
part of status value equality and hashing, with all previous facts preserved.

The flag reveals no account ID, authority URI, credential or token. It does not
assert that a user is currently logged in, that the server accepts the authority,
that the user owns the remote Material, or that dispatch or retry is permitted.
Network observations, failure codes and acknowledgements cannot add or remove a
saved binding. UI display cannot grant authentication or mutate queue intent.

The internal `submissionFailureLabel` uses only a failure code and this observed
flag. It never renders a raw adapter message, exception, account value or endpoint
as failure guidance. An absent failure produces an empty string. Unknown codes
use fixed generic Japanese text. Consumer item labels and other user content
remain unchanged.

## Fixed Japanese guidance

| Failure code | Local binding | Guidance |
| --- | --- | --- |
| `authenticationRequired` | Present | この資料の送信に対応するアカウントでログインしてください。解消しない場合は担当者に接続設定を確認してください。 |
| `authenticationRequired` | Absent | 以前の送信内容にはアカウント情報がありません。原本を保持して担当者に確認してください。 |
| `authRequired` | Present | ログイン状態を確認してください。送信結果は送信状況で確認できます。 |
| `authRequired` | Absent | 送信に必要な認証を確認できません。担当者に接続設定を確認してください。 |
| `credentialUnavailable` | Either | 認証情報を読み取れません。アカウントの状態を確認してください。 |
| `operationCancelled` | Either | 処理を中断しました。送信状況を確認してください。 |
| `operationTimeout` | Either | 応答を確認できませんでした。送信状況を確認してください。 |
| `connectionFailed`, `serviceUnavailable`, `rateLimited` | Either | 接続できませんでした。通信環境と送信状況を確認してください。 |
| `permissionDenied`, `handoffRejected` | Either | 送信先が処理を受け付けませんでした。アカウントと権限を確認してください。 |
| `handoffNotSent` | Either | 今回のStudioへの送信は開始できませんでした。接続とログイン状態を確認してください。 |
| `acceptanceUnknown`, `runRetired`, `acknowledgementMismatch` | Either | 受領結果を確認できません。原本と送信内容は保持されています。送信状況の照合が必要です。 |
| `integrityMismatch`, `verificationUnavailable`, `integrityUpgradeRequired` | Either | 原本の整合性を確認できません。原本は保持されています。担当者に確認してください。 |
| Any other non-null code | Either | 処理を完了できませんでした。原本と送信状況を確認してください。 |

Logging in does not adopt an old unbound intent. The unbound guidance therefore
keeps originals and asks the operator for help; it makes no promise that another
login or resend repairs the row. Bound guidance also does not promise that login
alone resolves server trust, target setup or ownership.

## Existing selection and interaction remain authoritative

Resource values retain their existing failure precedence: upload uses the
upload failure; TKL without a handoff uses the registration failure; otherwise a
handoff failure precedes the submission failure. The page supplement uses the
same function for its actual handoff failure. Existing TKL integrity-specific
instructions and transfer-route labels remain unchanged.

This presentation adds no login command, automatic retry, adoption, rebind,
queue transition, consent or network activity. Existing status/action factories,
fresh command checks, counts, lease facts and matching acknowledgements continue
to determine behavior. In particular, TKL registration is separate from Studio
acceptance. Unknown reception remains unknown, and the existing reconciliation
notice still explains that replay may send a previously unreceived request.

## Executable specification and remaining gates

Core specifications project ordinary/TKL bound and unbound records, codec
round trips, real SQLite reopening and a separate persisted Registered handoff.
They check independence from network observations, failure, uncertainty and
actual acknowledgement, plus value semantics and unchanged actions/counts.

TFAF specifications use genuine Core status values and the actual resource and
page composition. They cover the label matrix, upload/submission precedence,
absent failures, unknown codes with synthetic private diagnostics, immutable
item text, strict acknowledgement/uncertainty and passive rendering without
dispatch, wake or automatic reconciliation.

Parent validation and the complete connected Step's independent protected review
remain required. App/root activation, physical Android/iPhone verification,
producer authentication and Material ownership contracts, the original UC/MS/SB
and demonstration requirements, full Phase validation, its sole full review and
release are separate remaining gates.
