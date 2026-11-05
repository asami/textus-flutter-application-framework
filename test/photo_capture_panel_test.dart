import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  late Directory directory;
  late _Store store;
  late _Camera camera;
  late _Provider standard;
  late _Provider enhanced;
  late PhotoCaptureFacade facade;
  late _SettingsStorage storage;
  late SettingsLifecycleController settings;
  late SettingsView view;
  late PhotoCaptureController controller;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-panel-spec-');
    store = _Store(FileCaptureStore(directory.path));
    camera = _Camera();
    standard = _Provider();
    enhanced = _Provider(enhanced: true);
    facade = PhotoCaptureFacade(
      service: _service(camera, standard, enhanced, store),
    );
    storage = _SettingsStorage();
    settings = _settings(storage);
    view = SettingsView.fromService(service: settings);
    controller = PhotoCaptureController(facade: facade, settings: view);
  });
  tearDown(() async {
    controller.dispose();
    view.dispose();
    settings.dispose();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'G4 live gate rejects camera settings provider and saved-image callbacks without a frame',
    (tester) async {
      // Given current photo settings, an exact durable comparison and downloadable provider.
      await tester.runAsync(controller.initialize);
      await tester.runAsync(controller.capture);
      enhanced.state = RecognitionProviderState.downloadable;
      await tester.runAsync(controller.refreshAvailability);
      var allowed = true;
      final callbacks = <RecognitionComparison>[];
      await tester.pumpWidget(
        _host(
          controller,
          onComparison: callbacks.add,
          interactionAllowed: () => allowed,
        ),
      );
      final configuration = tester
          .widget<DropdownButton<String>>(
            find.byKey(const ValueKey('photo-capture-configuration')),
          )
          .onChanged!;
      final actions = [
        for (final id in [
          'refresh',
          'capture',
          'recover',
          'recognize',
          'compare',
          'prepare-geminiNano',
        ])
          tester
              .widget<ElevatedButton>(find.byKey(ValueKey('photo-capture-$id')))
              .onPressed!,
      ];
      final before = _photoEffects(camera, standard, enhanced, store, storage);
      final previous = controller.comparison;
      final snapshot = view.snapshot;
      // When the caller flips its pure Boolean without rebuilding any rendered action.
      allowed = false;
      configuration('pixelEnhanced');
      for (final action in actions) {
        // Given an actual rendered camera/provider/saved-recognition callback.
        // When invoked under current denial, no command is admitted.
        action();
        // Then provider/camera/storage/settings counts stay exactly unchanged.
        expect(
          _photoEffects(camera, standard, enhanced, store, storage),
          before,
        );
      }
      // Then desired intent, immutable report, settings snapshot and owner result remain unchanged.
      expect(controller.desiredConfigurationId, 'androidStandard');
      expect(controller.comparison, same(previous));
      expect(view.snapshot, same(snapshot));
      expect(controller.busy, isFalse);
      expect(controller.error, isNull);
      expect(callbacks, isEmpty);
      // When the same current owner reenables without rebuilding and selects enhanced intent.
      allowed = true;
      configuration('pixelEnhanced');
      await tester.runAsync(view.retrySave);
      // Then only that explicit settings intent writes and capture remains untouched.
      expect(controller.desiredConfigurationId, 'pixelEnhanced');
      expect(
        SettingsRecord.decode(storage.record!)
            .values[RecognitionSettings.configuration.id],
        'pixelEnhanced',
      );
      expect(camera.captures, 1);
      expect(store.imports, 1);
      // When the earlier captured same-owner capture command is explicitly invoked.
      await tester.runAsync(() async {
        // Given the reenabling owner and its captured capture command.
        // When it is admitted, join the real controller operation.
        actions[1]();
        await _waitIdle(controller);
        // Then real durable capture completed before fixture disposal.
        expect(controller.comparison, isNotNull);
      });
      await tester.pumpAndSettle();
      // Then capture imports exactly once and reports exactly once to the original owner.
      expect(camera.captures, 2);
      expect(store.imports, 2);
      expect(callbacks, [controller.comparison]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final retry in ['retry-load', 'retry-save']) {
    testWidgets('G4 $retry captured settings callback has live admission', (
      tester,
    ) async {
      // Given the settings read/save state exposing this exact retry command.
      if (retry == 'retry-save') {
        await tester.runAsync(controller.initialize);
        storage.writeError = StateError('actual retained settings failure');
        controller.selectConfiguration('pixelEnhanced');
        await tester.runAsync(_settle);
        await tester.runAsync(view.retrySave);
      }
      var allowed = true;
      await tester.pumpWidget(
        _host(controller, interactionAllowed: () => allowed),
      );
      final captured = tester
          .widget<ElevatedButton>(find.byKey(ValueKey('photo-capture-$retry')))
          .onPressed!;
      final before = _photoEffects(camera, standard, enhanced, store, storage);
      final desired = controller.desiredConfigurationId;
      final snapshot = view.snapshot;
      // When its live policy denies without rebuilding, no settings command starts.
      allowed = false;
      captured();
      // Then intent, read/save state, pending error and actual IO counters remain unchanged.
      expect(view.snapshot, same(snapshot));
      expect(controller.desiredConfigurationId, desired);
      expect(_photoEffects(camera, standard, enhanced, store, storage), before);
      expect(controller.busy, isFalse);
      // When the original same-owner callback is explicitly reenabled.
      allowed = true;
      storage.writeError = null;
      await tester.runAsync(() async {
        // Given a current owner with supported settings storage.
        // When its captured retry starts, await actual settlement.
        captured();
        await _waitIdle(controller);
        // Then there is no fixture-owned command left pending.
        expect(controller.busy, isFalse);
      });
      await tester.pumpAndSettle();
      // Then only the selected explicit retry issues a read or write.
      expect(
        _photoEffects(camera, standard, enhanced, store, storage),
        isNot(before),
      );
      expect(view.snapshot.readState, SettingsReadState.ready);
      if (retry == 'retry-save') {
        expect(view.snapshot.hasUnsavedChanges, isFalse);
      }
      expect(camera.captures + camera.recoveries, 0);
      expect(store.imports + store.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final operation in ['capture', 'prepare-geminiNano']) {
    for (final fails in [false, true]) {
      testWidgets(
        'G4 accepted $operation failure=$fails settles while caller denies users',
        (tester) async {
          // Given current common settings and a controlled held camera/preparation outcome.
          var allowed = true;
          final callbacks = <RecognitionComparison>[];
          if (operation == 'capture') {
            camera.gate = Completer<CapturedPhoto?>();
          } else {
            enhanced.state = RecognitionProviderState.downloadable;
            enhanced.prepareGate = Completer<void>();
            if (fails) {
              enhanced.prepareError = StateError(
                'accepted preparation failure',
              );
            }
          }
          await tester.runAsync(controller.initialize);
          await tester.pumpWidget(
            _host(
              controller,
              onComparison: callbacks.add,
              interactionAllowed: () => allowed,
            ),
          );
          final control = find.byKey(ValueKey('photo-capture-$operation'));
          await tester.ensureVisible(control);
          // When the real UI admits work and then caller admission flips before settlement.
          await tester.runAsync(() async {
            // Given a current allowed production camera/preparation control.
            // When its actual gesture dispatches in the real IO event zone.
            await tester.tap(control);
            // Then exactly that admitted operation owns the held command.
            expect(controller.busy, isTrue);
          });
          await tester.pump();
          expect(controller.busy, isTrue);
          allowed = false;
          await tester.pumpWidget(
            _host(
              controller,
              onComparison: callbacks.add,
              interactionAllowed: () => allowed,
            ),
          );
          await tester.runAsync(() async {
            // Given previously admitted work and current user denial.
            // When the actual fixture gate settles, join the borrowed controller.
            if (operation == 'capture') {
              if (fails) {
                camera.gate!.completeError(
                  StateError('accepted camera failure'),
                );
              } else {
                camera.gate!.complete(_photo());
              }
            } else {
              enhanced.prepareGate!.complete();
            }
            await _waitIdle(controller);
            // Then admitted work has settled without a widget cancellation or ownership transfer.
            expect(controller.busy, isFalse);
          });
          await tester.pumpAndSettle();
          // Then actual success/error and original callback semantics survive temporary denial.
          if (fails) {
            expect(controller.error, isNotNull);
            expect(callbacks, isEmpty);
            expect(controller.comparison, isNull);
          } else if (operation == 'capture') {
            expect(callbacks, [controller.comparison]);
            expect(store.imports, 1);
            expect(store.writes, greaterThan(0));
          } else {
            expect(callbacks, isEmpty);
            expect(
              controller.availability.last.state,
              RecognitionProviderState.available,
            );
            expect(find.text('利用準備中 geminiNano'), findsNothing);
            expect(enhanced.inputs, isEmpty);
            expect(controller.desiredConfigurationId, 'androidStandard');
          }
          expect(camera.captures, operation == 'capture' ? 1 : 0);
          expect(enhanced.prepares, operation == 'capture' ? 0 : 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final retirement in ['replace', 'round-trip', 'unmount']) {
    testWidgets(
      'G5 photo $retirement rejects stale configuration and capture callbacks',
      (tester) async {
        // Given borrowed owners A/B and the actual configuration/capture callbacks rendered for A.
        await tester.runAsync(controller.initialize);
        final nextStorage = _SettingsStorage();
        final nextSettings = _settings(nextStorage);
        final nextView = SettingsView.fromService(service: nextSettings);
        final other = PhotoCaptureController(
          facade: facade,
          settings: nextView,
        );
        await tester.runAsync(other.initialize);
        final callbacks = <RecognitionComparison>[];
        await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
        final configuration = tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('photo-capture-configuration')),
            )
            .onChanged!;
        final capture = tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('photo-capture-capture')),
            )
            .onPressed!;
        final before = _photoEffects(
          camera,
          standard,
          enhanced,
          store,
          storage,
        );
        // When A retires, including A->B->A with the identical controller under a new generation.
        if (retirement == 'unmount') {
          await tester.pumpWidget(const SizedBox.shrink());
        } else {
          await tester.pumpWidget(_host(other, onComparison: callbacks.add));
          if (retirement == 'round-trip') {
            await tester.pumpWidget(
              _host(controller, onComparison: callbacks.add),
            );
          }
        }
        configuration('pixelEnhanced');
        capture();
        // Then stale actions mutate neither owner, settings nor providers before rejection.
        expect(
          _photoEffects(camera, standard, enhanced, store, storage),
          before,
        );
        expect(nextStorage.writes, 0);
        expect(controller.desiredConfigurationId, 'androidStandard');
        expect(other.desiredConfigurationId, 'androidStandard');
        expect(controller.busy, isFalse);
        expect(other.busy, isFalse);
        expect(controller.comparison, isNull);
        expect(other.comparison, isNull);
        expect(callbacks, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        other.dispose();
        nextView.dispose();
        nextSettings.dispose();
      },
    );
  }

  testWidgets(
    'G6 denied photo controls remain visible and scrollable at scaled 320px',
    (tester) async {
      // Given current photo settings and downloadable preparation at 320px and scale two.
      enhanced.state = RecognitionProviderState.downloadable;
      await tester.runAsync(controller.initialize);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final before = _photoEffects(camera, standard, enhanced, store, storage);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: PhotoCapturePanel(
                  controller: controller,
                  interactionAllowed: () => false,
                ),
              ),
            ),
          ),
        ),
      );
      // Enumerate the actual disabled controls in the scaled caller scrollable.
      for (final id in [
        'refresh',
        'capture',
        'recover',
        'recognize',
        'compare',
        'prepare-geminiNano',
      ]) {
        // Given the finder for the actual disabled scaled control.
        final finder = find.byKey(ValueKey('photo-capture-$id'));
        await tester.ensureVisible(finder);
        // Then the visible control has no admitted gesture callback.
        expect(tester.widget<ElevatedButton>(finder).onPressed, isNull);
        // When the actual disabled control is tapped.
        await tester.tap(finder);
        await tester.pump();
        // Then controls remain reachable with unchanged IO and no overflow/Flutter exception.
        expect(finder.hitTestable(), findsOneWidget);
        expect(
          _photoEffects(camera, standard, enhanced, store, storage),
          before,
        );
        expect(tester.takeException(), isNull);
      }
      // Then the visible configuration selector is disabled and settings intent stays literal.
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('photo-capture-configuration')),
            )
            .onChanged,
        isNull,
      );
      expect(controller.desiredConfigurationId, 'androidStandard');
      expect(camera.captures + camera.recoveries, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  group('PC2 operation-start comparison callback', () {
    testWidgets(
      'same-controller rebuild retains the callback bound before held capture',
      (tester) async {
        // Given an initialized actual service and a held camera under the first callback.
        final first = <RecognitionComparison>[];
        final rebuilt = <RecognitionComparison>[];
        await tester.runAsync(controller.initialize);
        camera.gate = Completer<CapturedPhoto?>();
        await tester.pumpWidget(_host(controller, onComparison: first.add));
        await tester.runAsync(
          () async =>
              tester.tap(find.byKey(const ValueKey('photo-capture-capture'))),
        );
        await tester.pump();
        // When the same panel/controller rebuilds with a replacement callback before capture completion.
        await tester.pumpWidget(_host(controller, onComparison: rebuilt.add));
        await tester.runAsync(() async {
          camera.gate!.complete(_photo());
          await _waitIdle(controller);
        });
        await tester.pumpAndSettle();
        // Then only the original callback receives the exact once-durable completion.
        expect(first, [controller.comparison]);
        expect(rebuilt, isEmpty);
        expect(camera.captures, 1);
        expect(store.imports, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  testWidgets(
    'W1 public interaction selects enhanced and compares one durable original',
    (tester) async {
      // Given explicitly initialized real Core interaction and a borrowed panel callback.
      final callbacks = <RecognitionComparison>[];
      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
      // When the user selects enhanced intent, captures, then compares the same original.
      await tester.tap(
        find.byKey(const ValueKey('photo-capture-configuration')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('端末内AIで補完（対応端末）').last);
      await tester.pumpAndSettle();
      await tester.runAsync(view.retrySave);
      await _command(tester, controller, 'capture');
      final captured = controller.comparison!;
      await _command(tester, controller, 'compare');
      final compared = controller.comparison!;
      final reopened = await tester.runAsync(
        () =>
            LocalRecognitionRepository(store: FileCaptureStore(directory.path))
                .findById(compared.id),
      );
      // Then the two rows retain raw ordered proposals, timing, shared work and durable identity.
      expect(
        find.byKey(const ValueKey('recognition-run-androidStandard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('recognition-run-pixelEnhanced')),
        findsOneWidget,
      );
      expect(find.text('実際の構成: pixelEnhanced'), findsOneWidget);
      expect(find.text('標準処理への切替理由: なし'), findsNWidgets(2));
      expect(
        find.text(
          '候補 0: 種類 "unknown kind"; 値 " opaque proposal "',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '候補 1: 種類 "unknown kind"; 値 " opaque proposal "',
        ),
        findsOneWidget,
      );
      expect(
        find.text('バーコード 0: " second "; 形式 "rawFormat"'),
        findsNWidgets(2),
      );
      expect(
        find.text('バーコード 1: "first"; 形式 "anotherFormat"'),
        findsNWidgets(2),
      );
      expect(find.text('OCR: " raw OCR "'), findsNWidgets(2));
      expect(
        find.text('画像の解釈結果: " raw interpretation "'),
        findsOneWidget,
      );
      for (final run in compared.runs) {
        // Given the actual Core timing of this desired route.
        // When the report is rendered.
        // Then row and attempt milliseconds are displayed without invented timing.
        expect(
          find.text(
            '構成の処理時間: ${run.elapsed.inMilliseconds} ms（共通処理を含む）',
          ),
          findsWidgets,
        );
        for (final attempt in run.attempts) {
          // Given this provider attempt's actual measured duration.
          // When its presentation is observed.
          // Then the exact elapsed milliseconds remain visible.
          expect(
            find.text('試行の処理時間: ${attempt.elapsed.inMilliseconds} ms'),
            findsWidgets,
          );
        }
      }
      expect(find.textContaining('共通処理'), findsWidgets);
      expect(compared.material, same(captured.material));
      expect(camera.captures, 1);
      expect(store.imports, 1);
      expect(controller.desiredConfigurationId, 'pixelEnhanced');
      expect(callbacks, [captured, compared]);
      expect(
        RecognitionReportCodec.encode(reopened!),
        RecognitionReportCodec.encode(compared),
      );
      expect(
        SettingsRecord.decode(storage.record!)
            .values[RecognitionSettings.configuration.id],
        'pixelEnhanced',
      );
      // Given the same saved original and explicit saved-image/recovery controls.
      // When recognition and recovery complete successfully through the UI.
      await _command(tester, controller, 'recognize');
      await _command(tester, controller, 'recover');
      // Then each success emits exactly one callback and recovery alone adds acquisition.
      expect(callbacks, hasLength(4));
      expect(camera.captures, 1);
      expect(camera.recoveries, 1);
      expect(store.imports, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'W2 explicit model preparation renders busy status and excludes duplicate operations',
    (tester) async {
      // Given a downloadable provider and a held model preparation.
      enhanced.state = RecognitionProviderState.downloadable;
      enhanced.prepareGate = Completer<void>();
      final callbacks = <RecognitionComparison>[];
      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
      // When the user explicitly chooses Prepare.
      await tester.tap(
        find.byKey(const ValueKey('photo-capture-prepare-geminiNano')),
      );
      await tester.pump();
      await tester.runAsync(_settle);
      await tester.pump();
      // Then busy/preparing are visible and every action is disabled.
      expect(find.text('利用準備中 geminiNano'), findsOneWidget);
      expect(enhanced.prepares, 1);
      for (final id in [
        'refresh',
        'capture',
        'recover',
        'recognize',
        'compare',
        'prepare-geminiNano',
      ]) {
        // Given this action during the same held preparation.
        // When its callback is inspected.
        // Then no duplicate UI operation can be started.
        expect(
          tester
              .widget<ElevatedButton>(find.byKey(ValueKey('photo-capture-$id')))
              .onPressed,
          isNull,
        );
      }
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('photo-capture-configuration')),
            )
            .onChanged,
        isNull,
      );
      // Given completion of the actual provider fixture.
      enhanced.prepareGate!.complete();
      // When the admitted operation settles.
      await tester.runAsync(() => _waitIdle(controller));
      await tester.pumpAndSettle();
      // Then model availability is visible without inference, callback or preference change.
      expect(find.text('認識処理 geminiNano: 利用可能'), findsOneWidget);
      expect(find.text('利用モデル: fixture-model'), findsNWidgets(2));
      expect(enhanced.inputs, isEmpty);
      expect(callbacks, isEmpty);
      expect(controller.desiredConfigurationId, 'androidStandard');
      // Given externally preparing state without a new preparation request.
      enhanced.state = RecognitionProviderState.preparing;
      // When availability is refreshed explicitly.
      await _command(tester, controller, 'refresh');
      // Then preparing is displayed and another Prepare action is absent.
      expect(find.text('認識処理 geminiNano: 準備中'), findsOneWidget);
      expect(find.text('利用準備中 geminiNano'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('photo-capture-prepare-geminiNano')),
        findsNothing,
      );
      expect(enhanced.prepares, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'W2 failure retains report and cancellation emits no new callback',
    (tester) async {
      // Given an accepted capture displayed by the public interaction panel.
      final callbacks = <RecognitionComparison>[];
      await tester.runAsync(controller.initialize);
      await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
      await _command(tester, controller, 'capture');
      final previous = controller.comparison!;
      // When an actual report write fails through Compare.
      store.writeError = StateError('actual report write failure');
      await _command(tester, controller, 'compare');
      // Then the UI presents a fixed failure while the model retains its actual error and accepted report.
      expect(
        find.text('撮影・認識の処理を完了できませんでした。'),
        findsOneWidget,
      );
      expect(find.textContaining('actual report write failure'), findsNothing);
      expect(controller.error, isA<StateError>());
      expect(controller.error.toString(), contains('actual report write failure'));
      expect(controller.comparison, same(previous));
      expect(callbacks, [previous]);
      expect(tester.takeException(), isNull);
      // Given a downloadable provider whose explicit preparation fails.
      store.writeError = null;
      enhanced.state = RecognitionProviderState.downloadable;
      enhanced.prepareError = StateError('actual model preparation failure');
      await _command(tester, controller, 'refresh');
      // When its visible Prepare action is used.
      await _command(tester, controller, 'prepare-geminiNano');
      // Then the fixed UI failure and retained actual model error leave the report unchanged.
      expect(
        find.text('撮影・認識の処理を完了できませんでした。'),
        findsOneWidget,
      );
      expect(find.textContaining('actual model preparation failure'), findsNothing);
      expect(controller.error, isA<StateError>());
      expect(controller.error.toString(), contains('actual model preparation failure'));
      expect(controller.comparison, same(previous));
      expect(callbacks, [previous]);
      // Given camera cancellation for both acquisition entry points.
      camera.photo = null;
      // When the user captures and recovers.
      await _command(tester, controller, 'capture');
      await _command(tester, controller, 'recover');
      // Then no new report callback is emitted and previous output stays visible.
      expect(callbacks, [previous]);
      expect(controller.comparison, same(previous));
      expect(find.text('比較ID: ${previous.id}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'W3 settings read/save errors and retry UI preserve barrier and unsaved truth',
    (tester) async {
      // Given a borrowed panel whose owner has not initialized settings.
      final callbacks = <RecognitionComparison>[];
      await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
      // When construction and mount are observed.
      // Then no load starts and acquisition stays disabled.
      expect(storage.reads, 0);
      expect(find.text('設定の読込: 未読込'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('photo-capture-capture')),
            )
            .onPressed,
        isNull,
      );
      // Given a held read followed by an actual read failure.
      storage.readGate = Completer<String?>();
      await tester.tap(find.byKey(const ValueKey('photo-capture-retry-load')));
      await tester.pump();
      // When the read is still pending.
      // Then loading is visible independently of photo capability.
      expect(find.text('設定の読込: 読込中'), findsOneWidget);
      expect(controller.busy, isTrue);
      // Given completion with the actual error.
      storage.readGate!.completeError(
        StateError('actual settings read failure'),
      );
      storage.readGate = null;
      // When the controller's retry settles.
      await tester.runAsync(() => _waitIdle(controller));
      await tester.pumpAndSettle();
      // Then the fixed UI message and actual snapshot error remain visible while capture stays blocked.
      expect(find.text('設定の読込: 読込失敗'), findsOneWidget);
      expect(
        find.text('設定を読み込めませんでした。'),
        findsOneWidget,
      );
      expect(find.textContaining('actual settings read failure'), findsNothing);
      expect(view.snapshot.readError, isA<StateError>());
      expect(view.snapshot.readError.toString(), contains('actual settings read failure'));
      expect(camera.captures, 0);
      // Given supported storage and a failing next write.
      storage.writeError = StateError('actual settings save failure');
      // When explicit read retry succeeds and enhanced intent is selected.
      await _command(tester, controller, 'retry-load');
      controller.selectConfiguration('pixelEnhanced');
      await tester.runAsync(_settle);
      await tester.pumpAndSettle();
      // Then the independent save failure/unsaved state is visible.
      expect(find.text('設定の読込: 読込済み'), findsOneWidget);
      expect(find.text('設定の保存: 保存失敗'), findsOneWidget);
      expect(find.text('未保存の設定があります'), findsOneWidget);
      expect(
        find.text('設定を保存できませんでした。'),
        findsOneWidget,
      );
      expect(find.textContaining('actual settings save failure'), findsNothing);
      expect(view.snapshot.saveError, isA<StateError>());
      expect(view.snapshot.saveError.toString(), contains('actual settings save failure'));
      // Given the same failing storage.
      // When a UI retry Future settles normally according to Core's contract.
      await _command(tester, controller, 'retry-save');
      // Then UI still says unsaved and never claims durability.
      expect(find.text('未保存の設定があります'), findsOneWidget);
      expect(find.text('設定の保存: 保存失敗'), findsOneWidget);
      expect(find.text('設定を保存できませんでした。'), findsOneWidget);
      expect(find.textContaining('actual settings save failure'), findsNothing);
      // Given a held successful write retry.
      storage.writeError = null;
      storage.writeGate = Completer<void>();
      await tester.ensureVisible(
        find.byKey(const ValueKey('photo-capture-retry-save')),
      );
      await tester.tap(find.byKey(const ValueKey('photo-capture-retry-save')));
      await tester.pump();
      await tester.runAsync(_settle);
      await tester.pump();
      // When actual acknowledgement is pending.
      // Then saving is rendered alongside unsaved state.
      expect(find.text('設定の保存: 保存中'), findsOneWidget);
      expect(find.text('未保存の設定があります'), findsOneWidget);
      // Given actual storage acknowledgement.
      storage.writeGate!.complete();
      // When the retry settles.
      await tester.runAsync(() => _waitIdle(controller));
      await tester.pumpAndSettle();
      // Then the UI follows the acknowledged snapshot and settings commands emitted no result callbacks.
      expect(find.text('設定は保存済みです'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('photo-capture-retry-save')),
        findsNothing,
      );
      expect(callbacks, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'W3 unsupported camera/settings permit existing history display and readiness refresh',
    (tester) async {
      // Given a real saved report before camera support is lost and settings are unsupported.
      final saved = await tester.runAsync(
        () => facade.capture(desiredConfigurationId: 'androidStandard'),
      );
      camera.supported = false;
      storage.record = _preference('pixelEnhanced', version: 99);
      await tester.runAsync(controller.initialize);
      await tester.runAsync(() => controller.loadComparison(saved!.id));
      await tester.pumpWidget(_host(controller));
      // When the borrowed panel displays saved history and independent readiness.
      await _command(tester, controller, 'refresh');
      // Then saved output remains readable with acquisition and saved inference blocked by settings.
      expect(find.text('この端末では撮影を利用できません'), findsOneWidget);
      expect(find.text('設定の読込: 利用不可'), findsOneWidget);
      expect(find.text('比較ID: ${saved!.id}'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('photo-capture-retry-load')),
        findsOneWidget,
      );
      for (final id in ['capture', 'recover', 'recognize', 'compare']) {
        // Given an acquisition/inference control while settings are unsupported.
        // When its callback is inspected.
        // Then the read barrier disables it even though saved output is displayed.
        expect(
          tester
              .widget<ElevatedButton>(find.byKey(ValueKey('photo-capture-$id')))
              .onPressed,
          isNull,
        );
      }
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('photo-capture-refresh')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'W4 raw empty stages duplicates failures fallback sharing and provenance fit large text',
    (tester) async {
      // Given controlled completed empty stages and an enhanced output containing opaque duplicates/failure.
      standard.output = ImageRecognitionResult(
        text: '',
        barcodeCompleted: true,
      );
      enhanced.output = ImageRecognitionResult(
        interpretation: '',
        candidateOrganizationCompleted: true,
        candidates: [
          RecognitionCandidate(kind: 'unknown kind', value: ' same raw '),
          RecognitionCandidate(kind: 'unknown kind', value: ' same raw '),
        ],
        failures: [
          ImageRecognitionFailure(
            stage: ImageRecognitionStage.cleanup,
            code: 'rawCode',
            message: 'raw failure message',
          ),
        ],
      );
      await tester.runAsync(controller.initialize);
      final original = await tester.runAsync(controller.capture);
      final comparison = await tester.runAsync(controller.compareCurrent);
      final raw = RecognitionComparison(
        id: 'rawDisplay',
        material: original!.material,
        createdAt: _time,
        runs: comparison!.runs,
        extensions: {
          'opaque': [
            ' preserve ',
            null,
            {
              'ordered': [2, 1],
            },
          ],
        },
      );
      // When a pure view displays the report at a narrow width and large text scale.
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    RecognitionComparisonView(comparison: raw),
                    PhotoCapturePanel(controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // Then empty completed output and all raw stages remain explicit and error-free.
      expect(find.text('OCR: ""'), findsWidgets);
      expect(find.text('バーコード認識: 完了'), findsWidgets);
      expect(
        find.text('候補の整理: 未完了'),
        findsWidgets,
      );
      expect(find.text('画像の解釈結果: ""'), findsWidgets);
      expect(
        find.text('候補 0: 種類 "unknown kind"; 値 " same raw "'),
        findsWidgets,
      );
      expect(
        find.text('候補 1: 種類 "unknown kind"; 値 " same raw "'),
        findsWidgets,
      );
      expect(
        find.text('失敗: 後処理 (cleanup) / rawCode / raw failure message'),
        findsWidgets,
      );
      expect(find.textContaining('共通処理'), findsWidgets);
      expect(
        find.textContaining('入力の試行ID: ["recognition'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      // Given expandable provenance and scrollable embedding.
      // When provenance expands and the acquisition controls are brought into view.
      await tester.ensureVisible(find.text('出典の詳細').first);
      await tester.tap(find.text('出典の詳細').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(jsonEncode(raw.extensions)));
      await tester.ensureVisible(
        find.byKey(const ValueKey('photo-capture-capture')),
      );
      // Then verbatim JSON and reachable controls coexist without Flutter layout errors.
      expect(find.text(jsonEncode(raw.extensions)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('photo-capture-capture')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // Given completed empty candidate organization from the next enhanced invocation.
      enhanced.output = ImageRecognitionResult(
        interpretation: '',
        candidateOrganizationCompleted: true,
      );
      // When the original is recognized as enhanced and displayed.
      controller.selectConfiguration('pixelEnhanced');
      final empty = await tester.runAsync(controller.recognizeCurrent);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecognitionComparisonView(comparison: empty!),
            ),
          ),
        ),
      );
      // Then empty completed candidates are explicitly represented.
      expect(
        find.text('候補の整理: 完了'),
        findsOneWidget,
      );
      expect(find.text('候補数: 0'), findsNWidgets(2));
      // Given enhanced unavailability on a later same-original comparison.
      enhanced.state = RecognitionProviderState.unavailable;
      // When common comparison renders the Core fallback report.
      final fallback = await tester.runAsync(controller.compareCurrent);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecognitionComparisonView(comparison: fallback!),
            ),
          ),
        ),
      );
      // Then unavailable nonexecuted work and explicit fallback reason are visible.
      expect(find.text('実際の構成: androidStandard'), findsNWidgets(2));
      expect(
        find.textContaining('標準処理への切替理由: geminiNano:'),
        findsOneWidget,
      );
      expect(find.text('認識処理: geminiNano; 未実行'), findsOneWidget);
      expect(find.text('利用状態: 利用不可'), findsOneWidget);
      expect(find.textContaining('失敗: 利用可否 (availability) /'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'W5 unmounted panel suppresses held completion callback and borrows dependencies',
    (tester) async {
      // Given a panel with a camera acquisition held by its borrowed controller.
      final callbacks = <RecognitionComparison>[];
      await tester.runAsync(controller.initialize);
      camera.gate = Completer<CapturedPhoto?>();
      await tester.pumpWidget(_host(controller, onComparison: callbacks.add));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('photo-capture-capture')));
      });
      await tester.pump();
      // When the panel unmounts before Core finishes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        camera.gate!.complete(_photo());
        await _waitIdle(controller);
      });
      // Then the borrowed controller accepts durable completion but no late UI callback is sent.
      expect(callbacks, isEmpty);
      expect(controller.comparison, isNotNull);
      expect(tester.takeException(), isNull);
      // Given dependencies whose lifetime remains owned by the fixture.
      camera.gate = null;
      // When settings and service are used after unmount.
      view.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
      await tester.runAsync(view.retrySave);
      final saved = await tester.runAsync(
        () => facade.capture(desiredConfigurationId: 'androidStandard'),
      );
      // Then neither dependency was disposed by the widget.
      expect(saved, isNotNull);
      expect(controller.desiredConfigurationId, 'pixelEnhanced');
    },
  );

  testWidgets(
    'W5 replaced controller suppresses old callbacks and detaches its listener',
    (tester) async {
      // Given an initialized panel holding acquisition on the first controller.
      final oldCallbacks = <RecognitionComparison>[];
      final newCallbacks = <RecognitionComparison>[];
      await tester.runAsync(controller.initialize);
      camera.gate = Completer<CapturedPhoto?>();
      await tester.pumpWidget(
        _host(controller, onComparison: oldCallbacks.add),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('photo-capture-capture')));
      });
      await tester.pump();
      final nextCamera = _Camera();
      final nextSettings = _settings(_SettingsStorage());
      final nextView = SettingsView.fromService(service: nextSettings);
      final next = (await tester.runAsync(
        () async => PhotoCaptureController(
          settings: nextView,
          facade: PhotoCaptureFacade(
            service: _service(
              nextCamera,
              _Provider(),
              _Provider(enhanced: true),
              store,
            ),
          ),
        ),
      ))!;
      await tester.runAsync(next.initialize);
      // When the same panel element replaces its borrowed controller before old completion.
      await tester.pumpWidget(_host(next, onComparison: newCallbacks.add));
      await tester.runAsync(() async {
        camera.gate!.complete(_photo());
        await _waitIdle(controller);
      });
      await tester.pump();
      // Then old durable work causes no late callback or notification error in the new panel.
      expect(oldCallbacks, isEmpty);
      expect(newCallbacks, isEmpty);
      expect(controller.comparison, isNotNull);
      expect(next.comparison, isNull);
      expect(tester.takeException(), isNull);
      // Given the new controller remains independently usable.
      // When a new UI capture succeeds and the panel is detached.
      await _command(tester, next, 'capture');
      await tester.pumpWidget(const SizedBox.shrink());
      // Then exactly its own successful report is sent and borrowed settings
      // remain usable.
      expect(newCallbacks, [next.comparison]);
      nextView.setValue(RecognitionSettings.configuration.id, 'pixelEnhanced');
      expect(next.desiredConfigurationId, 'pixelEnhanced');
      next.dispose();
      nextView.dispose();
      nextSettings.dispose();
    },
  );
}

// Compose the borrowed photo panel and pure caller admission in a scrollable host.
Widget _host(
  PhotoCaptureController controller, {
  ValueChanged<RecognitionComparison>? onComparison,
  bool Function()? interactionAllowed,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: PhotoCapturePanel(
        controller: controller,
        onComparison: onComparison,
        interactionAllowed: interactionAllowed,
      ),
    ),
  ),
);

// Snapshot camera, provider, filesystem and settings effects independently.
List<int> _photoEffects(
  _Camera camera,
  _Provider standard,
  _Provider enhanced,
  _Store store,
  _SettingsStorage storage,
) {
  final values = [
    camera.captures,
    camera.recoveries,
    standard.probes,
    enhanced.probes,
    standard.prepares,
    enhanced.prepares,
    standard.inputs.length,
    enhanced.inputs.length,
    store.imports,
    store.reads,
    store.writes,
    storage.reads,
    storage.writes,
  ];
  expect(values.every((value) => value >= 0), isTrue);
  return values;
}

// Join a finite released controller command before fixture disposal.
Future<void> _waitIdle(PhotoCaptureController controller) async {
  final watch = Stopwatch()..start();
  while (controller.busy) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      throw StateError('Held fixture did not settle');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(controller.busy, isFalse);
}

// Reveal/tap an explicit photo control and join its real command.
Future<void> _command(
  WidgetTester tester,
  PhotoCaptureController controller,
  String id,
) async {
  final control = find.byKey(ValueKey('photo-capture-$id'));
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(control);
    await _waitIdle(controller);
  });
  await tester.pumpAndSettle();
}

final _time = DateTime.utc(2026, 10, 6);
CapturedPhoto _photo() => CapturedPhoto(
  bytes: Uint8List.fromList([1, 2, 3]),
  mediaType: 'image/jpeg',
  capturedAt: _time,
  originalName: 'original.jpg',
);

final class _Camera implements CameraProvider {
  bool supported = true;
  CapturedPhoto? photo = _photo();
  Object? error;
  Completer<CapturedPhoto?>? gate;
  int captures = 0;
  int recoveries = 0;
  @override
  bool get isSupported => supported;
  @override
  // Count capture and return the controlled original/gate or actual configured fault.
  Future<CapturedPhoto?> capturePhoto() async {
    captures++;
    if (error != null) {
      throw error!;
    }
    return gate == null ? photo : gate!.future;
  }

  @override
  // Count recovery independently and return its configured original or fault.
  Future<CapturedPhoto?> recoverLostPhoto() async {
    recoveries++;
    if (error != null) {
      throw error!;
    }
    return photo;
  }
}

final class _Provider
    implements ImageRecognitionProvider, ImageRecognitionProviderProvenance {
  _Provider({this.enhanced = false});
  final bool enhanced;
  RecognitionProviderState state = RecognitionProviderState.available;
  Object? prepareError;
  Object? provenanceError;
  Completer<void>? prepareGate;
  int probes = 0;
  int prepares = 0;
  final inputs = <ImageRecognitionInput>[];
  ImageRecognitionResult? output;
  @override
  RecognitionProviderDescriptor get descriptor => RecognitionProviderDescriptor(
    id: enhanced ? 'geminiNano' : 'mlkitStandard',
    label: enhanced ? 'Enhanced' : 'Standard',
    capabilities: enhanced
        ? {
            RecognitionCapability.imageInterpretation,
            RecognitionCapability.candidateOrganization,
          }
        : {RecognitionCapability.ocr, RecognitionCapability.barcodes},
  );
  @override
  // Retain raw ordered provenance or throw its configured actual failure.
  Map<String, Object?> get provenance {
    if (provenanceError != null) {
      throw provenanceError!;
    }
    return {
      'model': 'fixture-model',
      'opaque': [true, null, ' raw '],
    };
  }

  @override
  // Count readiness observation and return the literal provider descriptor/state.
  Future<RecognitionProviderAvailability> availability() async {
    probes++;
    return RecognitionProviderAvailability(
      providerId: descriptor.id,
      state: state,
      capabilities: descriptor.capabilities,
      modelName: 'fixture-model',
      reason: state == RecognitionProviderState.unavailable
          ? 'not supported here'
          : null,
    );
  }

  @override
  // Count/join explicit preparation; only successful completion marks availability.
  Future<void> prepare() async {
    prepares++;
    if (prepareGate != null) {
      await prepareGate!.future;
    }
    if (prepareError != null) {
      throw prepareError!;
    }
    state = RecognitionProviderState.available;
  }

  @override
  // Retain exact input and return the controlled raw provider result.
  Future<ImageRecognitionResult> recognize(ImageRecognitionInput input) async {
    inputs.add(input);
    return output ??
        (enhanced
            ? ImageRecognitionResult(
                interpretation: ' raw interpretation ',
                candidateOrganizationCompleted: true,
                candidates: [
                  RecognitionCandidate(
                    kind: 'unknown kind',
                    value: ' opaque proposal ',
                  ),
                  RecognitionCandidate(
                    kind: 'unknown kind',
                    value: ' opaque proposal ',
                  ),
                  RecognitionCandidate(kind: 'isbn', value: 'not validated'),
                ],
              )
            : ImageRecognitionResult(
                text: ' raw OCR ',
                barcodeCompleted: true,
                barcodes: [
                  RecognizedImageBarcode(
                    value: ' second ',
                    format: 'rawFormat',
                  ),
                  RecognizedImageBarcode(
                    value: 'first',
                    format: 'anotherFormat',
                  ),
                ],
              ));
  }
}

final class _Store implements LocalCaptureStore {
  _Store(this.delegate);
  final LocalCaptureStore delegate;
  Object? writeError;
  Object? readError;
  int writes = 0;
  int imports = 0;
  int reads = 0;
  @override
  // Count exact original import and delegate to real private storage.
  Future<CaptureMaterialReference> saveMaterial({
    required Uint8List bytes,
    required String mediaType,
    required DateTime capturedAt,
    String? originalName,
  }) {
    imports++;
    return delegate.saveMaterial(
      bytes: bytes,
      mediaType: mediaType,
      capturedAt: capturedAt,
      originalName: originalName,
    );
  }

  @override
  // Count original-byte reads before real filesystem delegation.
  Future<Uint8List> readMaterial(CaptureMaterialReference reference) {
    reads++;
    return delegate.readMaterial(reference);
  }

  @override
  // Count report writes; configured failure precedes real durable delegation.
  Future<void> saveDocument(
    String collection,
    String id,
    Map<String, Object?> document,
  ) async {
    writes++;
    if (writeError != null) {
      throw writeError!;
    }
    await delegate.saveDocument(collection, id, document);
    expect(await delegate.readDocument(collection, id), document);
  }

  @override
  // Preserve actual report read failure or delegate the exact document identity.
  Future<Map<String, Object?>?> readDocument(
    String collection,
    String id,
  ) async {
    if (readError != null) {
      throw readError!;
    }
    return delegate.readDocument(collection, id);
  }

  @override
  Future<List<String>> listDocumentIds(String collection) =>
      delegate.listDocumentIds(collection);
}

var _serviceIdentities = 0;
PhotoCaptureService _service(
  _Camera camera,
  _Provider standard,
  _Provider enhanced,
  LocalCaptureStore store,
) {
  final serviceIdentity = _serviceIdentities++;
  var tick = 0;
  var identity = 0;
  return PhotoCaptureService(
    camera: CameraService(provider: camera),
    recognition: ImageRecognitionService(
      registry: RecognitionProviderRegistry(providers: [standard, enhanced]),
      clock: () => _time.add(Duration(milliseconds: tick++ * 7)),
      idGenerator: () => 'recognition${serviceIdentity}_${identity++}',
    ),
    store: store,
  );
}

final class _SettingsStorage implements SettingsStorage {
  String? record;
  Object? readError;
  Object? writeError;
  Completer<String?>? readGate;
  Completer<void>? writeGate;
  int reads = 0;
  int writes = 0;
  @override
  // Count settings reads and return the controlled record, gate or actual fault.
  Future<String?> read() async {
    reads++;
    if (readError != null) {
      throw readError!;
    }
    return readGate == null ? record : readGate!.future;
  }

  @override
  // Count/join the settings write; update the retained record only after successful completion.
  Future<void> write(String value) async {
    writes++;
    if (writeGate != null) {
      await writeGate!.future;
    }
    if (writeError != null) {
      throw writeError!;
    }
    record = value;
  }
}

SettingsLifecycleController _settings(_SettingsStorage storage) =>
    SettingsLifecycleController(
      registry: RecognitionSettings.registry(),
      storage: storage,
      resetDefinitions: RecognitionSettings.definitions,
    );

String _preference(String desired, {int version = 1}) => SettingsRecord.empty()
    .withUpdates({RecognitionSettings.configuration.id: desired})
    .encode()
    .replaceFirst('"version":1', '"version":$version');

Future<void> _settle() => Future<void>.delayed(Duration.zero);
