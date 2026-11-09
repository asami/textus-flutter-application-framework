import 'dart:typed_data';

import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Common capture interaction entry point for Core-owned local persistence.
///
/// This facade preserves Core values and failures without owning application
/// schema, acquisition lifecycle, caching, or storage disposal.
final class CaptureStorageFacade {
  /// Uses the caller's `store` for every persistence operation.
  CaptureStorageFacade({required this._store});

  final LocalCaptureStore _store;

  /// Borrows this exact store and the caller-owned native video provider.
  VideoCaptureRecovery createVideoRecovery({
    required VideoInputProvider provider,
  }) => VideoCaptureRecovery(store: _store, provider: provider);

  /// Reads only durable picker metadata; no native acquisition is started.
  Future<PendingVideoCapture?> pendingVideoCapture() =>
      VideoCaptureRecovery.pendingIn(_store);

  Future<void> acknowledgeVideoCapture({
    required String id,
    required VideoRecoveryTarget target,
    required CaptureMaterialReference original,
  }) => VideoCaptureRecovery.acknowledgeStored(
    _store,
    id: id,
    target: target,
    original: original,
  );

  /// Creates an inert retrieval service borrowing this facade's exact store.
  /// The caller closes the returned service; storage ownership stays unchanged.
  LocalMaterialRetrievalService createMaterialRetrievalService({
    required MaterialRetrievalCorpus corpus,
    required String corpusId,
  }) => LocalMaterialRetrievalService(
    store: _store,
    corpus: corpus,
    corpusId: corpusId,
  );

  /// Imports unchanged original bytes and returns Core's durable reference.
  Future<CaptureMaterialReference> importMaterial({
    required Uint8List bytes,
    required String mediaType,
    required DateTime capturedAt,
    String? originalName,
  }) => _store.saveMaterial(
    bytes: bytes,
    mediaType: mediaType,
    capturedAt: capturedAt,
    originalName: originalName,
  );

  /// Reads original bytes, preserving missing-material and storage failures.
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) =>
      _store.readMaterial(reference);

  /// Delegates opaque JSON persistence, including Core's validation and errors.
  Future<void> saveDocument(
    String collection,
    String id,
    Map<String, Object?> document,
  ) => _store.saveDocument(collection, id, document);

  /// Reads Core's detached document, or null only when Core reports absence.
  Future<Map<String, Object?>?> readDocument(String collection, String id) =>
      _store.readDocument(collection, id);

  /// Lists document identities according to Core's storage contract.
  Future<List<String>> listDocumentIds(String collection) =>
      _store.listDocumentIds(collection);
}

/// Opens the default Core store; provider and unsupported-platform errors pass
/// through without a successful fallback.
Future<CaptureStorageFacade> openDefaultCaptureStorageFacade() async =>
    CaptureStorageFacade(store: await openDefaultCaptureStore());
