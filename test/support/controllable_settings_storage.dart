import 'dart:async';

import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

/// Test-only whole-record adapter with explicitly completed indexed requests.
class ControllableSettingsStorage implements SettingsStorage {
  ControllableSettingsStorage({String? durableRecord}) : this._(durableRecord);

  ControllableSettingsStorage._(this._durableRecord);

  String? _durableRecord;
  final _reads = <PendingSettingsRead>[];
  final _writes = <PendingSettingsWrite>[];

  /// Last acknowledged image, including null for absent storage.
  String? get durableRecord => _durableRecord;

  /// Immutable request inventories; each request rejects double completion.
  List<PendingSettingsRead> get reads => List.unmodifiable(_reads);
  List<PendingSettingsWrite> get writes => List.unmodifiable(_writes);

  int readCount = 0;
  int writeCount = 0;
  int activeReads = 0;
  int activeWrites = 0;
  int maxActiveReads = 0;
  int maxActiveWrites = 0;

  /// Optional one-shot synchronous adapter failures.
  Object? nextReadError;
  Object? nextWriteError;

  @override
  Future<String?> read() {
    readCount++;
    final error = nextReadError;
    nextReadError = null;
    if (error != null) throw error;
    activeReads++;
    if (activeReads > maxActiveReads) maxActiveReads = activeReads;
    final request = PendingSettingsRead._(() => activeReads--);
    _reads.add(request);
    return request._completer.future;
  }

  @override
  Future<void> write(String record) {
    writeCount++;
    final error = nextWriteError;
    nextWriteError = null;
    if (error != null) throw error;
    activeWrites++;
    if (activeWrites > maxActiveWrites) maxActiveWrites = activeWrites;
    final request = PendingSettingsWrite._(record, (success) {
      activeWrites--;
      if (success) _durableRecord = record;
    });
    _writes.add(request);
    return request._completer.future;
  }

  /// Completes a normal restart read with the last durable image.
  void readDurable(int index) => _reads[index].succeed(_durableRecord);
}

/// One delayed read, able to return an explicitly chosen stale image.
class PendingSettingsRead {
  PendingSettingsRead._(this._finish);

  final void Function() _finish;
  final _completer = Completer<String?>();

  bool get isCompleted => _completer.isCompleted;

  void succeed(String? record) {
    _requirePending();
    _finish();
    _completer.complete(record);
  }

  void fail(Object error) {
    _requirePending();
    _finish();
    _completer.completeError(error);
  }

  void _requirePending() {
    if (isCompleted) throw StateError('Read already completed');
  }
}

/// Immutable submitted record and its explicit durable acknowledgement.
class PendingSettingsWrite {
  PendingSettingsWrite._(this.record, this._finish);

  final String record;
  final void Function(bool success) _finish;
  final _completer = Completer<void>();

  bool get isCompleted => _completer.isCompleted;

  void succeed() {
    _requirePending();
    _finish(true);
    _completer.complete();
  }

  void fail(Object error) {
    _requirePending();
    _finish(false);
    _completer.completeError(error);
  }

  void _requirePending() {
    if (isCompleted) throw StateError('Write already completed');
  }
}
