import 'package:flutter/foundation.dart';

import 'resource_collection_view.dart';
import 'resource_data_source.dart';
import 'resource_detail_view.dart';

/// Compatibility adapter for the standard List/Detail Widget.
///
/// The application-wide View Model owns the semantic collection and detail
/// views. This adapter combines their notifications and public API for existing
/// List/Detail presentations; it does not own app-wide state.
class ResourceViewModel extends ChangeNotifier {
  factory ResourceViewModel({
    required ResourceDataSource dataSource,
    ResourceActionHandler? actionHandler,
  }) {
    final collection = ResourceCollectionView(dataSource: dataSource);
    final detail = ResourceDetailView(
      dataSource: dataSource,
      actionHandler: actionHandler,
      onActionSucceeded: collection.load,
    );
    return ResourceViewModel._(
      collectionView: collection,
      detailView: detail,
      ownsViews: true,
    );
  }

  /// Presents views owned by an application view space without disposing them.
  ResourceViewModel.fromViews({
    required ResourceCollectionView collectionView,
    required ResourceDetailView detailView,
  }) : this._(
         collectionView: collectionView,
         detailView: detailView,
         ownsViews: false,
       );

  ResourceViewModel._({
    required this.collectionView,
    required this.detailView,
    required this._ownsViews,
  }) {
    collectionView.addListener(_notify);
    detailView.addListener(_notify);
  }

  final ResourceCollectionView collectionView;
  final ResourceDetailView detailView;
  final bool _ownsViews;
  bool _disposed = false;

  ResourceDataSource get dataSource => collectionView.dataSource;
  ResourceActionHandler? get actionHandler => detailView.actionHandler;
  List<ResourceRecord>? get resources => collectionView.resources;
  ResourceRecord? get selectedResource => detailView.resource;
  String? get selectedId => detailView.selectedId;
  bool get listLoading => collectionView.loading;
  bool get listFailed => collectionView.failed;
  bool get detailLoading => detailView.loading;
  bool get detailFailed => detailView.failed;
  bool get actionRunning => detailView.actionRunning;
  bool get actionFailed => detailView.actionFailed;
  List<ResourceAction> get selectedActions => detailView.actions;

  Future<void> load() => collectionView.load();
  Future<void> select(String id) => detailView.select(id);
  Future<void> performAction(String actionId) =>
      detailView.performAction(actionId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    collectionView.removeListener(_notify);
    detailView.removeListener(_notify);
    if (_ownsViews) {
      collectionView.dispose();
      detailView.dispose();
    }
    super.dispose();
  }
}
