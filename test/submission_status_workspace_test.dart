import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/submission_fixture.dart';

class ObservedSubmissionDisplay extends ResourceListDetailDisplayModel {
  int disposals = 0;

  @override
  // Count explicit disposal of the externally owned display.
  void dispose() {
    disposals++;
    super.dispose();
  }
}

void main() {
  // Exercise workspace-owned retirement and borrowed/default display lifetimes.
  group('CU4 workspace ownership and drain', () {
    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU4 workspace inert and borrowed display survives detach', () async {
      // Given real originals/queue, an external display and a borrowed facade.
      final fixture = await SubmissionFixture.create();
      final display = ObservedSubmissionDisplay();
      final queue = await fixture.openQueue();
      final facade = SubmissionFacade(service: fixture.service(queue));
      // When constructing a route-owned workspace.
      final workspace = SubmissionStatusWorkspace(
        facade: facade,
        presentationConfiguration: submissionPresentation(),
        displayModel: display,
        now: fixture.now,
      );
      try {
        // Then construction performs no reads or commands.
        expect(workspace.viewModel.resources, isNull);
        expect(workspace.viewModel.dataSource, same(workspace.binding));
        expect(workspace.viewModel.actionHandler, same(workspace.binding));
        expect(fixture.scheduler.calls, 0);
        expect(fixture.access.calls, 0);
        // When explicitly detaching before any implicit work.
        final detached = workspace.detach();
        // Then VM/binding retirement is synchronous and detach is idempotent.
        expect(workspace.isDetached, isTrue);
        expect(workspace.binding.isDetached, isTrue);
        expect(workspace.detach(), same(detached));
        await detached;
        // Then the borrowed display and Core resources remain reusable after the join.
        expect(display.disposals, 0);
        display.openDetail();
        expect(display.compactDetailRequested, isTrue);
        expect(await queue.list(), isEmpty);
        expect(
          await facade.listTransferStatuses(observedAt: fixture.clock),
          isEmpty,
        );
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        await workspace.detach();
        display.dispose();
        await fixture.dispose();
      }
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU4 workspace drains held read and predispatch action', () async {
      // Given durable uploaded intent, a selected resource and a controlled access gate.
      final fixture = await SubmissionFixture.create();
      final queue = await fixture.openQueue();
      final service = fixture.service(queue);
      final facade = SubmissionFacade(service: service);
      final request = await fixture.request();
      final workspace = SubmissionStatusWorkspace(
        facade: facade,
        presentationConfiguration: submissionPresentation(),
        now: fixture.now,
      );
      final gate = SubmissionGate();
      try {
        await facade.commit(request);
        await fixture.uploadAll(service);
        await workspace.viewModel.select(request.id);
        final record = workspace.viewModel.selectedResource!;
        fixture.access.gate = gate;
        // When a fresh read and supported action both enter the held observation.
        final read = workspace.viewModel.load();
        final action = workspace.binding.execute('requestRun', record);
        final actionExpectation = expectLater(action, throwsStateError);
        await gate.entered.future;
        final wakes = fixture.scheduler.calls;
        // When detaching with both operations accepted.
        final detached = workspace.detach();
        var joined = false;
        // Record accepted-work join settlement without publishing a UI result.
        detached.then((_) => joined = true);
        await Future<void>.value();
        // Then retirement is synchronous while the join stays pending.
        expect(joined, isFalse);
        expect(workspace.binding.isDetached, isTrue);
        await expectLater(workspace.binding.listResources(), throwsStateError);
        // When the held read/action validation is released and joined.
        gate.release();
        await read;
        await actionExpectation;
        await detached;
        // Then no new command or retired publication escapes.
        expect(joined, isTrue);
        expect(workspace.viewModel.resources, isNull);
        expect(workspace.binding.lastActionResult, isNull);
        expect(fixture.scheduler.calls, wakes);
        expect((await service.find(request.id))!.request, request);
        expect(
          // Then only the owned default display is disposed after the join.
          () => workspace.displayModel.addListener(() {}),
          throwsFlutterError,
        );
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        gate.release();
        await workspace.detach();
        await fixture.dispose();
      }
    });
  });
}
