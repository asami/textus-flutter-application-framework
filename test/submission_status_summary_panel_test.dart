import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

void main() {
  // Exercise fresh overview partitions, safe failures and explicit summary navigation.
  group('CU7 overview current observations', () {
    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU7 actual queue partitions and fresh fault distinguish empty from failure', () async {
      // Given real borrowed Core resources and an inert empty overview.
      final fixture = await SubmissionFixture.create();
      final queue = await fixture.openQueue();
      final service = fixture.service(queue);
      final facade = SubmissionFacade(service: service);
      final controller = SubmissionStatusOverviewController(
        facade: facade,
        now: fixture.now,
      );
      try {
        // Then constructor starts no observation or scheduler work.
        expect(controller.summary, isNull);
        expect(fixture.scheduler.calls, 0);
        // When explicitly querying the actually empty queue.
        expect(await controller.load(), isTrue);
        // Then successful empty observation alone produces zero.
        expect(controller.summary!.totalCount, 0);
        expect(controller.failed, isFalse);
        // Given real durable records arranged by test-owned processing and claims.
        final completed = await fixture.request(
          id: 'complete',
          subjectId: 'complete',
          withMaterials: false,
        );
        await facade.commit(completed);
        await service.processNext(networkAllowed: true);
        final attention = await fixture.request(
          id: 'attention',
          subjectId: 'attention',
          withMaterials: false,
        );
        await facade.commit(attention);
        fixture.transport.fail = true;
        await service.processNext(networkAllowed: true);
        fixture.transport.fail = false;
        final running = await fixture.request(
          id: 'running',
          subjectId: 'running',
          withMaterials: false,
        );
        await facade.commit(running);
        await queue.claimNext(
          now: fixture.clock,
          leaseToken: 'controlledOwner',
          leaseDuration: const Duration(minutes: 5),
        );
        final waiting = await fixture.request(
          id: 'waiting',
          subjectId: 'waiting',
          withMaterials: false,
        );
        await facade.commit(waiting);
        final wakes = fixture.scheduler.calls;
        final submits = fixture.transport.submits;
        // When explicitly refreshing with default unknown network state.
        expect(await controller.load(), isTrue);
        final summary = controller.summary!;
        final expected = SubmissionStatusSummary.fromStatuses(
          await facade.listTransferStatuses(observedAt: fixture.clock),
        );
        // Then exact disjoint C1 partitions use actual acknowledgement to define completion.
        expect(summary.totalCount, 4);
        expect(summary.waitingCount, 1);
        expect(summary.runningCount, 1);
        expect(summary.attentionCount, 1);
        expect(summary.completedCount, 1);
        expect(summary.completedCount, expected.completedCount);
        expect((await queue.find(completed.id))!.acknowledgement, isNotNull);
        expect((await queue.find(waiting.id))!.acknowledgement, isNull);
        expect(fixture.scheduler.calls, wakes);
        expect(fixture.transport.submits, submits);
        // Given backing failure after closing the queue.
        await queue.close();
        // When explicitly refreshing that failed backing.
        expect(await controller.load(), isFalse);
        // Then stale counts clear to fault without a false empty summary.
        expect(controller.failed, isTrue);
        expect(controller.summary, isNull);
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        await controller.detach();
        controller.dispose();
        await fixture.dispose();
      }
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU7 duplicate held read and reentrant notify clock network retirement', () async {
      // Given uploaded originals that enter a finite controlled access observation.
      final fixture = await SubmissionFixture.create();
      final service = fixture.service(await fixture.openQueue());
      final facade = SubmissionFacade(service: service);
      final request = await fixture.request();
      await facade.commit(request);
      await fixture.uploadAll(service);
      // Given fresh counters and a new overview owner for reentrant retirement.
      var clockCalls = 0;
      var networkCalls = 0;
      late SubmissionStatusOverviewController controller;
      // Count exact observation-time callback entry.
      DateTime clock() {
        clockCalls++;
        return fixture.clock;
      }

      // Count network observation and return unknown without execution consent.
      SubmissionNetworkState network() {
        networkCalls++;
        return SubmissionNetworkState.unknown;
      }

      controller = SubmissionStatusOverviewController(
        facade: facade,
        now: clock,
        networkState: network,
      );
      final gate = SubmissionGate();
      try {
        // Given the access gate holding the next observation.
        fixture.access.gate = gate;
        // When explicitly loading and attempting a duplicate held read.
        final accepted = controller.load();
        await gate.entered.future;
        expect(await controller.load(), isFalse);
        // When detaching before the accepted observation settles.
        final detached = controller.detach();
        // Then retirement is synchronous and the join remains pending.
        expect(controller.isDetached, isTrue);
        expect(controller.detach(), same(detached));
        var joined = false;
        // Record accepted-read join settlement without current-result authority.
        detached.then((_) => joined = true);
        await Future<void>.value();
        expect(joined, isFalse);
        // When releasing and joining the accepted read.
        gate.release();
        expect(await accepted, isFalse);
        await detached;
        // Then no stale summary or false-empty publication occurs.
        expect(joined, isTrue);
        expect(controller.summary, isNull);
        expect(controller.failed, isFalse);
        expect(clockCalls, 1);
        expect(networkCalls, 1);
        controller.dispose();
        fixture.access.gate = null;
        final reads = fixture.access.calls;
        clockCalls = 0;
        networkCalls = 0;
        controller = SubmissionStatusOverviewController(
          facade: facade,
          now: clock,
          networkState: network,
        );
        // Observe loading reservation and retire before external observation callbacks.
        void retireInNotification() {
          // Then notification observes the reserved loading state.
          expect(controller.loading, isTrue);
          // When the listener retires before any clock/network query.
          controller.dispose();
        }

        controller.addListener(retireInNotification);
        // When loading with a listener that retires during notification.
        expect(await controller.load(), isFalse);
        // Then neither clock/network callback nor Core read runs.
        expect(clockCalls, 0);
        expect(networkCalls, 0);
        expect(fixture.access.calls, reads);
        await controller.detach();
        // Retire during time observation to fence the network callback and Core query.
        DateTime retireInClock() {
          controller.detach();
          return fixture.clock;
        }

        controller = SubmissionStatusOverviewController(
          facade: facade,
          now: retireInClock,
          networkState: network,
        );
        // When the explicit load retires from its clock callback.
        expect(await controller.load(), isFalse);
        // Then no network callback or Core query follows clock retirement.
        expect(networkCalls, 0);
        expect(fixture.access.calls, reads);
        await controller.detach();
        controller.dispose();
        // Retire during network observation; its value grants no query authority.
        SubmissionNetworkState retireInNetwork() {
          controller.detach();
          return SubmissionNetworkState.allowed;
        }

        controller = SubmissionStatusOverviewController(
          facade: facade,
          now: fixture.now,
          networkState: retireInNetwork,
        );
        // When the explicit load retires from its network callback.
        expect(await controller.load(), isFalse);
        // Then network observation grants no query authority or transfer execution.
        expect(fixture.access.calls, reads);
        expect(controller.summary, isNull);
        expect(fixture.scheduler.calls, 1);
        expect(fixture.transport.submits, 0);
        expect((await service.find(request.id))!.request, request);
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        gate.release();
        await controller.detach();
        controller.dispose();
        await fixture.dispose();
      }
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets(
      'CU7 CU8 summary explicit refresh navigation replacement and responsive counts',
      (tester) async {
        // Use real async for host queue observations.
        await tester.runAsync(() async {
          // Given two borrowed overview owners, an empty queue and App navigation callback.
          final fixture = await SubmissionFixture.create();
          final queue = await fixture.openQueue();
          final facade = SubmissionFacade(service: fixture.service(queue));
          final controller = SubmissionStatusOverviewController(
            facade: facade,
            now: fixture.now,
          );
          final replacement = SubmissionStatusOverviewController(
            facade: facade,
            now: fixture.now,
          );
          var opens = 0;
          // Count explicit borrowed App navigation without queue or runner effects.
          void open() {
            opens++;
          }

          try {
            // When mounting without a lifecycle load.
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SubmissionStatusSummaryPanel(
                    controller: controller,
                    openStatuses: open,
                  ),
                ),
              ),
            );
            await tester.pump();
            // Then unloaded state has no fabricated counts, query, navigation or scheduler work.
            expect(find.text('送信状況は未読込です。'), findsOneWidget);
            // Then unloaded input supplies no fabricated zero counts.
            expect(find.text('合計: 0'), findsNothing);
            expect(controller.summary, isNull);
            expect(opens, 0);
            expect(fixture.scheduler.calls, 0);
            final staleRefresh = tester
                .widget<TextButton>(find.widgetWithText(TextButton, '再読み込み'))
                .onPressed!;
            final staleOpen = tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, '送信一覧を開く'),
                )
                .onPressed!;
            // When explicitly tapping Refresh.
            await tester.tap(find.widgetWithText(TextButton, '再読み込み'));
            await tester.pump();
            // Then loading remains visible until the actual read settles.
            expect(find.text('送信状況を読み込んでいます…'), findsOneWidget);
            for (
              var attempt = 0;
              controller.loading && attempt < 100;
              attempt++
            ) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            await tester.pump();
            // Then the settled successful empty observation alone supplies zero counts.
            expect(find.text('合計: 0'), findsOneWidget);
            expect(find.text('完了: 0'), findsOneWidget);
            await tester.tap(
              // When explicitly navigating through the App callback.
              find.widgetWithText(TextButton, '送信一覧を開く'),
            );
            // Then only navigation is counted without scheduler work.
            expect(opens, 1);
            expect(fixture.scheduler.calls, 0);
            // When replacing the owner and invoking obsolete Refresh/Open closures.
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SubmissionStatusSummaryPanel(
                    controller: replacement,
                    openStatuses: open,
                  ),
                ),
              ),
            );
            staleRefresh();
            staleOpen();
            await tester.pump();
            // Then obsolete closures cannot observe or navigate through the replacement.
            expect(replacement.summary, isNull);
            expect(opens, 1);
            expect(controller.isDetached, isFalse);
            // Given an explicitly loaded replacement and long labels at doubled text.
            await replacement.load();
            for (final width in [320.0, 900.0]) {
              tester.view.physicalSize = Size(width, 1600);
              tester.view.devicePixelRatio = 1;
              // When rendering the summary at each narrow/expanded width.
              await tester.pumpWidget(
                MaterialApp(
                  // Retain the effective OS text scaler for responsive summary labels.
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: SubmissionStatusSummaryPanel(
                      controller: replacement,
                      openStatuses: open,
                      title: 'Current original upload and background submission status overview',
                      openStatusesLabel: 'View the current complete list of queued original submissions',
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              // Then counts/actions wrap without overflow or implicit queries.
              expect(tester.takeException(), isNull);
              expect(find.text('合計: 0'), findsOneWidget);
              expect(fixture.scheduler.calls, 0);
              expect(opens, 1);
            }
            // Given backing failure for the replacement overview.
            await queue.close();
            // When explicitly refreshing that failure.
            expect(await replacement.load(), isFalse);
            await tester.pump();
            expect(
              // Then fixed fault replaces previous counts.
              find.text('送信状況を読み込めませんでした。'),
              findsOneWidget,
            );
            expect(find.text('合計: 0'), findsNothing);
            final unmounted = tester
                .widget<TextButton>(find.widgetWithText(TextButton, '再読み込み'))
                .onPressed!;
            // When unmounting and invoking a captured Refresh callback.
            await tester.pumpWidget(const SizedBox.shrink());
            unmounted();
            // Then the unmounted callback starts no observation.
            expect(replacement.loading, isFalse);
          } finally {
            // Release held work, remove presentation and drain borrowers before owner cleanup.
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            await tester.pumpWidget(const SizedBox.shrink());
            await controller.detach();
            await replacement.detach();
            controller.dispose();
            replacement.dispose();
            await fixture.dispose();
          }
        });
      },
    );
  });
}
