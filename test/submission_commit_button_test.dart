import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

void main() {
  // Specify the named existing behavior with its actual setup, commands and observations.
  testWidgets(
    'CU6 explicit eligible Commit reserves once and retirement prevents stale dispatch',
    (tester) async {
      // Use real host IO for filesystem and SQLite operations.
      await tester.runAsync(() async {
        // Given App eligibility, exact durable intent and a held edit-flush callback.
        final fixture = await SubmissionFixture.create();
        final queue = await fixture.openQueue();
        final facade = SubmissionFacade(service: fixture.service(queue));
        final request = await fixture.request();
        final gate = SubmissionGate();
        var calls = 0;
        // Hold App edits and recheck current validity before Core Commit.
        Future<SubmissionCommitResult> commit(
          SubmissionCommitInvocation invocation,
        ) async {
          calls++;
          await gate.wait();
          if (!invocation.isCurrent) throw StateError('retired');
          return facade.commit(request);
        }

        final controller = SubmissionCommitController(commit: commit);
        try {
          // When mounting with false eligibility and the App disabled reason.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SubmissionCommitButton(
                  controller: controller,
                  eligible: false,
                  disabledReason: 'Add the required current item description.',
                ),
              ),
            ),
          );
          await tester.pump();
          // Then mount is inert and the disabled control creates no intent.
          expect(calls, 0);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          expect(
            find.text('Add the required current item description.'),
            findsOneWidget,
          );
          expect(await queue.list(), isEmpty);
          // Given a newly eligible button and a captured current callback.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SubmissionCommitButton(
                  controller: controller,
                  eligible: true,
                ),
              ),
            ),
          );
          fixture.scheduler.fail = true;
          final button = tester
              .widget<FilledButton>(find.byType(FilledButton))
              .onPressed!;
          // When invoking that same callback twice before flush completion.
          button();
          button();
          await gate.entered.future;
          await tester.pump();
          // Then one reservation renders Queuing and disables further taps.
          expect(calls, 1);
          expect(find.text('登録しています…'), findsOneWidget);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          // When releasing edits and synchronously retiring before the callback resumes.
          gate.release();
          await controller.detach().timeout(const Duration(seconds: 5));
          await tester.pump();
          // Then no stale queue or UI result is published and no transfer runs.
          expect(controller.result, isNull);
          expect(
            find.textContaining('送信待ちに登録済み'),
            findsNothing,
          );
          expect(await queue.find(request.id), isNull);
          expect(await queue.list(), isEmpty);
          expect(fixture.scheduler.calls, 0);
          expect(fixture.transport.submits, 0);
        } finally {
          // Release held work, remove presentation and drain borrowers before owner cleanup.
          gate.release();
          await tester.pumpWidget(const SizedBox.shrink());
          await controller.detach();
          controller.dispose();
          await fixture.dispose();
        }
      });
    },
  );

  // Specify the named existing behavior with its actual setup, commands and observations.
  testWidgets(
    'CU6 current queued result warning and replaced controller remain distinct',
    (tester) async {
      // Use real async for the host durable queue and replacement scenario.
      await tester.runAsync(() async {
        // Given two borrowed callback owners with distinct immutable requests.
        final fixture = await SubmissionFixture.create();
        final facade = SubmissionFacade(
          service: fixture.service(await fixture.openQueue()),
        );
        final first = await fixture.request(withMaterials: false);
        final second = await fixture.request(
          id: 'request2',
          subjectId: 'subject2',
          withMaterials: false,
        );
        var firstCalls = 0;
        var secondCalls = 0;
        // Count explicit first-owner dispatch and queue that exact request.
        Future<SubmissionCommitResult> commitFirst(
          SubmissionCommitInvocation invocation,
        ) {
          firstCalls++;
          return facade.commit(first);
        }

        // Count explicit replacement-owner dispatch and queue its exact request.
        Future<SubmissionCommitResult> commitSecond(
          SubmissionCommitInvocation invocation,
        ) {
          secondCalls++;
          return facade.commit(second);
        }

        final controller = SubmissionCommitController(commit: commitFirst);
        final replacement = SubmissionCommitController(commit: commitSecond);
        try {
          // Given a failed controlled wake after durable queuing.
          fixture.scheduler.fail = true;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SubmissionCommitButton(
                  controller: controller,
                  eligible: true,
                ),
              ),
            ),
          );
          final stale = tester
              .widget<FilledButton>(find.byType(FilledButton))
              .onPressed!;
          // When explicitly queuing the current request.
          expect(await controller.commit(), isTrue);
          await tester.pump();
          expect(
            // Then exact queued intent and scheduling warning remain separate from Submitted.
            find.text('送信待ちに登録済み: request1'),
            findsOneWidget,
          );
          expect(
            find.text('送信待ちに登録済みです。送信処理の手配を確認してください。'),
            findsOneWidget,
          );
          expect(find.text('Submitted'), findsNothing);
          expect(controller.result!.record.acknowledgement, isNull);
          // When replacing the button controller and invoking an obsolete callback.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SubmissionCommitButton(
                  controller: replacement,
                  eligible: true,
                ),
              ),
            ),
          );
          stale();
          await tester.pump();
          // Then old result/tap cannot dispatch through the replacement.
          expect(firstCalls, 1);
          expect(secondCalls, 0);
          expect(
            find.textContaining('送信待ちに登録済み'),
            findsNothing,
          );
          expect(controller.isDetached, isFalse);
          // When explicitly committing through the replacement.
          expect(await replacement.commit(), isTrue);
          await tester.pump();
          expect(
            // Then its distinct exact request ID is shown.
            find.text('送信待ちに登録済み: request2'),
            findsOneWidget,
          );
          final unmounted = tester
              .widget<FilledButton>(find.byType(FilledButton))
              .onPressed!;
          // When unmounting and invoking a captured replacement callback.
          await tester.pumpWidget(const SizedBox.shrink());
          unmounted();
          // Then no extra callback or transport execution occurs.
          expect(secondCalls, 1);
          expect(fixture.transport.submits, 0);
        } finally {
          // Release held work, remove presentation and drain borrowers before owner cleanup.
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

  // Specify the named existing behavior with its actual setup, commands and observations.
  testWidgets(
    'CU6 CU8 fixed failure and long Commit labels wrap with large text',
    (tester) async {
      // Given a callback that throws raw details and long labels at doubled text.
      var calls = 0;
      // Count explicit callback entry and throw untrusted details.
      Future<SubmissionCommitResult> fault(
        SubmissionCommitInvocation invocation,
      ) async {
        calls++;
        throw StateError('secret raw callback details');
      }

      final controller = SubmissionCommitController(commit: fault);
      try {
        // When rendering both narrow and expanded button layouts.
        for (final width in [320.0, 900.0]) {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            MaterialApp(
              // Retain doubled OS text scaling for the long-label fixture.
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SubmissionCommitButton(
                  controller: controller,
                  eligible: true,
                  label: 'Commit the current immutable original item for background submission',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Then presentation has no overflow or implicit callback.
          expect(tester.takeException(), isNull);
          expect(calls, 0);
        }
        // When explicitly tapping Commit once.
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        // Then the fixed safe message replaces raw failure details.
        expect(calls, 1);
        expect(find.text('送信待ちに登録できませんでした。'), findsOneWidget);
        expect(find.textContaining('secret raw'), findsNothing);
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        controller.dispose();
      }
    },
  );
}
