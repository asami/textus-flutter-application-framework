import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Test-only finite entrance/release signals; cleanup releases every held port.
final class SubmissionGate {
  final Completer<void> entered = Completer<void>();
  final Completer<void> _release = Completer<void>();

  Future<void> wait() {
    // Given a held controlled port, When it is entered, Then signal its caller.
    if (!entered.isCompleted) {
      entered.complete();
    }
    return _release.future;
  }

  void release() {
    // Given pending or already released work, When cleanup runs, Then join safely.
    if (!_release.isCompleted) {
      _release.complete();
    }
  }
}

/// Public Core IO resources owned exclusively by each scenario.
final class SubmissionFixture {
  SubmissionFixture._(this.directory)
    : materials = FileCaptureStore('${directory.path}/originals');

  static final time = DateTime.utc(2026, 10, 10, 12);
  static final photoBytes = Uint8List.fromList([0, 255, 1, 80, 32, 0]);
  static final audioBytes = Uint8List.fromList([82, 73, 70, 70, 0, 254, 128]);
  final Directory directory;
  final FileCaptureStore materials;
  final ControlledSubmissionStorage storage = ControlledSubmissionStorage();
  final ControlledSubmissionTransport transport =
      ControlledSubmissionTransport();
  final ControlledSubmissionScheduler scheduler =
      ControlledSubmissionScheduler();
  final ControlledSubmissionAccess access = ControlledSubmissionAccess();
  final List<SqliteSubmissionQueueStore> _queues = [];
  final List<SubmissionService> _services = [];
  DateTime clock = time;

  static Future<SubmissionFixture> create({
    void Function() initializeFfi = sqfliteFfiInit,
  }) async {
    // Given injected host SQLite initialization, When creating isolated artifacts,
    // Then no global database factory is replaced.
    initializeFfi();
    return SubmissionFixture._(
      await Directory.systemTemp.createTemp('tfaf-submission-'),
    );
  }

  Future<SqliteSubmissionQueueStore> openQueue() async {
    // Given a test-owned durable path, When opening an independent public handle,
    // Then preserve its data and record ownership for finally cleanup.
    final queue = await SqliteSubmissionQueueStore.open(
      '${directory.path}/queue.sqlite',
      factory: databaseFactoryFfi,
    );
    _queues.add(queue);
    return queue;
  }

  // Given a controlled observation clock, When read, Then return its exact value without IO.
  DateTime now() => clock;

  SubmissionService service(SubmissionQueueStore queue) {
    // Given real originals/queue and controlled ports, When borrowing them,
    // Then construction starts no runner, network or scheduler.
    final service = SubmissionService(
      queue: queue,
      materials: materials,
      storageAdapters: {'storage': storage},
      transports: {'transport': transport},
      scheduler: scheduler,
      referenceAccessPolicy: access,
      now: now,
    );
    _services.add(service);
    return service;
  }

  Future<SubmissionRequest> request({
    String id = 'request1',
    String subjectId = 'subject1',
    bool withMaterials = true,
  }) async {
    // Given binary originals and exact opaque Unicode/whitespace/context,
    // When saving through public filesystem storage, Then intent borrows them.
    final originals = <SubmissionMaterial>[];
    if (withMaterials) {
      final photo = await materials.saveMaterial(
        bytes: photoBytes,
        mediaType: 'image/jpeg',
        capturedAt: time,
        originalName: '写真 原本.jpg',
      );
      final audio = await materials.saveMaterial(
        bytes: audioBytes,
        mediaType: 'audio/wav',
        capturedAt: time,
        originalName: '音声 原本.wav',
      );
      originals.addAll([
        SubmissionMaterial(
          key: 'photo',
          original: photo,
          provenance: {'role': '原本'},
        ),
        SubmissionMaterial(
          key: 'audio',
          original: audio,
          provenance: {'role': '録音'},
        ),
      ]);
    }
    return SubmissionRequest(
      id: id,
      kind: 'opaqueKind',
      subjectId: subjectId,
      createdAt: time,
      document: {'title': '  題名\n原文  ', 'localOnly': true},
      payload: {
        'transcript': '  手入力\n原文  ',
        'nested': [null, 'é😀'],
      },
      materials: originals,
      storageConnectionId: withMaterials ? 'storage' : null,
      transportConnectionId: 'transport',
      extensions: {
        'executionContext': {'locale': 'ja-JP', 'opaque': '  未解釈  '},
      },
    );
  }

  Future<void> uploadAll(SubmissionService service) async {
    // Given two required originals, When explicitly pumping the controlled runner,
    // Then prepare both reservations and upload both originals before transport.
    for (var index = 0; index < 4; index++) {
      await service.processNext(networkAllowed: true);
    }
  }

  Future<void> dispose() async {
    // Given all accepted test work, When finally releases controlled gates,
    // Then drain services before queue handles before deleting only this temp dir.
    access.gate?.release();
    scheduler.gate?.release();
    storage.gate?.release();
    transport.gate?.release();
    try {
      for (final service in _services.reversed) {
        await service.close();
      }
    } finally {
      try {
        for (final queue in _queues.reversed) {
          await queue.close();
        }
      } finally {
        await directory.delete(recursive: true);
      }
    }
  }
}

final class ControlledSubmissionStorage implements SubmissionStorageAdapter {
  @override
  String get providerId => 'controlledStorage';
  int prepares = 0;
  int uploads = 0;
  String? failKey;
  SubmissionGate? gate;
  final List<Uint8List> uploadedBytes = [];

  @override
  Future<SubmissionStorageReservation> prepare({
    required SubmissionRequest request,
    required SubmissionMaterial material,
  }) async {
    // Given explicit runner consent, When preparing a material, Then no bytes upload.
    prepares++;
    return SubmissionStorageReservation(
      key: material.key,
      providerId: providerId,
      data: {'remoteId': 'controlled/${request.id}/${material.key}'},
    );
  }

  @override
  Future<SubmissionMaterialReceipt> upload({
    required SubmissionRequest request,
    required SubmissionMaterial material,
    required SubmissionStorageReservation reservation,
    required Uint8List bytes,
  }) async {
    // Given the exact reservation/original, When this controlled upload is entered,
    // Then retain observed bytes and report only actual receipt or safe failure.
    uploads++;
    uploadedBytes.add(Uint8List.fromList(bytes));
    await gate?.wait();
    if (material.key == failKey) {
      throw SubmissionAdapterException(
        stage: SubmissionFailureStage.storage,
        code: 'controlledUploadFailure',
        message: 'Controlled upload failed.',
        retryable: false,
      );
    }
    return SubmissionMaterialReceipt(
      key: material.key,
      providerId: providerId,
      remoteId: reservation.data['remoteId'] as String,
      accessConnectionId: 'storage',
      storedAt: SubmissionFixture.time,
    );
  }
}

final class ControlledSubmissionTransport implements SubmissionTransport {
  @override
  String get providerId => 'controlledTransport';
  int submits = 0;
  bool fail = false;
  SubmissionTransportFailureOutcome failureOutcome =
      SubmissionTransportFailureOutcome.unknown;
  SubmissionGate? gate;
  final List<SubmissionPacket> packets = [];

  @override
  Future<SubmissionAcknowledgement> submit(SubmissionPacket packet) async {
    // Given a complete controlled packet, When explicitly submitted by the runner,
    // Then record exact intent and return fake acknowledgement or safe uncertainty.
    submits++;
    packets.add(packet);
    await gate?.wait();
    if (fail) {
      throw SubmissionAdapterException(
        stage: SubmissionFailureStage.transport,
        code: 'controlledTransportFailure',
        message: 'Controlled submission failed.',
        retryable: false,
        transportFailureOutcome: failureOutcome,
      );
    }
    return SubmissionAcknowledgement(
      requestId: packet.request.id,
      subjectId: packet.request.subjectId,
      serverId: 'controlled/${packet.request.id}',
      receivedAt: SubmissionFixture.time,
    );
  }
}

final class ControlledSubmissionScheduler implements SubmissionWakeScheduler {
  int calls = 0;
  bool fail = false;
  SubmissionGate? gate;

  @override
  Future<void> requestRun() async {
    // Given durable queued intent, When wake is requested, Then never run transport.
    calls++;
    await gate?.wait();
    if (fail) {
      throw StateError('Controlled wake failure');
    }
  }
}

final class ControlledSubmissionAccess
    implements SubmissionReferenceAccessPolicy {
  int calls = 0;
  bool fail = false;
  SubmissionReferenceAccessState state =
      SubmissionReferenceAccessState.available;
  SubmissionGate? gate;

  @override
  Future<SubmissionReferenceAccessState> evaluate(
    SubmissionPacket packet,
  ) async {
    // Given an explicit test-only access observation, When queried, Then no grant/IO.
    calls++;
    await gate?.wait();
    if (fail) {
      throw StateError('Controlled policy failure');
    }
    return state;
  }
}

/// Controlled config-only JSON backing; this establishes no native durability.
final class MemorySubmissionConfiguration
    implements SubmissionConfigurationStore {
  MemorySubmissionConfiguration(SubmissionConfigurationSnapshot snapshot)
    : value = snapshot;

  SubmissionConfigurationSnapshot value;
  int reads = 0;
  int writes = 0;
  bool closed = false;
  Object? fault;
  SubmissionGate? readGate;
  SubmissionGate? writeGate;
  int writeAttempts = 0;

  void _open() {
    // Given injected failure or retired backing, When used, Then propagate exactly.
    final error = fault;
    if (error != null) {
      throw error;
    }
    if (closed) {
      throw StateError('Controlled configuration closed');
    }
  }

  @override
  Future<SubmissionConfigurationSnapshot> snapshot() async {
    // Given this backing, When read, Then preserve the exact immutable value.
    _open();
    reads++;
    await readGate?.wait();
    _open();
    return value;
  }

  Future<void> _beforeWrite() async {
    // Given a controlled write gate, When a command enters, Then count dispatch
    // before holding it and preserve backing faults on eventual release.
    writeAttempts++;
    await writeGate?.wait();
    _open();
  }

  void _replace({
    List<DriveSubmissionConnection>? drives,
    List<HttpSubmissionConnection>? transports,
    Map<String, List<String>>? bindings,
  }) {
    // Given a bounded change, When validating the full replacement, Then write atomically.
    _open();
    final next = SubmissionConfigurationSnapshot(
      driveConnections: drives ?? value.driveConnections,
      httpConnections: transports ?? value.httpConnections,
      selectedStorageConnectionId: value.selectedStorageConnectionId,
      selectedTransportConnectionId: value.selectedTransportConnectionId,
      referenceAccessBindings: bindings ?? value.referenceAccessBindings,
    );
    value = next;
    writes++;
  }

  @override
  Future<void> putDrive(DriveSubmissionConnection connection) async {
    // Given existing immutable definitions, When inserting, Then conflicts never retarget.
    _open();
    await _beforeWrite();
    for (final old in value.driveConnections) {
      if (old.id == connection.id) {
        if (jsonEncode(old.toJson()) != jsonEncode(connection.toJson())) {
          throw StateError('Controlled connection conflict');
        }
        return;
      }
    }
    _replace(drives: [...value.driveConnections, connection]);
  }

  @override
  Future<void> putHttp(HttpSubmissionConnection connection) async {
    // Given immutable HTTP definitions, When inserting, Then retain identical definitions.
    _open();
    await _beforeWrite();
    for (final old in value.httpConnections) {
      if (old.id == connection.id) {
        if (jsonEncode(old.toJson()) != jsonEncode(connection.toJson())) {
          throw StateError('Controlled connection conflict');
        }
        return;
      }
    }
    _replace(transports: [...value.httpConnections, connection]);
  }

  @override
  Future<void> select({
    String? storageConnectionId,
    String? transportConnectionId,
  }) async {
    // Given exact registered identities, When selecting, Then null clears independently of grants.
    _open();
    await _beforeWrite();
    final next = SubmissionConfigurationSnapshot(
      driveConnections: value.driveConnections,
      httpConnections: value.httpConnections,
      selectedStorageConnectionId: storageConnectionId,
      selectedTransportConnectionId: transportConnectionId,
      referenceAccessBindings: value.referenceAccessBindings,
    );
    value = next;
    writes++;
  }

  @override
  Future<void> setReferenceAccess({
    required String transportConnectionId,
    required List<String> storageConnectionIds,
  }) async {
    // Given explicit access declarations, When replacing, Then keep missing/empty distinct.
    await _beforeWrite();
    _replace(
      bindings: {
        ...value.referenceAccessBindings,
        transportConnectionId: storageConnectionIds,
      },
    );
  }

  @override
  Future<void> close() async {
    // Given test ownership, When finally closed, Then reject future backing operations.
    readGate?.release();
    writeGate?.release();
    closed = true;
  }
}

SubmissionConfigurationSnapshot submissionConfiguration({bool empty = false}) {
  // Given safe test definitions, When an isolated configuration is requested,
  // Then return immutable targets with no implicit defaults or access grant.
  return SubmissionConfigurationSnapshot(
    driveConnections: empty
        ? []
        : [
            DriveSubmissionConnection(
              id: 'storage',
              accountId: 'user@example.test',
              folderId: 'folderA',
            ),
          ],
    httpConnections: empty
        ? []
        : [
            HttpSubmissionConnection(
              id: 'transport',
              endpoint: Uri.parse('https://example.test/submit'),
            ),
            HttpSubmissionConnection(
              id: 'otherTransport',
              endpoint: Uri.parse('https://example.test/other'),
            ),
          ],
  );
}

/// Actual Android public store over a controlled host channel, not native proof.
final class ControlledSubmissionConfigurationChannel {
  static const channel = MethodChannel('org.textus.flutter.core/submission');
  final MemorySubmissionConfiguration backing = MemorySubmissionConfiguration(
    submissionConfiguration(),
  );
  final List<MethodCall> calls = [];
  SubmissionAuthorizationState authorization =
      SubmissionAuthorizationState.authorizationRequired;
  SubmissionGate? gate;
  String? failureCode;
  TargetPlatform? _previousPlatform;

  void attach() {
    // Given the actual public Android store, When binding controlled host calls,
    // Then expose only observed enums and exact explicit writes, no native receipt.
    _previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }

  Future<Object?> _handle(MethodCall call) async {
    // Given explicit Core channel dispatch, When held or failed by this fixture,
    // Then report safe native vocabulary or an exact controlled result.
    calls.add(call);
    await gate?.wait();
    final failure = failureCode;
    if (failure != null) {
      throw PlatformException(
        code: failure,
        message: 'untrusted token details',
      );
    }
    final arguments = Map<String, Object?>.from(call.arguments as Map? ?? {});
    switch (call.method) {
      case 'snapshot':
        return (await backing.snapshot()).toJson();
      case 'putDrive':
        await backing.putDrive(
          DriveSubmissionConnection.fromJson(
            Map<String, Object?>.from(arguments['connection'] as Map),
          ),
        );
      case 'putHttp':
        await backing.putHttp(
          HttpSubmissionConnection.fromJson(
            Map<String, Object?>.from(arguments['connection'] as Map),
          ),
        );
      case 'select':
        await backing.select(
          storageConnectionId: arguments['storageConnectionId'] as String?,
          transportConnectionId: arguments['transportConnectionId'] as String?,
        );
      case 'setReferenceAccess':
        await backing.setReferenceAccess(
          transportConnectionId: arguments['transportConnectionId'] as String,
          storageConnectionIds: List<String>.from(
            arguments['storageConnectionIds'] as List,
          ),
        );
      case 'authorizationState':
      case 'authorizeDrive':
        return authorization.name;
      case 'setHttpBearerToken':
      case 'closeConfiguration':
        return null;
      default:
        throw StateError('Unexpected controlled configuration operation');
    }
    return null;
  }

  Future<void> dispose() async {
    // Given owned host wiring, When the scenario finishes, Then release gates,
    // remove mock interception and restore the previous platform exactly.
    gate?.release();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = _previousPlatform;
    await backing.close();
  }
}

SubmissionPresentationConfiguration submissionPresentation() {
  // Given generic caller-owned vocabulary, When mapping actual identities,
  // Then preserve exact safe destination ids without introducing domain semantics.
  // Given the exact Core subject, When labeled, Then return consumer text without commands.
  String itemLabel(SubmissionTransferStatus status) =>
      'Item ${status.subjectId}';
  // Given the nullable Core storage destination, When labeled, Then preserve null without commands.
  String storageLabel(String? id) => id == null ? 'No storage' : 'Storage $id';
  // Given the exact Core transport destination, When labeled, Then return consumer text without commands.
  String transportLabel(String id) => 'Transport $id';
  return SubmissionPresentationConfiguration(
    listTitle: 'Transfers',
    detailTitle: 'Transfer',
    uploadLabel: 'Original upload',
    submissionLabel: 'Server submission',
    itemLabel: itemLabel,
    storageDestinationLabel: storageLabel,
    transportDestinationLabel: transportLabel,
  );
}
