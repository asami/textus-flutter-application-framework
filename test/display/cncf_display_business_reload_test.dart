import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';
import 'cncf_display_business_resource_view_test.dart' as common;

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() complete, {
  required Duration budget,
}) async {
  final maxFrames = (budget.inMilliseconds / 16).ceil();
  for (var frame = 0; frame < maxFrames && !complete(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump();
}

void main() {
  testWidgets(
    'automatic Reload publishes ACK before GET and selection change retains manual recovery without replay',
    (tester) async {
      // Given selected actual common Detail, its enabled callback, and a held automatic read.
      final fixture = common.session(tester);
      // Cover the public client's finite timeout, including retirement, plus a 500ms margin.
      final pumpBudget =
          fixture.client.timeout + const Duration(milliseconds: 500);
      await tester.pumpWidget(MaterialApp(home: common.view(fixture)));
      await tester.pumpAndSettle();
      await common.select(tester);
      final staleCallback = tester
          .widget<TextButton>(find.byKey(common.businessKey))
          .onPressed!;
      final observation = fixture.source.lastDetail;
      final read = fixture.hold('read');
      String? methodAtAck;
      int? requestsAtAck;
      bool? reconciliationAtAck;
      fixture.controller.addListener(() {
        if (fixture.controller.businessReceipt != null && methodAtAck == null) {
          methodAtAck = fixture.requests.last.method;
          requestsAtAck = fixture.requests.length;
          reconciliationAtAck = fixture.controller.needsReconciliation;
        }
      });
      // When one actual Business click returns ACK and the automatic read enters its gate.
      await common.tapBusiness(tester);
      await pumpUntil(
        tester,
        () => read.entered.isCompleted,
        budget: pumpBudget,
      );
      // Then receipt publication precedes GET and the shared owner stays busy during the read.
      expect(read.entered.isCompleted, isTrue);
      expect(methodAtAck, 'POST');
      expect(requestsAtAck, 3);
      expect(reconciliationAtAck, isTrue);
      final receipt = fixture.controller.businessReceipt!;
      expect(receipt.resourceId, fixture.id);
      expect(receipt.revision, '2');
      expect(fixture.controller.busy, isTrue);
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.source.lastDetail, same(observation));
      expect(fixture.requests.map((request) => request.method), [
        'GET',
        'GET',
        'POST',
        'GET',
      ]);
      expect(find.byKey(common.progressKey), findsOneWidget);
      // When a callback captured before dispatch competes with the held read.
      staleCallback();
      await tester.pump();
      // Then it cannot send another POST or acquire another read.
      expect(fixture.posts, hasLength(1));
      expect(fixture.requests, hasLength(4));
      expect(fixture.controller.businessReceipt, same(receipt));
      // When programmatic selection changes during the held automatic Detail read.
      await fixture.viewModel.select('other-resource');
      final requestsAfterSelection = fixture.requests.length;
      read.release();
      await pumpUntil(
        tester,
        () => read.settled.isCompleted && !fixture.controller.busy,
        budget: pumpBudget,
      );
      // Then no following query targets the changed selection or fabricates reconciliation.
      expect(read.settled.isCompleted, isTrue);
      expect(fixture.controller.busy, isFalse);
      expect(fixture.viewModel.selectedId, 'other-resource');
      expect(fixture.requests, hasLength(requestsAfterSelection));
      expect(
        fixture.requests.where(
          (request) => request.url.path.endsWith('query.json'),
        ),
        hasLength(1),
      );
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.controller.businessReceipt, same(receipt));
      expect(fixture.posts, hasLength(1));
      expect(find.byKey(common.reloadKey), findsOneWidget);
      // Given the affected resource is explicitly selected again.
      await fixture.viewModel.select(fixture.id);
      await tester.pumpAndSettle();
      // When the user chooses the retained manual Reload action.
      await tester.tap(find.byKey(common.reloadKey));
      await pumpUntil(
        tester,
        () => !fixture.controller.busy,
        budget: pumpBudget,
      );
      // Then safe reads reconcile the known ACK without replaying Business.
      expect(fixture.controller.busy, isFalse);
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.controller.businessReceipt, same(receipt));
      expect(fixture.viewModel.selectedId, fixture.id);
      expect(find.text('レビュー待ち'), findsWidgets);
      expect(find.byKey(common.businessKey), findsNothing);
      expect(fixture.posts, hasLength(1));
      expect(fixture.puts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'controller retirement during an entered automatic Detail read preserves known ACK and borrowed owners',
    (tester) async {
      // Given actual common Detail on a pushed route and a gate for the automatic read.
      final fixture = common.session(tester);
      // Cover the public client's finite timeout, including retirement, plus a 500ms margin.
      final pumpBudget =
          fixture.client.timeout + const Duration(milliseconds: 500);
      final navigation = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigation,
          home: const Scaffold(body: Text('Root remains')),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        navigation.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => common.view(fixture)),
        ),
      );
      await common.readyRoute(tester, find.byType(ResourceListDetail));
      await tester.pumpAndSettle();
      await common.select(tester);
      final read = fixture.hold('read');
      final route = ModalRoute.of(
        tester.element(find.byType(CncfDisplayResourceView)),
      );
      // When an actual Business click publishes ACK and its automatic GET enters the gate.
      await common.tapBusiness(tester);
      await pumpUntil(
        tester,
        () => read.entered.isCompleted,
        budget: pumpBudget,
      );
      // Then the automatic read is already active with a known ACK before retirement.
      expect(read.entered.isCompleted, isTrue);
      expect(fixture.controller.busy, isTrue);
      final receipt = fixture.controller.businessReceipt!;
      expect(receipt.revision, '2');
      expect(receipt.resourceId, fixture.id);
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.controller.failure, isNull);
      expect(fixture.requests.map((request) => request.method), [
        'GET',
        'GET',
        'POST',
        'GET',
      ]);
      // When the test retires the controller outside all notifier callbacks.
      final requestsAtDisposal = fixture.requests.length;
      final methodAtDisposal = fixture.requests.last.method;
      fixture.controller.dispose();
      // Then retirement preserves the known ACK and leaves the pushed route current.
      expect(fixture.controller.isDisposed, isTrue);
      expect(fixture.controller.businessReceipt, same(receipt));
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.controller.failure, isNull);
      expect(requestsAtDisposal, 4);
      expect(methodAtDisposal, 'GET');
      expect(route!.isCurrent, isTrue);
      // When the already-entered read is released after controller retirement.
      read.release();
      await pumpUntil(
        tester,
        () => read.settled.isCompleted && !fixture.viewModel.detailLoading,
        budget: pumpBudget,
      );
      await tester.pump();
      // Then settlement cannot start a following query, any further I/O, or navigation.
      expect(read.settled.isCompleted, isTrue);
      expect(fixture.viewModel.detailLoading, isFalse);
      expect(fixture.requests, hasLength(requestsAtDisposal));
      expect(
        fixture.requests.where(
          (request) => request.url.path.endsWith('query.json'),
        ),
        hasLength(1),
      );
      expect(fixture.posts, hasLength(1));
      expect(fixture.controller.businessReceipt, same(receipt));
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(fixture.controller.failure, isNull);
      expect(route.isCurrent, isTrue);
      expect(navigation.currentState!.canPop(), isTrue);
      expect(find.byType(CncfDisplayResourceView), findsOneWidget);
      expect(tester.takeException(), isNull);
      // When the common view is unmounted and its borrowed owners perform safe reads.
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.viewModel.select(fixture.id);
      final query = await fixture.client.query();
      // Then View, source and transport survive retirement without command replay.
      expect(query.resources, hasLength(2));
      expect(fixture.viewModel.selectedResource!.value('stage'), 'レビュー待ち');
      expect(fixture.posts, hasLength(1));
      expect(fixture.controller.businessReceipt!.revision, '2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'callback captured from replaced opener cannot dispatch and leaves replacement owners untouched',
    (tester) async {
      // Given selected actual common Detail and independent replacement owners.
      final fixture = common.session(tester);
      final other = CncfDisplayMutationFixture(
        businessBindings: [referenceBusinessBinding()],
      );
      final root = ValueNotifier<Widget>(common.view(fixture));
      addTearDown(root.dispose);
      addTearDown(() async {
        other.releaseAll();
        await tester.pumpWidget(const SizedBox.shrink());
        other.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<Widget>(
            valueListenable: root,
            builder: (_, child, _) => child,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await common.select(tester);
      final oldCallback = tester
          .widget<TextButton>(find.byKey(common.businessKey))
          .onPressed!;
      final commonState = tester.state(find.byType(CncfDisplayResourceView));
      final oldRequests = fixture.requests.length;
      // When replacement completes didUpdateWidget and the captured old callback is invoked.
      root.value = common.view(other);
      await tester.pumpAndSettle();
      final replacementRequests = other.requests.length;
      oldCallback();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // Then the same common State rejects retired authority before any command or read.
      expect(
        tester.state(find.byType(CncfDisplayResourceView)),
        same(commonState),
      );
      expect(fixture.requests, hasLength(oldRequests));
      expect(fixture.posts, isEmpty);
      expect(fixture.controller.businessOperation, isNull);
      expect(fixture.controller.businessReceipt, isNull);
      expect(other.requests, hasLength(replacementRequests));
      expect(other.posts, isEmpty);
      expect(other.controller.businessOperation, isNull);
      expect(other.controller.businessReceipt, isNull);
      expect(other.controller.observation, isNull);
      expect(other.controller.busy, isFalse);
      expect(other.controller.needsReconciliation, isFalse);
      expect(other.controller.editorOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
