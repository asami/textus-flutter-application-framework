import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'user_account_authentication_facade.dart';

/// A bounded credential surface borrowing its explicitly supplied facade.
class UserAccountAuthenticationPanel extends StatefulWidget {
  const UserAccountAuthenticationPanel({required this.facade, super.key});

  final UserAccountAuthenticationFacade facade;

  @override
  State<UserAccountAuthenticationPanel> createState() =>
      _UserAccountAuthenticationPanelState();
}

class _UserAccountAuthenticationPanelState
    extends State<UserAccountAuthenticationPanel> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _localFailure;
  int _generation = 0;
  int _latestAction = 0;

  @override
  void initState() {
    super.initState();
    widget.facade.addListener(_changed);
  }

  @override
  void didUpdateWidget(UserAccountAuthenticationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.facade, widget.facade)) {
      oldWidget.facade.removeListener(_changed);
      _generation++;
      _latestAction++;
      _identifier.clear();
      _clearSensitive();
      _localFailure = null;
      widget.facade.addListener(_changed);
    }
  }

  void _clearSensitive() {
    _password.clear();
    _code.clear();
  }

  void _changed() {
    if (!mounted) return;
    _clearSensitive();
    setState(() => _localFailure = null);
  }

  bool _attached(UserAccountAuthenticationFacade facade) =>
      mounted && identical(facade, widget.facade);

  Future<void> _perform(
    UserAccountAuthenticationFacade facade,
    Future<void> Function() invoke,
  ) async {
    if (!_attached(facade)) return;
    final generation = _generation;
    final action = ++_latestAction;
    setState(() => _localFailure = null);
    bool current() =>
        _attached(facade) &&
        generation == _generation &&
        action == _latestAction;
    try {
      await invoke();
    } catch (_) {
      if (current()) {
        setState(() => _localFailure = '操作を完了できませんでした。もう一度お試しください。');
      }
    }
    if (current()) setState(() {});
  }

  void _signIn(UserAccountAuthenticationFacade facade) {
    if (!_attached(facade) || !facade.canSignIn) return;
    final identifier = _identifier.text;
    final password = _password.text;
    _password.clear();
    _perform(
      facade,
      () => facade.signIn(identifier: identifier, password: password),
    );
  }

  void _verify(UserAccountAuthenticationFacade facade) {
    if (!_attached(facade) || !facade.canVerifyChallenge) return;
    final code = _code.text;
    _code.clear();
    _perform(facade, () => facade.verifyChallenge(code));
  }

  void _cancel(UserAccountAuthenticationFacade facade) {
    if (!_attached(facade) || !facade.canCancel) return;
    _clearSensitive();
    _perform(facade, facade.cancel);
  }

  void _signOut(UserAccountAuthenticationFacade facade) {
    if (!_attached(facade) || !facade.canSignOut) return;
    _clearSensitive();
    _perform(facade, () async {
      await facade.signOut();
    });
  }

  @override
  void dispose() {
    widget.facade.removeListener(_changed);
    _generation++;
    _latestAction++;
    for (final controller in [_identifier, _password, _code]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facade = widget.facade;
    final snapshot = facade.snapshot;
    final account = snapshot.isAuthenticated ? snapshot.account : null;
    final logout = snapshot.lastLogoutResult;
    final logoutFailed = logout?.localCleared == false;
    final showLogout = account != null || logoutFailed;
    final unavailable =
        snapshot.status == UserAccountAuthenticationStatus.unavailable ||
        snapshot.failure == UserAccountAuthenticationFailure.notConfigured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('アカウント', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (unavailable) const Text('ログインの接続を準備中です。'),
        if (facade.isClosed) const Text('アカウント画面を終了しました。'),
        if (account != null) ...[
          Text(
            account.displayName?.trim().isNotEmpty == true
                ? account.displayName!
                : account.userAccountId,
          ),
          Text('アカウントID: ${account.userAccountId}'),
        ],
        if (facade.canSignIn && !unavailable) ...[
          TextField(
            controller: _identifier,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'ログインID'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'パスワード'),
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              FilledButton(
                onPressed: () => _signIn(facade),
                child: const Text('ログイン'),
              ),
            ],
          ),
        ],
        if (snapshot.status ==
            UserAccountAuthenticationStatus.challengeRequired) ...[
          const Text('メールに届いた確認コードを入力してください。'),
          TextField(
            controller: _code,
            enabled: facade.canVerifyChallenge,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: '確認コード'),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: facade.canVerifyChallenge
                    ? () => _verify(facade)
                    : null,
                child: const Text('確認する'),
              ),
            ],
          ),
        ],
        if (facade.busy) ...[
          const SizedBox(height: 12),
          const Text('処理中です。しばらくお待ちください。'),
        ],
        if (facade.canCancel || showLogout)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (facade.canCancel)
                TextButton(
                  onPressed: () => _cancel(facade),
                  child: const Text('キャンセル'),
                ),
              if (showLogout)
                TextButton(
                  onPressed: facade.canSignOut ? () => _signOut(facade) : null,
                  child: Text(logoutFailed ? 'ログアウトを再試行' : 'ログアウト'),
                ),
            ],
          ),
        if (!facade.busy && !facade.isClosed && !unavailable) ...[
          if (logout != null &&
              (logoutFailed ||
                  snapshot.status == UserAccountAuthenticationStatus.signedOut))
            Text(_logoutCopy(logout))
          else if (snapshot.failure != null)
            Text(_failureCopy(snapshot.failure!)),
        ],
        if (_localFailure != null) Text(_localFailure!),
      ],
    );
  }
}

String _logoutCopy(UserAccountLogoutResult result) {
  if (!result.localCleared) {
    return 'この端末のログアウトを完了できませんでした。もう一度ログアウトしてください。';
  }
  return switch (result.remoteRevocation) {
    UserAccountRemoteRevocation.confirmed => 'ログアウトしました。',
    UserAccountRemoteRevocation.notAttempted => 'この端末からログアウトしました。',
    UserAccountRemoteRevocation.failed || UserAccountRemoteRevocation.unknown =>
      'この端末からログアウトしました。サーバー側の失効は確認できていません。',
  };
}

String _failureCopy(UserAccountAuthenticationFailure failure) =>
    switch (failure) {
      UserAccountAuthenticationFailure.notConfigured => 'ログインの接続を準備中です。',
      UserAccountAuthenticationFailure.invalidCredentials =>
        'ログインIDまたはパスワードを確認してください。',
      UserAccountAuthenticationFailure.authorizationRequired =>
        'もう一度ログインしてください。',
      UserAccountAuthenticationFailure.challengeRejected =>
        '確認コードを確認して、もう一度ログインしてください。',
      UserAccountAuthenticationFailure.cancelled => 'ログインをキャンセルしました。',
      UserAccountAuthenticationFailure.serviceUnavailable =>
        'ログインサービスを利用できません。しばらくしてからお試しください。',
      UserAccountAuthenticationFailure.transportUnavailable =>
        '接続できません。通信環境を確認してお試しください。',
      UserAccountAuthenticationFailure.invalidResponse =>
        'ログイン結果を確認できませんでした。もう一度お試しください。',
    };
