import 'package:textus_flutter_core/textus_flutter_core.dart';

/// Borrows one configuration store. Capability flags describe bound operations,
/// while Core alone determines platform readiness, authorization and errors.
final class SubmissionConfigurationFacade {
  const SubmissionConfigurationFacade({required this._store}) : _android = null;

  factory SubmissionConfigurationFacade.android({
    required AndroidSubmissionConfigurationStore store,
  }) => SubmissionConfigurationFacade._android(store);

  SubmissionConfigurationFacade._android(
    AndroidSubmissionConfigurationStore store,
  ) : _store = store,
      _android = store;

  final SubmissionConfigurationStore _store;
  final AndroidSubmissionConfigurationStore? _android;

  bool get hasDriveAuthorization => _android != null;
  bool get hasHttpCredentialWriter => _android != null;

  Future<SubmissionConfigurationSnapshot> snapshot() => _store.snapshot();

  Future<void> putDrive(DriveSubmissionConnection connection) =>
      _store.putDrive(connection);

  Future<void> putHttp(HttpSubmissionConnection connection) =>
      _store.putHttp(connection);

  Future<void> select({
    String? storageConnectionId,
    String? transportConnectionId,
  }) => _store.select(
    storageConnectionId: storageConnectionId,
    transportConnectionId: transportConnectionId,
  );

  Future<void> setReferenceAccess({
    required String transportConnectionId,
    required List<String> storageConnectionIds,
  }) => _store.setReferenceAccess(
    transportConnectionId: transportConnectionId,
    storageConnectionIds: storageConnectionIds,
  );

  AndroidSubmissionConfigurationStore get _native {
    final store = _android;
    if (store == null) {
      throw UnsupportedError('Native submission configuration is not bound');
    }
    return store;
  }

  Future<SubmissionAuthorizationState> authorizationState(
    String connectionId,
  ) => _native.authorizationState(connectionId);

  Future<SubmissionAuthorizationState> authorizeDrive(String connectionId) =>
      _native.authorizeDrive(connectionId);

  /// Explicit ephemeral write; this wrapper never retains or retrieves a token.
  Future<void> setHttpBearerToken(String connectionId, String? token) =>
      _native.setHttpBearerToken(connectionId, token);
}
