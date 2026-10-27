import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';

ResourceListDetailConfiguration configuration(String name) =>
    ResourceListDetailConfiguration(
      listTitle: '$name list',
      detailTitle: '$name detail',
      primaryField: 'title',
      detailFields: [
        ResourceFieldConfiguration(key: 'title', label: '$name title'),
      ],
    );

CncfDisplayReadProfile profile({
  String? componentId,
  String? resourceType,
  String listScreenId = 'collecting-resources',
  String detailScreenId = 'capture-detail',
  String definitionRevision = 'ess-reference-definition-1',
  Map<String, Object?>? semanticContract,
  Map<String, Object?>? provenance,
}) {
  final initial = mutationFixture('detail-initial');
  return CncfDisplayReadProfile(
    componentId: componentId ?? initial['componentId']! as String,
    resourceType: resourceType ?? initial['resourceType']! as String,
    listScreenId: listScreenId,
    detailScreenId: detailScreenId,
    definitionRevision: definitionRevision,
    semanticContract:
        semanticContract ??
        initial['semanticContract']! as Map<String, Object?>,
    provenance: provenance ?? initial['provenance']! as Map<String, Object?>,
  );
}

Map<String, Object?> context(List<Map<String, Object?>> families) => {
  'version': 1,
  'families': families,
};

Map<String, Object?> supplied(String variant) => context([
  {
    'name': 'cncf.presentation',
    'version': 1,
    'data': {'variant': variant},
  },
]);

CncfDisplayRead observation({
  bool detail = false,
  Map<String, Object?>? presentationContext,
}) {
  final wire = mutationFixture(detail ? 'detail-initial' : 'list-initial');
  if (presentationContext != null) {
    wire['presentationContext'] = presentationContext;
  }
  final id = detail
      ? ((wire['model']! as Map)['resource']! as Map)['entityId']! as String
      : null;
  return CncfDisplayRead.decode(
    wire,
    profile(),
    detail: detail,
    expectedResourceId: id,
  );
}

CncfDisplayPresentationRegistry registry({CncfDisplayReadProfile? trusted}) =>
    CncfDisplayPresentationRegistry(
      profile: trusted ?? profile(),
      neutralConfiguration: configuration('Neutral'),
      variants: {'reference-variant': configuration('Reference')},
    );

void main() {
  group('formal supplied presentation registry', () {
    test(
      'no observation or supported presentation family selects frozen neutral',
      () {
        // Given genuine local read baselines decorated only with controlled optional families.
        final selected = registry();
        final candidates = <CncfDisplayRead?>[
          null,
          observation(),
          observation(presentationContext: context([])),
          observation(
            presentationContext: context([
              {
                'name': 'cncf.locale',
                'version': 1,
                'data': {'languageTag': 'ja-JP'},
              },
              {
                'name': 'cncf.display-flow',
                'version': 1,
                'data': {
                  'displayInstance': 'controlled-display',
                  'correlation': 'controlled-correlation',
                  'expiresAt': '2026-10-27T01:00:00Z',
                },
              },
            ]),
          ),
          observation(
            presentationContext: context([
              {
                'name': 'cncf.presentation',
                'version': 2,
                'data': {'future': true},
              },
              {
                'name': 'example.optional',
                'version': 1,
                'data': {'variant': 'reference-variant'},
              },
            ]),
          ),
        ];
        // When each admitted observation resolves.
        final results = candidates.map(selected.resolve).toList();
        // Then optional unrelated/future data never selects a variant or rejects neutral.
        for (final result in results) {
          expect(result.isAvailable, isTrue);
          expect(result.configuration, same(selected.neutralConfiguration));
          expect(result.variant, isNull);
          expect(result.failure, isNull);
        }
      },
    );

    for (final detail in [false, true]) {
      test(
        'exact supplied variant selects a stable configuration on ${detail ? 'Detail' : 'List'}',
        () {
          // Given a formal observation with an independently registered Unicode variant.
          const exact = 'référence/二';
          final selected = CncfDisplayPresentationRegistry(
            profile: profile(),
            neutralConfiguration: configuration('Neutral'),
            variants: {
              exact: configuration('Reference'),
              'reference-variant': configuration('Other'),
            },
          );
          final read = observation(
            detail: detail,
            presentationContext: supplied(exact),
          );
          // When the same exact observation resolves repeatedly.
          final first = selected.resolve(read);
          final second = selected.resolve(read);
          // Then configuration identity and the exact supplied name are retained.
          expect(first.isAvailable, isTrue);
          expect(first.configuration, same(selected.variants[exact]));
          expect(second.configuration, same(first.configuration));
          expect(first.configuration!.listTitle, 'Reference list');
          expect(first.variant, exact);
          expect(first.failure, isNull);
        },
      );
    }

    test('unknown exact variant is explicitly unavailable without a neutral substitution', () {
      // Given a valid formal Display whose supplied variant is not installed.
      final selected = registry();
      final read = observation(
        presentationContext: supplied('Reference-variant'),
      );
      // When resolution uses the exact declared map rather than coercing the name.
      final result = selected.resolve(read);
      // Then the caller receives no configuration and an explicit redacted failure.
      expect(result.isAvailable, isFalse);
      expect(result.configuration, isNull);
      expect(result.variant, 'Reference-variant');
      expect(result.failure, CncfDisplayPresentationFailure.unknownVariant);
    });

    final mismatches = <String, CncfDisplayReadProfile Function()>{
      'component': () => profile(componentId: 'another-component'),
      'resource type': () => profile(resourceType: 'another-resource'),
      'List screen': () => profile(listScreenId: 'another-list'),
      'Detail screen': () => profile(detailScreenId: 'another-detail'),
      'definition': () => profile(definitionRevision: 'another-definition'),
      'semantic contract': () =>
          profile(semanticContract: {'schema': 'another-contract'}),
      'provenance': () =>
          profile(provenance: {'producerId': 'another-producer'}),
    };
    for (final entry in mismatches.entries) {
      test('re-admission rejects a different trusted ${entry.key}', () {
        // Given valid reads admitted by their own source and a different independent pin.
        final selected = registry(trusted: entry.value());
        final detail = entry.key == 'Detail screen';
        final read = observation(
          detail: detail,
          presentationContext: supplied('reference-variant'),
        );
        // When the registry re-admits the complete wire against its trusted profile.
        final result = selected.resolve(read);
        // Then incompatible Display never exposes an available configuration or variant.
        expect(result.isAvailable, isFalse);
        expect(result.configuration, isNull);
        expect(result.variant, isNull);
        expect(
          result.failure,
          CncfDisplayPresentationFailure.incompatibleDisplay,
        );
      });
    }

    test(
      'declarations and configurations are defensively frozen once per entry',
      () {
        // Given caller-owned mutable maps and nested field/action lists.
        final fields = [
          const ResourceFieldConfiguration(
            key: 'title',
            label: 'Original title',
          ),
        ];
        final actions = [
          const ResourceActionConfiguration(
            id: 'request-review',
            label: 'Review',
          ),
        ];
        final original = ResourceListDetailConfiguration(
          listTitle: 'Original list',
          detailTitle: 'Original detail',
          primaryField: 'title',
          detailFields: fields,
          detailActions: actions,
        );
        final variants = <String, ResourceListDetailConfiguration>{
          'reference-variant': original,
          ' reference-variant ': original,
          '二' * 128: original,
        };
        final selected = CncfDisplayPresentationRegistry(
          profile: profile(),
          neutralConfiguration: original,
          variants: variants,
        );
        // When caller-owned collections are modified after construction.
        fields.clear();
        actions.clear();
        variants.clear();
        final result = selected.resolve(
          observation(presentationContext: supplied('reference-variant')),
        );
        // Then every owned entry remains stable, exact and recursively unmodifiable.
        expect(
          result.configuration,
          same(selected.variants['reference-variant']),
        );
        expect(result.configuration, isNot(same(original)));
        expect(
          result.configuration!.detailFields.single.label,
          'Original title',
        );
        expect(result.configuration!.detailActions!.single.label, 'Review');
        expect(selected.variants.keys, contains(' reference-variant '));
        expect(selected.variants.keys, contains('二' * 128));
        expect(selected.neutralConfiguration.detailFields, hasLength(1));
        expect(() => selected.variants.clear(), throwsUnsupportedError);
        expect(
          () => result.configuration!.detailFields.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => result.configuration!.detailActions!.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => selected.neutralConfiguration.detailFields.clear(),
          throwsUnsupportedError,
        );
      },
    );

    for (final key in ['', ' \t ', 'a' * 129]) {
      test(
        'invalid declared variant key is a local argument error (${key.length} characters)',
        () {
          // Given a trusted declaration with a blank or overlong Dart string key.
          final variants = {key: configuration('Reference')};
          // When the local registry is constructed.
          void construct() => CncfDisplayPresentationRegistry(
            profile: profile(),
            neutralConfiguration: configuration('Neutral'),
            variants: variants,
          );
          // Then invalid declarations fail as arguments before any transport exists.
          expect(construct, throwsArgumentError);
        },
      );
    }

    test('an invalid trusted configuration is a local argument error', () {
      // Given an empty field declaration rejected by the existing configuration codec.
      const invalid = ResourceListDetailConfiguration(
        listTitle: 'Invalid',
        detailTitle: 'Invalid',
        primaryField: 'title',
        detailFields: [],
      );
      // When the registry freezes that declaration through the existing codec.
      void construct() => CncfDisplayPresentationRegistry(
        profile: profile(),
        neutralConfiguration: invalid,
        variants: const {},
      );
      // Then the declaration fails locally with the promised argument contract.
      expect(construct, throwsArgumentError);
    });
  });

  group('latest completely projected Display', () {
    test('a complete formal read whose flat projection is ambiguous preserves the last Display', () async {
      // Given a real Core client and a controlled cross-section duplicate field.
      var ambiguous = false;
      final initial = mutationFixture('detail-initial');
      final id =
          ((initial['model']! as Map)['resource']! as Map)['entityId']!
              as String;
      final transport = MockClient((request) async {
        final detail = request.url.path.endsWith('read.json');
        final wire = mutationFixture(
          detail ? 'detail-initial' : 'list-initial',
        );
        if (detail && ambiguous) {
          final sections = (wire['model']! as Map)['sections']! as List;
          sections.add({
            'id': 'other-section',
            'fields': [((sections.first as Map)['fields']! as List).first],
          });
          wire['presentationContext'] = supplied('uninstalled');
        }
        return mutationReply(wire);
      });
      final client = CncfDisplayReadClient(
        profile: profile(),
        endpoint: Uri.parse('https://studio.test/rest/v1/editing-studio/'),
        client: transport,
        bearerToken: () async => 'fixture-token',
      );
      addTearDown(transport.close);
      addTearDown(client.dispose);
      final source = CncfDisplayResourceDataSource(client: client);
      await source.listResources();
      await source.getResource(id);
      final accepted = source.lastDisplay;
      ambiguous = true;
      // When a valid formal Detail cannot be completely projected to flat Resource fields.
      final attempt = source.getResource(id);
      // Then the typed projection failure leaves both accepted observation getters intact.
      await expectLater(
        attempt,
        throwsA(
          isA<CncfDisplayReadException>().having(
            (error) => error.code,
            'projection failure',
            'ambiguousResourceField',
          ),
        ),
      );
      expect(source.lastDisplay, same(accepted));
      expect(source.lastDetail, same(accepted));
      expect(registry().resolve(source.lastDisplay).isAvailable, isTrue);
    });

    test('a superseded older query cannot replace newer Detail and a fresh query can', () async {
      // Given a selected formal Detail and a held older-started query.
      final fixture = CncfDisplayMutationFixture(
        presentationContext: supplied('reference-variant'),
      );
      addTearDown(fixture.dispose);
      await fixture.select();
      final gate = fixture.hold('query');
      final query = fixture.viewModel.load();
      await gate.entered.future;
      fixture.presentationContext = supplied('other');
      // When Detail completes before that query.
      await fixture.viewModel.detailView.refresh();
      final detail = fixture.source.lastDetail;
      // Then Detail is the latest accepted Display even though a query is pending.
      expect(fixture.source.lastDisplay, same(detail));
      expect(
        registry().resolve(fixture.source.lastDisplay).failure,
        CncfDisplayPresentationFailure.unknownVariant,
      );
      // Given the newer Detail has superseded the held older query in Core.
      fixture.presentationContext = supplied('reference-variant');
      // When the retired query settles after the newer Detail.
      gate.release();
      await query;
      // Then its failure cannot replace the accepted Detail or its unavailable variant.
      expect(fixture.source.lastDisplay, same(detail));
      expect(fixture.source.lastDetail, same(detail));
      expect(fixture.viewModel.listFailed, isTrue);
      expect(
        registry().resolve(fixture.source.lastDisplay).failure,
        CncfDisplayPresentationFailure.unknownVariant,
      );
      // Given the next query supplies the registered presentation.
      // When an explicit fresh query is accepted and completely projected.
      await fixture.viewModel.load();
      // Then it becomes the latest Display while the captured Detail remains intact.
      expect(fixture.source.lastDisplay, same(fixture.source.lastQuery));
      expect(fixture.source.lastDetail, same(detail));
      expect(fixture.viewModel.listFailed, isFalse);
      expect(
        registry().resolve(fixture.source.lastDisplay).isAvailable,
        isTrue,
      );
    });

    test('failed reads, descriptors and command ACKs never replace the latest Display', () async {
      // Given a successful selected Display with trusted ordinary Business.
      final binding = referenceBusinessBinding();
      final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
      addTearDown(fixture.dispose);
      await fixture.select();
      final accepted = fixture.source.lastDisplay;
      // When a descriptor and ordinary command ACK succeed without a read.
      await fixture.client.describeMutation();
      final committed = await fixture.controller.executeBusiness(binding);
      // Then command evidence does not manufacture or replace an observation.
      expect(committed, isTrue);
      expect(fixture.controller.businessReceipt!.revision, '2');
      expect(fixture.source.lastDisplay, same(accepted));
      // Given the subsequent safe reads fail at transport admission.
      fixture.failQuery = true;
      fixture.failRead = true;
      // When both Resource projections are attempted.
      await fixture.viewModel.load();
      await fixture.viewModel.detailView.refresh();
      // Then failures preserve the last complete Display and the existing observations.
      expect(fixture.viewModel.listFailed, isTrue);
      expect(fixture.viewModel.detailFailed, isTrue);
      expect(fixture.source.lastDisplay, same(accepted));
      expect(fixture.source.lastDetail, same(accepted));
      expect(fixture.source.lastQuery, isNotNull);
    });
  });
}
