import 'dart:typed_data';

import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Inert, borrowed forwarding boundary for Core's canonical region processing.
final class ImageRegionFacade {
  /// The composition owner retains the service and its store lifetime.
  const ImageRegionFacade({required this._service});

  final ImageRegionService _service;

  /// Explicitly loads the canonical upright raster of this exact original.
  Future<ImageRegionFrame> loadFrame(CaptureMaterialReference source) =>
      _service.loadFrame(source);

  /// Saves Core's exact source-bound crop and mask.
  Future<ImageRegionDerivation> derive(ImageRegionSnapshot region) =>
      _service.derive(region);

  /// Reads the actual saved PNG, without synthesizing a preview.
  Future<Uint8List> readDerived(ImageRegionDerivation derivation) =>
      _service.readDerived(derivation);

  /// Recognition is explicit; local AI is opt-in and never implicitly prepared.
  Future<ImageRegionExtraction> recognize(
    ImageRegionDerivation derivation, {
    bool supplementWithLocalAi = false,
    RecognitionOperationContext? operationContext,
  }) => _service.recognize(
    derivation,
    supplementWithLocalAi: supplementWithLocalAi,
    operationContext: operationContext,
  );

  /// Actual readiness snapshot without model preparation.
  Future<List<RecognitionProviderAvailability>> availability() =>
      _service.availability();

  /// Explicitly delegates preparation to the registered provider.
  Future<RecognitionProviderAvailability> prepareProvider(String providerId) =>
      _service.prepareProvider(providerId);
}

/// Forwards the existing Core factory with the caller's exact shared store.
Future<ImageRegionFacade> openDefaultImageRegionFacade({
  LocalCaptureStore? store,
  Iterable<ImageRecognitionProvider> additionalProviders = const [],
}) async => ImageRegionFacade(
  service: await openDefaultImageRegionService(
    store: store,
    additionalProviders: additionalProviders,
  ),
);
