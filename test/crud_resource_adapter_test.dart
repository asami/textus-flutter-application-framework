import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

final class _Row {
  const _Row(this.id, this.title, this.revision);

  final String id;
  final String title;
  final int revision;
}

final class _Client implements CrudResourceClient<_Row, String, String> {
  final rows = <String, _Row>{'one': const _Row('one', 'First', 2)};
  int? observedRevision;

  @override
  Future<List<_Row>> list() async => rows.values.toList();

  @override
  Future<_Row?> read(String id) async => rows[id];

  @override
  Future<_Row> create(String input) async {
    final row = _Row('two', input, 0);
    rows[row.id] = row;
    return row;
  }

  @override
  Future<_Row> update(
    String id,
    String input, {
    required int expectedRevision,
  }) async {
    observedRevision = expectedRevision;
    final old = rows[id]!;
    if (old.revision != expectedRevision) throw StateError('stale');
    final next = _Row(id, input, old.revision + 1);
    rows[id] = next;
    return next;
  }

  @override
  Future<void> delete(String id, {required int expectedRevision}) async {
    observedRevision = expectedRevision;
    if (rows[id]?.revision != expectedRevision) throw StateError('stale');
    rows.remove(id);
  }
}

void main() {
  test('CRUD client projects into the resource read contract', () async {
    final client = _Client();
    final adapter = CrudResourceAdapter<_Row, String, String>(
      client: client,
      project: (row) => ResourceRecord(
        id: row.id,
        revision: row.revision,
        values: {'title': row.title},
      ),
    );

    expect((await adapter.listResources()).single.value('title'), 'First');
    expect((await adapter.getResource('one'))!.revision, 2);
    expect(await adapter.getResource('missing'), isNull);

    final created = await adapter.create('Second');
    expect(created.id, 'two');
    final updated = await adapter.update('one', 'Changed', expectedRevision: 2);
    expect(updated.revision, 3);
    expect(client.observedRevision, 2);
    expect(
      () => adapter.update('one', 'Stale', expectedRevision: 2),
      throwsStateError,
    );
    await adapter.delete('one', expectedRevision: 3);
    expect(await adapter.getResource('one'), isNull);
    expect(client.observedRevision, 3);
  });
}
