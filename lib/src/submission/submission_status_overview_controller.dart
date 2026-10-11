import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'submission_facade.dart';
import 'submission_status_summary.dart';

/// Explicit fresh observations; owns no Core ports, polling or execution.
final class SubmissionStatusOverviewController extends ChangeNotifier {
  SubmissionStatusOverviewController({
    required this._facade,
    DateTime Function()? now,
    SubmissionNetworkState Function()? networkState,
  }) : _now = now ?? DateTime.now,
       _networkState = networkState ?? _unknownNetwork;

  final SubmissionFacade _facade;
  final DateTime Function() _now;
  final SubmissionNetworkState Function() _networkState;
  final List<(VoidCallback, VoidCallback)> _listeners = [];
  Completer<bool>? _pending;
  Future<void>? _detachment;
  SubmissionStatusSummary? _summary;
  bool _failed = false;
  bool _detached = false;
  bool _disposed = false;
  int _notificationDepth = 0;

  SubmissionStatusSummary? get summary => _summary;
  bool get loading => _pending != null;
  bool get failed => _failed;
  bool get isDetached => _detached;

  static SubmissionNetworkState _unknownNetwork() =>
      SubmissionNetworkState.unknown;

  Future<bool> load() {
    if (_detached || loading) return Future<bool>.value(false);
    final completion = Completer<bool>();
    _pending = completion;
    _summary = null;
    _failed = false;
    _notify();
    // Given a reserved refresh, When external observation callbacks retire it,
    // Then no subsequent callback, Core read or result publication may occur.
    Future<void> run() async {
      var success = false;
      try {
        if (_detached) return;
        final time = _now();
        if (_detached) return;
        final network = _networkState();
        if (_detached) return;
        final statuses = await _facade.listTransferStatuses(
          observedAt: time,
          networkState: network,
        );
        if (_detached) return;
        final value = SubmissionStatusSummary.fromStatuses(statuses);
        if (_detached) return;
        _summary = value;
        success = true;
      } catch (_) {
        if (!_detached) _failed = true;
      } finally {
        _pending = null;
        completion.complete(success && !_detached);
        _notify();
      }
    }

    unawaited(run());
    return completion.future;
  }

  Future<void> detach() {
    _detached = true;
    // Given a retired overview, When accepted query work settles, Then join only.
    return _detachment ??= (_pending?.future ?? Future<bool>.value(false))
        .then<void>((_) {});
  }

  @override
  void addListener(VoidCallback listener) {
    // Given an owner notification, When another listener retires it,
    // Then this listener receives only current observations.
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
