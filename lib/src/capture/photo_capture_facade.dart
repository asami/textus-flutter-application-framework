import 'dart:typed_data';

import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Exact interaction forwarding to a caller-owned Core photo service.
/// Construction performs no acquisition, probing, preparation or inference.
final class PhotoCaptureFacade {
  PhotoCaptureFacade({required this._service});

  final PhotoCaptureService _service;

  /// Whether the borrowed camera supports acquisition.
  bool get isSupported => _service.isSupported;

  /// Core's immutable catalog, retaining its identity and order.
  List<RecognitionConfiguration> get configurations => _service.configurations;

  /// Explicit capability probe, independent of desired settings.
  Future<List<RecognitionProviderAvailability>> availability() =>
      _service.availability();

  /// Explicit model preparation; never starts recognition.
  Future<RecognitionProviderAvailability> prepareProvider(String providerId) =>
      _service.prepareProvider(providerId);

  /// Returns Core's durable original, or null on camera cancellation.
  /// Requires no settings or readiness and starts no recognition or report.
  Future<CaptureMaterialReference?> captureOriginal() => _service.captureOriginal();

  /// Forwards original-only recovery and actual camera/import failures unchanged.
  Future<CaptureMaterialReference?> recoverOriginal() => _service.recoverOriginal();

  /// Reads the exact original through the borrowed Core service's shared guard.
  /// Forwards bytes and actual store errors without camera or readiness work.
  Future<Uint8List> readOriginal(CaptureMaterialReference material) =>
      _service.readOriginal(material);

  /// Returns Core's durable report with this call's optional opaque intent,
  /// or null for camera cancellation. No intent is retained by the facade.
  Future<RecognitionComparison?> capture({
    required String desiredConfigurationId,
    RecognitionOperationContext? operationContext,
  }) => _service.capture(desiredConfigurationId: desiredConfigurationId,
    operationContext: operationContext);

  /// Recovers Core's lost camera acquisition without changing desired intent.
  /// Optional context is forwarded exactly for this recovery operation.
  Future<RecognitionComparison?> recover({
    required String desiredConfigurationId,
    RecognitionOperationContext? operationContext,
  }) => _service.recover(desiredConfigurationId: desiredConfigurationId,
    operationContext: operationContext);

  /// Recognizes exactly the supplied saved original.
  /// Optional roles, kinds and instructions remain caller-owned vocabulary.
  Future<RecognitionComparison> recognize(
    CaptureMaterialReference material, {
    required String desiredConfigurationId,
    RecognitionOperationContext? operationContext,
  }) => _service.recognize(material, desiredConfigurationId: desiredConfigurationId,
    operationContext: operationContext);

  /// Compares selected routes on exactly the supplied saved original.
  /// The same optional intent reaches all actually executed providers.
  Future<RecognitionComparison> compare(
    CaptureMaterialReference material, {
    Iterable<String>? configurationIds,
    RecognitionOperationContext? operationContext,
  }) => _service.compare(material, configurationIds: configurationIds,
    operationContext: operationContext);

  /// Reads history without acquisition, inference or re-saving.
  Future<RecognitionComparison?> findComparison(String id) =>
      _service.reports.findById(id);

  /// Lists Core's durable history for an original logical identity.
  Future<List<RecognitionComparison>> listComparisonsForMaterial(String id) =>
      _service.reports.listForMaterial(id);
}

/// Opens Core's defaults with the exact caller-supplied store and providers.
/// Callers own the shared store and any book-configured enhancement provider.
Future<PhotoCaptureFacade> openDefaultPhotoCaptureFacade({
  LocalCaptureStore? store,
  Iterable<ImageRecognitionProvider> additionalProviders = const [],
}) async => PhotoCaptureFacade(
  service: await openDefaultPhotoCaptureService(
    store: store,
    additionalProviders: additionalProviders,
  ),
);
