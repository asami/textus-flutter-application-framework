import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';

const configuration = ResourceListDetailConfiguration(
  listTitle: 'Collecting Resources',
  detailTitle: 'Capture Detail',
  primaryField: 'title',
  secondaryField: 'stage',
  detailFields: [
    ResourceFieldConfiguration(key: 'title', label: 'Title'),
    ResourceFieldConfiguration(key: 'stage', label: 'Capture stage'),
    ResourceFieldConfiguration(key: 'description', label: 'Description'),
  ],
);
const editKey = Key('cncf-display-edit');
const editorKey = Key('cncf-display-editor');
const saveKey = Key('cncf-display-save');
const cancelKey = Key('cncf-display-cancel');
const reloadKey = Key('cncf-display-reload');
const titleKey = ValueKey(('cncf-display-field', 'main', 'title'));
const descriptionKey = ValueKey(('cncf-display-field', 'main', 'description'));

void main() {
  for (final width in [400.0, 1000.0]) {
    testWidgets(
      'common modal roundtrip preserves List Detail identity at $width',
      (tester) async {
        // Given actual common List/Detail, borrowed layout, and genuine Japanese rows.
        final fixture = session(tester);
        final display = ResourceListDetailDisplayModel();
        addTearDown(display.dispose);
        await mount(tester, fixture, width: width, display: display);
        expect(fixture.requests, hasLength(1));
        expect(fixture.requests.single.url.path, endsWith('query.json'));
        expect(fixture.puts, isEmpty);
        await tester.tap(find.text('日本の民話'));
        await tester.pumpAndSettle();
        final listDetailState = tester.state(find.byType(ResourceListDetail));
        final captured = fixture.source.lastDetail;
        final descriptor = fixture.hold('descriptor');
        // When Edit is tapped, the actual route immediately protects underlying selection.
        await tester.tap(find.byKey(editKey));
        await tester.pump();
        final editorFinder = find.byKey(editorKey, skipOffstage: false);
        for (
          var frame = 0;
          frame < 5 && editorFinder.evaluate().isEmpty;
          frame++
        ) {
          await tester.pump();
        }
        expect(editorFinder, findsOneWidget);
        final editorRoute = ModalRoute.of(tester.element(editorFinder))!;
        for (
          var animationFrame = 0;
          animationFrame < 120 &&
              editorRoute.animation?.status != AnimationStatus.completed;
          animationFrame++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(editorRoute.animation?.status, AnimationStatus.completed);
        await tester.pump();
        await descriptor.entered.future;
        expect(find.byKey(editorKey), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(fixture.controller.observation, same(captured));
        descriptor.release();
        await tester.pumpAndSettle();
        // Then ordered producer labels, readonly stage and required hint are rendered.
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('Title *'), findsOneWidget);
        expect(find.text('Capture stage'), findsOneWidget);
        expect(find.text('収集中'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(titleKey)).dy,
          lessThan(tester.getTopLeft(find.text('Capture stage')).dy),
        );
        expect(
          tester.getTopLeft(find.text('Capture stage')).dy,
          lessThan(tester.getTopLeft(find.byKey(descriptionKey)).dy),
        );
        // When exact Text is saved and the first safe read is deliberately held.
        const exact = '  日本の民話・改訂\t\n😀  ';
        await tester.enterText(find.byKey(titleKey), exact);
        final read = fixture.hold('read');
        await tester.ensureVisible(find.byKey(saveKey));
        await tester.tap(find.byKey(saveKey));
        await tester.pump();
        await read.entered.future;
        expect(fixture.controller.receipt!.revision, '2');
        expect(find.text('Committed updated, revision 2'), findsOneWidget);
        expect(fixture.puts, hasLength(1));
        expect(fixture.puts.single.headers['If-Match'], '"revision-1"');
        expect(
          tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byKey(cancelKey)).onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(editorKey), findsOneWidget);
        expect(fixture.puts, hasLength(1));
        read.release();
        await tester.pumpAndSettle();
        // Then the same common List/Detail state returns with coherent revision2 data.
        expect(find.byKey(editorKey), findsNothing);
        expect(
          tester.state(find.byType(ResourceListDetail)),
          same(listDetailState),
        );
        expect(fixture.viewModel.selectedId, fixture.id);
        expect(fixture.viewModel.selectedResource!.value('title'), exact);
        expect(find.text(exact), findsWidgets);
        expect(fixture.source.lastDetail!.resources.single.revision, '2');
        expect(fixture.source.lastQuery!.resources.first.revision, '2');
        expect(
          find.text(width == 400 ? 'Capture Detail' : 'Collecting Resources'),
          findsOneWidget,
        );
        expect(fixture.puts, hasLength(1));
        if (width == 1000) {
          expect(find.text('地域資料目録'), findsOneWidget);
        }
        // When unmounted, then all borrowed layout/View/transport owners remain usable.
        await tester.pumpWidget(const SizedBox.shrink());
        display.focusDetail();
        await fixture.viewModel.load();
        expect((await fixture.client.query()).resources, hasLength(2));
        expect(
          display.preference,
          ResourceListDetailDisplayPreference.detailFocused,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('dirty cancel and back require one discard decision at $width', (
      tester,
    ) async {
      // Given a current modal editor with an exact dirty Text draft.
      final fixture = session(tester);
      await mount(tester, fixture, width: width);
      await openEditor(tester);
      await tester.enterText(find.byKey(titleKey), ' retained draft ');
      // When Cancel is selected and the confirmation is declined.
      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      // Then the current route and its exact draft survive without command I/O.
      expect(find.byKey(editorKey), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(titleKey)).controller!.text,
        ' retained draft ',
      );
      expect(fixture.controller.draftValues[mutationTitle], ' retained draft ');
      expect(fixture.puts, isEmpty);
      // When system Back asks once and explicit Discard is accepted.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      // Then only the current editor closes and actual Detail retains selection.
      expect(find.byKey(editorKey), findsNothing);
      expect(fixture.controller.editorOpen, isFalse);
      expect(fixture.viewModel.selectedId, fixture.id);
      expect(
        find.text(width == 400 ? 'Capture Detail' : 'Collecting Resources'),
        findsOneWidget,
      );
      expect(fixture.puts, isEmpty);
    });
  }

  testWidgets(
    'common editable rejection presents scoped safe error then explicit next Save',
    (tester) async {
      // Given a modal editor whose server rejects title with an approved scoped code.
      final fixture = session(tester);
      await mount(tester, fixture);
      await openEditor(tester);
      fixture.updateResponse = (_) async => fixture.failureReply();
      await tester.enterText(find.byKey(titleKey), 'bad');
      // When the common Save is explicitly selected.
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      // Then fixed field text appears without raw Conclusion prose or automatic retry.
      expect(
        find.text('Invalid value (DSP96_MUTATION_VALUE_INVALID)'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(fixture.puts, hasLength(1));
      expect(fixture.controller.draftValues[mutationTitle], 'bad');
      // When the input is corrected, only the next explicit Save sends again.
      await tester.enterText(find.byKey(titleKey), 'corrected 日本語');
      await tester.pump();
      expect(
        find.text('Invalid value (DSP96_MUTATION_VALUE_INVALID)'),
        findsNothing,
      );
      expect(fixture.puts, hasLength(1));
      fixture.updateResponse = null;
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      expect(fixture.puts, hasLength(2));
      expect(find.byKey(editorKey), findsNothing);
    },
  );

  testWidgets(
    'producer placeholder help and required hints survive without local domain validation',
    (tester) async {
      // Given inert producer hints including a pattern which grants no authority.
      final fixture = session(tester);
      final title = (fixture.descriptorData['fields']! as List).first as Map;
      final web = title['web'] as Map;
      web['placeholder'] = 'Title placeholder';
      web['help'] = 'Producer help';
      (web['validation'] as Map)['pattern'] = r'^server-only$';
      await mount(tester, fixture);
      // When the actual common Editor renders that descriptor.
      await openEditor(tester);
      final text = tester.widget<TextField>(find.byKey(titleKey));
      // Then hints/labels are preserved without pattern-based authorization or coercion.
      expect(text.decoration!.labelText, 'Title *');
      expect(text.decoration!.hintText, 'Title placeholder');
      expect(text.decoration!.helperText, 'Producer help');
      await tester.enterText(find.byKey(titleKey), 'not-the-pattern');
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      expect(fixture.puts, hasLength(1));
      expect(
        fixture.viewModel.selectedResource!.value('title'),
        'not-the-pattern',
      );
    },
  );

  testWidgets(
    'pending known commit survives safe Reload failure and resolves without replay',
    (tester) async {
      // Given an editor with a controlled committed-pending result.
      final fixture = session(tester);
      await mount(tester, fixture);
      await openEditor(tester);
      fixture.pending = true;
      await tester.enterText(find.byKey(titleKey), 'accepted pending');
      // When Save receives the receipt, then the route offers Reload with Save disabled.
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      expect(find.text('Committed; projection pending'), findsOneWidget);
      expect(find.text('Committed updated, revision 2'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
        isNull,
      );
      expect(fixture.requests.last.method, 'PUT');
      fixture.failQuery = true;
      // When explicit safe Reload fails, then receipt and accepted draft are retained.
      await tester.ensureVisible(find.byKey(reloadKey));
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      expect(fixture.controller.receipt!.revision, '2');
      expect(find.byKey(editorKey), findsOneWidget);
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.puts, hasLength(1));
      // When the next explicit safe Reload is coherent, then Detail returns with one PUT total.
      fixture.failQuery = false;
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      expect(find.byKey(editorKey), findsNothing);
      expect(fixture.controller.receipt!.revision, '2');
      expect(fixture.puts, hasLength(1));
    },
  );

  for (final kind in ['conflict', 'unknown', 'malformed']) {
    testWidgets(
      '$kind stays pinned after coherent Reload until explicit discard',
      (tester) async {
        // Given a common editor with controlled command uncertainty or structured conflict.
        final fixture = session(tester);
        await mount(tester, fixture);
        await openEditor(tester);
        fixture.updateResponse = (_) async => kind == 'conflict'
            ? fixture.failureReply(conflict: true, status: 400)
            : kind == 'malformed'
            ? mutationRawReply('{"data":{}}')
            : throw StateError('PRIVATE network detail');
        await tester.enterText(find.byKey(titleKey), 'old pinned draft');
        // When one Save fails and explicit Reload obtains coherent safe reads.
        await tester.tap(find.byKey(saveKey));
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
          isNull,
        );
        expect(find.textContaining('PRIVATE'), findsNothing);
        await tester.ensureVisible(find.byKey(reloadKey));
        await tester.tap(find.byKey(reloadKey));
        await tester.pumpAndSettle();
        // Then neither a new observation nor a retry replaces the old draft.
        expect(find.byKey(editorKey), findsOneWidget);
        expect(
          fixture.controller.draftValues[mutationTitle],
          'old pinned draft',
        );
        expect(
          tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
          isNull,
        );
        expect(fixture.puts, hasLength(1));
        // When explicitly discarded, a subsequent Edit starts with current producer values.
        await tester.tap(find.byKey(cancelKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(editKey));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byKey(titleKey)).controller!.text,
          '日本の民話',
        );
        expect(fixture.puts, hasLength(1));
      },
    );
  }

  testWidgets(
    'closed pending editor keeps receipt and safe Reload in common failed Detail',
    (tester) async {
      // Given a known pending commit in the modal and a future Detail read failure.
      final fixture = session(tester);
      await mount(tester, fixture);
      await openEditor(tester);
      fixture.pending = true;
      await tester.enterText(find.byKey(titleKey), 'pending');
      await tester.tap(find.byKey(saveKey));
      await tester.pumpAndSettle();
      // When dirty Cancel is explicitly discarded, the receipt obligation outlives the route.
      await tester.tap(find.byKey(cancelKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byKey(editorKey), findsNothing);
      expect(find.text('Committed updated, revision 2'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(editKey)).onPressed, isNull);
      fixture.failRead = true;
      // When common toolbar Reload fails, then existing diagnostics and receipt coexist.
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      expect(find.text('詳細を読み込めませんでした。'), findsOneWidget);
      expect(find.text('Committed updated, revision 2'), findsOneWidget);
      expect(find.byKey(reloadKey), findsOneWidget);
      expect(fixture.controller.receipt!.revision, '2');
      fixture.failRead = false;
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.puts, hasLength(1));
    },
  );

  testWidgets(
    'busy command rejects repeated Save and Back without claiming cancellation',
    (tester) async {
      // Given a real Editor and a command held after its one transport dispatch.
      final fixture = session(tester);
      await mount(tester, fixture);
      await openEditor(tester);
      final command = fixture.hold('update');
      await tester.enterText(find.byKey(titleKey), 'busy');
      await tester.tap(find.byKey(saveKey));
      await tester.pump();
      await command.entered.future;
      // When another Save/Cancel/Back is attempted while delivery is unresolved.
      await tester.tap(find.byKey(saveKey));
      await tester.tap(find.byKey(cancelKey));
      await tester.binding.handlePopRoute();
      await tester.pump();
      // Then there is one command, no discard dialog, and the protected route remains.
      expect(fixture.puts, hasLength(1));
      expect(find.byKey(editorKey), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      command.release();
      await tester.pumpAndSettle();
      expect(find.byKey(editorKey), findsNothing);
      expect(fixture.puts, hasLength(1));
    },
  );

  for (final binding in ['replaced', 'removed']) {
    final operations = binding == 'replaced'
        ? ['descriptor', 'update', 'read']
        : ['update'];
    for (final operation in operations) {
      for (final dismissal in ['Cancel', 'Back']) {
        testWidgets(
          '$binding opener during held $operation preserves unrelated route then permits explicit $dismissal',
          (tester) async {
            // Given the actual Editor with a finite descriptor/command/refresh gate.
            final fixture = session(tester);
            final replacement = CncfDisplayMutationFixture();
            addTearDown(replacement.dispose);
            final navigation = GlobalKey<NavigatorState>();
            final root = ValueNotifier<Widget>(view(fixture));
            addTearDown(root.dispose);
            tester.view.physicalSize = const Size(1000, 800);
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: navigation,
                home: ValueListenableBuilder<Widget>(
                  valueListenable: root,
                  builder: (_, child, _) => child,
                ),
              ),
            );
            await tester.pumpAndSettle();
            MutationGate gate;
            if (operation == 'descriptor') {
              gate = fixture.hold('descriptor');
              await tester.tap(find.text('日本の民話'));
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(editKey));
            } else {
              await openEditor(tester);
              gate = fixture.hold(operation);
              await tester.enterText(find.byKey(titleKey), 'late');
              await tester.tap(find.byKey(saveKey));
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            await gate.entered.future;
            // When the opener is replaced/removed and another route becomes current.
            root.value = binding == 'replaced'
                ? view(replacement)
                : const SizedBox.shrink();
            await tester.pump();
            // Retirement must rebuild without relying on the held controller's notifier.
            await tester.pump();
            expect(find.byType(LinearProgressIndicator), findsNothing);
            expect(
              tester.widget<TextButton>(find.byKey(cancelKey)).onPressed,
              isNotNull,
            );
            expect(
              tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
              isNull,
            );
            for (final field in tester.widgetList<TextField>(
              find.byType(TextField),
            )) {
              expect(field.enabled, isFalse);
            }
            unawaited(
              navigation.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Unrelated route')),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            gate.release();
            await tester.pumpAndSettle();
            // Then old futures neither publish UI callbacks nor pop the unrelated route.
            expect(find.text('Unrelated route'), findsOneWidget);
            expect(replacement.controller.editorOpen, isFalse);
            expect(replacement.puts, isEmpty);
            expect(tester.takeException(), isNull);
            expect(fixture.puts, hasLength(operation == 'descriptor' ? 0 : 1));
            // When Back returns from the unrelated route, the retired Editor is current.
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('Unrelated route'), findsNothing);
            expect(find.byKey(editorKey), findsOneWidget);
            expect(find.byType(LinearProgressIndicator), findsNothing);
            expect(
              tester.widget<FilledButton>(find.byKey(saveKey)).onPressed,
              isNull,
            );
            final reload = find.byKey(reloadKey);
            if (reload.evaluate().isNotEmpty) {
              expect(tester.widget<TextButton>(reload).onPressed, isNull);
            }
            final originalRequests = fixture.requests.length;
            final replacementRequests = replacement.requests.length;
            final originalDraft = fixture.controller.draftValues;
            final originalReceipt = fixture.controller.receipt;
            final originalEditorOpen = fixture.controller.editorOpen;
            if (operation != 'descriptor') {
              expect(originalReceipt!.revision, '2');
            }
            // When the user explicitly dismisses this current retired route.
            if (dismissal == 'Cancel') {
              await tester.tap(find.byKey(cancelKey));
            } else {
              await tester.binding.handlePopRoute();
            }
            await tester.pumpAndSettle();
            // Then only that Editor closes, with no discard, command, or replacement action.
            expect(find.byKey(editorKey, skipOffstage: false), findsNothing);
            expect(find.text('Discard changes?'), findsNothing);
            expect(fixture.requests, hasLength(originalRequests));
            expect(fixture.puts, hasLength(operation == 'descriptor' ? 0 : 1));
            expect(fixture.controller.draftValues, same(originalDraft));
            expect(fixture.controller.receipt, same(originalReceipt));
            expect(fixture.controller.editorOpen, originalEditorOpen);
            expect(replacement.requests, hasLength(replacementRequests));
            expect(replacement.controller.editorOpen, isFalse);
            expect(replacement.controller.descriptor, isNull);
            expect(replacement.controller.observation, isNull);
            expect(replacement.controller.draftValues, isEmpty);
            expect(replacement.controller.receipt, isNull);
            expect(replacement.puts, isEmpty);
            expect(tester.takeException(), isNull);
            // When all routes unmount, the borrowed original client remains usable.
            await tester.pumpWidget(const SizedBox.shrink());
            expect((await fixture.client.query()).resources, hasLength(2));
          },
        );
      }
    }
  }

  testWidgets(
    'disposed controller ignores descriptor completion and permits explicit Back without owning callers',
    (tester) async {
      // Given an actual Editor with its descriptor held after route push.
      final fixture = session(tester);
      await mount(tester, fixture);
      await tester.tap(find.text('日本の民話'));
      await tester.pumpAndSettle();
      final gate = fixture.hold('descriptor');
      await tester.tap(find.byKey(editKey));
      await tester.pump();
      await gate.entered.future;
      // When controller disposal precedes descriptor completion.
      fixture.controller.dispose();
      gate.release();
      // The disposed controller deliberately emits no terminal UI notification;
      // observe bounded frames rather than waiting on its retired loading ticker.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Then no late notifier/navigation runs and borrowed source/client remain alive.
      expect(fixture.controller.descriptor, isNull);
      expect(find.byKey(editorKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      // When explicit system Back dismisses the current route despite stale busy state.
      expect(fixture.controller.busy, isTrue);
      final requests = fixture.requests.length;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      // Then the Editor closes without discard or any additional transport activity.
      expect(find.byKey(editorKey, skipOffstage: false), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
      expect(fixture.requests, hasLength(requests));
      expect(fixture.puts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.viewModel.select(fixture.id);
      expect((await fixture.client.query()).resources, isNotEmpty);
    },
  );
}

CncfDisplayMutationFixture session(WidgetTester tester) {
  final fixture = CncfDisplayMutationFixture();
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async {
    fixture.releaseAll();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    fixture.dispose();
  });
  return fixture;
}

Widget view(
  CncfDisplayMutationFixture fixture, {
  ResourceListDetailDisplayModel? display,
}) => CncfDisplayResourceView(
  configuration: configuration,
  viewModel: fixture.viewModel,
  mutationController: fixture.controller,
  displayModel: display,
);

Future<void> mount(
  WidgetTester tester,
  CncfDisplayMutationFixture fixture, {
  double width = 1000,
  ResourceListDetailDisplayModel? display,
}) async {
  tester.view.physicalSize = Size(width, 800);
  await tester.pumpWidget(MaterialApp(home: view(fixture, display: display)));
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester) async {
  // Given the visible producer row, when it and common Edit are explicitly tapped,
  // then the actual standard Editor owns the current modal route.
  await tester.tap(find.text('日本の民話'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(editKey));
  await tester.pumpAndSettle();
  expect(find.byKey(editorKey), findsOneWidget);
}
