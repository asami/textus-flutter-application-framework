import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

void main() {
  group('Settings record shape and retained compatibility envelope', () {
    test('R01 empty record roundtrips without implicit defaults', () {
      // Given absent storage represented by an empty record.
      final record = SettingsRecord.empty();

      // When that record is encoded and decoded.
      final restored = SettingsRecord.decode(record.encode());

      // Then version one is supported and no catalog defaults are introduced.
      expect(SettingsRecord.currentVersion, 1);
      expect(restored.version, 1);
      expect(restored.isSupported, isTrue);
      expect(restored.values, isEmpty);
      expect(restored.extraFields, isEmpty);
      expect(jsonDecode(record.encode()), {'version': 1, 'values': {}});
    });

    test('R02 supported record retains scalar null nested and extra data', () {
      // Given JSON containing unrelated scalar and structured application data.
      final envelope = {
        'version': 1,
        'values': {
          'unknown': 'opaque',
          'number': 17,
          'flag': true,
          'null': null,
          'nested': {
            'list': [
              null,
              false,
              {'leaf': 2.5},
            ],
          },
        },
        'application': {'name': 'sample', 'optional': null},
        'extraList': [1, 'two'],
      };

      // When the codec decodes and re-encodes the envelope.
      final record = SettingsRecord.decode(jsonEncode(envelope));
      final encoded = jsonDecode(record.encode());

      // Then all semantic JSON data survives without registry interpretation.
      expect(record.isSupported, isTrue);
      expect(record.values, envelope['values']);
      expect(record.extraFields, {
        'application': envelope['application'],
        'extraList': envelope['extraList'],
      });
      expect(encoded, envelope);
      expect(record.values.containsKey('null'), isTrue);
    });

    test('R03 malformed JSON and invalid envelope shapes reject', () {
      // Given malformed text and every missing or wrong required shape.
      final sources = [
        '{',
        'null',
        '[]',
        '"scalar"',
        '12',
        'true',
        '{}',
        '{"values":{}}',
        '{"version":1}',
        '{"version":null,"values":{}}',
        '{"version":true,"values":{}}',
        '{"version":"1","values":{}}',
        '{"version":1.0,"values":{}}',
        '{"version":[],"values":{}}',
        '{"version":{},"values":{}}',
        '{"version":1,"values":null}',
        '{"version":1,"values":[]}',
        '{"version":1,"values":"scalar"}',
        '{"version":1,"values":3}',
        '{"version":1,"values":false}',
      ];

      // When each source is offered to the public decoder.
      final attempts = sources.map(
        (source) =>
            () => SettingsRecord.decode(source),
      );

      // Then each independent malformed envelope throws FormatException.
      for (final attempt in attempts) {
        expect(attempt, throwsFormatException);
      }
    });

    test('R04 unsupported integer versions retain data and block updates', () {
      // Given zero, negative and future integer versions with retained data.
      final versions = [-3, 0, 2, 99];

      // When each well-formed envelope is decoded.
      final records = [
        for (final version in versions)
          SettingsRecord.decode(
            jsonEncode({
              'version': version,
              'values': {'unknown': null},
              'owner': 'application',
            }),
          ),
      ];

      // Then none is silently upgraded or allowed an ordinary update.
      for (var index = 0; index < records.length; index++) {
        final record = records[index];
        expect(record.version, versions[index]);
        expect(record.isSupported, isFalse);
        expect(record.values, {'unknown': null});
        expect(record.extraFields, {'owner': 'application'});
        expect(() => record.withUpdates({'edit': true}), throwsStateError);
        expect(SettingsRecord.decode(record.encode()).version, versions[index]);
      }
    });

    test('R05 explicit version reset upgrades and retains unrelated data', () {
      // Given a future envelope with unrelated values and top-level fields.
      final original = SettingsRecord.decode(
        '{"version":8,"values":{"old":null,"edit":false},"extra":[1,2]}',
      );

      // When an explicitly authorized version reset overlays one key.
      final reset = original.withUpdates({'edit': true}, resetVersion: true);

      // Then only the version and named key change, leaving the original intact.
      expect(reset.version, 1);
      expect(reset.values, {'old': null, 'edit': true});
      expect(reset.extraFields, {
        'extra': [1, 2],
      });
      expect(original.version, 8);
      expect(original.values['edit'], isFalse);
    });
  });

  group('Settings record immutable updates and semantic roundtrips', () {
    test('R06 overlay replaces only named keys and preserves its source', () {
      // Given a supported record with two unrelated values and an extra field.
      final source = SettingsRecord.decode(
        '{"version":1,"values":{"a":1,"b":{"kept":true}},"extra":null}',
      );

      // When updates replace one value and add an explicit null.
      final updated = source.withUpdates({'a': 2, 'new': null});

      // Then the old envelope and every unnamed value remain intact.
      expect(source.values, {
        'a': 1,
        'b': {'kept': true},
      });
      expect(updated.values, {
        'a': 2,
        'b': {'kept': true},
        'new': null,
      });
      expect(updated.extraFields, {'extra': null});
      expect(source.values.containsKey('new'), isFalse);
    });

    test('R07 recursive aliases and exposed collections cannot mutate data', () {
      // Given mutable nested maps/lists supplied as programmatic updates.
      final leaf = <String, Object?>{'value': 1};
      final list = <Object?>[leaf];
      final updates = <String, Object?>{'nested': list};
      final base = SettingsRecord.decode(
        '{"version":1,"values":{},"extra":{"list":[null]}}',
      );

      // When updates are copied and every source alias is subsequently changed.
      final record = base.withUpdates(updates);
      leaf['value'] = 2;
      list.add('later');
      updates.clear();
      final retainedList = record.values['nested'] as List<Object?>;
      final retainedMap = retainedList.single as Map<String, Object?>;
      final extra = record.extraFields['extra'] as Map<String, Object?>;

      // Then the copy is unchanged and all exposed nested collections reject mutation.
      expect(retainedList, [
        {'value': 1},
      ]);
      expect(() => record.values['new'] = true, throwsUnsupportedError);
      expect(() => retainedList.add(null), throwsUnsupportedError);
      expect(() => retainedMap['value'] = 3, throwsUnsupportedError);
      expect(() => record.extraFields.clear(), throwsUnsupportedError);
      expect(() => extra['new'] = true, throwsUnsupportedError);
      expect(() => (extra['list'] as List).clear(), throwsUnsupportedError);
    });

    test(
      'R08 invalid JSON updates reject atomically without source mutation',
      () {
        // Given a supported baseline and non-JSON, nonfinite, wrong-key or cyclic data.
        final source = SettingsRecord.empty().withUpdates({'kept': true});
        final cyclicList = <Object?>[];
        cyclicList.add(cyclicList);
        final cyclicMap = <String, Object?>{};
        cyclicMap['self'] = cyclicMap;
        final invalid = <Object?>[
          Object(),
          DateTime(2026),
          double.nan,
          double.infinity,
          double.negativeInfinity,
          {1: 'wrong key'},
          [
            true,
            {'nested': double.infinity},
          ],
          cyclicList,
          cyclicMap,
        ];

        // When each invalid value is submitted with an otherwise valid overlay.
        final attempts = invalid.map(
          (value) =>
              () => source.withUpdates({'kept': false, 'invalid': value}),
        );

        // Then ArgumentError leaves the original envelope unchanged.
        for (final attempt in attempts) {
          expect(attempt, throwsArgumentError);
          expect(source.values, {'kept': true});
        }
      },
    );

    test('R09 numeric wire data roundtrips without catalog coercion', () {
      // Given wire integers, doubles and a noncatalog multiplier.
      final source = SettingsRecord.decode(
        '{"version":1,"values":{"integer":1,"double":1.0,"other":1.2}}',
      );

      // When the raw record is encoded and decoded again.
      final restored = SettingsRecord.decode(source.encode());

      // Then numeric data retains its codec type without becoming typed choices.
      expect(restored.values['integer'], isA<int>());
      expect(restored.values['double'], isA<double>());
      expect(restored.values, {'integer': 1, 'double': 1.0, 'other': 1.2});
      expect(source.values, restored.values);
    });

    test(
      'R10 unknown data survives successive updates reset and storage',
      () async {
        // Given a future application envelope and controllable whole-record storage.
        final original = SettingsRecord.decode(
          '{"version":12,"values":{"unknown":[null,{"leaf":true}]},"owner":{"id":4}}',
        );
        final storage = ControllableSettingsStorage();

        // When explicit reset and successive updates are encoded and acknowledged.
        final updated = original
            .withUpdates({'common': 'automatic'}, resetVersion: true)
            .withUpdates({'another': 1})
            .withUpdates({'common': 'changed'});
        final written = storage.write(updated.encode());
        storage.writes.single.succeed();
        await written;
        final restored = SettingsRecord.decode(storage.durableRecord!);

        // Then every unrelated unknown value/extra survives and acknowledgement is unique.
        expect(restored.version, 1);
        expect(restored.values, {
          'unknown': [
            null,
            {'leaf': true},
          ],
          'common': 'changed',
          'another': 1,
        });
        expect(restored.extraFields, {
          'owner': {'id': 4},
        });
        expect(storage.activeWrites, 0);
        expect(() => storage.writes.single.succeed(), throwsStateError);
      },
    );
  });
}
