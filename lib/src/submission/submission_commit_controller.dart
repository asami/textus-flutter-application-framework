import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Owner validity only; neither execution consent nor cancellation authority.
final class SubmissionCommitInvocation {
  SubmissionCommitInvocation._();

  bool _current = true;
  bool get isCurrent => _current;
}

/// The App callback flushes edits, checks validity after awaits and before Commit,
/// validates its domain and freezes originals/provenance. This owner borrows it.
final class SubmissionCommitController extends ChangeNotifier {
  SubmissionCommitController({required this._commit});

  final Future<SubmissionCommitResult> Function(SubmissionCommitInvocation)
  _commit;
  final List<(VoidCallback, VoidCallback)> _listeners = [];
  Completer<bool>? _pending;
  SubmissionCommitInvocation? _invocation;
  SubmissionCommitResult? _result;
  Future<void>? _detachment;
  bool _failed = false;
  bool _detached = false;
  bool _disposed = false;
  int _notificationDepth = 0;

  bool get busy => _pending != null;
  bool get isDetached => _detached;
  SubmissionCommitResult? get result => _result;
  bool get failed => _failed;
  String? get failureMessage => _failed ? 'Could not queue submission.' : null;

  Future<bool> commit() {
    if (_detached || busy) return Future<bool>.value(false);
    final completion = Completer<bool>();
    final invocation = SubmissionCommitInvocation._();
    _pending = completion;
    _invocation = invocation;
    _result = null;
    _failed = false;
    _notify();
    // Given reserved current intent, When notifying can reentrantly detach,
    // Then only the still-current invocation may enter the App callback once.
    Future<void> run() async {
      var success = false;
      try {
        if (invocation.isCurrent) {
          final value = await _commit(invocation);
          if (invocation.isCurrent) {
            _result = value;
            success = true;
          }
        }
      } catch (_) {
        if (invocation.isCurrent) _failed = true;
      } finally {
        _pending = null;
        completion.complete(success && invocation.isCurrent);
        invocation._current = false;
        _invocation = null;
        _notify();
      }
    }

    unawaited(run());
    return completion.future;
  }

  Future<void> detach() {
    _detached = true;
    _invocation?._current = false;
    // Given retired callback ownership, When accepted work settles, Then join only.
    return _detachment ??= (_pending?.future ?? Future<bool>.value(false))
        .then<void>((_) {});
  }

  @override
  void addListener(VoidCallback listener) {
    // Given subscribers, When one retires the owner during notification,
    // Then subsequent callbacks cannot publish obsolete state.
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
