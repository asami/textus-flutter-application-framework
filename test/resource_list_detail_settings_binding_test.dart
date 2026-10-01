import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

void main() {
  group('Borrowed adaptive settings binding', () {
    test('B01 captures a baseline and copies validated borrowed models', () {
      // Given explicit pre-attachment intent and two independent tab choices.
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferSinglePane,
      );
      for (final model in fixture.models) {
        model.focusDetail();
        model.setHingePolicy(ResourceListDetailHingePolicy.span);
      }
      final supplied = [...fixture.models];

      // When a binding captures that intent and the caller mutates its input list.
      fixture.bind(models: supplied);
      supplied.clear();
      final baseline = fixture.view.snapshot.revision;
      final choices = fixture.models
          .map((model) => model.preferenceOverride)
          .toList();
      fixture.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferSinglePane,
      );

      // Then old intent is not replayed and subsequent intent reaches the copied set.
      expect(
        choices,
        everyElement(ResourceListDetailDisplayPreference.detailFocused),
      );
      expect(
        fixture.models.map((model) => model.preferenceOverride),
        everyElement(isNull),
      );
      expect(
        fixture.models.map((model) => model.hingePolicyOverride),
        everyElement(ResourceListDetailHingePolicy.span),
      );
      expect(fixture.view.snapshot.revision, baseline + 1);
      expect(fixture.storage.readCount, 0);
      expect(fixture.storage.writeCount, 0);
    });

    test('B01 rejects empty duplicate and unregistered inputs before attachment', () {
      // Given an actual Settings View and a service with an incomplete catalog.
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final incomplete = _IncompleteCatalog();
      final incompleteView = SettingsView.fromService(service: incomplete);
      addTearDown(incomplete.dispose);
      addTearDown(incompleteView.dispose);

      // When invalid bindings are constructed.
      final attempts = <void Function()>[
        () => ResourceListDetailSettingsBinding(
          view: fixture.view,
          displayModels: [],
        ),
        () => ResourceListDetailSettingsBinding(
          view: fixture.view,
          displayModels: [fixture.models.first, fixture.models.first],
        ),
        () => ResourceListDetailSettingsBinding(
          view: incompleteView,
          displayModels: fixture.models,
        ),
      ];

      // Then rejection occurs without applying values or attaching an observer.
      for (final attempt in attempts) {
        expect(attempt, throwsArgumentError);
      }
      fixture.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferSinglePane,
      );
      expect(
        fixture.models.first.resolve(splitCapable: true, hasSelection: false),
        ResourceListDetailPresentation.split,
      );
      expect(fixture.storage.readCount, 0);
      expect(fixture.storage.writeCount, 0);
    });

    test('B02 explicit edits clear only their dimension in every tab', () {
      // Given a binding containing two tabs, including one without a mounted page.
      final extension = SettingDefinition<bool>(
        id: 'example.flag',
        groupId: 'application',
        label: 'Flag',
        defaultValue: false,
        choices: [
          SettingChoice(value: false, label: 'Off', storedValue: false),
          SettingChoice(value: true, label: 'On', storedValue: true),
        ],
      );
      final fixture = _Fixture(
        registry: CommonSettings.registry(extensions: [extension]),
      );
      addTearDown(fixture.dispose);
      fixture.bind();
      void choose() {
        for (final model in fixture.models) {
          model.focusDetail();
          model.setHingePolicy(ResourceListDetailHingePolicy.span);
        }
      }

      choose();

      // When pane, hinge, unrelated edits and reset are explicitly requested.
      fixture.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.automatic,
      );
      final paneClears = fixture.models
          .map((model) => model.preferenceOverride)
          .toList();
      final paneHinges = fixture.models
          .map((model) => model.hingePolicyOverride)
          .toList();
      choose();
      fixture.view.setValue(
        CommonSettings.hingePreference.id,
        SettingsHingePreference.automatic,
      );
      final hingePanes = fixture.models
          .map((model) => model.preferenceOverride)
          .toList();
      final hingeClears = fixture.models
          .map((model) => model.hingePolicyOverride)
          .toList();
      choose();
      fixture.view.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
      fixture.view.setValue(extension.id, true);
      final unrelatedPanes = fixture.models
          .map((model) => model.preferenceOverride)
          .toList();
      final unrelatedHinges = fixture.models
          .map((model) => model.hingePolicyOverride)
          .toList();
      fixture.view.resetCommon();

      // Then every tab receives independent clears while compact navigation survives.
      expect(paneClears, everyElement(isNull));
      expect(paneHinges, everyElement(ResourceListDetailHingePolicy.span));
      expect(
        hingePanes,
        everyElement(ResourceListDetailDisplayPreference.detailFocused),
      );
      expect(hingeClears, everyElement(isNull));
      expect(
        unrelatedPanes,
        everyElement(ResourceListDetailDisplayPreference.detailFocused),
      );
      expect(unrelatedHinges, everyElement(ResourceListDetailHingePolicy.span));
      expect(
        fixture.models.map((model) => model.preferenceOverride),
        everyElement(isNull),
      );
      expect(
        fixture.models.map((model) => model.hingePolicyOverride),
        everyElement(isNull),
      );
      expect(
        fixture.models.map((model) => model.compactDetailRequested),
        everyElement(isTrue),
      );
      expect(fixture.view.value(extension), isTrue);
    });

    test(
      'B03 restoration and save failure retry never replay intent',
      () async {
        // Given a controllable read and a binding retaining pre-attachment choices.
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.bind();
        final model = fixture.models.first;
        model.focusDetail();
        model.setHingePolicy(ResourceListDetailHingePolicy.span);

        // When restoration, an explicit edit, failure and retry publish snapshots.
        final load = fixture.view.load();
        fixture.storage.reads.single.succeed(
          SettingsRecord.empty().withUpdates({
            CommonSettings.panePreference.id: 'preferSinglePane',
            CommonSettings.hingePreference.id: 'automatic',
          }).encode(),
        );
        await load;
        final restoredOverride = model.hingePolicyOverride;
        fixture.view.setValue(
          CommonSettings.hingePreference.id,
          SettingsHingePreference.avoid,
        );
        model.setHingePolicy(ResourceListDetailHingePolicy.span);
        var notifications = 0;
        model.addListener(() => notifications++);
        await Future<void>.delayed(Duration.zero);
        fixture.storage.writes.single.fail(StateError('not acknowledged'));
        await Future<void>.delayed(Duration.zero);
        final failed = fixture.view.snapshot.saveState;
        final retry = fixture.view.retrySave();
        await Future<void>.delayed(Duration.zero);
        fixture.storage.writes.last.succeed();
        await retry;

        // Then status-only events preserve new choices and do not notify models again.
        expect(restoredOverride, ResourceListDetailHingePolicy.span);
        expect(failed, SettingsSaveState.failed);
        expect(model.hingePolicyOverride, ResourceListDetailHingePolicy.span);
        expect(
          model.preferenceOverride,
          ResourceListDetailDisplayPreference.detailFocused,
        );
        expect(model.compactDetailRequested, isTrue);
        expect(notifications, 0);
        expect(fixture.view.snapshot.saveState, SettingsSaveState.idle);
        expect(fixture.view.snapshot.revision, 1);
      },
    );

    for (final wire in [null, 'invalid', 'automatic']) {
      test('B03 restored $wire distinguishes inherited from explicit automatic', () async {
        // Given configured span and a controllable saved hinge value.
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.bind();

        // When actual controller restoration decodes the stored record.
        final load = fixture.view.load();
        fixture.storage.reads.single.succeed(
          SettingsRecord.empty().withUpdates({
            CommonSettings.hingePreference.id: ?wire,
          }).encode(),
        );
        await load;

        // Then only valid saved automatic suppresses configured span for a gap.
        expect(
          fixture.models.first.resolveHingePolicy(
            hasOcclusion: true,
            defaultPolicy: ResourceListDetailHingePolicy.span,
          ),
          wire == 'automatic'
              ? ResourceListDetailHingePolicy.avoid
              : ResourceListDetailHingePolicy.span,
        );
        expect(
          fixture.view.snapshot.hasExplicitValue(
            CommonSettings.hingePreference.id,
          ),
          wire == 'automatic',
        );
        expect(fixture.storage.writeCount, 0);
      });
    }

    test(
      'B04 capability loss and return retain settings and session overrides',
      () {
        // Given stored-current span and a separate session avoid choice.
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.view.setValue(
          CommonSettings.hingePreference.id,
          SettingsHingePreference.span,
        );
        fixture.bind();
        fixture.models.first.setHingePolicy(
          ResourceListDetailHingePolicy.avoid,
        );
        final snapshot = fixture.view.snapshot;

        // When capability becomes unsupported and later returns.
        fixture.binding!.updateCapabilities(SettingsCapabilities());
        final unavailable = fixture.models.first.resolveHingePolicy(
          hasOcclusion: false,
        );
        fixture.binding!.updateCapabilities(
          SettingsCapabilities(supported: {'hinge'}),
        );

        // Then fallback was automatic and retained choices return without persistence.
        expect(unavailable, ResourceListDetailHingePolicy.span);
        expect(
          fixture.models.first.hingePolicyOverride,
          ResourceListDetailHingePolicy.avoid,
        );
        expect(
          fixture.models.first.resolveHingePolicy(hasOcclusion: false),
          ResourceListDetailHingePolicy.avoid,
        );
        expect(
          fixture.models.last.resolveHingePolicy(hasOcclusion: true),
          ResourceListDetailHingePolicy.span,
        );
        expect(fixture.view.snapshot, same(snapshot));
        expect(fixture.storage.readCount, 0);
        expect(fixture.storage.writeCount, 0);
      },
    );

    test('B05 constructor-time edits join initial fanout FIFO', () {
      // Given existing tab choices and a listener that edits Settings on first apply.
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferSinglePane,
      );
      for (final model in fixture.models) {
        model.focusDetail();
        model.setHingePolicy(ResourceListDetailHingePolicy.span);
      }
      var nested = false;
      final observed =
          <
            (
              ResourceListDetailDisplayPreference?,
              ResourceListDetailHingePolicy?,
              ResourceListDetailHingePolicy,
            )
          >[];
      fixture.models.first.addListener(() {
        if (nested) return;
        nested = true;
        fixture.view.setValue(
          CommonSettings.hingePreference.id,
          SettingsHingePreference.avoid,
        );
      });
      fixture.models.last.addListener(() {
        final model = fixture.models.last;
        observed.add((
          model.preferenceOverride,
          model.hingePolicyOverride,
          model.resolveHingePolicy(hasOcclusion: false),
        ));
      });

      // When initial application triggers a new explicit edit during construction.
      fixture.bind();

      // Then both tabs see the initial snapshot before the new hinge intent once.
      expect(observed, [
        (
          ResourceListDetailDisplayPreference.detailFocused,
          ResourceListDetailHingePolicy.span,
          ResourceListDetailHingePolicy.span,
        ),
        (
          ResourceListDetailDisplayPreference.detailFocused,
          null,
          ResourceListDetailHingePolicy.avoid,
        ),
      ]);
      for (final model in fixture.models) {
        expect(
          model.preferenceOverride,
          ResourceListDetailDisplayPreference.detailFocused,
        );
        expect(model.compactDetailRequested, isTrue);
        expect(model.hingePolicyOverride, isNull);
        expect(
          model.resolveHingePolicy(hasOcclusion: false),
          ResourceListDetailHingePolicy.avoid,
        );
      }
      final snapshot = fixture.view.snapshot;
      expect(snapshot.revision, 2);
      expect(fixture.storage.readCount, 0);
      expect(fixture.storage.writeCount, 0);

      // When capability is lost and returns without another Settings notification.
      fixture.binding!.updateCapabilities(SettingsCapabilities());
      final unavailable = fixture.models
          .map((model) => model.resolveHingePolicy(hasOcclusion: false))
          .toList();
      fixture.binding!.updateCapabilities(
        SettingsCapabilities(supported: {'hinge'}),
      );

      // Then the retained latest snapshot returns without replay or persistence.
      expect(unavailable, everyElement(ResourceListDetailHingePolicy.span));
      for (final model in fixture.models) {
        expect(
          model.resolveHingePolicy(hasOcclusion: false),
          ResourceListDetailHingePolicy.avoid,
        );
        expect(
          model.preferenceOverride,
          ResourceListDetailDisplayPreference.detailFocused,
        );
        expect(model.hingePolicyOverride, isNull);
        expect(model.compactDetailRequested, isTrue);
      }
      expect(fixture.view.snapshot, same(snapshot));
      expect(fixture.storage.readCount, 0);
      expect(fixture.storage.writeCount, 0);
    });

    test(
      'B05 nested edit reset and capabilities retain ordered dimension clears',
      () {
        // Given two overridden tabs and a reentrant first-tab observer.
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.bind();
        for (final model in fixture.models) {
          model.focusDetail();
          model.setHingePolicy(ResourceListDetailHingePolicy.span);
        }
        var nested = false;
        final observed =
            <
              (
                ResourceListDetailDisplayPreference?,
                ResourceListDetailHingePolicy?,
                ResourceListDetailHingePolicy,
              )
            >[];
        fixture.models.first.addListener(() {
          if (nested) return;
          nested = true;
          fixture.view.setValue(
            CommonSettings.hingePreference.id,
            SettingsHingePreference.avoid,
          );
          fixture.binding!.updateCapabilities(SettingsCapabilities());
          fixture.view.resetCommon();
          fixture.binding!.updateCapabilities(
            SettingsCapabilities(supported: {'hinge'}),
          );
        });
        fixture.models.last.addListener(() {
          final model = fixture.models.last;
          observed.add((
            model.preferenceOverride,
            model.hingePolicyOverride,
            model.resolveHingePolicy(hasOcclusion: false),
          ));
        });

        // When a pane edit initiates fanout and nested notifications occur.
        fixture.view.setValue(
          CommonSettings.panePreference.id,
          SettingsPanePreference.preferSinglePane,
        );

        // Then the second tab sees each captured event in FIFO order, exactly once.
        expect(observed, [
          (
            null,
            ResourceListDetailHingePolicy.span,
            ResourceListDetailHingePolicy.span,
          ),
          (null, null, ResourceListDetailHingePolicy.avoid),
          (null, null, ResourceListDetailHingePolicy.span),
          (null, null, ResourceListDetailHingePolicy.span),
          (null, null, ResourceListDetailHingePolicy.span),
        ]);
        expect(fixture.view.snapshot.revision, 3);
        expect(fixture.models.last.compactDetailRequested, isTrue);
      },
    );

    test(
      'B05 disposal during fanout halts remaining models and queued intent',
      () {
        // Given two tabs and a listener disposing the binding reentrantly.
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.bind();
        for (final model in fixture.models) {
          model.focusDetail();
        }
        fixture.models.first.addListener(() {
          fixture.view.resetCommon();
          fixture.binding!.dispose();
        });

        // When an edit begins fanout to the first model.
        fixture.view.setValue(
          CommonSettings.panePreference.id,
          SettingsPanePreference.preferSinglePane,
        );

        // Then disposal stops both pending events and the remainder of this fanout.
        expect(fixture.models.first.preferenceOverride, isNull);
        expect(
          fixture.models.last.preferenceOverride,
          ResourceListDetailDisplayPreference.detailFocused,
        );
        expect(fixture.view.snapshot.revision, 2);
        expect(
          () => fixture.binding!.updateCapabilities(SettingsCapabilities()),
          throwsStateError,
        );
      },
    );

    test('B06 disposal detaches only the binding and borrowed owners remain usable', () {
      // Given a bound View, controller, storage and two caller-owned models.
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      fixture.bind();
      fixture.models.first.focusDetail();

      // When binding disposal repeats and its borrowed owners continue operating.
      fixture.binding!.dispose();
      fixture.binding!.dispose();
      fixture.view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferSinglePane,
      );
      fixture.models.first.restoreSplit();
      fixture.controller.resetCommon();
      final read = fixture.storage.read();
      fixture.storage.reads.single.succeed(null);

      // Then settings edits no longer fan out and no borrowed dependency was disposed.
      expect(read, completion(isNull));
      expect(
        fixture.models.first.preferenceOverride,
        ResourceListDetailDisplayPreference.split,
      );
      expect(
        fixture.models.last.resolve(splitCapable: true, hasSelection: false),
        ResourceListDetailPresentation.split,
      );
      expect(fixture.view.snapshot.revision, 2);
      expect(
        () => fixture.binding!.updateCapabilities(SettingsCapabilities()),
        throwsStateError,
      );
      expect(fixture.storage.writeCount, 0);
    });
  });
}

class _Fixture {
  _Fixture({SettingsRegistry? registry}) {
    controller = SettingsController(registry: registry, storage: storage);
    view = SettingsView.fromService(service: controller);
  }

  final storage = ControllableSettingsStorage();
  late final SettingsController controller;
  late final SettingsView view;
  final models = [
    ResourceListDetailDisplayModel(),
    ResourceListDetailDisplayModel(),
  ];
  ResourceListDetailSettingsBinding? binding;

  void bind({List<ResourceListDetailDisplayModel>? models}) {
    binding = ResourceListDetailSettingsBinding(
      view: view,
      displayModels: models ?? this.models,
      capabilities: SettingsCapabilities(supported: {'hinge'}),
    );
  }

  void dispose() {
    binding?.dispose();
    view.dispose();
    controller.dispose();
    for (final model in models) {
      model.dispose();
    }
  }
}

// Only the constructor-rejection case needs a service that cannot register common
// definitions; every propagation/lifetime case above uses the actual controller.
class _IncompleteCatalog extends ChangeNotifier implements SettingsService {
  @override
  final registry = SettingsRegistry(
    groups: CommonSettings.groups,
    definitions: [],
  );

  @override
  SettingsSnapshot get snapshot => SettingsSnapshot(registry: registry);

  @override
  Future<void> load() async {}
  @override
  Future<void> retryLoad() async {}
  @override
  Future<void> retrySave() async {}
  @override
  void setValue(String id, Object value) => throw ArgumentError(id);
  @override
  void resetCommon() {}
}
