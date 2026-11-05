import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/controllable_settings_storage.dart';

class _ObservedView extends SettingsView {
  _ObservedView(SettingsController controller)
    : super.fromService(service: controller);

  int attached = 0;
  int detached = 0;
  int disposeCalls = 0;
  int loadCalls = 0;
  int retryLoadCalls = 0;
  int retrySaveCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    attached++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    detached++;
    super.removeListener(listener);
  }

  @override
  Future<void> load() {
    loadCalls++;
    return super.load();
  }

  @override
  Future<void> retryLoad() {
    retryLoadCalls++;
    return super.retryLoad();
  }

  @override
  Future<void> retrySave() {
    retrySaveCalls++;
    return super.retrySave();
  }

  @override
  void dispose() {
    if (disposeCalls != 0) return;
    disposeCalls++;
    super.dispose();
  }
}

class _Session {
  _Session({SettingsRegistry? registry}) {
    controller = SettingsController(registry: registry, storage: storage);
    view = _ObservedView(controller);
  }

  final storage = ControllableSettingsStorage();
  late final SettingsController controller;
  late final _ObservedView view;

  void dispose() {
    view.dispose();
    controller.dispose();
  }
}

SettingDefinition<bool> _flag({
  String id = 'example.flag',
  String group = 'application',
  String label = 'Example flag',
  SettingAvailabilityPolicy policy = SettingAvailabilityPolicy.always,
  bool single = false,
}) => SettingDefinition<bool>(
  id: id,
  groupId: group,
  label: label,
  defaultValue: false,
  requiredCapability: 'example',
  availabilityPolicy: policy,
  choices: [
    if (!single)
      SettingChoice(value: true, label: 'On', storedValue: 'yes-wire'),
    SettingChoice(value: false, label: 'Off', storedValue: 'no-wire'),
  ],
);

SettingDefinition<String> _choice({
  String id = 'example.choice',
  String group = 'application',
  String label = 'Example choice',
  String secondLabel = 'Second',
  SettingAvailabilityPolicy policy = SettingAvailabilityPolicy.always,
}) => SettingDefinition<String>(
  id: id,
  groupId: group,
  label: label,
  defaultValue: 'first',
  requiredCapability: 'example',
  availabilityPolicy: policy,
  choices: [
    SettingChoice(value: 'first', label: 'First', storedValue: 'one-wire'),
    SettingChoice(value: 'second', label: secondLabel, storedValue: 'two-wire'),
  ],
);

String _wire(Map<String, Object?> values, {int version = 1}) => jsonEncode({
  'version': version,
  'values': {
    ...values,
    'unknown.setting': {
      'nested': [1, null],
    },
  },
  'unknown.envelope': ['keep', true],
});

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _row(SettingDefinition<Object> definition) =>
    _key('settings-control:${definition.id}');

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

_Session _session(WidgetTester tester, {SettingsRegistry? registry}) {
  final session = _Session(registry: registry);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    // Every indexed pending adapter request settles after observation detaches.
    for (var i = 0; i < session.storage.reads.length; i++) {
      if (!session.storage.reads[i].isCompleted) {
        session.storage.reads[i].succeed(null);
      }
    }
    for (var i = 0; i < session.storage.writes.length; i++) {
      if (!session.storage.writes[i].isCompleted) {
        session.storage.writes[i].succeed();
      }
    }
    await _flush(tester);
  });
  return session;
}

Future<void> _mount(
  WidgetTester tester,
  SettingsView view,
  SettingsPresentation style, {
  SettingsCapabilities? capabilities,
  TargetPlatform platform = TargetPlatform.android,
  TextScaler? textScaler,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(platform: platform),
    home: Builder(
      builder: (context) {
        final shell = SettingsShell(
          key: const ValueKey('borrowed-shell'),
          view: view,
          capabilities: capabilities,
          presentation: style,
        );
        return textScaler == null
            ? shell
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: shell,
              );
      },
    ),
  ),
);

Future<void> _load(
  WidgetTester tester,
  _Session session, {
  String? record,
}) async {
  final loaded = session.view.load();
  session.storage.reads.last.succeed(record);
  await loaded;
  await _flush(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _flush(tester);
}

Future<void> _openChoice(
  WidgetTester tester,
  SettingDefinition<Object> definition,
) async {
  await _tap(tester, _row(definition));
  await tester.pumpAndSettle(); // Only the bounded native modal animation.
}

Future<void> _select(
  WidgetTester tester,
  SettingDefinition<Object> definition,
  int index,
) async {
  await _openChoice(tester, definition);
  await _tap(tester, _key('settings-choice:${definition.id}:$index'));
  await tester.pumpAndSettle(); // Bounded modal dismissal, no status spinner.
}

Future<void> _reset(WidgetTester tester, {bool confirm = true}) async {
  await _tap(tester, _key('settings-reset'));
  await tester.pumpAndSettle();
  await _tap(
    tester,
    _key(confirm ? 'settings-reset-confirm' : 'settings-reset-cancel'),
  );
  await tester.pumpAndSettle();
}

Future<void> _ack(WidgetTester tester, _Session session, int index) async {
  session.storage.writes[index].succeed();
  await _flush(tester);
}

void _label(SettingDefinition<Object> definition, String label) {
  expect(
    find.descendant(of: _row(definition), matching: find.text(label)),
    findsOneWidget,
  );
}

void _retained(SettingsRecord record) {
  expect(record.values['unknown.setting'], {
    'nested': [1, null],
  });
  expect(record.extraFields['unknown.envelope'], ['keep', true]);
}

void main() {
  for (final style in [
    SettingsPresentation.material,
    SettingsPresentation.cupertino,
  ]) {
    group('${style.name} borrowed Settings screen', () {
      testWidgets('W01 defaults and rebuild have no implicit lifetime or I/O', (
        tester,
      ) async {
        // Given a real unloaded controller and caller-owned View.
        final session = _session(tester);

        // When the shell mounts and rebuilds with a different platform/input.
        await _mount(tester, session.view, style);
        _label(CommonSettings.panePreference, '自動');
        _label(CommonSettings.textSizeMultiplier, '標準');
        expect(find.text('設定をまだ読み込んでいません'), findsOneWidget);
        expect(find.text('設定を保存しました'), findsNothing);
        expect(find.textContaining('この環境では利用できません'), findsOneWidget);
        await _mount(
          tester,
          session.view,
          style,
          platform: TargetPlatform.iOS,
          capabilities: SettingsCapabilities(),
        );

        // Then inherited defaults, one observation and no I/O/intent persist.
        expect(session.storage.readCount, 0);
        expect(session.storage.writeCount, 0);
        expect(session.view.snapshot.revision, 0);
        expect(session.view.snapshot.explicitValueIds, isEmpty);
        expect(session.view.snapshot.lastIntent, isNull);
        expect(session.view.attached, 1);
        expect(session.view.disposeCalls, 0);
        expect(_key('settings-load'), findsOneWidget);
        expect(_key('settings-reset'), findsOneWidget);
      });

      testWidgets(
        'W02 registered group and definition order admits extensions',
        (tester) async {
          // Given custom groups in a different order from their definitions.
          final a2 = _choice(id: 'a.two', group: 'a', label: 'A second');
          final b1 = _choice(id: 'b.one', group: 'b', label: 'B first');
          final a1 = _choice(id: 'a.one', group: 'a', label: 'A first');
          final session = _session(
            tester,
            registry: CommonSettings.registry(
              extensionGroups: [
                SettingGroup(id: 'empty', label: 'Empty'),
                SettingGroup(id: 'b', label: 'Custom B'),
                SettingGroup(id: 'a', label: 'Custom A'),
              ],
              extensions: [a2, b1, a1],
            ),
          );

          // When schema iteration renders the custom registry unchanged.
          await _mount(tester, session.view, style);

          // Then only nonempty groups appear in registry order, with schema labels.
          final groups = ['appearance', 'layout', 'b', 'a'];
          final positions = [
            for (final id in groups)
              tester.getTopLeft(_key('settings-group:$id')).dy,
          ];
          expect(positions, orderedEquals([...positions]..sort()));
          expect(_key('settings-group:empty'), findsNothing);
          expect(_key('settings-group:accessibility'), findsNothing);
          expect(_key('settings-group:application'), findsNothing);
          expect(find.text('Custom B'), findsOneWidget);
          expect(
            tester.getTopLeft(_row(a2)).dy,
            lessThan(tester.getTopLeft(_row(a1)).dy),
          );
          expect(
            tester.getTopLeft(_row(CommonSettings.panePreference)).dy,
            lessThan(
              tester.getTopLeft(_row(CommonSettings.hingePreference)).dy,
            ),
          );
          expect(session.storage.readCount, 0);
        },
      );

      testWidgets(
        'W03 every common choice forwards typed ID and same-value intent',
        (tester) async {
          // Given restored absent storage with all common capabilities available.
          final session = _session(tester);
          await _mount(
            tester,
            session.view,
            style,
            capabilities: SettingsCapabilities(supported: {'hinge'}),
          );
          await _load(tester, session);
          var revision = 0;
          var write = 0;

          for (final definition in CommonSettings.definitions) {
            for (var index = 0; index < definition.choices.length; index++) {
              // When each catalog action is selected, including inherited/current.
              final choice = definition.choices[index];
              await _openChoice(tester, definition);
              final current = definition.choices.firstWhere(
                (item) => item.value == session.view.value(definition),
              );
              expect(find.text('✓ ${current.label}'), findsOneWidget);
              await _tap(
                tester,
                _key('settings-choice:${definition.id}:$index'),
              );
              await tester.pumpAndSettle();

              // Then typed identity, immediate label and one dirty intent precede ack.
              expect(session.view.value(definition), choice.value);
              expect(session.view.snapshot.revision, ++revision);
              expect(
                session.view.snapshot.lastIntent!.settingId,
                definition.id,
              );
              expect(session.view.snapshot.unsavedIds, contains(definition.id));
              _label(definition, choice.label);
              expect(find.text('設定を保存しています'), findsOneWidget);
              expect(find.text('未保存の変更があります'), findsOneWidget);
              expect(find.text('設定を保存しました'), findsNothing);
              expect(
                SettingsRecord.decode(session.storage.writes[write].record)
                    .values[definition.id],
                choice.storedValue,
              );

              // When that exact indexed write acknowledges the submitted choice.
              await _ack(tester, session, write++);

              // Then saved status follows the snapshot and not selector completion.
              expect(session.view.snapshot.savedRevision, revision);
              expect(session.view.snapshot.unsavedIds, isEmpty);
              expect(find.text('設定を保存しました'), findsOneWidget);
            }
          }
          expect(session.storage.readCount, 1);
          expect(session.storage.writeCount, 9);
        },
      );

      testWidgets('W04 reversed string-wire bool uses labelled typed switch', (
        tester,
      ) async {
        // Given true/false catalog order with string wire identities.
        final flag = _flag();
        final session = _session(
          tester,
          registry: CommonSettings.registry(extensions: [flag]),
        );
        await _mount(tester, session.view, style);
        await _load(tester, session);
        final switchFinder = find.descendant(
          of: _row(flag),
          matching: find.byType(
            style == SettingsPresentation.material ? Switch : CupertinoSwitch,
          ),
        );

        // When the native switch toggles twice and each write acknowledges.
        for (final next in [true, false]) {
          await _tap(tester, switchFinder);

          // Then label/toggle semantics and typed values agree despite wire order.
          expect(session.view.value(flag), next);
          final data = tester.getSemantics(_row(flag)).getSemanticsData();
          expect(data.label, contains('Example flag'));
          expect(data.flagsCollection.isToggled, isNot(Tristate.none));
          expect(
            data.flagsCollection.isToggled,
            next ? Tristate.isTrue : Tristate.isFalse,
          );
          expect(
            SettingsRecord.decode(session.storage.writes.last.record)
                .values[flag.id],
            next ? 'yes-wire' : 'no-wire',
          );
          await _ack(tester, session, next ? 0 : 1);
        }
        if (style == SettingsPresentation.cupertino) {
          // When the labelled row itself is tapped away from its trailing switch.
          await tester.tapAt(
            tester.getTopLeft(_row(flag)) + const Offset(20, 20),
          );
          await _flush(tester);

          // Then the row has no toggle callback and introduces no third intent.
          expect(session.view.snapshot.revision, 2);
          expect(tester.widget<CupertinoListTile>(_row(flag)).onTap, isNull);
        }
      });

      testWidgets('W05 bool and choice available disabled hidden policies', (
        tester,
      ) async {
        // Given both control shapes for disabled and hidden capability policies.
        final disabledBool = _flag(
          id: 'disabled.bool',
          policy: SettingAvailabilityPolicy.disableWhenUnsupported,
        );
        final hiddenBool = _flag(
          id: 'hidden.bool',
          policy: SettingAvailabilityPolicy.hideWhenUnsupported,
        );
        final disabledChoice = _choice(
          id: 'disabled.choice',
          policy: SettingAvailabilityPolicy.disableWhenUnsupported,
        );
        final hiddenChoice = _choice(
          id: 'hidden.choice',
          policy: SettingAvailabilityPolicy.hideWhenUnsupported,
        );
        final session = _session(
          tester,
          registry: CommonSettings.registry(
            extensions: [
              disabledBool,
              hiddenBool,
              disabledChoice,
              hiddenChoice,
            ],
          ),
        );
        await _mount(tester, session.view, style);

        // When unsupported visible controls are tapped and hidden ones inspected.
        await _tap(tester, _row(disabledBool));
        await _tap(tester, _row(disabledChoice));

        // Then neither shape permits intent and unavailable descriptions remain.
        expect(session.view.snapshot.revision, 0);
        expect(_row(hiddenBool), findsNothing);
        expect(_row(hiddenChoice), findsNothing);
        expect(find.textContaining('この環境では利用できません'), findsNWidgets(3));
        if (style == SettingsPresentation.material) {
          expect(
            tester.widget<SwitchListTile>(_row(disabledBool)).onChanged,
            isNull,
          );
          expect(tester.widget<ListTile>(_row(disabledChoice)).onTap, isNull);
        } else {
          expect(
            tester.widget<CupertinoListTile>(_row(disabledChoice)).onTap,
            isNull,
          );
          expect(
            tester
                .widget<CupertinoSwitch>(
                  find.descendant(
                    of: _row(disabledBool),
                    matching: find.byType(CupertinoSwitch),
                  ),
                )
                .onChanged,
            isNull,
          );
        }

        // When support is explicitly supplied by a rebuild and controls are used.
        await _mount(
          tester,
          session.view,
          style,
          capabilities: SettingsCapabilities(supported: {'example'}),
        );
        await _select(tester, hiddenChoice, 1);
        final toggle = find.descendant(
          of: _row(hiddenBool),
          matching: find.byType(
            style == SettingsPresentation.material ? Switch : CupertinoSwitch,
          ),
        );
        await _tap(tester, toggle);

        // Then restored visibility permits typed intent for each control shape.
        expect(_row(hiddenChoice), findsOneWidget);
        expect(session.view.value(hiddenChoice), 'second');
        expect(session.view.value(hiddenBool), isTrue);
        expect(session.view.snapshot.revision, 2);
        expect(session.storage.writeCount, 0); // Still explicitly not loaded.
      });

      testWidgets(
        'W06 capability rebuild preserves restored values and revisions',
        (tester) async {
          // Given a restored hidden-only extension group with no local intent.
          final flag = _flag(
            group: 'custom',
            policy: SettingAvailabilityPolicy.hideWhenUnsupported,
          );
          final choice = _choice(
            group: 'custom',
            policy: SettingAvailabilityPolicy.hideWhenUnsupported,
          );
          final session = _session(
            tester,
            registry: CommonSettings.registry(
              extensionGroups: [SettingGroup(id: 'custom', label: 'Custom')],
              extensions: [flag, choice],
            ),
          );
          final supported = SettingsCapabilities(
            supported: {'example', 'hinge'},
          );
          await _mount(tester, session.view, style, capabilities: supported);
          await _load(
            tester,
            session,
            record: _wire({flag.id: 'yes-wire', choice.id: 'two-wire'}),
          );
          final snapshot = session.view.snapshot;

          // When support disappears and returns through immutable inputs.
          await _mount(tester, session.view, style);
          expect(_key('settings-group:custom'), findsNothing);
          await _mount(tester, session.view, style, capabilities: supported);

          // Then the group returns and no value/presence/intent/I/O is rewritten.
          expect(_key('settings-group:custom'), findsOneWidget);
          expect(session.view.snapshot, same(snapshot));
          expect(session.view.value(flag), isTrue);
          _label(choice, 'Second');
          expect(session.view.snapshot.revision, 0);
          expect(session.view.snapshot.lastIntent, isNull);
          expect(session.storage.writeCount, 0);
          expect(session.storage.readCount, 1);
        },
      );

      testWidgets(
        'W07 single-choice bool uses finite chooser with current label',
        (tester) async {
          // Given a bool schema declaring only false, rather than a binary catalog.
          final flag = _flag(single: true);
          final session = _session(
            tester,
            registry: CommonSettings.registry(extensions: [flag]),
          );
          await _mount(tester, session.view, style);

          // When its current finite choice is explicitly selected.
          _label(flag, 'Off');
          await _select(tester, flag, 0);

          // Then no switch exists and the same typed false still creates intent.
          expect(
            find.descendant(of: _row(flag), matching: find.byType(Switch)),
            findsNothing,
          );
          expect(
            find.descendant(
              of: _row(flag),
              matching: find.byType(CupertinoSwitch),
            ),
            findsNothing,
          );
          expect(session.view.value(flag), isFalse);
          expect(session.view.snapshot.revision, 1);
          expect(session.view.snapshot.lastIntent!.settingId, flag.id);
          _label(flag, 'Off');
        },
      );

      testWidgets(
        'W08 external load and edit notifications render live values',
        (tester) async {
          // Given a mounted shell observing its caller's View.
          final session = _session(tester);
          await _mount(tester, session.view, style);

          // When composition restores storage then another consumer edits the View.
          await _load(
            tester,
            session,
            record: _wire({CommonSettings.textSizeMultiplier.id: 1.15}),
          );
          _label(CommonSettings.textSizeMultiplier, '大きめ');
          session.view.setValue(
            CommonSettings.panePreference.id,
            SettingsPanePreference.preferDualPane,
          );
          await _flush(tester);

          // Then controls display the authority's new values without a copied cache.
          _label(CommonSettings.panePreference, '2画面を優先');
          expect(find.text('未保存の変更があります'), findsOneWidget);
          expect(session.view.snapshot.revision, 1);
          await _ack(tester, session, 0);
          expect(find.text('設定を保存しました'), findsOneWidget);
        },
      );

      testWidgets(
        'W09 editable loading protects new intent from delayed read',
        (tester) async {
          // Given an explicit Load action with an indexed pending read.
          final session = _session(tester);
          await _mount(tester, session.view, style);
          await _tap(tester, _key('settings-load'));
          expect(find.text('設定を読み込んでいます'), findsOneWidget);

          // When the user selects a preference before a conflicting late read.
          await _select(tester, CommonSettings.panePreference, 2);
          expect(session.storage.writeCount, 0);
          expect(find.text('設定を保存しました'), findsNothing);
          session.storage.reads[0].succeed(
            _wire({CommonSettings.panePreference.id: 'preferSinglePane'}),
          );
          await _flush(tester);

          // Then current intent wins and writes only after the read barrier opens.
          _label(CommonSettings.panePreference, '2画面を優先');
          expect(session.view.snapshot.revision, 1);
          expect(session.view.loadCalls, 1);
          expect(session.storage.writeCount, 1);
          expect(find.text('設定を保存しています'), findsOneWidget);
          await _ack(tester, session, 0);
          expect(find.text('設定を保存しました'), findsOneWidget);
        },
      );

      testWidgets(
        'W10 failed read blocks edits reset and save retry until retry',
        (tester) async {
          // Given failed unread storage whose error must stay private.
          final session = _session(tester);
          await _mount(tester, session.view, style);
          await _tap(tester, _key('settings-load'));
          session.storage.reads[0].fail(StateError('private adapter detail'));
          await _flush(tester);
          expect(find.text('設定を読み込めませんでした'), findsOneWidget);

          // When UI edits/reset and an external save retry precede a read retry.
          await _select(tester, CommonSettings.panePreference, 1);
          await _reset(tester);
          await session.view.retrySave();
          expect(session.storage.writeCount, 0);
          await _tap(tester, _key('settings-retry-load'));
          await _select(tester, CommonSettings.panePreference, 2);
          session.storage.reads[1].succeed(
            _wire({CommonSettings.panePreference.id: 'preferSinglePane'}),
          );
          await _flush(tester);

          // Then successful retry preserves the latest intent and opens one write.
          expect(session.view.retryLoadCalls, 1);
          expect(session.storage.readCount, 2);
          expect(session.storage.writeCount, 1);
          expect(session.view.snapshot.revision, 3);
          _label(CommonSettings.panePreference, '2画面を優先');
          expect(find.textContaining('private adapter detail'), findsNothing);
          await _ack(tester, session, 0);
          expect(find.text('設定を保存しました'), findsOneWidget);
        },
      );

      testWidgets(
        'W11 unsupported format needs explicit preserving recovery reset',
        (tester) async {
          // Given a future envelope retaining extension and unknown raw data.
          final flag = _flag();
          final session = _session(
            tester,
            registry: CommonSettings.registry(extensions: [flag]),
          );
          await _mount(tester, session.view, style);
          await _load(
            tester,
            session,
            record: _wire({flag.id: 'yes-wire'}, version: 9),
          );
          expect(find.text('この設定形式には対応していません'), findsOneWidget);
          expect(_key('settings-retry-load'), findsOneWidget);
          expect(_key('settings-reset'), findsOneWidget);

          // When an ordinary edit cannot rewrite it, but confirmed reset authorizes.
          await _select(tester, CommonSettings.panePreference, 1);
          expect(session.storage.writeCount, 0);
          await _reset(tester);

          // Then version recovery preserves data but remains unsupported until ack.
          expect(session.view.snapshot.revision, 2);
          expect(session.view.value(flag), isTrue);
          final submitted = SettingsRecord.decode(
            session.storage.writes[0].record,
          );
          expect(submitted.version, 1);
          expect(submitted.values[flag.id], 'yes-wire');
          _retained(submitted);
          expect(find.text('この設定形式には対応していません'), findsOneWidget);
          expect(find.text('未保存の変更があります'), findsOneWidget);
          expect(find.text('設定を保存しました'), findsNothing);

          // When the exact recovery write acknowledges.
          await _ack(tester, session, 0);

          // Then the controller transitions to ready and the shell reports saved.
          expect(session.view.snapshot.readState, SettingsReadState.ready);
          expect(find.text('この設定形式には対応していません'), findsNothing);
          expect(find.text('設定を保存しました'), findsOneWidget);
        },
      );

      testWidgets(
        'W12 save failure retains newest value for explicit save retry',
        (tester) async {
          // Given supported storage and a preference awaiting durable ack.
          final session = _session(tester);
          await _mount(tester, session.view, style);
          await _load(tester, session);
          await _select(tester, CommonSettings.textSizeMultiplier, 1);
          expect(find.text('設定を保存しています'), findsOneWidget);

          // When that write fails and a newer UI edit precedes Retry saving.
          session.storage.writes[0].fail(StateError('secret write failure'));
          await _flush(tester);
          await _select(tester, CommonSettings.textSizeMultiplier, 2);
          expect(session.storage.writeCount, 1);
          expect(find.text('設定を保存できませんでした'), findsOneWidget);
          expect(find.text('未保存の変更があります'), findsOneWidget);
          expect(find.textContaining('secret write failure'), findsNothing);
          await _tap(tester, _key('settings-retry-save'));

          // Then retry delegates once and submits the latest typed value only.
          expect(session.view.retrySaveCalls, 1);
          expect(session.storage.writeCount, 2);
          expect(
            SettingsRecord.decode(session.storage.writes[1].record)
                .values[CommonSettings.textSizeMultiplier.id],
            1.30,
          );
          _label(CommonSettings.textSizeMultiplier, 'さらに大きく');
          expect(find.text('設定を保存しました'), findsNothing);
          await _ack(tester, session, 1);
          expect(find.text('設定を保存できませんでした'), findsNothing);
          expect(find.text('設定を保存しました'), findsOneWidget);
        },
      );

      testWidgets(
        'W13 reset cancel and same-default confirmation preserve extras',
        (tester) async {
          // Given nondefault common values, extension and retained unknown data.
          final flag = _flag();
          final session = _session(
            tester,
            registry: CommonSettings.registry(extensions: [flag]),
          );
          await _mount(tester, session.view, style);
          await _load(
            tester,
            session,
            record: _wire({
              flag.id: 'yes-wire',
              CommonSettings.panePreference.id: 'preferDualPane',
              CommonSettings.textSizeMultiplier.id: 1.30,
            }),
          );

          // When reset is cancelled, confirmed, then confirmed again at defaults.
          await _reset(tester, confirm: false);
          expect(session.view.snapshot.revision, 0);
          expect(session.storage.writeCount, 0);
          for (var index = 0; index < 2; index++) {
            await _reset(tester);

            // Then every confirmation is exactly one common-only preserving intent.
            expect(session.view.snapshot.revision, index + 1);
            expect(
              session.view.snapshot.lastIntent!.kind,
              SettingsIntentKind.resetCommon,
            );
            expect(session.view.snapshot.lastIntent!.settingId, isNull);
            for (final definition in CommonSettings.definitions) {
              expect(session.view.value(definition), definition.defaultValue);
            }
            expect(session.view.value(flag), isTrue);
            final submitted = SettingsRecord.decode(
              session.storage.writes[index].record,
            );
            expect(submitted.values[flag.id], 'yes-wire');
            _retained(submitted);
            await _ack(tester, session, index);
          }
        },
      );

      testWidgets(
        'W14 reset during read protects common and restores extension',
        (tester) async {
          // Given an extension registry and pending explicit restoration.
          final flag = _flag();
          final session = _session(
            tester,
            registry: CommonSettings.registry(extensions: [flag]),
          );
          await _mount(tester, session.view, style);
          await _tap(tester, _key('settings-load'));

          // When reset is confirmed before a nondefault common/extension read.
          await _reset(tester);
          expect(find.text('設定を読み込んでいます'), findsOneWidget);
          expect(find.text('未保存の変更があります'), findsOneWidget);
          expect(session.storage.writeCount, 0);
          session.storage.reads[0].succeed(
            _wire({
              CommonSettings.panePreference.id: 'preferDualPane',
              flag.id: 'yes-wire',
            }),
          );
          await _flush(tester);

          // Then common defaults win, untouched extension restores, ack stays pending.
          expect(session.view.snapshot.revision, 1);
          expect(session.view.value(flag), isTrue);
          _label(CommonSettings.panePreference, '自動');
          expect(find.text('設定を保存しています'), findsOneWidget);
          expect(find.text('設定を保存しました'), findsNothing);
          final submitted = SettingsRecord.decode(
            session.storage.writes[0].record,
          );
          expect(submitted.values[flag.id], 'yes-wire');
          _retained(submitted);
          await _ack(tester, session, 0);
          expect(find.text('設定を保存しました'), findsOneWidget);
        },
      );

      testWidgets(
        'W15 selector cancel back and barrier dismissal have no intent',
        (tester) async {
          // Given a real unloaded View and a native finite chooser.
          final session = _session(tester);
          await _mount(tester, session.view, style);
          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );

          // When back, barrier, and Cupertino's explicit Cancel dismiss selectors.
          await _openChoice(tester, CommonSettings.panePreference);
          navigator.pop();
          await tester.pumpAndSettle();
          await _openChoice(tester, CommonSettings.panePreference);
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          if (style == SettingsPresentation.cupertino) {
            await _openChoice(tester, CommonSettings.panePreference);
            await tester.tap(find.text('キャンセル'));
            await tester.pumpAndSettle();
          }

          // Then no selector remains and no dismissal edits or starts storage.
          expect(find.byType(SimpleDialog), findsNothing);
          expect(find.byType(CupertinoActionSheet), findsNothing);
          expect(session.view.snapshot.revision, 0);
          expect(session.view.snapshot.lastIntent, isNull);
          expect(session.storage.readCount, 0);
          expect(session.storage.writeCount, 0);
        },
      );

      testWidgets('W16 stale chooser respects newly disabled and hidden policy', (
        tester,
      ) async {
        // Given available definitions using each unsupported policy.
        final disabled = _choice(
          id: 'disabled',
          policy: SettingAvailabilityPolicy.disableWhenUnsupported,
        );
        final hidden = _choice(
          id: 'hidden',
          policy: SettingAvailabilityPolicy.hideWhenUnsupported,
        );
        final session = _session(
          tester,
          registry: CommonSettings.registry(extensions: [disabled, hidden]),
        );

        for (final definition in [disabled, hidden]) {
          await _mount(
            tester,
            session.view,
            style,
            capabilities: SettingsCapabilities(supported: {'example'}),
          );

          // When support is removed after opening but before choosing a result.
          await _openChoice(tester, definition);
          await _mount(tester, session.view, style);
          await _tap(tester, _key('settings-choice:${definition.id}:1'));
          await tester.pumpAndSettle();

          // Then completion consults current support and creates no stale edit.
          expect(session.view.value(definition), 'first');
          expect(session.view.snapshot.revision, 0);
          expect(session.storage.writeCount, 0);
        }
        expect(_row(hidden), findsNothing);
        expect(_row(disabled), findsOneWidget);
      });

      testWidgets(
        'W17 replacement detaches old View and ignores old definition',
        (tester) async {
          // Given two registries with distinct same-ID definition instances.
          final oldChoice = _choice(label: 'Old definition');
          final newChoice = _choice(label: 'Replacement definition');
          final old = _session(
            tester,
            registry: CommonSettings.registry(extensions: [oldChoice]),
          );
          final replacement = _session(
            tester,
            registry: CommonSettings.registry(extensions: [newChoice]),
          );
          await _mount(tester, old.view, style);

          // When the View replaces the original while its chooser is still open.
          await _openChoice(tester, oldChoice);
          await _mount(tester, replacement.view, style);
          old.view.dispose(); // Ownership may dispose only after detachment.
          await _tap(tester, _key('settings-choice:${oldChoice.id}:1'));
          await tester.pumpAndSettle();
          old.controller.setValue(oldChoice.id, 'second');
          await _flush(tester);

          // Then neither modal edits a View and the old authority cannot rerender it.
          expect(old.view.detached, 1);
          expect(old.view.attached, 1);
          expect(replacement.view.attached, 1);
          expect(replacement.view.snapshot.revision, 0);
          expect(
            old.view.snapshot.revision,
            1,
          ); // Only the explicit external edit.
          expect(find.text('Replacement definition'), findsOneWidget);
          _label(newChoice, 'First');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'W18 replacement and unmount invalidate pending reset and choice',
        (tester) async {
          // Given distinct borrowed Views and a pending original reset confirmation.
          final old = _session(tester);
          final replacement = _session(tester);
          await _mount(tester, old.view, style);
          await _tap(tester, _key('settings-reset'));
          await tester.pumpAndSettle();

          // When confirmation follows View replacement, then modals outlive unmount.
          await _mount(tester, replacement.view, style);
          await _tap(tester, _key('settings-reset-confirm'));
          await tester.pumpAndSettle();
          expect(old.view.snapshot.revision, 0);
          expect(replacement.view.snapshot.revision, 0);
          for (final reset in [false, true]) {
            final visible = ValueNotifier<bool>(true);
            addTearDown(visible.dispose);
            final navigatorKey = GlobalKey<NavigatorState>();
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: navigatorKey,
                home: ValueListenableBuilder<bool>(
                  valueListenable: visible,
                  builder: (context, show, child) => show
                      ? SettingsShell(
                          view: replacement.view,
                          presentation: style,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            );
            if (reset) {
              await _tap(tester, _key('settings-reset'));
              await tester.pumpAndSettle();
            } else {
              await _openChoice(tester, CommonSettings.panePreference);
            }
            visible.value = false;
            await _flush(tester);
            navigatorKey.currentState!.pop(
              reset ? true : SettingsPanePreference.preferDualPane,
            );
            await tester.pumpAndSettle();

            // Then stale completion has no intent/exception or remaining observation.
            expect(replacement.view.snapshot.revision, 0);
            expect(replacement.view.attached, replacement.view.detached);
            expect(tester.takeException(), isNull);
          }
          expect(old.view.snapshot.revision, 0);
        },
      );

      testWidgets('W19 narrow OS-scaled long text remains wrapped and reachable', (
        tester,
      ) async {
        // Given 320 logical pixels, OS scaling 2, and long schema/control text.
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const longLabel =
            'A long application preference label that must remain fully readable';
        const longValue =
            'A long selected value description that must wrap onto multiple lines';
        final choice = _choice(label: longLabel, secondLabel: longValue);
        final flag = _flag(
          label:
              'A long boolean preference label with an unavailable explanation',
          policy: SettingAvailabilityPolicy.disableWhenUnsupported,
        );
        final session = _session(
          tester,
          registry: CommonSettings.registry(extensions: [choice, flag]),
        );
        await _mount(
          tester,
          session.view,
          style,
          textScaler: TextScaler.linear(2),
        );

        // When selecting long text, scrolling statuses/actions and confirming reset.
        await _select(tester, choice, 1);
        await tester.ensureVisible(_row(choice));
        final textContext = tester.element(find.text(longValue));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(longValue),
            matching: find.byType(RichText),
          ),
        );

        // Then full choice text wraps with unchanged OS scaling and no truncation.
        expect(MediaQuery.textScalerOf(textContext).scale(10), 20);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, greaterThan(40));
        expect(tester.takeException(), isNull);
        await _tap(tester, _key('settings-load'));
        session.storage.reads[0].fail(StateError('read'));
        await _flush(tester);
        await tester.ensureVisible(_key('settings-retry-load'));
        expect(_key('settings-retry-load').hitTestable(), findsOneWidget);
        await _reset(tester);
        await tester.ensureVisible(find.text('未保存の変更があります'));

        // Then disabled descriptions/status/reset are readable and scrollable too.
        expect(find.textContaining('この環境では利用できません'), findsNWidgets(2));
        expect(session.view.snapshot.revision, 2);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'W20 unsupported read and failed recovery save stay independent',
        (tester) async {
          // Given a future format reached through one explicit Load action.
          final session = _session(tester);
          await _mount(tester, session.view, style);
          await _tap(tester, _key('settings-load'));
          expect(session.view.loadCalls, 1);
          expect(session.storage.readCount, 1);
          expect(find.text('設定を読み込んでいます'), findsOneWidget);
          session.storage.reads[0].succeed(_wire({}, version: 8));
          await _flush(tester);

          // When Retry loading repeats that format then reset recovery fails to save.
          await _tap(tester, _key('settings-retry-load'));
          expect(session.view.retryLoadCalls, 1);
          expect(session.storage.readCount, 2);
          session.storage.reads[1].succeed(_wire({}, version: 8));
          await _flush(tester);
          await _reset(tester);
          session.storage.writes[0].fail(StateError('private recovery write'));
          await _flush(tester);

          // Then real simultaneous read/save errors expose independent retry actions.
          expect(session.view.snapshot.readError, isNotNull);
          expect(session.view.snapshot.saveError, isNotNull);
          expect(find.text('この設定形式には対応していません'), findsOneWidget);
          expect(find.text('設定を保存できませんでした'), findsOneWidget);
          expect(_key('settings-retry-load'), findsOneWidget);
          expect(_key('settings-retry-save'), findsOneWidget);
          expect(find.text('未保存の変更があります'), findsOneWidget);
          expect(find.text('設定を保存しました'), findsNothing);

          // When retry-load and retry-save are each tapped once during recovery.
          await _tap(tester, _key('settings-retry-load'));
          expect(session.view.retryLoadCalls, 2);
          expect(
            session.storage.readCount,
            2,
          ); // Controller-owned recovery barrier.
          await _tap(tester, _key('settings-retry-save'));

          // Then each tap delegates once; only save retry performs the eligible I/O.
          expect(session.view.retrySaveCalls, 1);
          expect(session.storage.writeCount, 2);
          expect(find.text('設定を保存しています'), findsOneWidget);
          expect(find.text('この設定形式には対応していません'), findsOneWidget);
          await _ack(tester, session, 1);
          expect(find.text('設定を保存しました'), findsOneWidget);
          expect(session.view.snapshot.readError, isNull);
          expect(session.view.snapshot.saveError, isNull);
        },
      );
    });
  }
}
