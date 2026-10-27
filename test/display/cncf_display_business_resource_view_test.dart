import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';

const businessKey = Key('cncf-display-business-request-review');
const reloadKey = Key('cncf-display-reload');
const editKey = Key('cncf-display-edit');
const progressKey = Key('cncf-display-business-progress');
const titleKey = ValueKey(('cncf-display-field', 'main', 'title'));

ResourceListDetailConfiguration configuration({
  List<ResourceActionConfiguration>? actions,
}) => ResourceListDetailConfiguration(
  listTitle: 'Collecting Resources',
  detailTitle: 'Capture Detail',
  primaryField: 'title',
  secondaryField: 'stage',
  detailFields: const [
    ResourceFieldConfiguration(key: 'title', label: 'Title'),
    ResourceFieldConfiguration(key: 'stage', label: 'Capture stage'),
    ResourceFieldConfiguration(key: 'description', label: 'Description'),
  ],
  detailActions: actions,
);

Widget view(
  CncfDisplayMutationFixture fixture, {
  ResourceListDetailDisplayModel? display,
  List<ResourceActionConfiguration>? actions,
}) => CncfDisplayResourceView(
  configuration: configuration(actions: actions),
  viewModel: fixture.viewModel,
  mutationController: fixture.controller,
  displayModel: display,
);

CncfDisplayMutationFixture session(
  WidgetTester tester, {
  List<CncfDisplayBusinessBinding>? bindings,
}) {
  final fixture = CncfDisplayMutationFixture(
    businessBindings: bindings ?? [referenceBusinessBinding()],
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    fixture.releaseAll();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    fixture.dispose();
  });
  return fixture;
}

Future<void> select(WidgetTester tester) async {
  await tester.tap(find.text('日本の民話'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(editKey));
}

Future<void> tapBusiness(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(businessKey));
  await tester.tap(find.byKey(businessKey));
  await tester.pump();
}

Future<void> readyRoute(WidgetTester tester, Finder finder) async {
  for (var frame = 0; frame < 120; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty &&
        ModalRoute.of(tester.element(finder))?.animation?.status ==
            AnimationStatus.completed) {
      return;
    }
  }
  throw StateError('The actual route did not finish its bounded entrance');
}

void main() {
  for (final width in [400.0, 1000.0]) {
    testWidgets(
      'ordinary Business retains ACK until explicit Reload at $width with borrowed layout',
      (tester) async {
        // Given actual compact or expanded Detail with borrowed layout and held delivery.
        final fixture = session(tester);
        final display = ResourceListDetailDisplayModel();
        addTearDown(display.dispose);
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(home: view(fixture, display: display)),
        );
        await tester.pumpAndSettle();
        await select(tester);
        final state = tester.state(find.byType(ResourceListDetail));
        final observation = fixture.source.lastDetail;
        final gate = fixture.hold('business');
        // When one Business intent enters the held request.
        await tapBusiness(tester);
        await gate.entered.future;
        // Then the generic UI owns one ordinary POST and disables competing actions.
        expect(fixture.posts, hasLength(1));
        expect(
          fixture.posts.single.url.path,
          endsWith('reference-business/requestReview.json'),
        );
        expect(fixture.posts.single.headers['If-Match'], '"revision-1"');
        expect(fixture.controller.observation, same(observation));
        expect(find.byKey(progressKey), findsOneWidget);
        expect(
          tester.widget<TextButton>(find.byKey(businessKey)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byKey(editKey)).onPressed,
          isNull,
        );
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        // Given the held command and current layout presentation.
        final presentation = display.compactDetailRequested;
        // When Back or an underlying row is attempted.
        await tester.binding.handlePopRoute();
        await tester.pump();
        if (width == 1000) {
          await tester.tap(find.text('地域資料目録'), warnIfMissed: false);
          await tester.pump();
        }
        // Then selection and layout stay protected.
        expect(fixture.viewModel.selectedId, fixture.id);
        expect(display.compactDetailRequested, presentation);
        expect(fixture.posts, hasLength(1));
        expect(find.byType(ResourceListDetail), findsOneWidget);
        // When held delivery completes with an ordinary ACK.
        gate.release();
        await tester.pumpAndSettle();
        // Then the old Display stays visible with retained outcome and identity.
        expect(
          find.text('Committed review-requested, revision 2'),
          findsOneWidget,
        );
        expect(find.text('Affected resource: 日本の民話'), findsOneWidget);
        expect(find.text('収集中'), findsWidgets);
        final stageField = find.widgetWithText(ListTile, 'Capture stage');
        expect(stageField, findsOneWidget);
        expect(
          find.descendant(of: stageField, matching: find.text('収集中')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: stageField, matching: find.text('レビュー待ち')),
          findsNothing,
        );
        expect(fixture.source.lastDetail, same(observation));
        expect(fixture.requests, hasLength(3));
        expect(find.byKey(progressKey), findsNothing);
        expect(
          tester.widget<TextButton>(find.byKey(businessKey)).onPressed,
          isNull,
        );
        // When explicit common Reload returns coherent safe reads.
        await tester.tap(find.byKey(reloadKey));
        await tester.pumpAndSettle();
        // Then Japanese projection and the hidden action replace the old display.
        expect(find.text('レビュー待ち'), findsWidgets);
        expect(stageField, findsOneWidget);
        expect(
          find.descendant(of: stageField, matching: find.text('レビュー待ち')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: stageField, matching: find.text('収集中')),
          findsNothing,
        );
        expect(find.byKey(businessKey), findsNothing);
        expect(
          find.text('Committed review-requested, revision 2'),
          findsOneWidget,
        );
        expect(fixture.posts, hasLength(1));
        expect(fixture.puts, isEmpty);
        expect(fixture.controller.needsReconciliation, isFalse);
        expect(tester.state(find.byType(ResourceListDetail)), same(state));
        expect(display.compactDetailRequested, presentation);
        // When the common UI is unmounted and its borrowed owners are used.
        await tester.pumpWidget(const SizedBox.shrink());
        display.focusDetail();
        await fixture.viewModel.load();
        final query = await fixture.client.query();
        // Then layout, View, and transport remain usable.
        expect(
          display.preference,
          ResourceListDetailDisplayPreference.detailFocused,
        );
        expect(query.resources, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final title in <String?>['', '   ', null]) {
    testWidgets(
      '${title == null
          ? 'missing'
          : title.isEmpty
          ? 'empty'
          : 'whitespace-only'} title uses captured resource ID after ordinary Business',
      (tester) async {
        // Given an actual common view with a blank or Missing title and a trusted Business binding.
        final fixture = session(tester);
        if (title == null) {
          fixture.missingTitle = true;
        } else {
          fixture.values['title'] = title;
        }
        await tester.pumpWidget(MaterialApp(home: view(fixture)));
        await tester.pumpAndSettle();
        // When the first resource is selected by its unique visible secondary text and Business is invoked.
        await tester.tap(find.text('収集中'));
        await tester.pumpAndSettle();
        await tapBusiness(tester);
        await tester.pumpAndSettle();
        // Then the actual result falls back to the captured ID with one POST and no implicit reads.
        expect(find.text('Affected resource: ${fixture.id}'), findsOneWidget);
        expect(fixture.controller.businessReceipt!.resourceId, fixture.id);
        expect(fixture.posts, hasLength(1));
        expect(fixture.requests, hasLength(3));
        expect(fixture.puts, isEmpty);
      },
    );
  }

  for (final presentation in ['empty', 'null', 'override']) {
    testWidgets(
      '$presentation action presentation intersects trusted Business metadata',
      (tester) async {
        // Given a trusted binding and a configured action allowlist or label override.
        final fixture = session(tester);
        final actions = presentation == 'null'
            ? null
            : presentation == 'empty'
            ? <ResourceActionConfiguration>[]
            : [
                const ResourceActionConfiguration(
                  id: 'request-review',
                  label: 'レビューを依頼',
                ),
              ];
        // When the common view renders and formal Detail is selected.
        await tester.pumpWidget(
          MaterialApp(home: view(fixture, actions: actions)),
        );
        await tester.pumpAndSettle();
        await select(tester);
        // Then only permitted trusted actions use the configured presentation labels.
        expect(
          find.byKey(businessKey),
          presentation == 'empty' ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Request Review'),
          presentation == 'null' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('レビューを依頼'),
          presentation == 'override' ? findsOneWidget : findsNothing,
        );
        expect(fixture.posts, isEmpty);
        if (presentation != 'empty') {
          // When the presented Business action is tapped.
          await tapBusiness(tester);
          await tester.pumpAndSettle();
          // Then the same common binding dispatches one ordinary command.
          expect(fixture.posts, hasLength(1));
          expect(
            fixture.controller.businessReceipt!.outcome,
            'review-requested',
          );
        }
      },
    );
  }

  for (final availability in [
    'disabled',
    'hidden',
    'wrong-binding',
    'unregistered',
  ]) {
    testWidgets(
      '$availability wire action grants no extra execution authority',
      (tester) async {
        // Given disabled, hidden, mismatched, or unregistered action metadata.
        final fixture = session(
          tester,
          bindings: availability == 'unregistered' ? [] : null,
        );
        if (availability == 'wrong-binding') {
          fixture.actionBindingId = 'untrusted.binding';
        } else if (availability == 'disabled' || availability == 'hidden') {
          fixture.actionAvailability = availability;
        }
        // When common Detail renders for the selected resource.
        await tester.pumpWidget(MaterialApp(home: view(fixture)));
        await tester.pumpAndSettle();
        await select(tester);
        // Then only the disabled declaration remains visible and no command is sent.
        expect(
          find.byKey(businessKey),
          availability == 'disabled' ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Request Review'),
          availability == 'disabled' ? findsOneWidget : findsNothing,
        );
        expect(fixture.posts, isEmpty);
        if (availability == 'disabled') {
          // When the disabled button is inspected, then its callback cannot invoke anything.
          expect(
            tester.widget<TextButton>(find.byKey(businessKey)).onPressed,
            isNull,
          );
        }
      },
    );
  }

  testWidgets(
    'mutation2 followed by Business3 read failure shows only current receipt and read-only Reload',
    (tester) async {
      // Given a selected common Detail with a committed standard update at revision 2.
      final fixture = session(tester);
      await tester.pumpWidget(MaterialApp(home: view(fixture)));
      await tester.pumpAndSettle();
      await select(tester);
      await tester.tap(find.byKey(editKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(titleKey), 'updated title');
      await tester.ensureVisible(find.byKey(const Key('cncf-display-save')));
      await tester.tap(find.byKey(const Key('cncf-display-save')));
      await tester.pumpAndSettle();
      final prior = fixture.controller.receipt;
      // When Business returns its revision 3 ACK.
      await tapBusiness(tester);
      await tester.pumpAndSettle();
      // Then the current UI chooses the ordinary receipt over the older mutation receipt.
      expect(prior!.revision, '2');
      expect(
        find.text('Committed review-requested, revision 3'),
        findsOneWidget,
      );
      expect(find.text('Committed updated, revision 2'), findsNothing);
      // Given a failing Detail read.
      fixture.failRead = true;
      // When explicit toolbar Reload is attempted.
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      // Then Business revision 3 and the affected identity survive with Reload reachable.
      expect(find.text('Could not load resource'), findsOneWidget);
      expect(
        find.text('Committed review-requested, revision 3'),
        findsOneWidget,
      );
      expect(find.text('Affected resource: updated title'), findsOneWidget);
      expect(find.text('Committed updated, revision 2'), findsNothing);
      expect(find.byKey(reloadKey), findsOneWidget);
      expect(fixture.posts, hasLength(1));
      expect(fixture.puts, hasLength(1));
      expect(find.textContaining('PRIVATE'), findsNothing);
      // Given a restored coherent projection.
      fixture.failRead = false;
      // When explicit Reload succeeds.
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      // Then the projection reconciles without replaying either command.
      expect(find.text('レビュー待ち'), findsWidgets);
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.controller.receipt, same(prior));
      expect(fixture.posts, hasLength(1));
      expect(fixture.puts, hasLength(1));
    },
  );

  for (final kind in ['unknown', 'conflict', 'malformed']) {
    testWidgets(
      '$kind ordinary failure renders fixed text and safe explicit read without fake ACK',
      (tester) async {
        // Given an unknown, conflicting, or malformed ordinary command response.
        final fixture = session(tester);
        fixture.businessResponse = (_) async => kind == 'unknown'
            ? throw StateError('PRIVATE network')
            : kind == 'conflict'
            ? fixture.failureReply(conflict: true, status: 400)
            : mutationRawReply('{"data":{}}');
        await tester.pumpWidget(MaterialApp(home: view(fixture)));
        await tester.pumpAndSettle();
        await select(tester);
        // When Business is invoked and its failure renders.
        await tapBusiness(tester);
        await tester.pumpAndSettle();
        // Then fixed failure text appears without an ACK or private Conclusion.
        expect(find.textContaining('Committed'), findsNothing);
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(
          find.text(
            kind == 'conflict'
                ? 'The resource changed. Reload required.'
                : 'Could not complete the operation.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextButton>(find.byKey(businessKey)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byKey(editKey)).onPressed,
          isNull,
        );
        expect(fixture.posts, hasLength(1));
        // When explicit safe Reload returns current enabled Detail.
        await tester.tap(find.byKey(reloadKey));
        await tester.pumpAndSettle();
        // Then only a fresh user intent may send again; Reload does not replay the command.
        expect(fixture.controller.needsReconciliation, isFalse);
        expect(fixture.controller.businessReceipt, isNull);
        expect(
          tester.widget<TextButton>(find.byKey(businessKey)).onPressed,
          isNotNull,
        );
        expect(fixture.posts, hasLength(1));
      },
    );
  }

  testWidgets(
    'selection mismatch shows generic affected title and requires explicit original selection before Reload',
    (tester) async {
      // Given selected common Detail and a held Business request.
      final fixture = session(tester);
      await tester.pumpWidget(MaterialApp(home: view(fixture)));
      await tester.pumpAndSettle();
      await select(tester);
      final gate = fixture.hold('business');
      // When selection changes during dispatch and explicit Reload is attempted after ACK.
      await tapBusiness(tester);
      await gate.entered.future;
      await fixture.viewModel.select('other-resource');
      gate.release();
      await tester.pumpAndSettle();
      final requests = fixture.requests.length;
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      // Then fixed guidance identifies the captured generic title without read I/O.
      expect(
        find.text('Select the affected resource before Reload.'),
        findsOneWidget,
      );
      expect(find.text('Affected resource: 日本の民話'), findsOneWidget);
      expect(
        find.text('Committed review-requested, revision 2'),
        findsOneWidget,
      );
      expect(fixture.requests, hasLength(requests));
      expect(fixture.controller.needsReconciliation, isTrue);
      // When the original resource is explicitly selected and safe Reload is chosen.
      await fixture.viewModel.select(fixture.id);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      // Then the receipt reconciles without replay.
      expect(
        find.text('Select the affected resource before Reload.'),
        findsNothing,
      );
      expect(find.text('レビュー待ち'), findsWidgets);
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.posts, hasLength(1));
    },
  );

  for (final replacement in ['replaced', 'removed']) {
    testWidgets(
      '$replacement opener during held Business preserves unrelated route and replacement owners',
      (tester) async {
        // Given a selected opener, independent replacement owners, and held Business delivery.
        final fixture = session(tester);
        final other = CncfDisplayMutationFixture(
          businessBindings: [referenceBusinessBinding()],
        );
        addTearDown(other.dispose);
        final navigation = GlobalKey<NavigatorState>();
        final root = ValueNotifier<Widget>(view(fixture));
        addTearDown(root.dispose);
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
        await select(tester);
        final gate = fixture.hold('business');
        // When the opener is retired under an unrelated route before delivery completes.
        await tapBusiness(tester);
        await gate.entered.future;
        root.value = replacement == 'replaced'
            ? view(other)
            : const Text('Removed opener');
        await tester.pump();
        await tester.pump();
        unawaited(
          navigation.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Unrelated route')),
            ),
          ),
        );
        await readyRoute(tester, find.text('Unrelated route'));
        gate.release();
        await tester.pumpAndSettle();
        // Then navigation and replacement command state stay untouched.
        expect(find.text('Unrelated route'), findsOneWidget);
        expect(fixture.posts, hasLength(1));
        expect(fixture.requests, hasLength(3));
        expect(other.posts, isEmpty);
        expect(other.controller.businessOperation, isNull);
        expect(other.controller.businessReceipt, isNull);
        expect(other.controller.observation, isNull);
        expect(other.controller.editorOpen, isFalse);
        expect(tester.takeException(), isNull);
        // When explicit Back closes the unrelated route.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        // Then only the current replacement or removal is shown.
        expect(find.text('Unrelated route'), findsNothing);
        expect(find.byKey(progressKey), findsNothing);
        expect(
          find.byType(CncfDisplayResourceView),
          replacement == 'replaced' ? findsOneWidget : findsNothing,
        );
        expect(other.posts, isEmpty);
      },
    );
  }

  for (final pushed in [false, true]) {
    testWidgets(
      'disposed held Business explicit Back retires its own UI with pushed=$pushed',
      (tester) async {
        // Given a root or pushed common Detail and held Business delivery.
        final fixture = session(tester);
        final navigation = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigation,
            home: pushed
                ? const Scaffold(body: Text('Root remains'))
                : view(fixture),
          ),
        );
        await tester.pumpAndSettle();
        if (pushed) {
          unawaited(
            navigation.currentState!.push(
              MaterialPageRoute<void>(builder: (_) => view(fixture)),
            ),
          );
          await readyRoute(tester, find.byType(ResourceListDetail));
          await tester.pumpAndSettle();
        }
        await select(tester);
        final gate = fixture.hold('business');
        // When the controller is disposed while its request remains held.
        await tapBusiness(tester);
        await gate.entered.future;
        fixture.controller.dispose();
        await tester.pump();
        // Then the stale frame still shows its busy indicator without terminal notification.
        expect(find.byKey(progressKey), findsOneWidget);
        expect(fixture.posts, hasLength(1));
        final requests = fixture.requests.length;
        final route = ModalRoute.of(
          tester.element(find.byType(CncfDisplayResourceView)),
        )!;
        // When explicit Back retires the current disposed owner's stale UI.
        await tester.binding.handlePopRoute();
        await tester.pump();
        if (pushed) {
          for (
            var frame = 0;
            frame < 120 && route.animation?.status != AnimationStatus.dismissed;
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          // Then the pushed route finishes its exit animation.
          expect(route.animation?.status, AnimationStatus.dismissed);
          await tester.pump();
        } else {
          await tester.pump(const Duration(milliseconds: 400));
        }
        // Then only a real pushed route pops and the root never goes blank.
        expect(find.byKey(progressKey), findsNothing);
        expect(
          find.byType(CncfDisplayResourceView),
          pushed ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Root remains'),
          pushed ? findsOneWidget : findsNothing,
        );
        expect(navigation.currentState!.canPop(), isFalse);
        expect(fixture.requests, hasLength(requests));
        expect(fixture.posts, hasLength(1));
        // When a new unrelated route opens and the old delivery finishes.
        unawaited(
          navigation.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Text('Unrelated after retirement')),
            ),
          ),
        );
        await readyRoute(tester, find.text('Unrelated after retirement'));
        gate.release();
        await tester.pumpAndSettle();
        // Then no old future pops the unrelated route or repeats the POST.
        expect(find.text('Unrelated after retirement'), findsOneWidget);
        expect(fixture.requests, hasLength(requests));
        expect(fixture.posts, hasLength(1));
        expect(fixture.controller.needsReconciliation, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
