import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

void main() {
  // Exercise borrowed App Commit callbacks, durable intent and current-owner fences.
  group('CU5 Commit invocation current owner', () {
    late SubmissionFixture fixture;
    late SqliteSubmissionQueueStore queue;
    late SubmissionFacade facade;
    late SubmissionRequest request;

    // Compose real originals, SQLite and a borrowed facade without Commit.
    setUp(() async {
      // Given real private originals and fixture-owned Core resources.
      fixture = await SubmissionFixture.create();
      queue = await fixture.openQueue();
      facade = SubmissionFacade(service: fixture.service(queue));
      // When freezing the exact durable request used by this scenario.
      request = await fixture.request();
    });
    // Release and drain fixture-owned ports before closing durable resources.
    tearDown(() async => fixture.dispose());

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU5 one current callback queues once and reopens exact durable intent', () async {
      // Given an App callback with a finite current-edit flush gate.
      final flush = SubmissionGate();
      var calls = 0;
      SubmissionCommitInvocation? seen;
      // Borrow the exact App callback; check current owner before its Core dispatch.
      Future<SubmissionCommitResult> commit(
        SubmissionCommitInvocation invocation,
      ) async {
        calls++;
        seen = invocation;
        await flush.wait();
        if (!invocation.isCurrent) throw StateError('retired App callback');
        return facade.commit(request);
      }

      // When constructing the inert owner around the exact App callback.
      final controller = SubmissionCommitController(commit: commit);
      try {
        // Then controller construction starts no callback or scheduler work.
        expect(calls, 0);
        expect(fixture.scheduler.calls, 0);
        expect(controller.result, isNull);
        // Given a controlled scheduler failure after durable Commit.
        fixture.scheduler.fail = true;
        // When explicitly committing and repeating while the edit flush is held.
        final accepted = controller.commit();
        // Then reservation is synchronous.
        expect(controller.busy, isTrue);
        await flush.entered.future;
        // When attempting the duplicate Commit.
        expect(await controller.commit(), isFalse);
        // When the current edit flush is released.
        flush.release();
        expect(await accepted, isTrue);
        // Then one exact request is durable with a separate scheduling warning.
        expect(calls, 1);
        expect(controller.failed, isFalse);
        final result = controller.result!;
        expect(result.record.request, request);
        expect(result.record.acknowledgement, isNull);
        expect(result.schedulingFailure?.code, 'wakeUnavailable');
        expect(fixture.scheduler.calls, 1);
        // When opening another SQLite handle for that intent.
        final reopened = await fixture.openQueue();
        // Then original/provenance values survive without UI transfer execution.
        expect((await reopened.find(request.id))!.request, request);
        expect((await reopened.list()).length, 1);
        expect(fixture.storage.uploads, 0);
        expect(fixture.transport.submits, 0);
        // When retiring the callback owner after Commit.
        await controller.detach();
        // Then owner validity becomes false while durable intent stays reusable.
        expect(seen!.isCurrent, isFalse);
        expect((await facade.find(request.id))!.request, request);
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        flush.release();
        await controller.detach();
        controller.dispose();
      }
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU5 reentrant disposal reserves before notification and prevents callback', () async {
      // Given a queuing callback and a listener that disposes during notification.
      var calls = 0;
      // Count unexpected callback entry and attempt the exact durable request.
      Future<SubmissionCommitResult> commit(
        SubmissionCommitInvocation invocation,
      ) {
        calls++;
        return facade.commit(request);
      }

      final controller = SubmissionCommitController(commit: commit);
      // Observe the reservation and dispose synchronously during notification.
      void retire() {
        // Then the callback observes busy before reentrant retirement.
        expect(controller.busy, isTrue);
        // When it retires the owner before any App dispatch.
        controller.dispose();
      }

      controller.addListener(retire);
      // When Commit reserves busy and notifies that listener.
      expect(await controller.commit(), isFalse);
      // Then no callback, queue row or scheduler dispatch occurs.
      expect(calls, 0);
      expect(await queue.list(), isEmpty);
      expect(fixture.scheduler.calls, 0);
      await controller.detach();
      controller.dispose();
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test(
      'CU5 detach during edit flush joins callback without stale Commit',
      () async {
        // Given a compliant App callback held in current-edit flush.
        final flush = SubmissionGate();
        SubmissionCommitInvocation? seen;
        // Borrow the exact App callback; check current owner before its Core dispatch.
        Future<SubmissionCommitResult> commit(
          SubmissionCommitInvocation invocation,
        ) async {
          seen = invocation;
          await flush.wait();
          if (!invocation.isCurrent) {
            throw StateError('secret obsolete edit details');
          }
          return facade.commit(request);
        }

        final controller = SubmissionCommitController(commit: commit);
        var notifications = 0;
        // Count current publication notifications only.
        void observe() {
          notifications++;
        }

        controller.addListener(observe);
        try {
          // When explicit Commit enters the held flush.
          final accepted = controller.commit();
          await flush.entered.future;
          // When detaching before queue dispatch.
          final detached = controller.detach();
          // Then validity retires immediately and detach remains an idempotent pending join.
          expect(seen!.isCurrent, isFalse);
          expect(controller.detach(), same(detached));
          final retiredNotifications = notifications;
          var joined = false;
          // Record pending detach settlement without queue or UI authority.
          detached.then((_) => joined = true);
          await Future<void>.value();
          // Then held callback work has not settled.
          expect(joined, isFalse);
          // When the App flush completes and checks current validity.
          flush.release();
          expect(await accepted, isFalse);
          await detached;
          // Then the callback joins without late queue/result/fault/notification publication.
          expect(joined, isTrue);
          expect(controller.result, isNull);
          expect(controller.failed, isFalse);
          expect(notifications, retiredNotifications);
          expect(await queue.list(), isEmpty);
          expect(fixture.scheduler.calls, 0);
        } finally {
          // Release held work, remove presentation and drain borrowers before owner cleanup.
          flush.release();
          await controller.detach();
          controller.dispose();
        }
      },
    );

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU5 issued Core Commit drains and fences late result and raw callback fault', () async {
      // Given an issued durable Commit held at the scheduler.
      final gate = SubmissionGate();
      fixture.scheduler.gate = gate;
      // Borrow the exact App callback; check current owner before its Core dispatch.
      Future<SubmissionCommitResult> commit(
        SubmissionCommitInvocation invocation,
      ) {
        if (!invocation.isCurrent) throw StateError('retired');
        return facade.commit(request);
      }

      final controller = SubmissionCommitController(commit: commit);
      try {
        // When explicit Commit enters Core and the owner detaches before wake completion.
        final accepted = controller.commit();
        await gate.entered.future;
        final detached = controller.detach();
        // When the issued durable operation is released and joined.
        gate.release();
        expect(await accepted, isFalse);
        await detached;
        // Then the durable request survives while retired result/fault publication is fenced.
        expect(controller.result, isNull);
        expect(controller.failed, isFalse);
        expect((await queue.find(request.id))!.request, request);
        expect(fixture.scheduler.calls, 1);
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        gate.release();
        await controller.detach();
        controller.dispose();
      }
      // Throw raw App details to exercise the fixed safe callback failure boundary.
      Future<SubmissionCommitResult> fault(
        SubmissionCommitInvocation invocation,
      ) async {
        throw StateError('secret token Book details');
      }

      // Given a separate callback that throws untrusted App details.
      final failed = SubmissionCommitController(commit: fault);
      try {
        // When explicitly invoking that callback.
        expect(await failed.commit(), isFalse);
        // Then only the fixed safe queue-failure message is retained.
        expect(failed.failed, isTrue);
        expect(failed.failureMessage, 'Could not queue submission.');
        expect(failed.result, isNull);
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        await failed.detach();
        failed.dispose();
      }
    });
  });
}
