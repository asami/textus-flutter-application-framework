import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Passive shared presentation boundary over the exact borrowed Core TKL port.
///
/// Construction and reads do not start a Commit, upload, registration, consent
/// or retry. Mutation actions will use the owning durable Core service when
/// that route is connected; widgets must not bypass it through the raw client.
final class TklMaterialDeliveryFacade {
  const TklMaterialDeliveryFacade({required this._client});

  final TklMaterialDeliveryClient _client;

  /// Observes TKL's logical destination, without defining Google storage.
  Future<TklMaterialDeliveryDestination> getDestination() =>
      _client.getDestination();

  /// Null means actual authorized absence; query failures remain failures.
  Future<TklMaterialDeliverySnapshot?> findForRequest(String requestId) =>
      _client.findForRequest(requestId);

  /// Observes the same opaque delivery reference, preserving registration state.
  Future<TklMaterialDeliverySnapshot> get(String deliveryRef) =>
      _client.get(deliveryRef);
}
