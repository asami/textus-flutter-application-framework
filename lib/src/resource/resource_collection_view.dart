import 'package:flutter/foundation.dart';

import '../view/application_view_model.dart';
import 'resource_data_source.dart';

/// Observable read projection for one collection of resources.
class ResourceCollectionView extends ChangeNotifier implements ApplicationView {
  ResourceCollectionView({required this.dataSource});

  final ResourceDataSource dataSource;

  List<ResourceRecord>? _resources;
  bool _loading = false;
  bool _failed = false;
  bool _disposed = false;
  int _generation = 0;

  List<ResourceRecord>? get resources => _resources;
  bool get loading => _loading;
  bool get failed => _failed;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    _loading = true;
    _failed = false;
    _notify();
    try {
      final resources = await dataSource.listResources();
      if (_disposed || generation != _generation) return;
      _resources = List.unmodifiable(resources);
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
