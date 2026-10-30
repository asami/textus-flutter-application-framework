import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// One review owner's additive history. The service and source remain borrowed.
final class GeneratedDraftController implements Listenable {
  GeneratedDraftController({
    required this._service,
    required this.ownerId,
    GeneratedDraftWorkspace? initialWorkspace,
    this._onWorkspaceChanged,
    this._interactionAllowed,
    this._sourceIsCurrent,
    this._contextRevision,
    DateTime Function()? now,
    String Function()? idGenerator,
  }) : _workspace = initialWorkspace ?? GeneratedDraftWorkspace(),
       _now = now ?? _utcNow,
       _idGenerator = idGenerator ?? _randomId {
    if (ownerId.trim().isEmpty || ownerId.trim() != ownerId ||
        ownerId.contains('\u0000')) {
      throw ArgumentError.value(ownerId, 'ownerId');
    }
  }

  final String ownerId;
  final GeneratedDraftService _service;
  final void Function(GeneratedDraftWorkspace)? _onWorkspaceChanged;
  final bool Function()? _interactionAllowed;
  final bool Function(GeneratedDraftSource)? _sourceIsCurrent;
  final Object? Function()? _contextRevision;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final _DraftNotifier _notifier = _DraftNotifier();
  final Map<VoidCallback, List<VoidCallback>> _listeners = {};
  final Set<String> _issuedIds = {};
  GeneratedDraftWorkspace _workspace;
  GeneratedDraftSource? _source;
  GeneratedDraftOperation? _operation;
  Uint8List? _imageBytes;
  GeneratedDraftAvailability? _readiness;
  Object? _error;
  Future<void>? _ownedOperation;
  Future<void>? _detachment;
  String? _activeRequestId;
  String? _action;
  int _generation = 0;
  int _notificationDepth = 0;
  bool _publishing = false;
  bool _detached = false;
  bool _disposed = false;
  bool _disposalSettled = false;
  bool _notifierDisposed = false;

  GeneratedDraftWorkspace get workspace => _workspace;
  GeneratedDraftSource? get source => _source;
  Uint8List? get imageBytes => _imageBytes;
  GeneratedDraftOperation? get operation => _operation;
  GeneratedDraftAvailability? get readiness => _readiness;
  Object? get error => _error;
  bool get busy => _ownedOperation != null;
  bool get isDetached => _detached;
  bool get isDisposed => _disposed;
  int get generation => _generation;
  Object? get currentContextRevision =>
      _contextRevision == null ? 0 : _contextRevision();
  String? get action => _action;
  bool get canCancel => busy && _activeRequestId != null && _service.isBusy;
  bool get _live => !_detached && !_disposed;

  /// Selection is inert, but retires an owned inference without releasing busy.
  void selectSource(GeneratedDraftSource? source, {
    Uint8List? imageBytes,
    GeneratedDraftOperation? operation,
  }) {
    _requireLive();
    if (_publishing) throw StateError('Cannot select during publication');
    if (source == null) {
      if (imageBytes != null) throw ArgumentError('No source requires no bytes');
      if (operation != null) throw ArgumentError('An operation requires a source');
    } else {
      GeneratedDraftRequest(id: 'selection-validation',
        operation: operation ?? _operationFor(source), source: source,
        imageBytes: imageBytes);
    }
    final selectedOperation = source == null ? null
        : operation ?? _operationFor(source);
    if (_sameSource(source, _source) && listEquals(imageBytes, _imageBytes) &&
        selectedOperation == _operation) {
      return;
    }
    _source = source;
    _operation = selectedOperation;
    _imageBytes = imageBytes == null ? null
        : Uint8List.fromList(imageBytes).asUnmodifiableView();
    _generation++;
    _readiness = null;
    _error = null;
    _observeCancellation();
    _notify();
  }

  Future<GeneratedDraftAvailability> checkAvailability() =>
      _command('probe', (source, operation, token, revision) async {
        final value = await _service.availability(operation: operation);
        if (_matches(source, operation, token, revision)) _readiness = value;
        return value;
      });

  /// Core checks whether downloading is appropriate; this never runs on mount.
  Future<GeneratedDraftAvailability> prepare() =>
      _command('prepare', (source, operation, token, revision) async {
        final value = await _service.prepare(operation: operation);
        if (_matches(source, operation, token, revision)) _readiness = value;
        return value;
      });

  Future<GeneratedDraftAttempt> generate() =>
      _command('generate', (source, operation, token, revision) async {
        final imageBytes = _imageBytes;
        final id = _idGenerator();
        final retained = <String>{
          source.id,
          for (final attempt in _workspace.attempts) ...[
            attempt.id, attempt.source.id,
          ],
        };
        if (retained.contains(id) || _issuedIds.contains(id)) {
          throw StateError('Every generation requires a fresh non-source ID');
        }
        if (!_matches(source, operation, token, revision)) {
          throw StateError('Draft owner or context retired before launch');
        }
        final request = GeneratedDraftRequest(id: id,
          operation: operation, source: source,
          imageBytes: imageBytes);
        _issuedIds.add(id);
        _activeRequestId = id;
        late GeneratedDraftAttempt attempt;
        try {
          attempt = await _service.generate(request);
        } finally {
          _activeRequestId = null;
        }
        final current = _matches(source, operation, token, revision);
        if (current) _readiness = attempt.availability;
        if (!current && attempt.status == GeneratedDraftStatus.success) {
          attempt = GeneratedDraftAttempt.fromJson({
            ...attempt.toJson(),
            'status': GeneratedDraftStatus.canceled.name,
            'errorCode': 'contextChanged',
            'errorMessage': 'The original owner, source or human context changed '
                'while this draft was generated; its raw output is retained.',
          });
        }
        _publish(_workspace.append(attempt));
        return attempt;
      });

  /// Cancellation bypasses human admission and targets only this owned request.
  Future<bool> cancel() async {
    if (!canCancel) return false;
    try {
      return await _service.cancel();
    } catch (error) {
      _recordError(error);
      rethrow;
    }
  }

  bool canDecide(String attemptId, GeneratedDraftDecisionKind kind, {
    required int expectedGeneration,
    required Object? expectedContextRevision,
  }) {
    try {
      final selectedsource = _source;
      final selectedoperation = _operation;
      if (!_live || busy || _publishing ||
          expectedGeneration != _generation) {
        return false;
      }
      for (final attempt in _workspace.pending) {
        if (attempt.id == attemptId) {
          if (!_admitted() ||
              !_selectionMatches(selectedsource, selectedoperation,
                expectedGeneration) ||
              (kind != GeneratedDraftDecisionKind.discard &&
                !(_sourceIsCurrent?.call(attempt.source) ?? true))) {
            return false;
          }
          final revision = currentContextRevision;
          return expectedContextRevision == revision &&
              !busy && !_publishing &&
              _selectionMatches(selectedsource, selectedoperation,
                expectedGeneration) &&
              _workspace.pending.any((pending) => identical(pending, attempt));
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void decide(String attemptId, GeneratedDraftDecisionKind kind, {
    required int expectedGeneration,
    required Object? expectedContextRevision,
    String? editedText,
  }) {
    try {
      if (!canDecide(attemptId, kind, expectedGeneration: expectedGeneration,
          expectedContextRevision: expectedContextRevision)) {
        throw StateError('This rendered draft decision is no longer admitted');
      }
      final attempt = _workspace.pending.firstWhere((v) => v.id == attemptId);
      final time = _now();
      if (!time.isUtc || time.isBefore(attempt.completedAt)) {
        throw StateError('Decision clock must be UTC and not before completion');
      }
      final decision = GeneratedDraftDecision(attemptId: attemptId, kind: kind,
        recordedAt: time, editedText: editedText);
      // Injected callbacks (including the clock) cannot grant stale authority.
      if (!canDecide(attemptId, kind, expectedGeneration: expectedGeneration,
          expectedContextRevision: expectedContextRevision)) {
        throw StateError('Draft context changed before decision publication');
      }
      _error = null;
      _publish(_workspace.decide(decision));
    } catch (error) {
      _recordError(error);
      rethrow;
    }
  }

  Future<T> _command<T>(String action,
      Future<T> Function(GeneratedDraftSource, GeneratedDraftOperation,
        int, Object?) run) {
    try {
      _requireLive();
      if (busy || _publishing) throw StateError('Draft controller is busy');
      final source = _source;
      final operation = _operation;
      final token = _generation;
      if (source == null || operation == null || !_admitted() ||
          !(_sourceIsCurrent?.call(source) ?? true)) {
        throw StateError('Choose a current source in an admitted owner');
      }
      final revision = currentContextRevision;
      if (busy || _publishing ||
          !_selectionMatches(source, operation, token)) {
        throw StateError('Draft owner or selection retired during admission');
      }
      final completion = Completer<T>();
      final settled = completion.future.then<void>((_) {},
        onError: (Object _, StackTrace _) {});
      _ownedOperation = settled;
      _action = action;
      _error = null;
      _notify();
      Future<void> launch() async {
        try {
          if (!_matches(source, operation, token, revision)) {
            throw StateError('Draft owner or context retired before launch');
          }
          completion.complete(await run(source, operation, token, revision));
        } catch (error, stack) {
          if (_live) _error = error;
          completion.completeError(error, stack);
        } finally {
          _ownedOperation = null;
          _action = null;
          _notify();
        }
      }
      unawaited(launch());
      return completion.future;
    } catch (error, stack) {
      _recordError(error);
      return Future<T>.error(error, stack);
    }
  }

  bool _admitted() => _interactionAllowed?.call() ?? true;

  bool _selectionMatches(GeneratedDraftSource? source,
      GeneratedDraftOperation? operation, int token) =>
      _live && token == _generation && _sameSource(source, _source) &&
      operation == _operation;

  bool _matches(GeneratedDraftSource source,
      GeneratedDraftOperation operation, int token, Object? revision) {
    try {
      if (!_selectionMatches(source, operation, token) || !_admitted() ||
          !_selectionMatches(source, operation, token) ||
          !(_sourceIsCurrent?.call(source) ?? true) ||
          !_selectionMatches(source, operation, token)) {
        return false;
      }
      final currentrevision = currentContextRevision;
      return revision == currentrevision &&
          _selectionMatches(source, operation, token);
    } catch (_) {
      return false;
    }
  }

  void _publish(GeneratedDraftWorkspace next) {
    if (_publishing) throw StateError('Reentrant draft publication');
    _publishing = true;
    try {
      GeneratedDraftWorkspace.requireRetainedPrefix(_workspace, next);
      _workspace = next;
      if (_live) {
        try {
          _onWorkspaceChanged?.call(next);
        } catch (error) {
          _error = error;
        }
        _notify();
      }
    } finally {
      _publishing = false;
    }
  }

  void _recordError(Object error) {
    if (!_live) return;
    _error = error;
    _notify();
  }

  void _observeCancellation() {
    if (!canCancel) return;
    unawaited(cancel().then<void>((_) {},
      onError: (Object _, StackTrace _) {}));
  }

  /// Terminal owner fence, followed by actual owned operation/cleanup settlement.
  Future<void> detach() {
    if (_detachment != null) return _detachment!;
    final completion = Completer<void>();
    _detachment = completion.future;
    _detached = true;
    _generation++;
    final operation = _ownedOperation;
    _observeCancellation();
    Future<void> settle() async {
      if (operation != null) await operation;
    }
    settle().then(completion.complete, onError: completion.completeError);
    return completion.future;
  }

  void _requireLive() {
    if (!_live) throw StateError('Draft owner is detached or disposed');
  }

  @override
  void addListener(VoidCallback listener) {
    _requireLive();
    void guarded() { if (_live) listener(); }
    (_listeners[listener] ??= []).add(guarded);
    _notifier.addListener(guarded);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_notifierDisposed) return;
    final guards = _listeners[listener];
    if (guards == null || guards.isEmpty) return;
    _notifier.removeListener(guards.removeLast());
    if (guards.isEmpty) _listeners.remove(listener);
  }

  void _notify() {
    if (!_live) return;
    _notificationDepth++;
    try {
      _notifier.emit();
    } finally {
      _notificationDepth--;
      if (_disposed && _disposalSettled) _releaseNotifier();
    }
  }

  /// Starts terminal detach; the borrowed service is never disposed.
  void dispose() {
    if (_disposed) return;
    final settlement = detach();
    _disposed = true;
    unawaited(settlement.then<void>((_) {
      _disposalSettled = true;
      _releaseNotifier();
    }, onError: (Object _, StackTrace _) {
      _disposalSettled = true;
      _releaseNotifier();
    }));
  }

  void _releaseNotifier() {
    if (_notifierDisposed || _notificationDepth != 0) return;
    _notifierDisposed = true;
    _listeners.clear();
    _notifier.dispose();
  }
}

final class _DraftNotifier extends ChangeNotifier {
  void emit() => notifyListeners();
}

GeneratedDraftOperation _operationFor(GeneratedDraftSource source) =>
    source.kind == GeneratedDraftSourceKind.image
        ? GeneratedDraftOperation.imageDescription
        : GeneratedDraftOperation.textSummary;

bool _sameSource(GeneratedDraftSource? a, GeneratedDraftSource? b) =>
    a == null || b == null ? a == b : _sameValue(a.toJson(), b.toJson());

bool _sameValue(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((key) =>
        b.containsKey(key) && _sameValue(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

DateTime _utcNow() => DateTime.now().toUtc();

String _randomId() {
  final random = Random.secure();
  return List.generate(16, (_) =>
      random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
