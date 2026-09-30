import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

SettingDefinition<bool> _flag({
  String id = 'example.flag',
  String groupId = 'application',
  String label = 'Example flag',
  bool defaultValue = false,
  List<SettingChoice<bool>>? choices,
  String? requiredCapability,
  SettingAvailabilityPolicy policy = SettingAvailabilityPolicy.always,
}) => SettingDefinition<bool>(
  id: id,
  groupId: groupId,
  label: label,
  defaultValue: defaultValue,
  requiredCapability: requiredCapability,
  availabilityPolicy: policy,
  choices:
      choices ??
      [
        SettingChoice(value: false, label: 'Off', storedValue: false),
        SettingChoice(value: true, label: 'On', storedValue: true),
      ],
);

void main() {
  group('Common settings catalog and typed choices', () {
    test('defaults and ordered identities are stable', () {
      // Given a common registry without application extensions.
      final registry = CommonSettings.registry();

      // When its initial effective snapshot is constructed.
      final snapshot = SettingsSnapshot(registry: registry);

      // Then every common ID, group, catalog and default is stable.
      expect(registry.groups.map((group) => group.id), [
        'appearance',
        'layout',
        'accessibility',
        'application',
      ]);
      expect(registry.groups.map((group) => group.label), [
        'Appearance',
        'Layout',
        'Accessibility',
        'Application',
      ]);
      expect(registry.definitions.map((definition) => definition.id), [
        'textus.layout.panePreference',
        'textus.layout.hingePreference',
        'textus.appearance.textSizeMultiplier',
      ]);
      expect(
        snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(
        snapshot.value(CommonSettings.hingePreference),
        SettingsHingePreference.automatic,
      );
      expect(snapshot.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(
        CommonSettings.panePreference.choices.map((choice) => choice.value),
        SettingsPanePreference.values,
      );
      expect(
        CommonSettings.hingePreference.choices.map((choice) => choice.value),
        SettingsHingePreference.values,
      );
      expect(
        CommonSettings.textSizeMultiplier.choices.map((choice) => choice.value),
        [1.0, 1.15, 1.30],
      );
      expect(snapshot.explicitValueIds, isEmpty);
      expect(snapshot.hasUnsavedChanges, isFalse);
      expect(snapshot.revision, 0);
      expect(snapshot.savedRevision, 0);
      expect(snapshot.readState, SettingsReadState.notLoaded);
      expect(snapshot.saveState, SettingsSaveState.idle);
      expect(snapshot.readError, isNull);
      expect(snapshot.saveError, isNull);
      expect(snapshot.lastIntent, isNull);
    });

    test('every catalog choice round-trips through its scalar wire identity', () {
      // Given the common finite-choice catalog.
      final definitions = CommonSettings.definitions;

      // When every typed choice is validated, encoded and decoded.
      final restored = [
        for (final definition in definitions)
          for (final choice in definition.choices)
            definition.decode(definition.encode(choice.value)),
      ];

      // Then the declared typed choices and exact wire identities are retained.
      expect(restored, [
        for (final definition in definitions)
          for (final choice in definition.choices) choice.value,
      ]);
      expect(
        CommonSettings.panePreference.choices.map(
          (choice) => choice.storedValue,
        ),
        ['automatic', 'preferSinglePane', 'preferDualPane'],
      );
      expect(
        CommonSettings.hingePreference.choices.map(
          (choice) => choice.storedValue,
        ),
        ['automatic', 'avoid', 'span'],
      );
      expect(
        CommonSettings.textSizeMultiplier.choices.map(
          (choice) => choice.storedValue,
        ),
        [1.0, 1.15, 1.30],
      );
      for (final definition in definitions) {
        for (final choice in definition.choices) {
          expect(choice.label, isNot(choice.storedValue.toString()));
        }
      }
    });

    test(
      'invalid and missing payloads fall back per setting to typed defaults',
      () {
        // Given invalid/missing wire payloads and JSON numeric 1.
        final multiplier = CommonSettings.textSizeMultiplier;
        final invalid = <Object?>[null, 1.2, '1.15', true, [], {}, double.nan];

        // When each payload is decoded independently of valid siblings.
        final fallback = invalid.map(multiplier.decode).toList();
        final numericDefault = multiplier.decode(1);
        final pane = CommonSettings.panePreference.decode('preferDualPane');
        final hinge = CommonSettings.hingePreference.decode('unknown');

        // Then numeric 1 becomes a declared double and invalid values use defaults.
        expect(fallback, everyElement(1.0));
        expect(numericDefault, isA<double>());
        expect(numericDefault, 1.0);
        expect(pane, SettingsPanePreference.preferDualPane);
        expect(hinge, SettingsHingePreference.automatic);
      },
    );

    test(
      'edits check type and catalog rather than accepting raw wire values',
      () {
        // Given typed common definitions and a synthetic finite string setting.
        final mode = SettingDefinition<String>(
          id: 'example.mode',
          groupId: 'application',
          label: 'Mode',
          defaultValue: 'brief',
          choices: [
            SettingChoice(value: 'brief', label: 'Brief', storedValue: 'b'),
            SettingChoice(value: 'full', label: 'Full', storedValue: 'f'),
          ],
        );

        // When valid edits and invalid type/catalog/wire edits are attempted.
        final valid = mode.validate('full');
        final wire = mode.encode('full');
        final invalidEdits = <void Function()>[
          () => mode.validate('freeform'),
          () => mode.encode('f'),
          () => mode.encode(true),
          () => CommonSettings.textSizeMultiplier.validate(1),
          () => CommonSettings.textSizeMultiplier.encode(1.2),
          () => CommonSettings.panePreference.encode('automatic'),
          () => CommonSettings.panePreference.validate(
            SettingsHingePreference.automatic,
          ),
        ];

        // Then typed edits succeed and invalid edits all throw ArgumentError.
        expect(valid, 'full');
        expect(wire, 'f');
        expect(mode.decode('f'), 'full');
        for (final edit in invalidEdits) {
          expect(edit, throwsArgumentError);
        }
      },
    );
  });

  group('Definition and registry validation', () {
    test(
      'blank identities, labels, group references and capabilities reject',
      () {
        // Given constructors with a blank mandatory field or capability ID.
        final invalid = <void Function()>[
          () => SettingGroup(id: ' ', label: 'Group'),
          () => SettingGroup(id: 'group', label: '\t'),
          () => SettingChoice(value: true, label: '', storedValue: true),
          () => _flag(id: ''),
          () => _flag(groupId: ' '),
          () => _flag(label: '\n'),
          () => _flag(requiredCapability: ' '),
          () => SettingsCapabilities(supported: {' '}),
        ];

        // When each malformed schema input is constructed.
        // Then all blank inputs are rejected before registration.
        for (final construct in invalid) {
          expect(construct, throwsArgumentError);
        }
      },
    );

    test('empty catalogs, duplicate typed/wire choices and invalid defaults reject', () {
      // Given catalogs that violate finite-choice uniqueness or default membership.
      final off = SettingChoice(value: false, label: 'Off', storedValue: 'off');
      final duplicateValue = SettingChoice(
        value: false,
        label: 'Also off',
        storedValue: 'other',
      );
      final duplicateWire = SettingChoice(
        value: true,
        label: 'On',
        storedValue: 'off',
      );
      final invalid = <void Function()>[
        () => _flag(choices: []),
        () => _flag(choices: [off, duplicateValue]),
        () => _flag(choices: [off, duplicateWire]),
        () => _flag(defaultValue: true, choices: [off]),
        () => SettingDefinition<double>(
          id: 'numeric',
          groupId: 'application',
          label: 'Numeric',
          defaultValue: 1.0,
          choices: [
            SettingChoice(value: 1.0, label: 'One', storedValue: 1),
            SettingChoice(value: 2.0, label: 'Two', storedValue: 1.0),
          ],
        ),
      ];

      // When each invalid catalog is constructed.
      // Then duplicate numeric wire equality is also rejected.
      for (final construct in invalid) {
        expect(construct, throwsArgumentError);
      }
    });

    test('wire choices accept JSON scalars and reject objects/nonfinite doubles', () {
      // Given all supported scalars and values that JSON cannot store as scalars.
      final valid = <Object>['one', true, 1, 1.5];
      final invalid = <Object>[
        SettingsPanePreference.automatic,
        [],
        {},
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ];

      // When supported choices are constructed and unsupported ones attempted.
      final choices = [
        for (final scalar in valid)
          SettingChoice(value: true, label: 'Choice', storedValue: scalar),
      ];

      // Then every supported scalar is retained and unsupported values reject.
      expect(choices.map((choice) => choice.storedValue), valid);
      for (final scalar in invalid) {
        expect(
          () =>
              SettingChoice(value: true, label: 'Choice', storedValue: scalar),
          throwsArgumentError,
        );
      }
    });

    test(
      'duplicate group/setting IDs and unresolved group references reject',
      () {
        // Given distinct schema objects sharing IDs or referring to absent groups.
        final group = SettingGroup(id: 'application', label: 'Application');
        final flag = _flag();
        final invalid = <void Function()>[
          () => SettingsRegistry(
            groups: [
              group,
              SettingGroup(id: 'application', label: 'Other'),
            ],
            definitions: [flag],
          ),
          () => SettingsRegistry(groups: [group], definitions: [flag, _flag()]),
          () => SettingsRegistry(
            groups: [group],
            definitions: [_flag(groupId: 'missing')],
          ),
        ];

        // When each malformed registry is constructed.
        // Then ambiguous IDs and unresolved references throw ArgumentError.
        for (final construct in invalid) {
          expect(construct, throwsArgumentError);
        }
      },
    );

    test('lookup uses ID and rejects unknown or forged typed definitions', () {
      // Given one registered flag, an unregistered flag and a same-ID type forgery.
      final flag = _flag();
      final registry = CommonSettings.registry(extensions: [flag]);
      final forged = SettingDefinition<String>(
        id: flag.id,
        groupId: 'application',
        label: 'Forged flag',
        defaultValue: 'no',
        choices: [SettingChoice(value: 'no', label: 'No', storedValue: 'no')],
      );
      final snapshot = SettingsSnapshot(registry: registry);

      // When actual registered definitions are looked up and read.
      final definition = registry.definition(flag.id);
      final value = snapshot.value(flag);

      // Then identity/type authority is retained and every forgery is rejected.
      expect(definition, same(flag));
      expect(value, isFalse);
      expect(() => registry.definition('missing'), throwsArgumentError);
      expect(
        () => snapshot.value(_flag(id: 'unregistered')),
        throwsArgumentError,
      );
      expect(() => snapshot.value(_flag()), throwsArgumentError);
      expect(() => snapshot.value(forged), throwsArgumentError);
    });
  });

  group('Application extensions and ephemeral availability', () {
    test('synthetic extensions compose in order without changing the common registry', () {
      // Given explicit extension groups and finite bool/string definitions.
      final flag = _flag();
      final group = SettingGroup(id: 'example', label: 'Example');
      final mode = SettingDefinition<String>(
        id: 'example.mode',
        groupId: group.id,
        label: 'Mode',
        defaultValue: 'brief',
        choices: [
          SettingChoice(value: 'brief', label: 'Brief', storedValue: 'b'),
          SettingChoice(value: 'full', label: 'Full', storedValue: 'f'),
        ],
      );

      // When two independent common and extended registries are composed.
      final common = CommonSettings.registry();
      final extended = CommonSettings.registry(
        extensionGroups: [group],
        extensions: [flag, mode],
      );
      final snapshot = SettingsSnapshot(registry: extended);

      // Then extensions are readable in order while common identities stay intact.
      expect(extended.groups.last, same(group));
      expect(extended.definitions.skip(3), [flag, mode]);
      expect(
        extended.definition(CommonSettings.panePreference.id),
        same(CommonSettings.panePreference),
      );
      expect(snapshot.value(flag), isFalse);
      expect(snapshot.value(mode), 'brief');
      expect(common.definitions, hasLength(3));
      expect(() => common.definition(flag.id), throwsArgumentError);
      expect(CommonSettings.registry().definitions, hasLength(3));
    });

    test('extensions cannot collide with common groups or settings', () {
      // Given extension inputs reusing reserved common identities.
      final invalid = <void Function()>[
        for (final group in CommonSettings.groups)
          () => CommonSettings.registry(
            extensionGroups: [SettingGroup(id: group.id, label: 'Collision')],
          ),
        for (final definition in CommonSettings.definitions)
          () => CommonSettings.registry(extensions: [_flag(id: definition.id)]),
      ];

      // When composition attempts to redefine common schema authority.
      // Then every reserved identity collision is rejected.
      for (final construct in invalid) {
        expect(construct, throwsArgumentError);
      }
    });

    test(
      'availability changes never mutate retained setting values or intent',
      () {
        // Given explicit hinge preference and hidden-policy/always-policy extensions.
        final hidden = _flag(
          requiredCapability: 'example',
          policy: SettingAvailabilityPolicy.hideWhenUnsupported,
        );
        final always = _flag(
          id: 'example.always',
          requiredCapability: 'missing',
        );
        final registry = CommonSettings.registry(extensions: [hidden, always]);
        final snapshot = SettingsSnapshot(
          registry: registry,
          values: {
            CommonSettings.hingePreference.id: SettingsHingePreference.span,
          },
          explicitValueIds: {CommonSettings.hingePreference.id},
        );
        final absent = SettingsCapabilities();
        final present = SettingsCapabilities(supported: {'hinge', 'example'});

        // When capability inputs vary independently of the effective snapshot.
        final before = CommonSettings.hingePreference.availability(absent);
        final after = CommonSettings.hingePreference.availability(present);

        // Then unsupported controls disable/hide and supported controls are available.
        expect(before, SettingAvailability.disabled);
        expect(after, SettingAvailability.available);
        expect(hidden.availability(absent), SettingAvailability.hidden);
        expect(hidden.availability(present), SettingAvailability.available);
        expect(always.availability(absent), SettingAvailability.available);
        expect(
          CommonSettings.panePreference.availability(absent),
          SettingAvailability.available,
        );
        expect(
          CommonSettings.textSizeMultiplier.availability(absent),
          SettingAvailability.available,
        );
        expect(
          snapshot.value(CommonSettings.hingePreference),
          SettingsHingePreference.span,
        );
        expect(
          snapshot.hasExplicitValue(CommonSettings.hingePreference.id),
          isTrue,
        );
        expect(snapshot.revision, 0);
        expect(snapshot.lastIntent, isNull);
        expect(snapshot.hasUnsavedChanges, isFalse);
      },
    );
  });

  group('Immutable catalog and snapshots', () {
    test(
      'schema and capability collections copy inputs and forbid mutation',
      () {
        // Given mutable choice/group/definition/capability input collections.
        final choices = [
          SettingChoice(value: false, label: 'Off', storedValue: false),
        ];
        final flag = _flag(choices: choices);
        final groups = [SettingGroup(id: 'application', label: 'Application')];
        final definitions = <SettingDefinition<Object>>[flag];
        final registry = SettingsRegistry(
          groups: groups,
          definitions: definitions,
        );
        final supported = {'hinge'};
        final capabilities = SettingsCapabilities(supported: supported);

        // When caller-owned collections are cleared after composition.
        choices.clear();
        groups.clear();
        definitions.clear();
        supported.clear();

        // Then independent immutable copies retain their schema and capability.
        expect(flag.choices, hasLength(1));
        expect(registry.groups, hasLength(1));
        expect(registry.definitions, [flag]);
        expect(capabilities.supports('hinge'), isTrue);
        expect(() => flag.choices.clear(), throwsUnsupportedError);
        expect(() => registry.groups.clear(), throwsUnsupportedError);
        expect(() => registry.definitions.clear(), throwsUnsupportedError);
        expect(() => capabilities.supported.clear(), throwsUnsupportedError);
        expect(() => CommonSettings.groups.clear(), throwsUnsupportedError);
        expect(
          () => CommonSettings.definitions.clear(),
          throwsUnsupportedError,
        );
      },
    );

    test('effective values fill defaults and distinguish presence from acknowledgement', () {
      // Given absent defaults and an explicit automatic edit awaiting persistence.
      final registry = CommonSettings.registry();
      final id = CommonSettings.panePreference.id;
      final absent = SettingsSnapshot(registry: registry);
      final values = <String, Object>{id: SettingsPanePreference.automatic};
      final explicit = {id};
      final unsaved = {id};
      final error = StateError('write failed');

      // When an unsaved explicit snapshot is built and caller inputs mutate.
      final snapshot = SettingsSnapshot(
        registry: registry,
        values: values,
        explicitValueIds: explicit,
        unsavedIds: unsaved,
        revision: 1,
        saveState: SettingsSaveState.failed,
        saveError: error,
        lastIntent: SettingsIntent(
          revision: 1,
          kind: SettingsIntentKind.edit,
          settingId: id,
        ),
      );
      values.clear();
      explicit.clear();
      unsaved.clear();

      // Then equal effective defaults carry different presence/durability semantics.
      expect(
        snapshot.value(CommonSettings.panePreference),
        absent.value(CommonSettings.panePreference),
      );
      expect(absent.hasExplicitValue(id), isFalse);
      expect(snapshot.hasExplicitValue(id), isTrue);
      expect(snapshot.values, hasLength(3));
      expect(snapshot.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(snapshot.hasUnsavedChanges, isTrue);
      expect(snapshot.unsavedIds, {id});
      expect(snapshot.savedRevision, 0);
      expect(snapshot.saveError, same(error));
      expect(snapshot.lastIntent!.settingId, id);
      expect(() => snapshot.values.clear(), throwsUnsupportedError);
      expect(() => snapshot.explicitValueIds.clear(), throwsUnsupportedError);
      expect(() => snapshot.unsavedIds.clear(), throwsUnsupportedError);
    });

    test('snapshot rejects unknown IDs and invalid typed effective values', () {
      // Given valid schema and malformed effective/presence/unsaved inputs.
      final registry = CommonSettings.registry();
      final id = CommonSettings.textSizeMultiplier.id;
      final invalid = <void Function()>[
        () => SettingsSnapshot(registry: registry, values: {'missing': true}),
        () => SettingsSnapshot(registry: registry, values: {id: 1.2}),
        () => SettingsSnapshot(registry: registry, values: {id: '1.0'}),
        () => SettingsSnapshot(registry: registry, values: {id: 1}),
        () =>
            SettingsSnapshot(registry: registry, explicitValueIds: {'missing'}),
        () => SettingsSnapshot(registry: registry, unsavedIds: {'missing'}),
        () => SettingsSnapshot(registry: registry).hasExplicitValue('missing'),
      ];

      // When each invalid effective input is supplied instead of wire decoding.
      // Then snapshots reject invalid effective state rather than silently fallback.
      for (final construct in invalid) {
        expect(construct, throwsArgumentError);
      }
    });

    test('snapshot rejects invalid revisions and intent/registry relationships', () {
      // Given invalid revision bounds and well-formed but incompatible intents.
      final registry = CommonSettings.registry();
      final invalid = <void Function()>[
        () => SettingsSnapshot(registry: registry, revision: -1),
        () => SettingsSnapshot(registry: registry, savedRevision: -1),
        () =>
            SettingsSnapshot(registry: registry, revision: 1, savedRevision: 2),
        () => SettingsSnapshot(
          registry: registry,
          revision: 1,
          lastIntent: SettingsIntent(
            revision: 2,
            kind: SettingsIntentKind.resetCommon,
            settingId: null,
          ),
        ),
        () => SettingsSnapshot(
          registry: registry,
          revision: 1,
          lastIntent: SettingsIntent(
            revision: 1,
            kind: SettingsIntentKind.edit,
            settingId: 'missing',
          ),
        ),
      ];

      // When impossible sequence or schema relationships are constructed.
      // Then all invalid snapshots reject before being observed.
      for (final construct in invalid) {
        expect(construct, throwsArgumentError);
      }
    });

    test(
      'intent requires positive sequence and the correct setting-ID shape',
      () {
        // Given an edit identity and invalid revision/kind/ID combinations.
        final id = CommonSettings.panePreference.id;
        final invalid = <void Function()>[
          () => SettingsIntent(
            revision: 0,
            kind: SettingsIntentKind.edit,
            settingId: id,
          ),
          () => SettingsIntent(
            revision: -1,
            kind: SettingsIntentKind.resetCommon,
            settingId: null,
          ),
          () => SettingsIntent(
            revision: 1,
            kind: SettingsIntentKind.edit,
            settingId: null,
          ),
          () => SettingsIntent(
            revision: 1,
            kind: SettingsIntentKind.edit,
            settingId: ' ',
          ),
          () => SettingsIntent(
            revision: 1,
            kind: SettingsIntentKind.resetCommon,
            settingId: id,
          ),
        ];

        // When valid reset and edit intents and invalid shapes are constructed.
        final edit = SettingsIntent(
          revision: 1,
          kind: SettingsIntentKind.edit,
          settingId: id,
        );
        final reset = SettingsIntent(
          revision: 2,
          kind: SettingsIntentKind.resetCommon,
          settingId: null,
        );

        // Then intent kind/identity remain explicit and invalid shapes reject.
        expect(edit.revision, 1);
        expect(edit.settingId, id);
        expect(reset.kind, SettingsIntentKind.resetCommon);
        expect(reset.settingId, isNull);
        for (final construct in invalid) {
          expect(construct, throwsArgumentError);
        }
      },
    );
  });
}
