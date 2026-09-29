import 'resource_data_source.dart';

/// CRUD-shaped transport port supplied by an application integration layer.
///
/// A REST implementation may use generated Operation clients. This interface
/// does not grant write authority or define server-side Aggregate semantics.
abstract interface class CrudResourceClient<R, CreateInput, UpdateInput> {
  Future<List<R>> list();

  Future<R?> read(String id);

  Future<R> create(CreateInput input);

  Future<R> update(
    String id,
    UpdateInput input, {
    required int expectedRevision,
  });

  Future<void> delete(String id, {required int expectedRevision});
}

/// Projects a CRUD client into the framework's resource read contract.
///
/// Write methods retain the caller's typed input and observed revision. An
/// application must bind them only to authorized server Operations whose
/// implementation enforces the appropriate Aggregate rules.
final class CrudResourceAdapter<R, CreateInput, UpdateInput>
    implements ResourceDataSource {
  const CrudResourceAdapter({required this.client, required this.project});

  final CrudResourceClient<R, CreateInput, UpdateInput> client;
  final ResourceRecord Function(R) project;

  @override
  Future<List<ResourceRecord>> listResources() async =>
      List.unmodifiable((await client.list()).map(project));

  @override
  Future<ResourceRecord?> getResource(String id) async {
    final resource = await client.read(id);
    return resource == null ? null : project(resource);
  }

  Future<ResourceRecord> create(CreateInput input) async =>
      project(await client.create(input));

  Future<ResourceRecord> update(
    String id,
    UpdateInput input, {
    required int expectedRevision,
  }) async => project(
    await client.update(id, input, expectedRevision: expectedRevision),
  );

  Future<void> delete(String id, {required int expectedRevision}) =>
      client.delete(id, expectedRevision: expectedRevision);
}
