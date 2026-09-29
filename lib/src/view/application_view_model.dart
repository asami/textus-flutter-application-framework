import 'dart:collection';

import 'package:flutter/foundation.dart';

/// One observable semantic view in an application's view space.
///
/// Views represent readable application state, not Widgets or routes.
abstract interface class ApplicationView implements Listenable {
  void dispose();
}

/// Owns the named views for one application session.
///
/// Screens may observe the same view without becoming its owner. Views are
/// created by the application and can be backed by local or remote sources.
class ApplicationViewModel extends ChangeNotifier {
  ApplicationViewModel(Map<String, ApplicationView> views)
    : _views = Map.unmodifiable(views) {
    if (_views.isEmpty || _views.keys.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(views, 'views', 'Nonempty view IDs required');
    }
    final uniqueViews = HashSet<ApplicationView>.identity();
    for (final view in _views.values) {
      if (!uniqueViews.add(view)) {
        throw ArgumentError.value(
          views,
          'views',
          'Each view must have one stable ID',
        );
      }
    }
    for (final view in _views.values) {
      view.addListener(_notify);
    }
  }

  final Map<String, ApplicationView> _views;
  bool _disposed = false;

  Iterable<String> get viewIds => _views.keys;

  T view<T extends ApplicationView>(String id) {
    final selected = _views[id];
    if (selected == null) throw ArgumentError.value(id, 'id', 'Unknown view');
    if (selected is! T) {
      throw StateError('View $id is not a $T');
    }
    return selected;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final view in _views.values) {
      view.removeListener(_notify);
      view.dispose();
    }
    super.dispose();
  }
}
