import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'resource_data_source.dart';

/// Read-only CNCF binding for the standard Resource List/Detail Widget.
///
/// The wire observations remain available with their independent string revision,
/// definitions, context and optional snapshot. ResourceRecord is a presentation
/// adapter only: its integer revision is not used as a mutation observation.
final class CncfDisplayResourceDataSource implements ResourceDataSource {
  CncfDisplayResourceDataSource({required this.client});
  final CncfDisplayReadClient client;
  CncfDisplayRead? _lastQuery;
  CncfDisplayRead? _lastDetail;
  CncfDisplayRead? get lastQuery => _lastQuery;
  CncfDisplayRead? get lastDetail => _lastDetail;

  @override
  Future<List<ResourceRecord>> listResources() async {
    final result = await client.query();
    final records = result.resources.map(_record).toList(growable: false);
    _lastQuery = result;
    return List.unmodifiable(records);
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    final result = await client.read(id);
    final record = _record(result.resources.single);
    _lastDetail = result;
    return record;
  }

  ResourceRecord _record(CncfDisplayResource resource) {
    final values = <String, String>{};
    for (final field in resource.fields) {
      final id = field['id']! as String;
      // Existing ResourceRecord keys are flat. Reject an ambiguous projection;
      // never silently overwrite two same-ID fields from different sections.
      if (values.containsKey(id)) {
        throw const CncfDisplayReadException('ambiguousResourceField');
      }
      values[id] = resource.text(id);
    }
    return ResourceRecord(id: resource.entityId, values: values);
  }
}
