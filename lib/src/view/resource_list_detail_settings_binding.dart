import 'dart:collection';

import '../settings/common_settings.dart';
import '../settings/setting_definition.dart';
import '../settings/settings_snapshot.dart';
import 'resource_list_detail_display_model.dart';
import 'resource_list_detail_hinge_policy.dart';
import 'settings_view.dart';

/// Borrows Settings and all resource-tab display models for one composition.
///
/// Include inactive and unmounted tabs. Display models are presentation state,
/// not registered semantic Resource Views. Construction never loads or writes.
/// Dispose this binding before disposing its borrowed View or models.
class ResourceListDetailSettingsBinding {
  /// Validates the catalog and a copied, nonempty, distinct model list.
  ResourceListDetailSettingsBinding({
    required this._view,
    required Iterable<ResourceListDetailDisplayModel> displayModels,
    SettingsCapabilities? capabilities,
  }) : _displayModels = List.unmodifiable(displayModels),
       _capabilities = capabilities ?? SettingsCapabilities() {
    if (_displayModels.isEmpty ||
        _displayModels.toSet().length != _displayModels.length) {
      throw ArgumentError('Display models must be nonempty and distinct');
    }
    for (final definition in CommonSettings.definitions) {
      _view.registry.requireRegistered(definition);
    }
    _snapshot = _view.snapshot;
    _processedIntentRevision = _snapshot.lastIntent?.revision ?? 0;
    // Observe reentrant edits before the initial synchronous model fanout.
    _view.addListener(_changed);
    _enqueue(_snapshot, _capabilities);
  }

  final SettingsView _view;
  final List<ResourceListDetailDisplayModel> _displayModels;
  final _pending = Queue<_SettingsPresentationEvent>();
  late SettingsSnapshot _snapshot;
  SettingsCapabilities _capabilities;
  late int _processedIntentRevision;
  bool _applying = false;
  bool _disposed = false;

  void _changed() {
    if (_disposed) return;
    _snapshot = _view.snapshot;
    _enqueue(_snapshot, _capabilities);
  }

  /// Re-resolves retained values without creating intent or persistence.
  /// Reentrant updates join the same FIFO queue as Settings notifications.
  void updateCapabilities(SettingsCapabilities capabilities) {
    if (_disposed) throw StateError('Settings binding is disposed');
    _capabilities = capabilities;
    _enqueue(_snapshot, capabilities);
  }

  void _enqueue(SettingsSnapshot snapshot, SettingsCapabilities capabilities) {
    _pending.add(_SettingsPresentationEvent(snapshot, capabilities));
    if (_applying) return;
    _applying = true;
    try {
      while (!_disposed && _pending.isNotEmpty) {
        final event = _pending.removeFirst();
        final intent = event.snapshot.lastIntent;
        var clearPane = false;
        var clearHinge = false;
        if (intent != null && intent.revision > _processedIntentRevision) {
          // Consume before fanout so nested notifications cannot replay intent.
          _processedIntentRevision = intent.revision;
          clearPane =
              intent.kind == SettingsIntentKind.resetCommon ||
              intent.settingId == CommonSettings.panePreference.id;
          clearHinge =
              intent.kind == SettingsIntentKind.resetCommon ||
              intent.settingId == CommonSettings.hingePreference.id;
        }
        final hinge =
            event.snapshot.hasExplicitValue(CommonSettings.hingePreference.id)
            ? _mapHinge(event.snapshot.value(CommonSettings.hingePreference))
            : null;
        final applicable =
            _view.availability(
              CommonSettings.hingePreference.id,
              event.capabilities,
            ) ==
            SettingAvailability.available;
        for (final model in _displayModels) {
          if (_disposed) break;
          model.applySettingsPreferences(
            panePreference: event.snapshot.value(CommonSettings.panePreference),
            hingePreference: hinge,
            hingeApplicable: applicable,
            clearPaneOverride: clearPane,
            clearHingeOverride: clearHinge,
          );
        }
      }
    } finally {
      _applying = false;
    }
  }

  /// Detaches only this binding; safe during fanout and on repeated calls.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _view.removeListener(_changed);
    _pending.clear();
  }
}

ResourceListDetailHingePolicy _mapHinge(SettingsHingePreference preference) =>
    switch (preference) {
      SettingsHingePreference.automatic =>
        ResourceListDetailHingePolicy.automatic,
      SettingsHingePreference.avoid => ResourceListDetailHingePolicy.avoid,
      SettingsHingePreference.span => ResourceListDetailHingePolicy.span,
    };

class _SettingsPresentationEvent {
  _SettingsPresentationEvent(this.snapshot, this.capabilities);

  final SettingsSnapshot snapshot;
  final SettingsCapabilities capabilities;
}
