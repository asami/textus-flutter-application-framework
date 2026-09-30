import 'package:flutter/foundation.dart';

import '../settings/setting_definition.dart';
import '../settings/settings_registry.dart';
import '../settings/settings_service.dart';
import '../settings/settings_snapshot.dart';
import 'application_view_model.dart';

/// Observable application-session Settings view with explicit service ownership.
///
/// Register under an application-chosen stable ID (for example `settings`).
/// Delegates to the service without copying state, knowing storage, replacing
/// resource views or issuing domain commands. Composition explicitly calls load.
class SettingsView extends ChangeNotifier implements ApplicationView {
  /// Attaches one listener and takes responsibility for disposing the service.
  SettingsView.owned({required SettingsService service})
    : this._(service, true);

  /// Attaches one listener while leaving service lifetime with its caller.
  SettingsView.fromService({required SettingsService service})
    : this._(service, false);

  SettingsView._(this.service, this._ownsService) {
    service.addListener(_notify);
  }

  /// Observable service authority, owned or borrowed according to construction.
  final SettingsService service;
  final bool _ownsService;
  bool _disposed = false;

  /// Registered schema, read directly from the service.
  SettingsRegistry get registry => service.registry;

  /// Latest immutable state, read directly from the service.
  SettingsSnapshot get snapshot => service.snapshot;

  /// Reads a value with registered-definition type and identity validation.
  T value<T extends Object>(SettingDefinition<T> definition) =>
      snapshot.value(definition);

  /// Resolves ephemeral capability availability without changing values.
  SettingAvailability availability(
    String id,
    SettingsCapabilities capabilities,
  ) => registry.definition(id).availability(capabilities);

  /// Explicitly asks the service to load; constructors never start restoration.
  Future<void> load() {
    _requireActive();
    return service.load();
  }

  /// Delegates an explicit restoration retry.
  Future<void> retryLoad() {
    _requireActive();
    return service.retryLoad();
  }

  /// Delegates retry of the latest unsaved state.
  Future<void> retrySave() {
    _requireActive();
    return service.retrySave();
  }

  /// Validates the ID/type/catalog before forwarding an explicit edit.
  void setValue(String id, Object value) {
    _requireActive();
    registry.definition(id).validate(value);
    service.setValue(id, value);
  }

  /// Delegates explicit common reset, including a reset when already default.
  void resetCommon() {
    _requireActive();
    service.resetCommon();
  }

  void _requireActive() {
    if (_disposed) throw StateError('SettingsView is disposed');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Detaches once and disposes only an owned service; idempotent.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    service.removeListener(_notify);
    if (_ownsService) service.dispose();
    super.dispose();
  }
}
