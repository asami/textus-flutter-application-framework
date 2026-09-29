/// A presentation-neutral resource supplied by an application binding.
class ResourceRecord {
  ResourceRecord({
    required this.id,
    required Map<String, String> values,
    this.revision = 0,
  }) : values = Map.unmodifiable(values);

  final String id;
  final Map<String, String> values;

  /// Projection revision supplied to an aggregate command for conflict checks.
  final int revision;

  String value(String field) => values[field] ?? '';
}

/// The same boundary can be backed by fake data or generated Operation clients.
abstract interface class ResourceDataSource {
  Future<List<ResourceRecord>> listResources();

  Future<ResourceRecord?> getResource(String id);
}

/// A view action represents an intent; aggregate commands remain app-owned.
class ResourceAction {
  const ResourceAction({required this.id, required this.label});

  final String id;
  final String label;
}

/// Maps view intents to application commands without writing the projection.
abstract interface class ResourceActionHandler {
  List<ResourceAction> actionsFor(ResourceRecord record);

  Future<void> execute(String actionId, ResourceRecord record);
}
