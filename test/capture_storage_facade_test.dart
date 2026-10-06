import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  group('CaptureStorageFacade public persistence', () {
    late Directory directory;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('tfaf-capture-facade-');
    });
    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('F1 durable originals and nested documents survive a new facade', () async {
      // Given a public facade over a private test directory and original bytes.
      final facade = CaptureStorageFacade(store: FileCaptureStore(directory.path));
      final bytes = Uint8List.fromList([0, 255, 12, 9]);
      final document = <String, Object?>{
        'nested': <Object?>[null, <String, Object?>{'text': 'book', 'empty': []}],
      };
      // When material and an opaque document are saved through the public facade.
      final reference = await facade.importMaterial(
        bytes: bytes,
        mediaType: 'image/jpeg',
        capturedAt: DateTime.utc(2026, 10, 6),
        originalName: '../cover.jpg',
      );
      await facade.saveDocument('drafts', 'one', document);
      final reopened = CaptureStorageFacade(store: FileCaptureStore(directory.path));
      final read = await reopened.readMaterial(
        CaptureMaterialReference.fromJson(reference.toJson()),
      );
      final loaded = await reopened.readDocument('drafts', 'one');
      // Then fresh instances retain exact original bytes and nested JSON values.
      expect(read, orderedEquals(bytes));
      expect(reference.originalName, '../cover.jpg');
      expect(reference.mediaType, 'image/jpeg');
      expect(reference.byteLength, bytes.length);
      expect(CaptureMaterialReference.fromJson(reference.toJson()), reference);
      expect(loaded, document);
      expect(await reopened.readDocument('drafts', 'absent'), isNull);
      expect(await reopened.listDocumentIds('drafts'), ['one']);
      expect(await reopened.listDocumentIds('absent'), isEmpty);
    });

    test('F2 all five methods forward once and retain exact public values', () async {
      // Given a controllable public Core store with distinctive returned objects.
      final store = _ObservedStore();
      final facade = CaptureStorageFacade(store: store);
      final input = Uint8List.fromList([7, 8]);
      final time = DateTime.utc(2026, 10, 6);
      final document = <String, Object?>{'text': 'saved'};
      // When each facade method is invoked with the supplied public arguments.
      final reference = await facade.importMaterial(
        bytes: input, mediaType: 'image/png', capturedAt: time,
        originalName: 'page.png',
      );
      final bytes = await facade.readMaterial(reference);
      await facade.saveDocument('drafts', 'one', document);
      final read = await facade.readDocument('drafts', 'one');
      final ids = await facade.listDocumentIds('drafts');
      // Then delegation happens exactly once, without copying values or arguments.
      expect(store.calls, {
        'saveMaterial': 1, 'readMaterial': 1, 'saveDocument': 1,
        'readDocument': 1, 'listDocumentIds': 1,
      });
      expect(store.inputBytes, same(input));
      expect(store.inputMediaType, 'image/png');
      expect(store.inputTime, same(time));
      expect(store.inputName, 'page.png');
      expect(store.inputReference, same(store.reference));
      expect(store.savedDocument, same(document));
      expect(store.savedCollection, 'drafts');
      expect(store.savedId, 'one');
      expect(store.readCollection, 'drafts');
      expect(store.readId, 'one');
      expect(store.listCollection, 'drafts');
      expect(reference, same(store.reference));
      expect(bytes, same(store.bytes));
      expect(read, same(store.document));
      expect(ids, same(store.ids));
    });

    test('F3 actual storage errors pass through and later delegation works', () async {
      // Given every Core method configured to fail with the same actual object.
      final error = StateError('storage unavailable');
      final store = _ObservedStore()..failure = error;
      final facade = CaptureStorageFacade(store: store);
      // When each facade operation awaits a failed storage future.
      await expectLater(facade.importMaterial(
        bytes: store.bytes, mediaType: 'image/jpeg',
        capturedAt: DateTime.utc(2026, 10, 6),
      ), throwsA(same(error)));
      await expectLater(facade.readMaterial(store.reference), throwsA(same(error)));
      await expectLater(facade.saveDocument('drafts', 'one', {}), throwsA(same(error)));
      await expectLater(facade.readDocument('drafts', 'one'), throwsA(same(error)));
      await expectLater(facade.listDocumentIds('drafts'), throwsA(same(error)));
      // Then no fallback or repeated write occurs after any failure.
      expect(store.calls.values, everyElement(1));
      expect(store.calls, hasLength(5));
      // Given that the injected failure has been removed.
      store.failure = null;
      // When a later operation delegates to the same store.
      final bytes = await facade.readMaterial(store.reference);
      // Then the later result remains usable and exactly one more read occurs.
      expect(bytes, same(store.bytes));
      expect(store.calls['readMaterial'], 2);
      expect(store.calls['saveMaterial'], 1);
      expect(store.calls['saveDocument'], 1);
    });

    test('F4 real invalid material token and JSON preserve accepted data', () async {
      // Given durable original bytes and a previously accepted document.
      final facade = CaptureStorageFacade(store: FileCaptureStore(directory.path));
      final bytes = Uint8List.fromList([1, 2, 3]);
      final reference = await facade.importMaterial(
        bytes: bytes, mediaType: 'image/jpeg',
        capturedAt: DateTime.utc(2026, 10, 6),
      );
      await facade.saveDocument('drafts', 'one', {'accepted': true});
      final cyclic = <Object?>[];
      cyclic.add(cyclic);
      // When invalid material, identity and JSON reach actual FileCaptureStore.
      await expectLater(facade.importMaterial(
        bytes: Uint8List(0), mediaType: 'image/jpeg', capturedAt: reference.capturedAt,
      ), throwsArgumentError);
      await expectLater(facade.importMaterial(
        bytes: bytes, mediaType: 'invalid', capturedAt: reference.capturedAt,
      ), throwsArgumentError);
      await expectLater(facade.saveDocument('drafts', '../one', {}), throwsArgumentError);
      await expectLater(facade.readDocument('../drafts', 'one'), throwsArgumentError);
      await expectLater(facade.listDocumentIds('../drafts'), throwsArgumentError);
      for (final invalid in <Object?>[double.infinity, Object(), cyclic, {1: 'bad'}]) {
        await expectLater(
          facade.saveDocument('drafts', 'one', {'invalid': invalid}),
          throwsArgumentError,
        );
      }
      // Then failures preserve accepted originals and the accepted document.
      expect(await facade.readMaterial(reference), orderedEquals(bytes));
      expect(await facade.readDocument('drafts', 'one'), {'accepted': true});
      expect(await facade.listDocumentIds('drafts'), ['one']);
    });
  });
}

final class _ObservedStore implements LocalCaptureStore {
  final reference = CaptureMaterialReference(
    id: 'original', mediaType: 'image/jpeg', byteLength: 2,
    capturedAt: DateTime.utc(2026, 10, 6),
  );
  final bytes = Uint8List.fromList([3, 4]);
  final document = <String, Object?>{'nested': [null, true]};
  final ids = <String>['one'];
  final calls = <String, int>{};
  Object? failure;
  Uint8List? inputBytes;
  String? inputMediaType;
  DateTime? inputTime;
  String? inputName;
  CaptureMaterialReference? inputReference;
  String? savedCollection;
  String? savedId;
  Map<String, Object?>? savedDocument;
  String? readCollection;
  String? readId;
  String? listCollection;

  Future<T> _result<T>(String method, T value) {
    calls.update(method, (count) => count + 1, ifAbsent: () => 1);
    final error = failure;
    return error == null ? Future<T>.value(value) : Future<T>.error(error);
  }

  @override
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes, required String mediaType,
    required DateTime capturedAt, String? originalName,
  }) {
    inputBytes = bytes;
    inputMediaType = mediaType;
    inputTime = capturedAt;
    inputName = originalName;
    return _result('saveMaterial', reference);
  }

  @override
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) {
    inputReference = reference;
    return _result('readMaterial', bytes);
  }

  @override
  Future<void> saveDocument(String collection, String id, Map<String, Object?> document) {
    savedCollection = collection;
    savedId = id;
    savedDocument = document;
    return _result<void>('saveDocument', null);
  }

  @override
  Future<Map<String, Object?>?> readDocument(String collection, String id) {
    readCollection = collection;
    readId = id;
    return _result('readDocument', document);
  }

  @override
  Future<List<String>> listDocumentIds(String collection) {
    listCollection = collection;
    return _result('listDocumentIds', ids);
  }
}
