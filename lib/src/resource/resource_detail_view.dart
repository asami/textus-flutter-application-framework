import 'package:flutter/foundation.dart';

import '../view/application_view_model.dart';
import 'resource_data_source.dart';

/// Observable read projection and action state for one selected resource.
class ResourceDetailView extends ChangeNotifier implements ApplicationView {
  ResourceDetailView({
    required this.dataSource,
    this.actionHandler,
    this.onActionSucceeded,
  });

  final ResourceDataSource dataSource;
  final ResourceActionHandler? actionHandler;

  /// Invalidate other dependent views after an aggregate command succeeds.
  final Future<void> Function()? onActionSucceeded;

  ResourceRecord? _resource;
  String? _selectedId;
  bool _loading = false;
  bool _failed = false;
  bool _actionRunning = false;
  bool _actionFailed = false;
  bool _disposed = false;
  int _generation = 0;

  ResourceRecord? get resource => _resource;
  String? get selectedId => _selectedId;
  bool get loading => _loading;
  bool get failed => _failed;
  bool get actionRunning => _actionRunning;
  bool get actionFailed => _actionFailed;
  List<ResourceAction> get actions => _resource == null
      ? const []
      : actionHandler?.actionsFor(_resource!) ?? const [];

  Future<void> select(String id) async {
    if (_disposed) return;
    final generation = ++_generation;
    _selectedId = id;
    _resource = null;
    _loading = true;
    _failed = false;
    _actionFailed = false;
    _notify();
    try {
      final resource = await dataSource.getResource(id);
      if (_disposed || generation != _generation) return;
      _resource = resource;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _failed = true;
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    final id = _selectedId;
    if (id != null) await select(id);
  }

  Future<void> performAction(String actionId) async {
    if (_disposed) return;
    final selected = _resource;
    final handler = actionHandler;
    if (_actionRunning ||
        selected == null ||
        handler == null ||
        !handler.actionsFor(selected).any((action) => action.id == actionId)) {
      return;
    }
    _actionRunning = true;
    _actionFailed = false;
    _notify();
    try {
      await handler.execute(actionId, selected);
      if (_disposed) return;
      await onActionSucceeded?.call();
      if (!_disposed && _selectedId == selected.id) await refresh();
    } catch (_) {
      if (!_disposed && _selectedId == selected.id) _actionFailed = true;
    } finally {
      if (!_disposed) {
        _actionRunning = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
