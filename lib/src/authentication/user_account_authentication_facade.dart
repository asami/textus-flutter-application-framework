import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Safe presentation commands borrowing Core's authentication authority.
class UserAccountAuthenticationFacade extends ChangeNotifier {
  UserAccountAuthenticationFacade({
    required UserAccountAuthenticationClient client,
    bool ownsClient = false,
    // Preserve the public named argument while retaining the client privately.
    // ignore: prefer_initializing_formals
  }) : _client = client,
       // Preserve the public ownership option without exposing stored state.
       // ignore: prefer_initializing_formals
       _ownsClient = ownsClient {
    _client.addListener(_changed);
  }

  final UserAccountAuthenticationClient _client;
  final bool _ownsClient;
  UserAccountAuthenticationSnapshot? _closedSnapshot;
  Future<void>? _closeFuture;
  bool _disposeRequested = false;
  bool _notifierDisposed = false;
  int _notificationDepth = 0;

  UserAccountAuthenticationSnapshot get snapshot =>
      _closedSnapshot ?? _client.snapshot;
  bool get isClosed => _closedSnapshot != null || _client.isClosed;
  bool get busy => !isClosed && _client.busy;

  bool get _configured =>
      !isClosed &&
      snapshot.status != UserAccountAuthenticationStatus.unavailable;

  bool get canSignIn =>
      _configured &&
      !busy &&
      snapshot.lastLogoutResult?.localCleared != false &&
      (snapshot.status == UserAccountAuthenticationStatus.signedOut ||
          snapshot.status == UserAccountAuthenticationStatus.failure);
  bool get canVerifyChallenge =>
      _configured &&
      !busy &&
      snapshot.status == UserAccountAuthenticationStatus.challengeRequired;
  bool get canRefresh => _configured && !busy && snapshot.isAuthenticated;
  bool get canRestore => !isClosed && _client.canRestore;
  bool get canCancel =>
      _configured &&
      (snapshot.status == UserAccountAuthenticationStatus.signingIn ||
          snapshot.status == UserAccountAuthenticationStatus.refreshing ||
          snapshot.status == UserAccountAuthenticationStatus.challengeRequired);
  bool get canSignOut =>
      _configured &&
      snapshot.status != UserAccountAuthenticationStatus.cancelling &&
      snapshot.status != UserAccountAuthenticationStatus.signingOut;

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    _require(canSignIn);
    await _client.signIn(identifier: identifier, password: password);
    _changed();
  }

  Future<void> verifyChallenge(String code) async {
    _require(canVerifyChallenge);
    await _client.verifyChallenge(code);
    _changed();
  }

  Future<void> refresh() async {
    _require(canRefresh);
    await _client.refresh();
    _changed();
  }

  /// Explicit owner action; construction and account presentation remain inert.
  Future<void> restore() async {
    _require(canRestore);
    await _client.restore();
    _changed();
  }

  Future<void> cancel() async {
    _require(canCancel);
    await _client.cancel();
    _changed();
  }

  Future<UserAccountLogoutResult> signOut() async {
    _require(canSignOut);
    final result = await _client.signOut();
    _changed();
    return result;
  }

  void _require(bool allowed) {
    if (!allowed) {
      throw StateError('Authentication command is not available');
    }
  }

  /// Withdraws presentation immediately, without implicitly logging out.
  Future<void> close() => _beginClose(notify: true);

  Future<void> _beginClose({required bool notify}) {
    final existing = _closeFuture;
    if (existing != null) return existing;
    final completion = Completer<void>();
    _closeFuture = completion.future;
    unawaited(completion.future.then<void>((_) {}, onError: (Object _) {}));
    final revision = snapshot.revision;
    _client.removeListener(_changed);
    _closedSnapshot = UserAccountAuthenticationSnapshot(
      status: UserAccountAuthenticationStatus.closed,
      revision: revision + 1,
    );
    if (notify) _notify();
    unawaited(_closeOwnedClient(completion));
    return completion.future;
  }

  Future<void> _closeOwnedClient(Completer<void> completion) async {
    try {
      if (_ownsClient) await _client.close();
      completion.complete();
    } catch (_) {
      completion.completeError(StateError('Authentication close failed'));
    }
  }

  void _changed() {
    if (_closedSnapshot != null) return;
    _notify();
  }

  void _notify() {
    if (_disposeRequested || _notifierDisposed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
      _disposeNotifierWhenIdle();
    }
  }

  // The helper calls super.dispose exactly once after reentrant notifications.
  @override
  // ignore: must_call_super
  void dispose() {
    if (_disposeRequested) return;
    _disposeRequested = true;
    unawaited(_beginClose(notify: false));
    _disposeNotifierWhenIdle();
  }

  void _disposeNotifierWhenIdle() {
    if (_disposeRequested && !_notifierDisposed && _notificationDepth == 0) {
      _notifierDisposed = true;
      super.dispose();
    }
  }
}
