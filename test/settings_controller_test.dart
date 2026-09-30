import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

final _paneId = CommonSettings.panePreference.id;
final _hingeId = CommonSettings.hingePreference.id;
final _textId = CommonSettings.textSizeMultiplier.id;
final _commonIds = CommonSettings.definitions.map((value) => value.id).toSet();

SettingDefinition<bool> _flag({String id = 'example.flag'}) =>
    SettingDefinition<bool>(
      id: id,
      groupId: 'application',
      label: 'Example flag',
      defaultValue: false,
      choices: [
        SettingChoice(value: false, label: 'Off', storedValue: false),
        SettingChoice(value: true, label: 'On', storedValue: true),
      ],
    );

String _wire(
  Map<String, Object?> values, {
  int version = 1,
  Map<String, Object?> extras = const {},
}) => jsonEncode({...extras, 'version': version, 'values': values});

SettingsController _controller(
  ControllableSettingsStorage storage, {
  SettingsRegistry? registry,
}) {
  final controller = SettingsController(registry: registry, storage: storage);
  addTearDown(controller.dispose);
  return controller;
}

Future<SettingsController> _ready(
  ControllableSettingsStorage storage, {
  SettingsRegistry? registry,
  Map<String, Object?> values = const {},
  Map<String, Object?> extras = const {},
}) async {
  final controller = _controller(storage, registry: registry);
  final loaded = controller.load();
  storage.reads.last.succeed(_wire(values, extras: extras));
  await loaded;
  return controller;
}

Future<void> _flushMicrotasks() async {
  for (var turn = 0; turn < 8; turn++) {
    await Future<void>.value();
  }
}

Object? _captureError(void Function() action) {
  try {
    action();
    return null;
  } catch (error) {
    return error;
  }
}

SettingsRecord _submitted(ControllableSettingsStorage storage, int index) =>
    SettingsRecord.decode(storage.writes[index].record);

class _OtherView extends ChangeNotifier implements ApplicationView {
  int disposeCalls = 0;

  void publish() => notifyListeners();

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
  List<ResourceAction> actionsFor(ResourceRecord record) => const [];

  @override
  Future<void> execute(String actionId, ResourceRecord record) async {
    commandCalls++;
  }
}

void main() {
  group('Settings controller explicit restoration and local intent protection', () {
    test('C01 construction is idle and requires actual common definitions', () {
      // Given a storage fixture, synthetic extension and missing/forged registries.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final missing = SettingsRegistry(
        groups: CommonSettings.groups,
        definitions: [
          CommonSettings.panePreference,
          CommonSettings.hingePreference,
        ],
      );
      final forgedPane = SettingDefinition<SettingsPanePreference>(
        id: _paneId,
        groupId: 'layout',
        label: 'Forged pane',
        defaultValue: SettingsPanePreference.automatic,
        choices: CommonSettings.panePreference.choices,
      );
      final forged = SettingsRegistry(
        groups: CommonSettings.groups,
        definitions: [
          forgedPane,
          CommonSettings.hingePreference,
          CommonSettings.textSizeMultiplier,
        ],
      );

      // When default/extended controllers and invalid common compositions are built.
      final defaults = _controller(storage);
      final extended = _controller(
        storage,
        registry: CommonSettings.registry(extensions: [flag]),
      );
      final errors = [
        _captureError(
          () => SettingsController(registry: missing, storage: storage),
        ),
        _captureError(
          () => SettingsController(registry: forged, storage: storage),
        ),
      ];

      // Then construction has inherited defaults and zero I/O; common forgeries reject.
      expect(errors, everyElement(isA<ArgumentError>()));
      expect(defaults.snapshot.values, {
        _paneId: SettingsPanePreference.automatic,
        _hingeId: SettingsHingePreference.automatic,
        _textId: 1.0,
      });
      expect(extended.snapshot.value(flag), isFalse);
      expect(extended.registry.definition(flag.id), same(flag));
      expect(defaults.snapshot.readState, SettingsReadState.notLoaded);
      expect(defaults.snapshot.saveState, SettingsSaveState.idle);
      expect(defaults.snapshot.revision, 0);
      expect(defaults.snapshot.savedRevision, 0);
      expect(defaults.snapshot.lastIntent, isNull);
      expect(defaults.snapshot.explicitValueIds, isEmpty);
      expect(defaults.snapshot.unsavedIds, isEmpty);
      expect(defaults.snapshot.readError, isNull);
      expect(defaults.snapshot.saveError, isNull);
      expect(storage.readCount, 0);
      expect(storage.writeCount, 0);
    });

    test('C02 delayed load restores typed siblings without intent or writes', () async {
      // Given a new controller observed while valid stored choices are delayed.
      final storage = ControllableSettingsStorage();
      final controller = _controller(storage);
      final observed = <SettingsSnapshot>[];
      controller.addListener(() => observed.add(controller.snapshot));

      // When explicit load waits and then receives a valid stored envelope.
      final loaded = controller.load();
      final loading = controller.snapshot;
      storage.reads.single.succeed(
        _wire({_paneId: 'preferDualPane', _hingeId: 'avoid', _textId: 1}),
      );
      await loaded;

      // Then loading was visible and typed explicit choices restore without default writes.
      expect(loading.readState, SettingsReadState.loading);
      expect(controller.snapshot.readState, SettingsReadState.ready);
      expect(
        controller.snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.preferDualPane,
      );
      expect(
        controller.snapshot.value(CommonSettings.hingePreference),
        SettingsHingePreference.avoid,
      );
      expect(
        controller.snapshot.value(CommonSettings.textSizeMultiplier),
        isA<double>(),
      );
      expect(controller.snapshot.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(controller.snapshot.explicitValueIds, _commonIds);
      expect(controller.snapshot.revision, 0);
      expect(controller.snapshot.savedRevision, 0);
      expect(controller.snapshot.lastIntent, isNull);
      expect(controller.snapshot.unsavedIds, isEmpty);
      expect(observed.map((value) => value.readState), [
        SettingsReadState.loading,
        SettingsReadState.ready,
      ]);
      expect(storage.readCount, 1);
      expect(storage.writeCount, 0);
    });

    test('C03 null read inherits defaults without persisting them', () async {
      // Given absent durable storage and a newly constructed controller.
      final storage = ControllableSettingsStorage();
      final controller = _controller(storage);

      // When explicit load acknowledges absence.
      final loaded = controller.load();
      storage.readDurable(0);
      await loaded;
      await _flushMicrotasks();

      // Then defaults are ready but remain inherited with no write or intent.
      expect(controller.snapshot.readState, SettingsReadState.ready);
      expect(
        controller.snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(controller.snapshot.explicitValueIds, isEmpty);
      expect(controller.snapshot.unsavedIds, isEmpty);
      expect(controller.snapshot.revision, 0);
      expect(controller.snapshot.saveState, SettingsSaveState.idle);
      expect(storage.writeCount, 0);
      expect(storage.durableRecord, isNull);
    });

    test('C04 invalid and missing fields fall back independently with presence', () async {
      // Given valid defaults/siblings, an invalid pane and a missing extension.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final absent = _flag(id: 'example.absent');
      final controller = _controller(
        storage,
        registry: CommonSettings.registry(extensions: [flag, absent]),
      );

      // When the mixed-validity envelope is restored.
      final loaded = controller.load();
      storage.reads.single.succeed(
        _wire({
          _paneId: 'invalid',
          _hingeId: 'automatic',
          _textId: 1,
          flag.id: true,
        }),
      );
      await loaded;

      // Then each invalid/missing value inherits while valid explicit defaults stay explicit.
      expect(
        controller.snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(controller.snapshot.hasExplicitValue(_paneId), isFalse);
      expect(controller.snapshot.hasExplicitValue(_hingeId), isTrue);
      expect(controller.snapshot.hasExplicitValue(_textId), isTrue);
      expect(controller.snapshot.value(flag), isTrue);
      expect(controller.snapshot.hasExplicitValue(flag.id), isTrue);
      expect(controller.snapshot.value(absent), isFalse);
      expect(controller.snapshot.hasExplicitValue(absent.id), isFalse);
      expect(controller.snapshot.unsavedIds, isEmpty);
      expect(storage.writeCount, 0);
    });

    test(
      'C05 edit predating initial load stays unsaved behind the read barrier',
      () async {
        // Given an immediate local edit before any storage read.
        final storage = ControllableSettingsStorage();
        final controller = _controller(storage);
        controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
        final edited = controller.snapshot;

        // When load receives an older pane value and an untouched hinge value.
        final loaded = controller.load();
        final writesBeforeRead = storage.writeCount;
        storage.reads.single.succeed(
          _wire({_paneId: 'preferSinglePane', _hingeId: 'span'}),
        );
        await loaded;
        await _flushMicrotasks();

        // Then the predating intent survives and is merged only after the baseline is read.
        expect(
          edited.value(CommonSettings.panePreference),
          SettingsPanePreference.preferDualPane,
        );
        expect(edited.unsavedIds, {_paneId});
        expect(edited.readState, SettingsReadState.notLoaded);
        expect(writesBeforeRead, 0);
        expect(
          controller.snapshot.value(CommonSettings.panePreference),
          SettingsPanePreference.preferDualPane,
        );
        expect(
          controller.snapshot.value(CommonSettings.hingePreference),
          SettingsHingePreference.span,
        );
        expect(controller.snapshot.revision, 1);
        expect(controller.snapshot.savedRevision, 0);
        expect(_submitted(storage, 0).values[_paneId], 'preferDualPane');
        expect(storage.activeWrites, 1);
      },
    );

    test(
      'C06 edit during delayed read protects only the edited setting',
      () async {
        // Given a pending initial read with untouched common settings.
        final storage = ControllableSettingsStorage();
        final controller = _controller(storage);
        final loaded = controller.load();

        // When a pane edit precedes completion of older stored choices.
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        final writesBeforeRead = storage.writeCount;
        storage.reads.single.succeed(
          _wire({_paneId: 'preferDualPane', _hingeId: 'avoid', _textId: 1.30}),
        );
        await loaded;
        await _flushMicrotasks();

        // Then the local pane survives and untouched typed siblings restore normally.
        expect(writesBeforeRead, 0);
        expect(
          controller.snapshot.value(CommonSettings.panePreference),
          SettingsPanePreference.preferSinglePane,
        );
        expect(
          controller.snapshot.value(CommonSettings.hingePreference),
          SettingsHingePreference.avoid,
        );
        expect(
          controller.snapshot.value(CommonSettings.textSizeMultiplier),
          1.30,
        );
        expect(controller.snapshot.unsavedIds, {_paneId});
        expect(controller.snapshot.explicitValueIds, _commonIds);
        expect(controller.snapshot.revision, 1);
        expect(storage.writeCount, 1);
      },
    );

    test('C07 reset during read protects common defaults and restores extension', () async {
      // Given a delayed read and an untouched registered application extension.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final controller = _controller(
        storage,
        registry: CommonSettings.registry(extensions: [flag]),
      );
      final loaded = controller.load();

      // When reset intent precedes completion with nondefault common/extension data.
      controller.resetCommon();
      final writesBeforeRead = storage.writeCount;
      storage.reads.single.succeed(
        _wire({
          _paneId: 'preferDualPane',
          _hingeId: 'span',
          _textId: 1.30,
          flag.id: true,
        }),
      );
      await loaded;
      await _flushMicrotasks();

      // Then common defaults are explicit/unsaved while untouched extension data restores.
      expect(writesBeforeRead, 0);
      expect(
        controller.snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(
        controller.snapshot.value(CommonSettings.hingePreference),
        SettingsHingePreference.automatic,
      );
      expect(controller.snapshot.value(CommonSettings.textSizeMultiplier), 1.0);
      expect(controller.snapshot.value(flag), isTrue);
      expect(controller.snapshot.hasExplicitValue(flag.id), isTrue);
      expect(controller.snapshot.unsavedIds, _commonIds);
      expect(
        controller.snapshot.lastIntent!.kind,
        SettingsIntentKind.resetCommon,
      );
      expect(controller.snapshot.revision, 1);
      expect(_submitted(storage, 0).values[flag.id], isTrue);
    });

    test(
      'C08 failed read and explicit retry preserve all intervening local edits',
      () async {
        // Given an edit before load and a delayed storage failure.
        final storage = ControllableSettingsStorage();
        final flag = _flag();
        final controller = _controller(
          storage,
          registry: CommonSettings.registry(extensions: [flag]),
        );
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        final error = StateError('read failed');
        final loaded = controller.load();

        // When edits occur during the read, after failure and during explicit retry.
        controller.setValue(_textId, 1.15);
        storage.reads[0].fail(error);
        await loaded;
        final failed = controller.snapshot;
        controller.setValue(_hingeId, SettingsHingePreference.avoid);
        await controller.load();
        await controller.retrySave();
        final blockedCounts = (storage.readCount, storage.writeCount);
        final retried = controller.retryLoad();
        controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
        storage.reads[1].succeed(
          _wire({
            _paneId: 'automatic',
            _hingeId: 'span',
            _textId: 1.30,
            flag.id: true,
          }),
        );
        await retried;
        await _flushMicrotasks();

        // Then failures complete normally, no implicit retry writes, and only untouched data restores.
        expect(failed.readState, SettingsReadState.failed);
        expect(failed.readError, same(error));
        expect(failed.unsavedIds, {_paneId, _textId});
        expect(blockedCounts, (1, 0));
        expect(controller.snapshot.readState, SettingsReadState.ready);
        expect(controller.snapshot.readError, isNull);
        expect(
          controller.snapshot.value(CommonSettings.panePreference),
          SettingsPanePreference.preferDualPane,
        );
        expect(
          controller.snapshot.value(CommonSettings.hingePreference),
          SettingsHingePreference.avoid,
        );
        expect(
          controller.snapshot.value(CommonSettings.textSizeMultiplier),
          1.15,
        );
        expect(controller.snapshot.value(flag), isTrue);
        expect(controller.snapshot.unsavedIds, _commonIds);
        expect(controller.snapshot.revision, 4);
        expect(storage.readCount, 2);
        expect(storage.writeCount, 1);
      },
    );

    test('C09 malformed read blocks reset/edit/save until explicit successful retry', () async {
      // Given malformed storage behind a pending initial read.
      final storage = ControllableSettingsStorage(durableRecord: '{broken');
      final controller = _controller(storage);
      final loaded = controller.load();

      // When malformed completion is followed by reset/edit/save and explicit reread.
      storage.readDurable(0);
      await loaded;
      final failed = controller.snapshot;
      controller.resetCommon();
      controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
      await controller.retrySave();
      await controller.load();
      await _flushMicrotasks();
      final blockedCounts = (storage.readCount, storage.writeCount);
      final retried = controller.retryLoad();
      storage.reads[1].succeed(null);
      await retried;
      await _flushMicrotasks();

      // Then malformed storage remains protected until retry opens the baseline for latest intent.
      expect(failed.readState, SettingsReadState.failed);
      expect(failed.readError, isA<FormatException>());
      expect(blockedCounts, (1, 0));
      expect(storage.durableRecord, '{broken');
      expect(controller.snapshot.readState, SettingsReadState.ready);
      expect(controller.snapshot.unsavedIds, _commonIds);
      expect(controller.snapshot.revision, 2);
      expect(_submitted(storage, 0).values, {
        _paneId: 'preferDualPane',
        _hingeId: 'automatic',
        _textId: 1.0,
      });
    });

    test('C10 overlapping and reentrant load/retry share one read', () async {
      // Given a controller whose loading listener also requests load and retry.
      final storage = ControllableSettingsStorage();
      final controller = _controller(storage);
      Future<void>? listenerLoad;
      Future<void>? listenerRetry;
      controller.addListener(() {
        if (controller.snapshot.readState == SettingsReadState.loading) {
          listenerLoad = controller.load();
          listenerRetry = controller.retryLoad();
        }
      });

      // When retry starts the initial read and overlapping callers await completion.
      final initial = controller.retryLoad();
      final overlappingLoad = controller.load();
      final overlappingRetry = controller.retryLoad();
      storage.reads.single.succeed(null);
      await initial;
      await overlappingLoad;
      await overlappingRetry;
      await controller.load();
      await controller.retryLoad();

      // Then all active callers shared one read and ready calls do not reload.
      expect(listenerLoad, same(initial));
      expect(listenerRetry, same(initial));
      expect(overlappingLoad, same(initial));
      expect(overlappingRetry, same(initial));
      expect(storage.readCount, 1);
      expect(storage.maxActiveReads, 1);
      expect(storage.activeReads, 0);
      expect(storage.writeCount, 0);
      expect(() => storage.reads.single.succeed(null), throwsStateError);
    });

    test('C11 ordinary edit retains unknown extras and invalid untouched extension', () async {
      // Given supported raw application data and a known invalid extension payload.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final invalid = {
        'custom': [null, 7],
      };
      final unknown = [
        null,
        {'leaf': 'retained'},
      ];
      final controller = await _ready(
        storage,
        registry: CommonSettings.registry(extensions: [flag]),
        values: {flag.id: invalid, 'unknown': unknown, _hingeId: 'invalid'},
        extras: {
          'owner': {'identity': 9},
          'extraNull': null,
        },
      );

      // When one unrelated common setting is edited and submitted for persistence.
      controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
      await _flushMicrotasks();
      final record = _submitted(storage, 0);

      // Then the raw baseline survives without invalid-field canonicalization.
      expect(controller.snapshot.value(flag), isFalse);
      expect(controller.snapshot.hasExplicitValue(flag.id), isFalse);
      expect(record.values[flag.id], invalid);
      expect(record.values['unknown'], unknown);
      expect(record.values[_hingeId], 'invalid');
      expect(record.values.containsKey(_textId), isFalse);
      expect(record.extraFields, {
        'owner': {'identity': 9},
        'extraNull': null,
      });
      expect(record.values[_paneId], 'preferDualPane');
    });
  });

  group('Settings controller protected unsupported-version recovery', () {
    test('C12 unsupported record is retained without interpretation or ordinary writes', () async {
      // Given a future record with valid common and registered extension values.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final controller = _controller(
        storage,
        registry: CommonSettings.registry(extensions: [flag]),
      );

      // When load receives it and ordinary edit/save requests follow.
      final loaded = controller.load();
      storage.reads.single.succeed(
        _wire({
          _paneId: 'preferSinglePane',
          _hingeId: 'span',
          flag.id: true,
        }, version: 7),
      );
      await loaded;
      final unsupported = controller.snapshot;
      controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
      await controller.retrySave();
      await controller.load();
      await _flushMicrotasks();

      // Then known stored data stays uninterpreted and local intent remains usable but blocked.
      expect(unsupported.readState, SettingsReadState.unsupported);
      expect(unsupported.readError, isA<StateError>());
      expect(unsupported.readError.toString(), contains('7'));
      expect(
        unsupported.value(CommonSettings.panePreference),
        SettingsPanePreference.automatic,
      );
      expect(
        unsupported.value(CommonSettings.hingePreference),
        SettingsHingePreference.automatic,
      );
      expect(unsupported.value(flag), isFalse);
      expect(unsupported.explicitValueIds, isEmpty);
      expect(
        controller.snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.preferDualPane,
      );
      expect(controller.snapshot.unsavedIds, {_paneId});
      expect(controller.snapshot.readState, SettingsReadState.unsupported);
      expect(controller.snapshot.savedRevision, 0);
      expect(storage.readCount, 1);
      expect(storage.writeCount, 0);
    });

    test('C13 explicit future reset preserves extension data until acknowledgement', () async {
      // Given a future envelope with valid, invalid, unknown and locally edited extensions.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final invalidFlag = _flag(id: 'example.invalid');
      final localFlag = _flag(id: 'example.local');
      final controller = _controller(
        storage,
        registry: CommonSettings.registry(
          extensions: [flag, invalidFlag, localFlag],
        ),
      );
      final loaded = controller.load();
      final invalid = {
        'future': [null, false],
      };
      storage.reads.single.succeed(
        _wire(
          {
            _paneId: 'preferDualPane',
            _hingeId: 'span',
            _textId: 1.30,
            flag.id: true,
            invalidFlag.id: invalid,
            localFlag.id: false,
            'unknown': null,
          },
          version: 5,
          extras: {
            'owner': ['kept'],
          },
        ),
      );
      await loaded;

      // When extension intent and explicit common reset authorize one version-one recovery.
      controller.setValue(localFlag.id, true);
      controller.resetCommon();
      final recovering = controller.snapshot;
      await controller.retryLoad();
      await _flushMicrotasks();
      final record = _submitted(storage, 0);
      final saved = controller.retrySave();
      storage.writes.single.succeed();
      await saved;

      // Then extension/raw data is preserved and ready status begins only after durable success.
      expect(recovering.readState, SettingsReadState.unsupported);
      expect(recovering.saveState, SettingsSaveState.saving);
      expect(recovering.value(flag), isTrue);
      expect(recovering.hasExplicitValue(flag.id), isTrue);
      expect(recovering.value(invalidFlag), isFalse);
      expect(recovering.hasExplicitValue(invalidFlag.id), isFalse);
      expect(record.version, 1);
      expect(record.values, {
        _paneId: 'automatic',
        _hingeId: 'automatic',
        _textId: 1.0,
        flag.id: true,
        invalidFlag.id: invalid,
        localFlag.id: true,
        'unknown': null,
      });
      expect(record.extraFields, {
        'owner': ['kept'],
      });
      expect(controller.snapshot.readState, SettingsReadState.ready);
      expect(controller.snapshot.readError, isNull);
      expect(controller.snapshot.unsavedIds, isEmpty);
      expect(controller.snapshot.savedRevision, 2);
      expect(storage.readCount, 1);
      expect(storage.writeCount, 1);
      expect(
        SettingsRecord.decode(storage.durableRecord!).values,
        record.values,
      );
    });

    for (final timing in ['before', 'during']) {
      test(
        'C14 reset $timing future read authorizes preserving recovery',
        () async {
          // Given a new controller and delayed future data with an untouched extension.
          final storage = ControllableSettingsStorage();
          final flag = _flag();
          final controller = _controller(
            storage,
            registry: CommonSettings.registry(extensions: [flag]),
          );

          // When reset precedes or overlaps the read and that future envelope completes.
          if (timing == 'before') controller.resetCommon();
          final loaded = controller.load();
          if (timing == 'during') controller.resetCommon();
          final prematureWrites = storage.writeCount;
          storage.reads.single.succeed(
            _wire(
              {
                _paneId: 'preferDualPane',
                flag.id: true,
                'unknown': {'kept': null},
              },
              version: 9,
              extras: {
                'extra': [1],
              },
            ),
          );
          await loaded;
          final recovering = controller.snapshot;
          await _flushMicrotasks();
          final record = _submitted(storage, 0);
          final saved = controller.retrySave();
          storage.writes.single.succeed();
          await saved;

          // Then no premature write occurred and reset retains raw/typed extension data.
          expect(prematureWrites, 0);
          expect(recovering.readState, SettingsReadState.unsupported);
          expect(recovering.value(flag), isTrue);
          expect(recovering.unsavedIds, _commonIds);
          expect(record.version, 1);
          expect(record.values[_paneId], 'automatic');
          expect(record.values[_hingeId], 'automatic');
          expect(record.values[_textId], 1.0);
          expect(record.values[flag.id], isTrue);
          expect(record.values['unknown'], {'kept': null});
          expect(record.extraFields, {
            'extra': [1],
          });
          expect(controller.snapshot.readState, SettingsReadState.ready);
          expect(controller.snapshot.savedRevision, 1);
        },
      );
    }

    test(
      'C15 failed future recovery requires explicit retry of newest intent',
      () async {
        // Given a retained future baseline and an explicitly authorized common reset.
        final flag = _flag();
        final futureRecord = _wire({
          flag.id: true,
          'unknown': null,
        }, version: 6);
        final storage = ControllableSettingsStorage(
          durableRecord: futureRecord,
        );
        final controller = _controller(
          storage,
          registry: CommonSettings.registry(extensions: [flag]),
        );
        final loaded = controller.load();
        storage.readDurable(0);
        await loaded;
        controller.resetCommon();
        await _flushMicrotasks();
        final failure = StateError('recovery failed');

        // When recovery fails, ordinary edits/reset stay latched, then explicit retry succeeds.
        final firstPump = controller.retrySave();
        storage.writes[0].fail(failure);
        await firstPump;
        final failed = controller.snapshot;
        controller.setValue(flag.id, false);
        controller.resetCommon();
        await controller.retryLoad();
        await _flushMicrotasks();
        final writesBeforeRetry = storage.writeCount;
        final durableBeforeRetry = storage.durableRecord;
        final retried = controller.retrySave();
        await _flushMicrotasks();
        final newest = _submitted(storage, 1);
        storage.writes[1].succeed();
        await retried;

        // Then failure preserved unsupported/unsaved/error state and retry alone acknowledges recovery.
        expect(failed.readState, SettingsReadState.unsupported);
        expect(failed.readError, isA<StateError>());
        expect(failed.saveState, SettingsSaveState.failed);
        expect(failed.saveError, same(failure));
        expect(failed.unsavedIds, _commonIds);
        expect(failed.savedRevision, 0);
        expect(writesBeforeRetry, 1);
        expect(durableBeforeRetry, futureRecord);
        expect(newest.version, 1);
        expect(newest.values[flag.id], isFalse);
        expect(newest.values['unknown'], isNull);
        expect(controller.snapshot.readState, SettingsReadState.ready);
        expect(controller.snapshot.saveError, isNull);
        expect(controller.snapshot.readError, isNull);
        expect(controller.snapshot.unsavedIds, isEmpty);
        expect(controller.snapshot.savedRevision, 3);
        expect(storage.readCount, 1);
      },
    );

    for (final state in ['unread', 'failed']) {
      test(
        'C15 reset in $state storage cannot authorize an overwrite',
        () async {
          // Given storage that is either unread or has explicitly failed restoration.
          final storage = ControllableSettingsStorage();
          final controller = _controller(storage);
          final failure = StateError('unread storage');
          if (state == 'failed') {
            final loaded = controller.load();
            storage.reads.single.fail(failure);
            await loaded;
          }

          // When reset/edit/save retry occur while the read barrier is closed.
          controller.resetCommon();
          controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
          await controller.retrySave();
          await _flushMicrotasks();

          // Then explicit common intent remains unsaved without any write or hidden read error.
          expect(storage.readCount, state == 'failed' ? 1 : 0);
          expect(storage.writeCount, 0);
          expect(
            controller.snapshot.readState,
            state == 'failed'
                ? SettingsReadState.failed
                : SettingsReadState.notLoaded,
          );
          expect(
            controller.snapshot.readError,
            state == 'failed' ? same(failure) : isNull,
          );
          expect(controller.snapshot.unsavedIds, _commonIds);
          expect(
            controller.snapshot.value(CommonSettings.panePreference),
            SettingsPanePreference.preferDualPane,
          );
          expect(controller.snapshot.savedRevision, 0);
        },
      );
    }
  });

  group('Settings controller serialized writes and revision acknowledgement', () {
    test(
      'C16 same-value edits are distinct and invalid edits have no effects',
      () {
        // Given inherited defaults and an observer of every explicit local intent.
        final storage = ControllableSettingsStorage();
        final controller = _controller(storage);
        final observed = <SettingsSnapshot>[];
        controller.addListener(() => observed.add(controller.snapshot));
        final initial = controller.snapshot;

        // When the same default is explicitly selected twice and invalid edits are attempted.
        controller.setValue(_paneId, SettingsPanePreference.automatic);
        controller.setValue(_paneId, SettingsPanePreference.automatic);
        final afterValid = controller.snapshot;
        final errors = [
          _captureError(() => controller.setValue('missing', true)),
          _captureError(() => controller.setValue(_paneId, 'automatic')),
          _captureError(() => controller.setValue(_textId, 1)),
          _captureError(() => controller.setValue(_textId, 1.2)),
        ];

        // Then both valid intents publish, but invalid ID/type/catalog input changes nothing.
        expect(errors, everyElement(isA<ArgumentError>()));
        expect(initial.explicitValueIds, isEmpty);
        expect(initial.revision, 0);
        expect(observed.map((value) => value.revision), [1, 2]);
        expect(observed.map((value) => value.lastIntent!.revision), [1, 2]);
        expect(afterValid.lastIntent!.kind, SettingsIntentKind.edit);
        expect(afterValid.lastIntent!.settingId, _paneId);
        expect(afterValid.explicitValueIds, {_paneId});
        expect(afterValid.unsavedIds, {_paneId});
        expect(afterValid.savedRevision, 0);
        expect(controller.snapshot, same(afterValid));
        expect(storage.readCount, 0);
        expect(storage.writeCount, 0);
      },
    );

    test(
      'C17 synchronous edits coalesce newest values into one durable write',
      () async {
        // Given a ready controller and an acknowledged empty baseline.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);

        // When multiple synchronous edits precede the microtask capture and acknowledgement.
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
        controller.setValue(_textId, 1.15);
        final pending = controller.snapshot;
        final synchronousWriteCount = storage.writeCount;
        await _flushMicrotasks();
        final submitted = _submitted(storage, 0);
        final saved = controller.retrySave();
        final shared = controller.retrySave();
        storage.writes.single.succeed();
        await saved;

        // Then one newest record remains saving/unsaved until its exact revision is acknowledged.
        expect(synchronousWriteCount, 0);
        expect(pending.saveState, SettingsSaveState.saving);
        expect(pending.unsavedIds, {_paneId, _textId});
        expect(pending.savedRevision, 0);
        expect(submitted.values, {_paneId: 'preferDualPane', _textId: 1.15});
        expect(shared, same(saved));
        expect(storage.writeCount, 1);
        expect(storage.maxActiveWrites, 1);
        expect(controller.snapshot.saveState, SettingsSaveState.idle);
        expect(controller.snapshot.unsavedIds, isEmpty);
        expect(controller.snapshot.savedRevision, 3);
        expect(
          SettingsRecord.decode(storage.durableRecord!).values,
          submitted.values,
        );
      },
    );

    test(
      'C18 active writes serialize a single newest subsequent capture',
      () async {
        // Given a first captured pane edit whose storage acknowledgement is delayed.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        await _flushMicrotasks();
        final pump = controller.retrySave();

        // When several edits occur during that write and both writes then acknowledge.
        controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
        controller.setValue(_textId, 1.15);
        controller.setValue(_textId, 1.30);
        await _flushMicrotasks();
        final writesWhileActive = storage.writeCount;
        final newestSession = controller.snapshot;
        storage.writes[0].succeed();
        await _flushMicrotasks();
        final subsequent = _submitted(storage, 1);
        final afterFirst = controller.snapshot;
        storage.writes[1].succeed();
        await pump;

        // Then no overlapping write occurs and only one subsequent capture holds all latest edits.
        expect(writesWhileActive, 1);
        expect(
          newestSession.values[_paneId],
          SettingsPanePreference.preferDualPane,
        );
        expect(newestSession.values[_textId], 1.30);
        expect(_submitted(storage, 0).values[_paneId], 'preferSinglePane');
        expect(afterFirst.savedRevision, 1);
        expect(afterFirst.unsavedIds, {_paneId, _textId});
        expect(subsequent.values, {_paneId: 'preferDualPane', _textId: 1.30});
        expect(storage.writeCount, 2);
        expect(storage.maxActiveWrites, 1);
        expect(storage.activeWrites, 0);
        expect(controller.snapshot.savedRevision, 4);
        expect(
          SettingsRecord.decode(storage.durableRecord!).values,
          subsequent.values,
        );
      },
    );

    test(
      'C19 old acknowledgement clears captured IDs without equality shortcuts',
      () async {
        // Given a captured A pane choice and hinge intent awaiting acknowledgement.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        controller.setValue(_hingeId, SettingsHingePreference.avoid);
        await _flushMicrotasks();
        final pump = controller.retrySave();

        // When pane cycles A to B to A and a different ID changes before old success.
        controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        controller.setValue(_textId, 1.15);
        storage.writes[0].succeed();
        await _flushMicrotasks();
        final acknowledged = controller.snapshot;
        final subsequent = _submitted(storage, 1);
        storage.writes[1].succeed();
        await pump;

        // Then the unchanged captured hinge clears independently but newer equal pane intent stays dirty.
        expect(acknowledged.savedRevision, 2);
        expect(acknowledged.revision, 5);
        expect(acknowledged.unsavedIds, {_paneId, _textId});
        expect(acknowledged.unsavedIds.contains(_hingeId), isFalse);
        expect(acknowledged.saveState, SettingsSaveState.saving);
        expect(subsequent.values, {
          _paneId: 'preferSinglePane',
          _hingeId: 'avoid',
          _textId: 1.15,
        });
        expect(controller.snapshot.savedRevision, 5);
        expect(controller.snapshot.unsavedIds, isEmpty);
      },
    );

    test(
      'C20 pump drains only after newest same-value intent is acknowledged',
      () async {
        // Given one submitted explicit automatic choice.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);
        controller.setValue(_paneId, SettingsPanePreference.automatic);
        await _flushMicrotasks();
        final pump = controller.retrySave();

        // When automatic is explicitly selected again before both serialized successes.
        controller.setValue(_paneId, SettingsPanePreference.automatic);
        storage.writes[0].succeed();
        final durableBeforeControllerAcknowledges = storage.durableRecord;
        await _flushMicrotasks();
        final olderAcknowledgement = controller.snapshot;
        storage.writes[1].succeed();
        await pump;

        // Then durable replacement precedes acknowledgement and idle means every newest ID drained.
        expect(durableBeforeControllerAcknowledges, storage.writes[0].record);
        expect(olderAcknowledgement.savedRevision, 1);
        expect(olderAcknowledgement.revision, 2);
        expect(olderAcknowledgement.unsavedIds, {_paneId});
        expect(controller.snapshot.saveState, SettingsSaveState.idle);
        expect(controller.snapshot.savedRevision, 2);
        expect(controller.snapshot.revision, 2);
        expect(controller.snapshot.unsavedIds, isEmpty);
        expect(controller.snapshot.explicitValueIds, {_paneId});
        expect(storage.writeCount, 2);
        expect(storage.activeWrites, 0);
        expect(storage.durableRecord, storage.writes[1].record);
      },
    );

    test('C21 failed write preserves acknowledgement and retries only newest intent', () async {
      // Given a first successful write establishing saved revision one.
      final storage = ControllableSettingsStorage();
      final controller = await _ready(storage);
      controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
      await _flushMicrotasks();
      final first = controller.retrySave();
      storage.writes[0].succeed();
      await first;
      final acknowledgedRecord = storage.durableRecord;
      final failure = StateError('write failed');

      // When a later write fails, another edit remains latched, then explicit retry succeeds.
      controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
      await _flushMicrotasks();
      final failing = controller.retrySave();
      storage.writes[1].fail(failure);
      await failing;
      final failed = controller.snapshot;
      controller.setValue(_textId, 1.30);
      await _flushMicrotasks();
      final stillFailed = controller.snapshot;
      final countBeforeRetry = storage.writeCount;
      final durableBeforeRetry = storage.durableRecord;
      final retried = controller.retrySave();
      await _flushMicrotasks();
      final newest = _submitted(storage, 2);
      storage.writes[2].succeed();
      await retried;

      // Then session values/errors/dirty revisions remain truthful and only explicit retry saves latest.
      expect(failed.saveState, SettingsSaveState.failed);
      expect(failed.saveError, same(failure));
      expect(failed.values[_paneId], SettingsPanePreference.preferDualPane);
      expect(failed.unsavedIds, {_paneId});
      expect(failed.savedRevision, 1);
      expect(stillFailed.saveError, same(failure));
      expect(stillFailed.saveState, SettingsSaveState.failed);
      expect(stillFailed.unsavedIds, {_paneId, _textId});
      expect(countBeforeRetry, 2);
      expect(durableBeforeRetry, acknowledgedRecord);
      expect(newest.values, {_paneId: 'preferDualPane', _textId: 1.30});
      expect(controller.snapshot.saveError, isNull);
      expect(controller.snapshot.savedRevision, 3);
      expect(controller.snapshot.unsavedIds, isEmpty);
      expect(controller.snapshot.saveState, SettingsSaveState.idle);
    });

    test(
      'C22 retry Future includes edits added while its serialized pump runs',
      () async {
        // Given a failed pane write with the pump stopped.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        await _flushMicrotasks();
        final failing = controller.retrySave();
        storage.writes[0].fail(StateError('initial failure'));
        await failing;
        var settled = false;

        // When explicit retry receives edits before capture and while the retry write is active.
        final retried = controller.retrySave();
        unawaited(
          retried.then((_) {
            settled = true;
          }),
        );
        final shared = controller.retrySave();
        controller.setValue(_textId, 1.15);
        await _flushMicrotasks();
        final firstRetry = _submitted(storage, 1);
        controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
        controller.setValue(_textId, 1.30);
        storage.writes[1].succeed();
        await _flushMicrotasks();
        final settledAfterOlderWrite = settled;
        final lastRetry = _submitted(storage, 2);
        storage.writes[2].succeed();
        await retried;
        await _flushMicrotasks();

        // Then callers share the pump until all newest edits drain, with no concurrent adapter writes.
        expect(shared, same(retried));
        expect(firstRetry.values, {_paneId: 'preferSinglePane', _textId: 1.15});
        expect(settledAfterOlderWrite, isFalse);
        expect(lastRetry.values, {_paneId: 'preferDualPane', _textId: 1.30});
        expect(settled, isTrue);
        expect(storage.maxActiveWrites, 1);
        expect(controller.snapshot.savedRevision, 4);
        expect(controller.snapshot.unsavedIds, isEmpty);
      },
    );

    test(
      'C23 synchronous and delayed adapter errors complete nonfatally',
      () async {
        // Given one-shot synchronous read/write failures and delayed failure requests.
        final storage = ControllableSettingsStorage();
        final readError = StateError('synchronous read');
        final writeError = StateError('synchronous write');
        storage.nextReadError = readError;
        final controller = _controller(storage);

        // When synchronous failures and subsequent asynchronous write/read failures are completed.
        await controller.load();
        final failedRead = controller.snapshot;
        controller.resetCommon();
        storage.nextWriteError = writeError;
        final reloaded = controller.retryLoad();
        storage.reads.single.succeed(null);
        await reloaded;
        await _flushMicrotasks();
        final failedWrite = controller.snapshot;
        final retried = controller.retrySave();
        await _flushMicrotasks();
        final delayedWriteError = StateError('delayed write');
        storage.writes.single.fail(delayedWriteError);
        await retried;
        final lateStorage = ControllableSettingsStorage();
        final lateController = _controller(lateStorage);
        final delayedRead = lateController.load();
        final delayedReadError = StateError('delayed read');
        lateStorage.reads.single.fail(delayedReadError);
        await delayedRead;

        // Then every returned Future completes normally and each snapshot retains its error/intent.
        expect(failedRead.readState, SettingsReadState.failed);
        expect(failedRead.readError, same(readError));
        expect(failedWrite.readState, SettingsReadState.ready);
        expect(failedWrite.saveState, SettingsSaveState.failed);
        expect(failedWrite.saveError, same(writeError));
        expect(failedWrite.unsavedIds, _commonIds);
        expect(controller.snapshot.saveError, same(delayedWriteError));
        expect(controller.snapshot.saveState, SettingsSaveState.failed);
        expect(controller.snapshot.savedRevision, 0);
        expect(lateController.snapshot.readState, SettingsReadState.failed);
        expect(lateController.snapshot.readError, same(delayedReadError));
        expect(storage.writeCount, 2);
        expect(storage.durableRecord, isNull);
      },
    );

    test('C24 ready reset preserves extension presence unknown data and pending edits', () async {
      // Given ready nondefault common values, an explicit extension and unknown data.
      final storage = ControllableSettingsStorage();
      final flag = _flag();
      final controller = await _ready(
        storage,
        registry: CommonSettings.registry(extensions: [flag]),
        values: {
          _paneId: 'preferDualPane',
          _hingeId: 'span',
          _textId: 1.30,
          flag.id: true,
          'unknown': [null, 3],
        },
        extras: {'owner': 'application'},
      );

      // When a pending extension edit and two same-value common resets coalesce and save.
      controller.setValue(flag.id, false);
      controller.resetCommon();
      final firstReset = controller.snapshot;
      controller.resetCommon();
      final repeatedReset = controller.snapshot;
      await _flushMicrotasks();
      final record = _submitted(storage, 0);
      final saved = controller.retrySave();
      storage.writes.single.succeed();
      await saved;

      // Then resets are distinct intents and extension/raw data survives their common-only overlay.
      expect(firstReset.revision, 2);
      expect(repeatedReset.revision, 3);
      expect(repeatedReset.lastIntent!.kind, SettingsIntentKind.resetCommon);
      expect(repeatedReset.value(flag), isFalse);
      expect(repeatedReset.hasExplicitValue(flag.id), isTrue);
      expect(repeatedReset.unsavedIds, {..._commonIds, flag.id});
      expect(repeatedReset.savedRevision, 0);
      expect(record.values, {
        _paneId: 'automatic',
        _hingeId: 'automatic',
        _textId: 1.0,
        flag.id: false,
        'unknown': [null, 3],
      });
      expect(record.extraFields, {'owner': 'application'});
      expect(controller.snapshot.savedRevision, 3);
      expect(controller.snapshot.unsavedIds, isEmpty);
    });
  });

  group('Settings controller acknowledged restart behavior', () {
    test(
      'C25 restart restores acknowledged choices and explicit defaults',
      () async {
        // Given an empty baseline and a controller about to acknowledge explicit preferences.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);

        // When explicit automatic/text edits save and a fresh controller loads durable storage.
        controller.setValue(_paneId, SettingsPanePreference.automatic);
        controller.setValue(_textId, 1.30);
        await _flushMicrotasks();
        final saved = controller.retrySave();
        storage.writes.single.succeed();
        await saved;
        controller.dispose();
        final restarted = _controller(storage);
        final loaded = restarted.load();
        storage.readDurable(1);
        await loaded;

        // Then restart has acknowledged values/presence without inheriting old session revisions.
        expect(
          restarted.snapshot.value(CommonSettings.panePreference),
          SettingsPanePreference.automatic,
        );
        expect(
          restarted.snapshot.value(CommonSettings.textSizeMultiplier),
          1.30,
        );
        expect(restarted.snapshot.explicitValueIds, {_paneId, _textId});
        expect(restarted.snapshot.hasExplicitValue(_hingeId), isFalse);
        expect(restarted.snapshot.unsavedIds, isEmpty);
        expect(restarted.snapshot.revision, 0);
        expect(restarted.snapshot.savedRevision, 0);
        expect(restarted.snapshot.readState, SettingsReadState.ready);
        expect(storage.writeCount, 1);
      },
    );

    test('C26 restart after failed save restores old durable image', () async {
      // Given durable single-pane data and a restored first controller.
      final durable = _wire({_paneId: 'preferSinglePane'});
      final storage = ControllableSettingsStorage(durableRecord: durable);
      final controller = _controller(storage);
      final loaded = controller.load();
      storage.readDurable(0);
      await loaded;

      // When a dual-pane save fails and a fresh controller reads the untouched durable image.
      controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
      await _flushMicrotasks();
      final failedSave = controller.retrySave();
      storage.writes.single.fail(StateError('not durable'));
      await failedSave;
      final failedSession = controller.snapshot;
      controller.dispose();
      final restarted = _controller(storage);
      final reloaded = restarted.load();
      storage.readDurable(1);
      await reloaded;

      // Then failed in-session values never become durable restart state.
      expect(
        failedSession.values[_paneId],
        SettingsPanePreference.preferDualPane,
      );
      expect(failedSession.unsavedIds, {_paneId});
      expect(failedSession.saveState, SettingsSaveState.failed);
      expect(storage.durableRecord, durable);
      expect(
        restarted.snapshot.value(CommonSettings.panePreference),
        SettingsPanePreference.preferSinglePane,
      );
      expect(restarted.snapshot.explicitValueIds, {_paneId});
      expect(restarted.snapshot.unsavedIds, isEmpty);
      expect(restarted.snapshot.saveError, isNull);
      expect(restarted.snapshot.saveState, SettingsSaveState.idle);
      expect(storage.writeCount, 1);
    });
  });

  group(
    'Settings controller immediate disposal and reentrant notification',
    () {
      for (final outcome in ['success', 'failure']) {
        test(
          'C27 dispose at pending read $outcome suppresses continuation',
          () async {
            // Given a pending read with local unsaved intent and an active observer.
            final storage = ControllableSettingsStorage();
            final controller = _controller(storage);
            var notifications = 0;
            void listener() => notifications++;
            controller.addListener(listener);
            controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
            final loaded = controller.load();
            final last = controller.snapshot;
            final notificationsBeforeDispose = notifications;

            // When the adapter settles but disposal occurs before its async continuation.
            if (outcome == 'success') {
              storage.reads.single.succeed(_wire({_hingeId: 'span'}));
            } else {
              storage.reads.single.fail(StateError('late read failure'));
            }
            controller.dispose();
            controller.dispose();
            controller.removeListener(listener);
            await loaded;
            await _flushMicrotasks();
            final errors = <Object?>[
              _captureError(() => controller.setValue(_textId, 1.15)),
              _captureError(controller.resetCommon),
              _captureError(() => controller.load()),
              _captureError(() => controller.retryLoad()),
              _captureError(() => controller.retrySave()),
              _captureError(() => controller.addListener(listener)),
            ];

            // Then diagnostic state is unchanged, errors are caught and all new public work rejects.
            expect(controller.snapshot, same(last));
            expect(controller.registry, same(last.registry));
            expect(notifications, notificationsBeforeDispose);
            expect(errors, everyElement(isA<StateError>()));
            expect(storage.writeCount, 0);
            expect(storage.readCount, 1);
            expect(storage.activeReads, 0);
          },
        );
      }

      test(
        'C27 disposal from loading listener prevents the read from starting',
        () async {
          // Given a controller disposed by its first loading notification.
          final storage = ControllableSettingsStorage();
          final controller = _controller(storage);
          var laterNotifications = 0;
          controller.addListener(controller.dispose);
          controller.addListener(() => laterNotifications++);

          // When explicit load publishes loading and dispatch unwinds after logical disposal.
          await controller.load();
          await _flushMicrotasks();

          // Then no adapter read or subsequent listener is invoked and loading remains diagnostic.
          expect(storage.readCount, 0);
          expect(storage.writeCount, 0);
          expect(laterNotifications, 0);
          expect(controller.snapshot.readState, SettingsReadState.loading);
          expect(() => controller.addListener(() {}), throwsStateError);
        },
      );

      test(
        'C28 disposal before scheduled write prevents adapter I/O',
        () async {
          // Given a ready controller with a microtask-scheduled first write.
          final storage = ControllableSettingsStorage();
          final controller = await _ready(storage);
          var notifications = 0;
          controller.addListener(() => notifications++);
          controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
          final pending = controller.retrySave();
          final last = controller.snapshot;
          final before = notifications;

          // When disposal precedes that microtask and callers await its normal settlement.
          controller.dispose();
          await pending;
          await _flushMicrotasks();

          // Then scheduled I/O is suppressed without any post-disposal state or notifications.
          expect(storage.writeCount, 0);
          expect(controller.snapshot, same(last));
          expect(notifications, before);
          expect(last.unsavedIds, {_paneId});
          expect(last.saveState, SettingsSaveState.saving);
        },
      );

      for (final outcome in ['success', 'failure']) {
        test(
          'C28 disposal during active write $outcome prevents follow-up I/O',
          () async {
            // Given an active delayed write, a newer dirty edit and a shared pump Future.
            final storage = ControllableSettingsStorage();
            final controller = await _ready(storage);
            var notifications = 0;
            controller.addListener(() => notifications++);
            controller.setValue(
              _paneId,
              SettingsPanePreference.preferSinglePane,
            );
            await _flushMicrotasks();
            controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
            final pending = controller.retrySave();
            var settled = false;
            unawaited(
              pending.then((_) {
                settled = true;
              }),
            );
            final last = controller.snapshot;
            final before = notifications;

            // When disposal is immediate but the active adapter later succeeds or fails.
            controller.dispose();
            await _flushMicrotasks();
            final settledBeforeAdapter = settled;
            if (outcome == 'success') {
              storage.writes.single.succeed();
            } else {
              storage.writes.single.fail(StateError('late write failure'));
            }
            await pending;
            await _flushMicrotasks();

            // Then callers wait for active I/O, but its result cannot mutate/notify or start another write.
            expect(settledBeforeAdapter, isFalse);
            expect(settled, isTrue);
            expect(storage.writeCount, 1);
            expect(storage.activeWrites, 0);
            expect(storage.maxActiveWrites, 1);
            expect(controller.snapshot, same(last));
            expect(notifications, before);
            expect(last.savedRevision, 0);
            expect(last.values[_paneId], SettingsPanePreference.preferDualPane);
            expect(
              storage.durableRecord,
              outcome == 'success' ? storage.writes.single.record : isNull,
            );
          },
        );
      }

      test('C29 saving/ack listeners edit reset and retry through one serialized pump', () async {
        // Given a ready controller with listeners that issue reentrant intents exactly once.
        final storage = ControllableSettingsStorage();
        final controller = await _ready(storage);
        var editedDuringSaving = false;
        var editedDuringAcknowledgement = false;
        Future<void>? savingRetry;
        Future<void>? acknowledgementRetry;
        controller.addListener(() {
          final snapshot = controller.snapshot;
          if (!editedDuringSaving &&
              snapshot.saveState == SettingsSaveState.saving) {
            editedDuringSaving = true;
            controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
            controller.resetCommon();
            controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
            savingRetry = controller.retrySave();
          } else if (!editedDuringAcknowledgement &&
              snapshot.savedRevision == 4) {
            editedDuringAcknowledgement = true;
            controller.setValue(_textId, 1.30);
            acknowledgementRetry = controller.retrySave();
          }
        });

        // When an initial edit triggers nested intents and two durable acknowledgements.
        controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
        final pump = controller.retrySave();
        await _flushMicrotasks();
        final first = _submitted(storage, 0);
        storage.writes[0].succeed();
        await _flushMicrotasks();
        final between = controller.snapshot;
        final second = _submitted(storage, 1);
        storage.writes[1].succeed();
        await pump;

        // Then reentrant resets/retries share established promises and latest edits remain serialized.
        expect(editedDuringSaving, isTrue);
        expect(editedDuringAcknowledgement, isTrue);
        expect(savingRetry, same(pump));
        expect(acknowledgementRetry, same(pump));
        expect(first.values, {
          _paneId: 'preferDualPane',
          _hingeId: 'automatic',
          _textId: 1.0,
        });
        expect(between.revision, 5);
        expect(between.savedRevision, 4);
        expect(between.unsavedIds, {_textId});
        expect(second.values[_textId], 1.30);
        expect(controller.snapshot.savedRevision, 5);
        expect(controller.snapshot.unsavedIds, isEmpty);
        expect(storage.writeCount, 2);
        expect(storage.maxActiveWrites, 1);
      });

      test(
        'C29 disposal in acknowledgement listener suppresses queued follow-up',
        () async {
          // Given an active write, newer queued intent and disposal on old acknowledgement.
          final storage = ControllableSettingsStorage();
          final controller = await _ready(storage);
          controller.setValue(_paneId, SettingsPanePreference.preferSinglePane);
          await _flushMicrotasks();
          controller.setValue(_paneId, SettingsPanePreference.preferDualPane);
          var laterNotifications = 0;
          controller.addListener(() {
            if (controller.snapshot.savedRevision == 1) controller.dispose();
          });
          controller.addListener(() => laterNotifications++);
          final pump = controller.retrySave();

          // When the old write acknowledges while notification dispatch is still active.
          storage.writes.single.succeed();
          await pump;
          await _flushMicrotasks();

          // Then logical disposal suppresses remaining listeners and follow-up without notifier assertions.
          expect(storage.writeCount, 1);
          expect(storage.activeWrites, 0);
          expect(laterNotifications, 0);
          expect(controller.snapshot.savedRevision, 1);
          expect(controller.snapshot.revision, 2);
          expect(controller.snapshot.unsavedIds, {_paneId});
          expect(
            controller.snapshot.values[_paneId],
            SettingsPanePreference.preferDualPane,
          );
          expect(() => controller.retrySave(), throwsStateError);
          controller.dispose();
        },
      );
    },
  );

  group('Concrete settings controller consumers and ownership', () {
    for (final ownership in ['owned', 'borrowed']) {
      test(
        'C30 $ownership SettingsView observes and forwards persistence lifecycle',
        () async {
          // Given a real controller and a view using the selected ownership mode.
          final storage = ControllableSettingsStorage();
          final controller = _controller(storage);
          final view = ownership == 'owned'
              ? SettingsView.owned(service: controller)
              : SettingsView.fromService(service: controller);
          addTearDown(view.dispose);
          final observed = <SettingsSnapshot>[];
          view.addListener(() => observed.add(view.snapshot));
          final readError = StateError('view read');
          final saveError = StateError('view write');

          // When the view forwards edit/load/read retry/reset/save retry and then detaches.
          view.setValue(_textId, 1.15);
          final loaded = view.load();
          final loading = view.snapshot;
          storage.reads[0].fail(readError);
          await loaded;
          final failedRead = view.snapshot;
          view.resetCommon();
          final retriedRead = view.retryLoad();
          storage.reads[1].succeed(null);
          await retriedRead;
          await _flushMicrotasks();
          final saving = view.snapshot;
          final firstPump = view.retrySave();
          storage.writes[0].fail(saveError);
          await firstPump;
          final failedSave = view.snapshot;
          view.setValue(_paneId, SettingsPanePreference.preferDualPane);
          final retriedSave = view.retrySave();
          await _flushMicrotasks();
          storage.writes[1].succeed();
          await retriedSave;
          final finalSnapshot = view.snapshot;
          final exposedSnapshot = controller.snapshot;
          final countBeforeDetach = observed.length;
          view.dispose();
          view.dispose();
          final serviceEditError = _captureError(
            () => controller.setValue(_textId, 1.30),
          );

          // Then the view exposes exact controller states/intents and honors selected service ownership.
          expect(loading.readState, SettingsReadState.loading);
          expect(loading.unsavedIds, {_textId});
          expect(failedRead.readError, same(readError));
          expect(saving.lastIntent!.kind, SettingsIntentKind.resetCommon);
          expect(saving.unsavedIds, _commonIds);
          expect(failedSave.saveState, SettingsSaveState.failed);
          expect(failedSave.saveError, same(saveError));
          expect(finalSnapshot, same(exposedSnapshot));
          expect(finalSnapshot.revision, 3);
          expect(finalSnapshot.savedRevision, 3);
          expect(finalSnapshot.unsavedIds, isEmpty);
          expect(
            finalSnapshot.values[_paneId],
            SettingsPanePreference.preferDualPane,
          );
          expect(
            serviceEditError,
            ownership == 'owned' ? isA<StateError>() : isNull,
          );
          expect(observed.length, countBeforeDetach);
          expect(() => view.resetCommon(), throwsStateError);
          expect(storage.readCount, 2);
          expect(storage.writeCount, 2);
        },
      );
    }

    test('C30 ApplicationViewModel keeps resource identity and notification ownership', () async {
      // Given concrete borrowed Settings and loaded resource views in one owned view space.
      final storage = ControllableSettingsStorage();
      final controller = _controller(storage);
      final settings = SettingsView.fromService(service: controller);
      final resources = _Resources();
      final collection = ResourceCollectionView(dataSource: resources);
      final detail = ResourceDetailView(
        dataSource: resources,
        actionHandler: resources,
      );
      final other = _OtherView();
      final model = ApplicationViewModel({
        'settings': settings,
        'resources': collection,
        'detail': detail,
        'other': other,
      });
      addTearDown(model.dispose);
      await collection.load();
      await detail.select('one');
      final selected = detail.resource;
      final list = collection.resources;
      var notifications = 0;
      model.addListener(() => notifications++);

      // When settings loads, edits, resets and acknowledges, while another view also notifies.
      final loaded = settings.load();
      storage.reads.single.succeed(null);
      await loaded;
      settings.setValue(_paneId, SettingsPanePreference.preferDualPane);
      settings.resetCommon();
      await _flushMicrotasks();
      final saved = settings.retrySave();
      storage.writes.single.succeed();
      await saved;
      final beforeOther = notifications;
      other.publish();
      final afterOther = notifications;

      // Then Settings never replaces selected resource/view identity or invokes domain operations.
      expect(model.view<SettingsView>('settings'), same(settings));
      expect(model.view<ResourceCollectionView>('resources'), same(collection));
      expect(model.view<ResourceDetailView>('detail'), same(detail));
      expect(model.view<_OtherView>('other'), same(other));
      expect(collection.resources, same(list));
      expect(detail.resource, same(selected));
      expect(detail.selectedId, 'one');
      expect(resources.listCalls, 1);
      expect(resources.readCalls, 1);
      expect(resources.commandCalls, 0);
      expect(afterOther, beforeOther + 1);
      expect(other.disposeCalls, 0);

      // Given the unchanged model still owns its views and borrows the controller through Settings.
      final beforeModelDispose = notifications;

      // When model disposal detaches views and the externally owned controller edits again.
      model.dispose();
      controller.setValue(_textId, 1.15);

      // Then the other view disposes once and detached Settings cannot notify the disposed model.
      expect(other.disposeCalls, 1);
      expect(notifications, beforeModelDispose);
      expect(controller.snapshot.values[_textId], 1.15);
      expect(controller.snapshot.unsavedIds, {_textId});
    });
  });
}
