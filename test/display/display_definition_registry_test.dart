import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/display_presentation_fixture.dart';

void main() {
  group('Full supplied identity registry', () {
    final keyCases = <(String, DisplayDefinitionKey, bool)>[
      ('RG01-equal', definitionKey(), true),
      ('RG01-namespace', definitionKey(namespace: 'other'), false),
      ('RG01-set', definitionKey(set: 'other'), false),
      ('RG01-arm', definitionKey(arm: 'B'), false),
      ('RG01-version', definitionKey(version: 2), false),
    ];
    for (final entry in keyCases) {
      test(entry.$1, () {
        // Given the same full domain identity and one independently constructed candidate.
        final original = definitionKey();
        // When ordinary value equality and hash collection lookup are evaluated.
        final equal = original == entry.$2;
        final values = {original, entry.$2};
        // Then all four domain coordinates distinguish keys and equal keys share a hash.
        expect(equal, entry.$3);
        expect(values.length, entry.$3 ? 1 : 2);
        if (entry.$3) {
          expect(original.hashCode, entry.$2.hashCode);
        }
      });
    }
    for (final entry in [
      ('RG02-A', 'A', DisplayDefinitionStyle.standard),
      ('RG02-B', 'B', DisplayDefinitionStyle.cards),
      ('RG02-C', 'C', DisplayDefinitionStyle.sections),
    ]) {
      test(entry.$1, () {
        // Given an explicit full-key registration for each supplied style.
        final definitions = registry();
        final context = presentationContext(arm: entry.$2);
        // When the pure registry resolves the exact supplied tuple.
        final result = resolve(definitions, context);
        // Then style and key match without assignment allocation or context changes.
        expect(result.isAvailable, isTrue);
        expect(result.definition!.style, entry.$3);
        expect(result.key, definitionKey(arm: entry.$2));
        expect(result.failure, isNull);
        expect(
          context.families.where(
            (family) => family.payload is SuppliedArmPresentationPayload,
          ),
          hasLength(1),
        );
      });
    }
    for (final entry in [
      ('RG03-namespace', 'other', 'reading'),
      ('RG03-set', 'example', 'other'),
    ]) {
      test(entry.$1, () {
        // Given the same arm label independently registered in two different tuple scopes.
        final special = definition(
          id: entry.$1,
          style: DisplayDefinitionStyle.cards,
        );
        final definitions = DisplayDefinitionRegistry(
          registrations: [
            DisplayDefinitionRegistration(
              key: definitionKey(),
              definition: definition(),
            ),
            DisplayDefinitionRegistration(
              key: definitionKey(namespace: entry.$2, set: entry.$3),
              definition: special,
            ),
          ],
        );
        // When the second scope is explicitly supplied.
        final result = resolve(
          definitions,
          presentationContext(namespace: entry.$2, set: entry.$3),
        );
        // Then it resolves its own definition and leaves the first registration independent.
        expect(result.definition, same(special));
        expect(definitions.registrations, hasLength(2));
      });
    }
    test('RG04-duplicate', () {
      // Given two registrations for the identical full domain key.
      final entry = DisplayDefinitionRegistration(
        key: definitionKey(),
        definition: definition(),
      );
      // When duplicate full keys are supplied to construction.
      expect(
        () => DisplayDefinitionRegistry(registrations: [entry, entry]),
        throwsArgumentError,
      );
      // Then the original immutable values are unaffected by the rejected constructor.
      expect(entry.definition.id, 'standard');
      expect(entry.key, definitionKey());
    });
    test('RG04-version', () {
      // Given a key version differing from its definition version.
      final entry = DisplayDefinitionRegistration(
        key: definitionKey(version: 2),
        definition: definition(),
      );
      // When inconsistent registration data is constructed.
      expect(
        () => DisplayDefinitionRegistry(registrations: [entry]),
        throwsArgumentError,
      );
      // Then neither supplied value has been rewritten to fit the other.
      expect(entry.key.definitionVersion, 2);
      expect(entry.definition.version, 1);
    });
    for (final neutral in [true, false]) {
      test(neutral ? 'RG05-explicit-neutral' : 'RG05-missing-neutral', () {
        // Given a context with actual arm absence and explicit neutral policy.
        final definitions = registry(neutral: neutral);
        // When the locale-only context is resolved.
        final result = resolve(definitions, presentationContext(arm: null));
        // Then only explicit neutral data can be used and no key is invented.
        expect(result.key, isNull);
        expect(result.isAvailable, neutral);
        expect(
          result.definition,
          neutral ? same(definitions.neutralDefinition) : isNull,
        );
        expect(
          result.failure?.kind,
          neutral ? isNull : DisplayDefinitionFailureKind.missingNeutral,
        );
      });
    }
    final failures =
        <
          (
            String,
            DisplayDefinitionRegistry,
            PresentationContext,
            DisplayDefinitionFailureKind,
          )
        >[
          (
            'RG06-unknown',
            registry(),
            presentationContext(arm: 'unknown'),
            DisplayDefinitionFailureKind.unknownArm,
          ),
          (
            'RG07-version',
            registry(),
            presentationContext(version: 2),
            DisplayDefinitionFailureKind.unsupportedVersion,
          ),
          (
            'RG08-unavailable',
            registry(a: definition(available: false)),
            presentationContext(),
            DisplayDefinitionFailureKind.unavailableDefinition,
          ),
          (
            'RG09-resource',
            registry(a: definition(type: 'other')),
            presentationContext(),
            DisplayDefinitionFailureKind.incompatibleDefinition,
          ),
          (
            'RG09-list',
            registry(a: definition(list: 'other')),
            presentationContext(),
            DisplayDefinitionFailureKind.incompatibleDefinition,
          ),
          (
            'RG09-detail',
            registry(a: definition(detail: 'other')),
            presentationContext(),
            DisplayDefinitionFailureKind.incompatibleDefinition,
          ),
        ];
    for (final entry in failures) {
      test(entry.$1, () {
        // Given otherwise valid context and an explicit registry including neutral data.
        final context = entry.$3;
        // When a supplied tuple or definition is operationally incompatible.
        final result = resolve(entry.$2, context);
        // Then a visible failure replaces no supplied arm with neutral and mutates no context.
        expect(result.failure!.kind, entry.$4);
        expect(result.definition, isNull);
        expect(result.isAvailable, isFalse);
        expect(result.key, isNotNull);
        expect(context, entry.$3);
      });
    }
    test('RG10-unsupported-family', () {
      // Given a present future arm family with an opaque payload, rather than absence.
      final original = presentationContext();
      final context = PresentationContext(
        flowId: original.flowId,
        sourceId: original.sourceId,
        componentId: original.componentId,
        families: [
          PresentationContextFamily(
            namespace: 'textus.presentation.arm',
            version: 2,
            producerId: 'producer',
            isRequired: true,
            expiresAt: null,
            payload: OpaquePresentationPayload({'future': 'arm'}),
          ),
        ],
      );
      // When the registry encounters the unsupported family version and opaque shape.
      final result = resolve(registry(), context);
      // Then it reports unsupportedArmFamily with no neutral substitution.
      expect(
        result.failure!.kind,
        DisplayDefinitionFailureKind.unsupportedArmFamily,
      );
      expect(result.definition, isNull);
      expect(context.families.single.version, 2);
      expect(result.key, isNull);
    });
    test('RG11-immutable-copy', () {
      // Given caller-owned mutable registration input.
      final supplied = [
        DisplayDefinitionRegistration(
          key: definitionKey(),
          definition: definition(),
        ),
      ];
      final definitions = DisplayDefinitionRegistry(registrations: supplied);
      // When the caller clears its input and attempts to mutate published registration data.
      supplied.clear();
      expect(() => definitions.registrations.clear(), throwsUnsupportedError);
      // Then lookup still resolves the copied original registration.
      expect(resolve(definitions, presentationContext()).isAvailable, isTrue);
      expect(definitions.registrations, hasLength(1));
    });
    test('RG12-constructor-guards', () {
      // Given a valid immutable registry and a complete invalid-identifier/version table.
      final definitions = registry();
      final before = definitions.registrations;
      final attempts = <void Function()>[
        () => definitionKey(namespace: ' '),
        () => definitionKey(set: '\u3000'),
        () => definitionKey(arm: '\u0085'),
        () => definitionKey(version: 0),
        () => definitionKey(version: -1),
        () => definition(id: ''),
        () => definition(version: 0),
        () => definition(version: -1),
        () => definition(type: ' '),
        () => definition(list: ' '),
        () => definition(detail: ' '),
      ];
      for (final attempt in attempts) {
        // Given one invalid constructor attempt with an unaffected valid registry.
        // When that exact constructor is invoked.
        expect(attempt, throwsArgumentError);
        // Then the valid registry and its copied registration data remain unchanged.
        expect(definitions.registrations, same(before));
        expect(resolve(definitions, presentationContext()).isAvailable, isTrue);
      }
      // Given byte-preserving valid identifiers and a structurally equal definition.
      // When equal values and each definition field difference are compared.
      final value = definition(id: ' standard ');
      // Then equality uses all definition fields while valid text is preserved.
      expect(value.id, ' standard ');
      expect(value, definition(id: ' standard '));
      expect(value.hashCode, definition(id: ' standard ').hashCode);
      for (final other in [
        definition(id: 'other'),
        definition(id: ' standard ', version: 2),
        definition(id: ' standard ', type: 'other'),
        definition(id: ' standard ', list: 'other'),
        definition(id: ' standard ', detail: 'other'),
        definition(id: ' standard ', style: DisplayDefinitionStyle.cards),
        definition(id: ' standard ', available: false),
      ]) {
        expect(value, isNot(other));
      }
    });
  });
}

DisplayDefinitionResolution resolve(
  DisplayDefinitionRegistry registry,
  PresentationContext context,
) => registry.resolve(
  context: context,
  resourceType: 'documents',
  listScreenId: 'list',
  detailScreenId: 'detail',
);
