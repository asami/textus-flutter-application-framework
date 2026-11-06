/// Fixed presentation of a safe failure code and an immutable local intent fact.
/// Neither value establishes a current login, ownership or permission to retry.
String submissionFailureLabel(
  String? code, {
  required bool hasAuthenticationBinding,
}) => switch (code) {
  null => '',
  'studioInputInvalid' ||
  'studioHttp400' => '入力内容を確認してください。原本と保存済みの送信内容は保持されています。',
  'studioAuthenticationRequired' ||
  'studioHttp401' =>
    hasAuthenticationBinding
        ? 'ログインが必要です。もう一度ログインしてください。この保存済みの送信に対応するアカウントを使用してください。原本と入力内容を保持し、送信状況を確認してください。'
        : 'ログインが必要です。もう一度ログインしてください。以前の送信内容にはアカウント情報がありません。原本と入力内容を保持し、送信状況と接続設定を担当者に確認してください。',
  'studioPermissionDenied' ||
  'studioHttp403' => 'この操作を行う権限を確認できません。再試行を繰り返さず担当者に相談してください。',
  'studioNotFound' ||
  'studioHttp404' => '対象が見つからないか、表示できません。一覧に戻って確認してください。',
  'studioConflict' ||
  'studioHttp409' => '処理を完了できませんでした。入力内容と現在の状態を確認してください。原本と入力内容は保持されています。元の操作とその結果、保存済みの状態を確認してください。',
  'studioHttpUnknown' => '処理できませんでした。時間をおいて再度お試しください。まず保存済みの送信結果を確認してください。',
  'authenticationRequired' =>
    hasAuthenticationBinding
        ? 'この資料の送信に対応するアカウントでログインしてください。解消しない場合は担当者に接続設定を確認してください。'
        : '以前の送信内容にはアカウント情報がありません。原本を保持して担当者に確認してください。',
  'authRequired' =>
    hasAuthenticationBinding
        ? 'ログイン状態を確認してください。送信結果は送信状況で確認できます。'
        : '送信に必要な認証を確認できません。担当者に接続設定を確認してください。',
  'credentialUnavailable' => '認証情報を読み取れません。アカウントの状態を確認してください。',
  'operationCancelled' => '処理を中断しました。送信状況を確認してください。',
  'operationTimeout' => '応答を確認できませんでした。送信状況を確認してください。',
  'connectionFailed' ||
  'serviceUnavailable' ||
  'rateLimited' => '接続できませんでした。通信環境と送信状況を確認してください。',
  'permissionDenied' ||
  'handoffRejected' => '送信先が処理を受け付けませんでした。アカウントと権限を確認してください。',
  'handoffNotSent' => '今回のStudioへの送信は開始できませんでした。接続とログイン状態を確認してください。',
  'acceptanceUnknown' ||
  'runRetired' ||
  'acknowledgementMismatch' => '受領結果を確認できません。原本と送信内容は保持されています。送信状況の照合が必要です。',
  'integrityMismatch' ||
  'verificationUnavailable' ||
  'integrityUpgradeRequired' => '原本の整合性を確認できません。原本は保持されています。担当者に確認してください。',
  _ => '処理を完了できませんでした。原本と送信状況を確認してください。',
};
