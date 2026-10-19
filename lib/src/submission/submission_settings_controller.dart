import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'submission_configuration_facade.dart';

/// Borrows configuration. Owners await [detach] before closing its store.
final class SubmissionSettingsController extends ChangeNotifier {
  SubmissionSettingsController({required this._facade});

  final SubmissionConfigurationFacade _facade;
  SubmissionConfigurationSnapshot? _snapshot;
  final Map<String, SubmissionAuthorizationState> _authorizationStates = {};
  final List<(VoidCallback, VoidCallback)> _listeners = [];
  Completer<bool>? _pending;
  Future<void>? _detachment;
  bool _loading = false;
  bool _detached = false;
  bool _disposed = false;
  bool _configurationMayHaveChanged = false;
  int _notificationDepth = 0;
  SubmissionConfigurationException? _failure;

  SubmissionConfigurationSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  bool get busy => _pending != null;
  bool get failed => _failure != null;
  bool get isDetached => _detached;
  String? get failureCode => _failure?.code;
  String? get failureMessage => _failure?.message;
  bool get hasDriveAuthorization => _facade.hasDriveAuthorization;
  bool get hasHttpCredentialWriter => _facade.hasHttpCredentialWriter;
  bool get configurationMayHaveChanged => _configurationMayHaveChanged;
  Map<String, SubmissionAuthorizationState> get authorizationStates =>
      Map<String, SubmissionAuthorizationState>.unmodifiable(
        _authorizationStates,
      );

  Future<bool> load() => _accept(() async {
    final value = await _facade.snapshot();
    if (_detached) return false;
    _snapshot = value;
    return true;
  }, loading: true);

  Future<bool> putDrive(DriveSubmissionConnection connection) =>
      _write(() => _facade.putDrive(connection));

  Future<bool> putHttp(HttpSubmissionConnection connection) =>
      _write(() => _facade.putHttp(connection));

  Future<bool> select({
    String? storageConnectionId,
    String? transportConnectionId,
  }) => _write(
    () => _facade.select(
      storageConnectionId: storageConnectionId,
      transportConnectionId: transportConnectionId,
    ),
  );

  Future<bool> setReferenceAccess({
    required String transportConnectionId,
    required List<String> storageConnectionIds,
  }) {
    return _accept(() async {
      final ids = List<String>.unmodifiable(storageConnectionIds);
      if (_detached) return false;
      _configurationMayHaveChanged = true;
      await _facade.setReferenceAccess(
        transportConnectionId: transportConnectionId,
        storageConnectionIds: ids,
      );
      if (_detached) return false;
      final value = await _facade.snapshot();
      if (_detached) return false;
      _snapshot = value;
      return true;
    });
  }

  Future<bool> _write(Future<void> Function() write) => _accept(() async {
    _configurationMayHaveChanged = true;
    await write();
    if (_detached) return false;
    final value = await _facade.snapshot();
    if (_detached) return false;
    _snapshot = value;
    return true;
  });

  Future<bool> refreshAuthorization(String id) =>
      _authorization(id, interactive: false);

  Future<bool> authorizeDrive(String id) =>
      _authorization(id, interactive: true);

  Future<bool> _authorization(
    String id, {
    required bool interactive,
  }) => _accept(() async {
    if (interactive) _configurationMayHaveChanged = true;
    final value = await (interactive
        ? _facade.authorizeDrive(id)
        : _facade.authorizationState(id));
    if (_detached) return false;
    // Given a current configured Drive ID, When matching the observed target,
    // Then publish only its literal authorization enum.
    if (_snapshot?.driveConnections.any((connection) => connection.id == id) !=
        true) {
      return false;
    }
    _authorizationStates[id] = value;
    return true;
  });

  Future<bool> setHttpBearerToken(String id, String? token) =>
      _accept(() async {
        _configurationMayHaveChanged = true;
        await _facade.setHttpBearerToken(id, token);
        return !_detached;
      });

  Future<bool> _accept(
    Future<bool> Function() operation, {
    bool loading = false,
  }) {
    if (_detached || busy) return Future<bool>.value(false);
    final completion = Completer<bool>();
    _pending = completion;
    _loading = loading;
    _failure = null;
    _notify();
    // Given a reserved operation, When listeners retire its owner,
    // Then the operation must not dispatch any borrowed Core call.
    Future<void> run() async {
      var success = false;
      try {
        if (!_detached) success = await operation();
      } catch (error) {
        if (!_detached) {
          _failure = error is SubmissionConfigurationException
              ? error
              : SubmissionConfigurationException.safe(
                  error is ArgumentError
                      ? 'configurationInvalid'
                      : 'configurationUnavailable',
                );
        }
      } finally {
        _pending = null;
        _loading = false;
        completion.complete(success && !_detached);
        _notify();
      }
    }

    unawaited(run());
    return completion.future;
  }

  Future<void> detach() {
    _detached = true;
    // Given a retired owner, When accepted work completes, Then finish only its join.
    return _detachment ??= (_pending?.future ?? Future<bool>.value(false))
        .then<void>((_) {});
  }

  @override
  void addListener(VoidCallback listener) {
    // Given a live subscriber, When notification reentrantly retires the owner,
    // Then remaining listeners receive no retired publication.
    void guarded() {
      if (!_detached) listener();
    }

    if (_detached) return;
    _listeners.add((listener, guarded));
    super.addListener(guarded);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_disposed) return;
    // Given borrowed listener identity, When unsubscribing, Then remove only its registration.
    final index = _listeners.indexWhere((entry) => entry.$1 == listener);
    if (index >= 0) super.removeListener(_listeners.removeAt(index).$2);
  }

  void _notify() {
    if (_detached) return;
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(detach());
    _disposed = true;
    _listeners.clear();
    if (_notificationDepth == 0) super.dispose();
  }
}
