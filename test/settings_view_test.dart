import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

/// Controllable observation/delegation fixture, without storage or durability.
class _SettingsService extends ChangeNotifier implements SettingsService {
  _SettingsService({SettingsRegistry? registry})
    : registry = registry ?? CommonSettings.registry() {
    _snapshot = SettingsSnapshot(registry: this.registry);
  }

  @override
  final SettingsRegistry registry;
  late SettingsSnapshot _snapshot;
  bool disposed = false;
  int addedListeners = 0;
  int removedListeners = 0;
  int disposeCalls = 0;
  int loadCalls = 0;
  int retryLoadCalls = 0;
  int retrySaveCalls = 0;
  int resetCalls = 0;
  final edits = <(String, Object)>[];
  final attachedCallbacks = <VoidCallback>[];

  @override
  SettingsSnapshot get snapshot => _snapshot;

  @override
  void addListener(VoidCallback listener) {
    _requireActive();
    addedListeners++;
    attachedCallbacks.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removedListeners++;
    super.removeListener(listener);
  }

  void publish(SettingsSnapshot snapshot) {
    _requireActive();
    _snapshot = snapshot;
    notifyListeners();
  }

  SettingsSnapshot _readState(SettingsReadState state) => SettingsSnapshot(
    registry: registry,
    values: snapshot.values,
    explicitValueIds: snapshot.explicitValueIds,
    unsavedIds: snapshot.unsavedIds,
    revision: snapshot.revision,
    savedRevision: snapshot.savedRevision,
    readState: state,
    saveState: snapshot.saveState,
    saveError: snapshot.saveError,
    lastIntent: snapshot.lastIntent,
  );

  @override
  Future<void> load() {
    _requireActive();
    loadCalls++;
    publish(_readState(SettingsReadState.loading));
    return Future.value();
  }

  @override
  Future<void> retryLoad() {
    _requireActive();
    retryLoadCalls++;
    publish(_readState(SettingsReadState.loading));
    return Future.value();
  }

  @override
  Future<void> retrySave() {
    _requireActive();
    retrySaveCalls++;
    return Future.value();
  }

  @override
  void setValue(String id, Object value) {
    _requireActive();
    final validated = registry.definition(id).validate(value);
    edits.add((id, value));
    final revision = snapshot.revision + 1;
    publish(
      SettingsSnapshot(
        registry: registry,
        values: {...snapshot.values, id: validated},
        explicitValueIds: {...snapshot.explicitValueIds, id},
        unsavedIds: {...snapshot.unsavedIds, id},
        revision: revision,
        savedRevision: snapshot.savedRevision,
        readState: snapshot.readState,
        lastIntent: SettingsIntent(
          revision: revision,
          kind: SettingsIntentKind.edit,
          settingId: id,
        ),
      ),
    );
  }

  @override
  void resetCommon() {
    _requireActive();
    resetCalls++;
    final revision = snapshot.revision + 1;
    final commonIds = CommonSettings.definitions.map(
      (definition) => definition.id,
    );
    publish(
      SettingsSnapshot(
        registry: registry,
        values: {
          ...snapshot.values,
          for (final definition in CommonSettings.definitions)
            definition.id: definition.defaultValue,
        },
        explicitValueIds: {...snapshot.explicitValueIds, ...commonIds},
        unsavedIds: {...snapshot.unsavedIds, ...commonIds},
        revision: revision,
        savedRevision: snapshot.savedRevision,
        readState: snapshot.readState,
        lastIntent: SettingsIntent(
          revision: revision,
          kind: SettingsIntentKind.resetCommon,
          settingId: null,
        ),
      ),
    );
  }

  void _requireActive() {
    if (disposed) throw StateError('Fake service is disposed');
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    disposeCalls++;
    super.dispose();
  }
}

class _OtherView extends ChangeNotifier implements ApplicationView {
  int disposeCalls = 0;

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}

class _Resources implements ResourceDataSource, ResourceActionHandler {
  final record = ResourceRecord(id: 'one', values: {'name': 'One'});
  int listCalls = 0;
  int readCalls = 0;
  int commandCalls = 0;

  @override
  Future<List<ResourceRecord>> listResources() async {
    listCalls++;
    return [record];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    readCalls++;
    return id == record.id ? record : null;
  }

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) => const [
    ResourceAction(id: 'example', label: 'Example'),
  ];

  @override
  Future<void> execute(String actionId, ResourceRecord record) async {
    commandCalls++;
  }
}

void main() {
  group('Settings View state observation', () {
    test('construction attaches once, exposes defaults and waits for explicit load', () async {
      // Given a controllable service that has not loaded.
      final service = _SettingsService();

      // When the borrowing view is constructed and composition explicitly loads.
      final view = SettingsView.fromService(service: service);
      addTearDown(service.dispose);
      addTearDown(view.dispose);
      final initial = view.snapshot;
      final initialLoadCalls = service.loadCalls;
      await view.load();

      // Then initial defaults are observable without an implicit constructor load.
      expect(service.addedListeners, 1);
      expect(initialLoadCalls, 0);
      expect(service.loadCalls, 1);
      expect(view.service, same(service));
      expect(view.registry, same(service.registry));
      expect(initial.readState, SettingsReadState.notLoaded);
      expect(
        initial.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(view.snapshot, same(service.snapshot));
      expect(view.snapshot.readState, SettingsReadState.loading);
      expect(view.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(view.snapshot.revision, 0);
      expect(view.snapshot.lastIntent, isNull);
    });

    test('read loading, ready, error and unsupported state use the service snapshot', () {
      // Given an observed Settings view and controllable restoration outcomes.
      final service = _SettingsService();
      final view = SettingsView.owned(service: service);
      addTearDown(view.dispose);
      final observed = <SettingsSnapshot>[];
      view.addListener(() => observed.add(view.snapshot));
      final error = StateError('read failed');
      final states = [
        SettingsSnapshot(
          registry: service.registry,
          readState: SettingsReadState.loading,
        ),
        SettingsSnapshot(
          registry: service.registry,
          values: {CommonSettings.textSizeMultiplier.id: 1.15},
          explicitValueIds: {CommonSettings.textSizeMultiplier.id},
          readState: SettingsReadState.ready,
        ),
        SettingsSnapshot(
          registry: service.registry,
          readState: SettingsReadState.failed,
          readError: error,
        ),
        SettingsSnapshot(
          registry: service.registry,
          readState: SettingsReadState.unsupported,
        ),
      ];

      // When the service publishes each restoration state.
      for (final snapshot in states) {
        service.publish(snapshot);
      }

      // Then notifications expose those exact states without copying or inventing intent.
      expect(observed, orderedEquals(states));
      for (var index = 0; index < states.length; index++) {
        expect(observed[index], same(states[index]));
        expect(observed[index].revision, 0);
        expect(observed[index].lastIntent, isNull);
      }
      expect(observed[1].value(CommonSettings.textSizeMultiplier), 1.15);
      expect(
        observed[1].hasExplicitValue(CommonSettings.textSizeMultiplier.id),
        isTrue,
      );
      expect(observed[2].readError, same(error));
      expect(view.snapshot.readState, SettingsReadState.unsupported);
    });

    test('unsaved saving and failed-save state never imply acknowledgement', () {
      // Given an observed explicit preference awaiting storage acknowledgement.
      final service = _SettingsService();
      final view = SettingsView.owned(service: service);
      addTearDown(view.dispose);
      final id = CommonSettings.hingePreference.id;
      final error = StateError('write failed');
      final observed = <SettingsSnapshot>[];
      view.addListener(() => observed.add(view.snapshot));
      final intent = SettingsIntent(
        revision: 1,
        kind: SettingsIntentKind.edit,
        settingId: id,
      );

      // When the fake service publishes saving then failed state for that intent.
      for (final state in [
        SettingsSaveState.saving,
        SettingsSaveState.failed,
      ]) {
        service.publish(
          SettingsSnapshot(
            registry: service.registry,
            values: {id: SettingsHingePreference.span},
            explicitValueIds: {id},
            unsavedIds: {id},
            revision: 1,
            readState: SettingsReadState.ready,
            saveState: state,
            saveError: state == SettingsSaveState.failed ? error : null,
            lastIntent: intent,
          ),
        );
      }

      // Then both snapshots retain the value/intent as unsaved at saved revision zero.
      expect(observed.map((snapshot) => snapshot.saveState), [
        SettingsSaveState.saving,
        SettingsSaveState.failed,
      ]);
      for (final snapshot in observed) {
        expect(snapshot.hasUnsavedChanges, isTrue);
        expect(snapshot.savedRevision, 0);
        expect(
          snapshot.value(CommonSettings.hingePreference),
          SettingsHingePreference.span,
        );
        expect(snapshot.lastIntent, same(intent));
      }
      expect(view.snapshot.saveError, same(error));
      expect(view.snapshot, same(service.snapshot));
    });

    test(
      'availability queries use supplied capabilities without service edits',
      () {
        // Given a retained hinge preference and unsupported/supported environments.
        final service = _SettingsService();
        final view = SettingsView.owned(service: service);
        addTearDown(view.dispose);
        final id = CommonSettings.hingePreference.id;
        service.publish(
          SettingsSnapshot(
            registry: service.registry,
            values: {id: SettingsHingePreference.span},
            explicitValueIds: {id},
          ),
        );
        final snapshot = view.snapshot;
        var notifications = 0;
        view.addListener(() => notifications++);

        // When availability is queried with changing ephemeral inputs.
        final absent = view.availability(id, SettingsCapabilities());
        final present = view.availability(
          id,
          SettingsCapabilities(supported: {'hinge'}),
        );

        // Then availability changes independently of snapshot, preference and intent.
        expect(absent, SettingAvailability.disabled);
        expect(present, SettingAvailability.available);
        expect(view.snapshot, same(snapshot));
        expect(
          view.value(CommonSettings.hingePreference),
          SettingsHingePreference.span,
        );
        expect(view.snapshot.revision, 0);
        expect(view.snapshot.lastIntent, isNull);
        expect(service.edits, isEmpty);
        expect(notifications, 0);
        expect(
          () => view.availability('missing', SettingsCapabilities()),
          throwsArgumentError,
        );
      },
    );
  });

  group('Settings View intent delegation', () {
    test('valid edits forward once and invalid ID/type/catalog edits never forward', () {
      // Given a view whose service records forwarded edits and notifications.
      final service = _SettingsService();
      final view = SettingsView.owned(service: service);
      addTearDown(view.dispose);
      final id = CommonSettings.textSizeMultiplier.id;
      var notifications = 0;
      view.addListener(() => notifications++);

      // When one valid edit and invalid ID/type/catalog edits are attempted.
      view.setValue(id, 1.15);
      final afterValid = view.snapshot;
      final invalid = <void Function()>[
        () => view.setValue('missing', true),
        () => view.setValue(id, '1.15'),
        () => view.setValue(id, 1.2),
        () => view.setValue(id, 1),
        () => view.setValue(CommonSettings.panePreference.id, 'automatic'),
      ];

      // Then validation precedes forwarding and only the valid edit changes state.
      for (final edit in invalid) {
        expect(edit, throwsArgumentError);
      }
      expect(service.edits, [(id, 1.15)]);
      expect(view.value(CommonSettings.textSizeMultiplier), 1.15);
      expect(view.snapshot, same(afterValid));
      expect(view.snapshot.hasUnsavedChanges, isTrue);
      expect(notifications, 1);
    });

    test('explicit same-value edits and every reset have distinct intent revisions', () {
      // Given initial inherited defaults and a view observing service intent.
      final service = _SettingsService();
      final view = SettingsView.owned(service: service);
      addTearDown(view.dispose);
      final id = CommonSettings.panePreference.id;
      final before = view.snapshot;

      // When automatic is explicitly chosen twice and reset is requested twice.
      view.setValue(id, SettingsPanePreference.automatic);
      final first = view.snapshot;
      view.setValue(id, SettingsPanePreference.automatic);
      final second = view.snapshot;
      view.resetCommon();
      final reset = view.snapshot;
      view.resetCommon();
      final repeatedReset = view.snapshot;

      // Then unchanged effective values still expose semantic presence and sequence.
      expect(before.hasExplicitValue(id), isFalse);
      expect(first.hasExplicitValue(id), isTrue);
      expect(first.lastIntent!.kind, SettingsIntentKind.edit);
      expect(first.lastIntent!.settingId, id);
      expect(
        [
          first.revision,
          second.revision,
          reset.revision,
          repeatedReset.revision,
        ],
        [1, 2, 3, 4],
      );
      expect(second.lastIntent!.revision, 2);
      expect(reset.lastIntent!.kind, SettingsIntentKind.resetCommon);
      expect(reset.lastIntent!.settingId, isNull);
      expect(repeatedReset.lastIntent!.revision, 4);
      expect(
        repeatedReset.explicitValueIds,
        CommonSettings.definitions.map((definition) => definition.id).toSet(),
      );
      expect(service.edits, hasLength(2));
      expect(service.resetCalls, 2);
      expect(
        view.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(view.snapshot.hasUnsavedChanges, isTrue);
      expect(view.snapshot.savedRevision, 0);
    });

    test(
      'load and retry operations delegate without a new edit/reset intent',
      () async {
        // Given a service snapshot with an existing explicit user intent.
        final service = _SettingsService();
        final view = SettingsView.owned(service: service);
        addTearDown(view.dispose);
        view.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
        final intent = view.snapshot.lastIntent;

        // When composition loads and the user retries reading and saving.
        await view.load();
        await view.retryLoad();
        await view.retrySave();

        // Then each method delegates once without changing preference intent sequence.
        expect(service.loadCalls, 1);
        expect(service.retryLoadCalls, 1);
        expect(service.retrySaveCalls, 1);
        expect(service.edits, hasLength(1));
        expect(service.resetCalls, 0);
        expect(view.snapshot.lastIntent, same(intent));
        expect(view.snapshot.revision, 1);
        expect(view.value(CommonSettings.textSizeMultiplier), 1.15);
      },
    );

    test('reset delegates common defaults while synthetic extension values survive', () {
      // Given a synthetic application setting with explicit true and nondefault pane.
      final flag = SettingDefinition<bool>(
        id: 'example.flag',
        groupId: 'application',
        label: 'Example flag',
        defaultValue: false,
        choices: [
          SettingChoice(value: false, label: 'Off', storedValue: false),
          SettingChoice(value: true, label: 'On', storedValue: true),
        ],
      );
      final service = _SettingsService(
        registry: CommonSettings.registry(extensions: [flag]),
      );
      final view = SettingsView.owned(service: service);
      addTearDown(view.dispose);
      view.setValue(flag.id, true);
      view.setValue(
        CommonSettings.panePreference.id,
        SettingsPanePreference.preferDualPane,
      );

      // When the view forwards a common reset to the controllable service.
      view.resetCommon();

      // Then the fake's reset projection is observed without a View-owned reset copy.
      expect(service.resetCalls, 1);
      expect(view.snapshot, same(service.snapshot));
      expect(view.value(flag), isTrue);
      expect(view.snapshot.hasExplicitValue(flag.id), isTrue);
      expect(
        view.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(
        view.value(CommonSettings.hingePreference),
        SettingsHingePreference.automatic,
      );
      expect(view.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(view.snapshot.lastIntent!.kind, SettingsIntentKind.resetCommon);
    });
  });

  group('Application View space and ownership', () {
    test('settings notifications preserve resource views, selection and domain commands', () async {
      // Given named Settings/other/resource views with a selected resource.
      final service = _SettingsService();
      final settings = SettingsView.owned(service: service);
      final other = _OtherView();
      final resources = _Resources();
      final collection = ResourceCollectionView(dataSource: resources);
      final detail = ResourceDetailView(
        dataSource: resources,
        actionHandler: resources,
      );
      final model = ApplicationViewModel({
        'settings': settings,
        'other': other,
        'resources': collection,
        'detail': detail,
      });
      addTearDown(model.dispose);
      await collection.load();
      await detail.select('one');
      final selected = detail.resource;
      final list = collection.resources;
      var notifications = 0;
      model.addListener(() => notifications++);

      // When Settings notifies for an edit, reset and a loading state.
      settings.setValue(CommonSettings.textSizeMultiplier.id, 1.15);
      settings.resetCommon();
      await settings.load();

      // Then the same named views and selected resource survive without domain work.
      expect(model.view<SettingsView>('settings'), same(settings));
      expect(model.view<_OtherView>('other'), same(other));
      expect(model.view<ResourceCollectionView>('resources'), same(collection));
      expect(model.view<ResourceDetailView>('detail'), same(detail));
      expect(model.viewIds, ['settings', 'other', 'resources', 'detail']);
      expect(collection.resources, same(list));
      expect(detail.resource, same(selected));
      expect(detail.selectedId, 'one');
      expect(resources.listCalls, 1);
      expect(resources.readCalls, 1);
      expect(resources.commandCalls, 0);
      expect(other.disposeCalls, 0);
      expect(notifications, 3);
    });

    test(
      'owned disposal detaches once and disposes the service exactly once',
      () {
        // Given an owned service and a named application View space.
        final service = _SettingsService();
        final view = SettingsView.owned(service: service);
        final other = _OtherView();
        final model = ApplicationViewModel({'settings': view, 'other': other});

        // When the application owner and view receive repeated disposal.
        model.dispose();
        model.dispose();
        view.dispose();

        // Then each owned boundary detaches/disposes exactly once.
        expect(service.addedListeners, 1);
        expect(service.removedListeners, 1);
        expect(service.disposeCalls, 1);
        expect(service.disposed, isTrue);
        expect(other.disposeCalls, 1);
      },
    );

    test('borrowed disposal detaches once while the service remains usable', () {
      // Given a borrowing view and a separately owned service.
      final service = _SettingsService();
      addTearDown(service.dispose);
      final view = SettingsView.fromService(service: service);
      var notifications = 0;
      view.addListener(() => notifications++);

      // When the view is disposed twice and its service receives a later edit.
      view.dispose();
      view.dispose();
      service.setValue(CommonSettings.textSizeMultiplier.id, 1.15);

      // Then the borrowed service is usable and the detached view cannot notify.
      expect(service.addedListeners, 1);
      expect(service.removedListeners, 1);
      expect(service.disposeCalls, 0);
      expect(service.disposed, isFalse);
      expect(service.snapshot.value(CommonSettings.textSizeMultiplier), 1.15);
      expect(notifications, 0);
    });

    test('disposed views suppress late callbacks and reject all subsequent intents', () {
      // Given both ownership modes and callbacks captured while attached.
      final ownedService = _SettingsService();
      final borrowedService = _SettingsService();
      addTearDown(borrowedService.dispose);
      final views = [
        SettingsView.owned(service: ownedService),
        SettingsView.fromService(service: borrowedService),
      ];
      final services = [ownedService, borrowedService];
      var notifications = 0;
      for (final view in views) {
        view.addListener(() => notifications++);
      }

      // When disposed views receive captured late callbacks and every new intent.
      for (var index = 0; index < views.length; index++) {
        final view = views[index];
        view.dispose();
        services[index].attachedCallbacks.single();
        final intents = <void Function()>[
          () => view.load(),
          () => view.retryLoad(),
          () => view.retrySave(),
          () => view.setValue(CommonSettings.textSizeMultiplier.id, 1.15),
          () => view.resetCommon(),
        ];

        // Then intents throw synchronously and no service call or notification escapes.
        for (final intent in intents) {
          expect(intent, throwsStateError);
        }
        expect(services[index].loadCalls, 0);
        expect(services[index].retryLoadCalls, 0);
        expect(services[index].retrySaveCalls, 0);
        expect(services[index].edits, isEmpty);
        expect(services[index].resetCalls, 0);
        expect(services[index].removedListeners, 1);
      }
      expect(notifications, 0);
    });
  });
}
