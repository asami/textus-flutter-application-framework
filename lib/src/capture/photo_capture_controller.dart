import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../view/settings_view.dart';
import 'photo_capture_facade.dart';

/// Observable common interaction borrowing both settings and photo authority.
/// Owners explicitly initialize and dispose this controller after UI detaches.
class PhotoCaptureController extends ChangeNotifier {
  /// Borrows a complete registered photo catalog and the owner's settings view.
  PhotoCaptureController({required this.facade, required this.settings}) {
    final definition = settings.registry.requireRegistered(RecognitionSettings.configuration);
    final ids = configurations.map((configuration) => configuration.id).toSet();
    if (definition.choices.any((choice) => !ids.contains(choice.value))) {
      throw ArgumentError('Photo catalog must contain every recognition choice');
    }
    settings.addListener(_settingsChanged);
  }

  /// Borrowed interaction authority; never disposed here.
  final PhotoCaptureFacade facade;

  /// Borrowed settings authority; desired intent is read directly from it.
  final SettingsView settings;

  /// Registered generic routes in catalog order.
  List<RecognitionConfiguration> get configurations => facade.configurations;
  /// Camera support, independent of saved-original recognition readiness.
  bool get isSupported => facade.isSupported;
  /// Persisted or currently edited desired intent from borrowed settings.
  String get desiredConfigurationId => settings.value(RecognitionSettings.configuration);
  /// Whether this interaction already owns an operation.
  bool get busy => _busy;
  /// Actual last interaction failure.
  Object? get error => _error;
  /// Latest explicit probe/preparation snapshots; these do not prove inference.
  List<RecognitionProviderAvailability> get availability => _availability;
  /// Actual accepted durable report, or null before one completes.
  RecognitionComparison? get comparison => _comparison;

  bool _busy = false;
  Object? _error;
  List<RecognitionProviderAvailability> _availability = const [];
  RecognitionComparison? _comparison;
  bool _disposed = false;
  bool _superDisposed = false;
  int _dispatchDepth = 0;
  final _listeners = <VoidCallback>[];

  /// Restores settings explicitly, then probes even if restoration is blocked.
  Future<void> initialize() => _operate(() async {
    Object? loadError;
    StackTrace? loadStack;
    try {
      await settings.load();
    } catch (error, stack) {
      loadError = error;
      loadStack = stack;
    }
    final snapshots = await facade.availability();
    if (loadError != null) Error.throwWithStackTrace(loadError, loadStack!);
    if (!_disposed) _availability = List.unmodifiable(snapshots);
  });

  /// Probes capability without authorizing downloads or changing intent.
  Future<void> refreshAvailability() => _operate(() async {
    final snapshots = await facade.availability();
    if (!_disposed) _availability = List.unmodifiable(snapshots);
  });

  /// Explicit preparation publishes only the returned Core snapshot.
  Future<RecognitionProviderAvailability> prepareProvider(String providerId) =>
      _operate(() async {
        final prepared = await facade.prepareProvider(providerId);
        if (!_disposed) {
          final updated = List<RecognitionProviderAvailability>.of(_availability);
          final index = updated.indexWhere((item) => item.providerId == prepared.providerId);
          if (index < 0) {
            updated.add(prepared);
          } else {
            updated[index] = prepared;
          }
          _availability = List.unmodifiable(updated);
        }
        return prepared;
      });

  /// Changes desired intent synchronously; save status stays with settings.
  void selectConfiguration(String id) {
    _requireIdle();
    final definition = settings.registry.requireRegistered(RecognitionSettings.configuration);
    definition.validate(id);
    if (!configurations.any((configuration) => configuration.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown photo configuration');
    }
    settings.setValue(definition.id, id);
  }

  /// Acquires with the desired ID snapshotted before operation notification.
  /// Optional immutable context belongs only to this accepted operation.
  Future<RecognitionComparison?> capture({RecognitionOperationContext? operationContext}) {
    _requireIdle();
    final desired = desiredConfigurationId;
    return _operate(() async {
      _requireSettingsReady();
      final report = await facade.capture(desiredConfigurationId: desired,
        operationContext: operationContext);
      _accept(report);
      return report;
    });
  }

  /// Recovers acquisition with the operation's start-time desired ID.
  /// Optional immutable context is forwarded without being retained.
  Future<RecognitionComparison?> recover({RecognitionOperationContext? operationContext}) {
    _requireIdle();
    final desired = desiredConfigurationId;
    return _operate(() async {
      _requireSettingsReady();
      final report = await facade.recover(desiredConfigurationId: desired,
        operationContext: operationContext);
      _accept(report);
      return report;
    });
  }

  /// Recognizes the accepted report's unchanged saved original.
  /// Uses the current call's optional context, never the prior report's intent.
  Future<RecognitionComparison> recognizeCurrent({RecognitionOperationContext? operationContext}) {
    _requireIdle();
    final desired = desiredConfigurationId;
    return _operate(() async {
      _requireSettingsReady();
      final original = _requireComparison().material;
      final report = await facade.recognize(original, desiredConfigurationId: desired,
        operationContext: operationContext);
      _accept(report);
      return report;
    });
  }

  /// Recognizes the exact saved original through an explicit registered route.
  /// Borrowed desired settings, acquisition and preparation are untouched.
  /// Optional caller context is forwarded through the existing operation guard.
  Future<RecognitionComparison> recognizeOriginal(
    CaptureMaterialReference material, {required String desiredConfigurationId,
    RecognitionOperationContext? operationContext,
  }) => _operate(() async {
    _requireSettingsReady();
    if (!configurations.any((route) => route.id == desiredConfigurationId)) {
      throw ArgumentError.value(desiredConfigurationId,
        'desiredConfigurationId', 'Unknown photo configuration');
    }
    final report = await facade.recognize(material,
      desiredConfigurationId: desiredConfigurationId, operationContext: operationContext);
    _accept(report);
    return report;
  });

  /// Compares every registered desired choice in its declared order.
  /// The optional context is shared only within this comparison operation.
  Future<RecognitionComparison> compareCurrent({RecognitionOperationContext? operationContext}) => _operate(() async {
    _requireSettingsReady();
    final report = await facade.compare(
      _requireComparison().material,
      configurationIds: RecognitionSettings.configuration.choices.map((choice) => choice.value),
      operationContext: operationContext,
    );
    _accept(report);
    return report;
  });

  /// Displays a saved report independently of settings or camera readiness.
  Future<RecognitionComparison> loadComparison(String id) => _operate(() async {
    final report = await facade.findComparison(id);
    if (report == null) throw StateError('Comparison not found: $id');
    _accept(report);
    return report;
  });

  /// Retries restoration; inspect the settings snapshot for read success.
  Future<void> retrySettingsLoad() => _operate(settings.retryLoad);

  /// Retries persistence; completion does not replace unsaved/save state.
  Future<void> retrySettingsSave() => _operate(settings.retrySave);

  RecognitionComparison _requireComparison() =>
      _comparison ?? (throw StateError('No saved comparison'));

  void _requireSettingsReady() {
    if (settings.snapshot.readState != SettingsReadState.ready) {
      throw StateError('Recognition settings are not ready');
    }
  }

  void _accept(RecognitionComparison? report) {
    if (!_disposed && report != null) _comparison = report;
  }

  void _requireIdle() {
    if (_disposed) throw StateError('PhotoCaptureController is disposed');
    if (_busy) throw StateError('A photo interaction is already active');
  }

  Future<T> _operate<T>(Future<T> Function() operation) {
    _requireIdle();
    _error = null;
    _busy = true;
    notifyListeners();
    return _finish(operation);
  }

  Future<T> _finish<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      if (!_disposed) _error = error;
      rethrow;
    } finally {
      if (!_disposed) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void _settingsChanged() => notifyListeners();

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) throw StateError('PhotoCaptureController is disposed');
    _listeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_superDisposed) return;
    _listeners.remove(listener);
    super.removeListener(listener);
  }

  /// Allows disposal from a listener without late use of the super notifier.
  @override
  void notifyListeners() {
    if (_disposed) return;
    _dispatchDepth++;
    try {
      super.notifyListeners();
    } finally {
      _dispatchDepth--;
      if (_disposed && _dispatchDepth == 0) _disposeNotifier();
    }
  }

  /// Detaches once; active Core work settles its caller without late publication.
  @override
  // ignore: must_call_super
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    settings.removeListener(_settingsChanged);
    for (final listener in _listeners) {
      super.removeListener(listener);
    }
    _listeners.clear();
    if (_dispatchDepth == 0) _disposeNotifier();
  }

  void _disposeNotifier() {
    if (_superDisposed) return;
    _superDisposed = true;
    super.dispose();
  }
}
