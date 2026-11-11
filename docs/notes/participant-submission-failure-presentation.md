# Participant submission failure presentation

`submissionFailureLabel` presents the closed safe codes produced by Core's
Studio v2 transport and persisted by the handoff owner. The producer authority
is Studio commit `1a309691c0a0a62ba53d3bab6875a4bd69a3b7c5`,
`docs/spec/participant-japanese-error-presentation-v1.md`. Framework does not
parse server messages or infer causes from arbitrary numeric/string codes.

| Safe code pair | Fixed Japanese guidance |
| --- | --- |
| studioInputInvalid / studioHttp400 | 入力内容を確認してください。原本と保存済みの送信内容は保持されています。 |
| studioAuthenticationRequired / studioHttp401 | ログインが必要です。もう一度ログインしてください。 Followed by the account-safe guidance below. |
| studioPermissionDenied / studioHttp403 | この操作を行う権限を確認できません。再試行を繰り返さず担当者に相談してください。 |
| studioNotFound / studioHttp404 | 対象が見つからないか、表示できません。一覧に戻って確認してください。 |
| studioConflict / studioHttp409 | 処理を完了できませんでした。入力内容と現在の状態を確認してください。原本と入力内容は保持されています。元の操作とその結果、保存済みの状態を確認してください。 |
| studioHttpUnknown | 処理できませんでした。時間をおいて再度お試しください。まず保存済みの送信結果を確認してください。 |

For 401 with an immutable authentication binding, the suffix is
「この保存済みの送信に対応するアカウントを使用してください。原本と入力内容を保持し、送信状況を確認してください。」
Without a binding it is
「以前の送信内容にはアカウント情報がありません。原本と入力内容を保持し、送信状況と接続設定を担当者に確認してください。」
The binding is a saved-intent fact, not proof of a current login or permission
to use another account. Existing operator/configuration safety remains intact.

Labels are informational. They do not modify buttons, available actions,
authentication state, ownership, ACK/outcome classification or reconciliation.
404 does not distinguish another owner's target from a nonexistent target.
409 does not imply an external edit, an update operation or blind replay.
Unknown failure guidance requires checking the saved result; no automatic send
is added. Existing explicit-reconciliation warnings remain visible through the
ordinary `SubmissionStatusPage` and App workspace route.

The App consumer authors connected persisted-code/UI scenarios at 390 × 844.
Host qualification and independent focused Step review have passed for this
bounded integration; these labels alone establish no server, actual-device or
whole-Phase acceptance.
