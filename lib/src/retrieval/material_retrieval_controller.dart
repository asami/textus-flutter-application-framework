import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

enum MaterialRetrievalStatus {
  idle, loading, ready, empty, resolving, rebuilding, canceled, unavailable, error,
}

/// One query owner. The service, corpus and storage remain caller-owned.
final class MaterialRetrievalController extends ChangeNotifier {
  MaterialRetrievalController({required this._service});

  final MaterialRetrievalService _service;
  final Map<VoidCallback, List<VoidCallback>> _listeners = {};
  String _query = '';
  MaterialRetrievalResult? _result;
  MaterialRetrievalResolution? _resolution;
  Object? _error;
  MaterialRetrievalStatus _status = MaterialRetrievalStatus.idle;
  bool _rebuildCompleted = false;
  bool _closed = false;
  bool _disposed = false;
  bool _notifierDisposed = false;
  int _notificationDepth = 0;
  int _generation = 0;
  int _resultVersion = 0;
  _RetrievalCommand? _active;
  Future<void>? _detachment;

  String get query => _query;
  MaterialRetrievalResult? get result => _result;
  MaterialRetrievalResolution? get resolution => _resolution;
  Object? get error => _error;
  MaterialRetrievalStatus get status => _status;
  bool get rebuildCompleted => _rebuildCompleted;
  bool get busy => _active != null;
  bool get canSearch => !_closed && !busy && _query.trim().isNotEmpty;
  bool get canCancel => !_closed && _active != null &&
      !_active!.cancellation.isCanceled;
  bool get isClosed => _closed;
  int get resultVersion => _resultVersion;

  void setQuery(String value) {
    if (_closed || value == _query) {
      return;
    }
    _query = value;
    _generation++;
    _active?.cancellation.cancel();
    _clearResult();
    _status = MaterialRetrievalStatus.idle;
    _notify();
  }

  Future<void> search() async {
    if (!canSearch) {
      return;
    }
    _clearResult();
    final command = _reserve(MaterialRetrievalStatus.loading);
    await _execute(command, () async {
      // Capability access is a public callback boundary, too.
      _service.capability;
      if (!_owns(command)) {
        return;
      }
      final query = MaterialRetrievalQuery(command.query);
      final value = await _service.search(query,
        cancellation: command.cancellation);
      if (!_owns(command)) {
        return;
      }
      _result = value;
      _status = value.hits.isEmpty
          ? MaterialRetrievalStatus.empty : MaterialRetrievalStatus.ready;
    });
  }

  /// Retires only this owner's token, retaining busy until its original IO ends.
  void cancel() {
    if (!canCancel) {
      return;
    }
    _generation++;
    _active!.cancellation.cancel();
    _clearResult();
    _status = MaterialRetrievalStatus.canceled;
    _notify();
  }

  bool _admitsHit(MaterialRetrievalHit hit) => !_closed && _result != null &&
      _resolution?.status != MaterialRetrievalResolutionStatus.stale &&
      _resolution?.status != MaterialRetrievalResolutionStatus.unavailable &&
      _result!.query.text == _query &&
      _result!.hits.any((candidate) => identical(candidate, hit));

  Future<MaterialRetrievalResolution?> resolveHit(MaterialRetrievalHit hit) async {
    if (busy || !_admitsHit(hit)) {
      return null;
    }
    final result = _result;
    final command = _reserve(MaterialRetrievalStatus.resolving);
    MaterialRetrievalResolution? resolved;
    await _execute(command, () async {
      if (!_owns(command) || !identical(result, _result) ||
          command.resultVersion != _resultVersion || !_admitsHit(hit)) {
        return;
      }
      final value = await _service.resolve(hit,
        cancellation: command.cancellation);
      if (!_owns(command) || !identical(result, _result) ||
          command.resultVersion != _resultVersion) {
        return;
      }
      // An available response cannot grant a different source address/value.
      if (value.status == MaterialRetrievalResolutionStatus.available &&
          value.document != hit.document) {
        throw StateError('Available resolution changed the selected source');
      }
      _resolution = value;
      if (value.status == MaterialRetrievalResolutionStatus.unavailable) {
        // Unavailable includes denied access: retain no formerly readable text.
        _result = null;
        _resultVersion++;
      }
      _status = value.status == MaterialRetrievalResolutionStatus.unavailable
          ? MaterialRetrievalStatus.unavailable : MaterialRetrievalStatus.ready;
      resolved = value;
    });
    // Completion listeners may change query, close, or start a newer command.
    if (!_matches(command) || busy || command.resultVersion != _resultVersion ||
        !identical(result, _result) || !_admitsHit(hit) ||
        resolved?.status != MaterialRetrievalResolutionStatus.available) {
      return null;
    }
    return resolved;
  }

  Future<void> rebuild() async {
    if (_closed || busy) {
      return;
    }
    _clearResult();
    final command = _reserve(MaterialRetrievalStatus.rebuilding);
    await _execute(command, () async {
      await _service.rebuild(cancellation: command.cancellation);
      if (_owns(command)) {
        _rebuildCompleted = true;
        _status = MaterialRetrievalStatus.idle;
      }
    });
  }

  void _clearResult() {
    _resultVersion++;
    _result = null;
    _resolution = null;
    _error = null;
    _rebuildCompleted = false;
  }

  _RetrievalCommand _reserve(MaterialRetrievalStatus status) {
    final command = _RetrievalCommand(++_generation, _query, ++_resultVersion);
    _active = command;
    _error = null;
    _resolution = null;
    _rebuildCompleted = false;
    _status = status;
    _notify();
    return command;
  }

  bool _matches(_RetrievalCommand command) => !_closed &&
      command.generation == _generation && command.query == _query &&
      !command.cancellation.isCanceled;

  bool _owns(_RetrievalCommand command) =>
      identical(_active, command) && _matches(command);

  Future<void> _execute(
    _RetrievalCommand command, Future<void> Function() operation,
  ) async {
    try {
      if (_owns(command)) {
        await operation();
      }
    } catch (error) {
      if (_owns(command)) {
        _error = error;
        _result = null;
        _resultVersion++;
        _status = switch (error) {
          MaterialRetrievalCanceled() => MaterialRetrievalStatus.canceled,
          UnsupportedError() => MaterialRetrievalStatus.unavailable,
          _ => MaterialRetrievalStatus.error,
        };
      }
    } finally {
      if (identical(_active, command)) {
        _active = null;
      }
      // Complete only after cleanup and its final notification have run.
      _notify();
      command.settled.complete();
    }
  }

  /// Joins only original commands owned here, never the borrowed service tail.
  Future<void> detach() {
    if (_detachment != null) {
      return _detachment!;
    }
    _closed = true;
    _generation++;
    _active?.cancellation.cancel();
    return _detachment = _active?.settled.future ?? Future<void>.value();
  }

  Future<void> close() => detach();

  @override
  void addListener(VoidCallback listener) {
    if (_closed) {
      return;
    }
    void guarded() {
      if (_closed) {
        return;
      }
      try {
        listener();
      } catch (error) {
        if (!_closed) {
          _error = error;
          _generation++;
          _active?.cancellation.cancel();
          _result = null;
          _resultVersion++;
          _status = MaterialRetrievalStatus.error;
        }
      }
    }
    _listeners.putIfAbsent(listener, () => []).add(guarded);
    super.addListener(guarded);
  }

  @override
  void removeListener(VoidCallback listener) {
    final wrappers = _listeners[listener];
    if (wrappers == null || wrappers.isEmpty) {
      return;
    }
    super.removeListener(wrappers.removeAt(0));
    if (wrappers.isEmpty) {
      _listeners.remove(listener);
    }
  }

  void _notify() {
    if (_closed || _notifierDisposed) {
      return;
    }
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      _finishDisposal();
    }
  }

  void _finishDisposal() {
    if (_disposed && !_notifierDisposed && _notificationDepth == 0) {
      dispose();
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      unawaited(detach());
    }
    if (!_notifierDisposed && _notificationDepth == 0) {
      _notifierDisposed = true;
      _listeners.clear();
      super.dispose();
    }
  }
}

final class _RetrievalCommand {
  _RetrievalCommand(this.generation, this.query, this.resultVersion);
  final int generation;
  final String query;
  final int resultVersion;
  final cancellation = MaterialRetrievalCancellation();
  final settled = Completer<void>();
}
