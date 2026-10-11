import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

// Bound host query/action settlement with frames and event turns; run no Core work.
Future<void> settleSubmissionPage(
  WidgetTester tester,
  SubmissionStatusWorkspace workspace,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    if (!workspace.viewModel.listLoading &&
        !workspace.viewModel.detailLoading &&
        !workspace.viewModel.actionRunning) {
      await tester.pump();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Controlled page query did not settle');
}

// Scroll the actual standard detail viewport to reveal the requested control.
Future<void> showSubmissionDetail(
  WidgetTester tester,
  String text, {
  double delta = 300,
}) async {
  await tester.scrollUntilVisible(
    find.text(text),
    delta,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
}

void main() {
  // Exercise standard list/detail, exact two-stage status and explicit App navigation.
  group('CU3 CU4 standard submission status page', () {
    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets(
      'CU3 explicit Commit and status page preserve two-stage durable intent',
      (tester) async {
        // Use real host IO for original binary files and SQLite.
        await tester.runAsync(() async {
          // Given exact immutable intent and App callback borrowing the accepted Core facade.
          final fixture = await SubmissionFixture.create();
          final queue = await fixture.openQueue();
          final service = fixture.service(queue);
          final facade = SubmissionFacade(service: service);
          final request = await fixture.request();
          var commits = 0;
          // Flush App edits and check owner validity immediately before exact Core Commit.
          Future<SubmissionCommitResult> commit(
            SubmissionCommitInvocation invocation,
          ) async {
            await Future<void>.value();
            if (!invocation.isCurrent) throw StateError('retired owner');
            commits++;
            return facade.commit(request);
          }

          final controller = SubmissionCommitController(commit: commit);
          final workspace = SubmissionStatusWorkspace(
            facade: facade,
            presentationConfiguration: submissionPresentation(),
            now: fixture.now,
          );
          try {
            // When explicit Commit starts one durable queued intent.
            expect(await controller.commit(), isTrue);
            // When mounting the standard page, selecting and revealing file detail.
            await tester.pumpWidget(
              MaterialApp(home: SubmissionStatusPage(workspace: workspace)),
            );
            await settleSubmissionPage(tester, workspace);
            await tester.tap(find.text('Item subject1'));
            await settleSubmissionPage(tester, workspace);
            await showSubmissionDetail(tester, '写真 原本.jpg');
            // Then standard mount/selection read only and retain the exact original queue snapshot.
            expect(commits, 1);
            expect(fixture.scheduler.calls, 1);
            expect(fixture.storage.uploads, 0);
            expect(fixture.transport.submits, 0);
            expect(find.byType(ResourceListDetail), findsOneWidget);
            final standard = tester.widget<ResourceListDetail>(
              find.byType(ResourceListDetail),
            );
            expect(standard.viewModel, same(workspace.viewModel));
            expect(standard.displayModel, same(workspace.displayModel));
            expect(
              standard.configuration.primaryField,
              workspace.binding.configuration.primaryField,
            );
            expect((await queue.list()).single.request, request);
            expect((await queue.find(request.id))!.acknowledgement, isNull);
            expect(find.text('写真 原本.jpg'), findsOneWidget);
            expect(find.text('音声 原本.wav'), findsOneWidget);
            expect(
              find.text(
                'Stored at: ${SubmissionFixture.time.toIso8601String()}',
              ),
              findsNothing,
            );
            final initial =
                workspace.viewModel.selectedResource
                    as SubmissionStatusResourceRecord;
            // Then file order and the separate queued/waiting operations stay literal.
            expect(initial.status.files.map((file) => file.key), [
              'photo',
              'audio',
            ]);
            expect(
              initial.status.upload.state,
              SubmissionTransferOperationState.queued,
            );
            expect(
              initial.status.submission.state,
              SubmissionTransferOperationState.waiting,
            );
            // Given a controlled upload failure on the second original.
            fixture.storage.failKey = 'audio';
            // When the test owner runs upload and refreshes the selected detail.
            await fixture.uploadAll(service);
            await workspace.viewModel.detailView.refresh();
            await tester.pump();
            final partial =
                workspace.viewModel.selectedResource
                    as SubmissionStatusResourceRecord;
            expect(
              // Then only the first original has a receipt; failure is not guessed for another file.
              partial.status.upload.state,
              SubmissionTransferOperationState.failed,
            );
            expect(
              partial.status.submission.state,
              SubmissionTransferOperationState.waiting,
            );
            expect(
              partial.status.files[0].state,
              SubmissionTransferOperationState.succeeded,
            );
            expect(
              partial.status.files[1].state,
              SubmissionTransferOperationState.queued,
            );
            expect(partial.status.files[0].receipt, isNotNull);
            expect(partial.status.files[1].receipt, isNull);
            expect(
              find.text(
                'Stored at: ${SubmissionFixture.time.toIso8601String()}',
              ),
              findsOneWidget,
            );
            expect(
              find.text('Original ID: ${request.materials[0].original.id}'),
              findsOneWidget,
            );
            expect(find.text('Media type: audio/wav'), findsOneWidget);
            expect(
              find.text('Byte length: ${SubmissionFixture.audioBytes.length}'),
              findsOneWidget,
            );
            expect(
              await fixture.materials.readMaterial(
                request.materials[0].original,
              ),
              SubmissionFixture.photoBytes,
            );
            expect(
              await fixture.materials.readMaterial(
                request.materials[1].original,
              ),
              SubmissionFixture.audioBytes,
            );
            expect(fixture.storage.uploadedBytes, [
              SubmissionFixture.photoBytes,
              SubmissionFixture.audioBytes,
            ]);
            expect(fixture.transport.submits, 0);
            expect((await queue.find(request.id))!.request, request);
            expect(controller.result!.record.request, request);
            // When the user explicitly reveals and invokes the currently supported Retry.
            await showSubmissionDetail(tester, 'Retry', delta: -300);
            await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
            await settleSubmissionPage(tester, workspace);
            // Then only existing intent is awakened, with no duplicate row or submit.
            expect(fixture.scheduler.calls, 2);
            expect((await queue.list()).length, 1);
            expect((await queue.find(request.id))!.request, request);
            expect(fixture.transport.submits, 0);
          } finally {
            // Release held work, remove presentation and drain borrowers before owner cleanup.
            await tester.pumpWidget(const SizedBox.shrink());
            await workspace.detach();
            await controller.detach();
            controller.dispose();
            await fixture.dispose();
          }
        });
      },
    );

    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets(
      'CU4 scheduling notice belongs to exact request and hides during action',
      (tester) async {
        // Use real host IO for durable queue and UI reads.
        await tester.runAsync(() async {
          // Given two distinct request/subject identities and a borrowed workspace.
          final fixture = await SubmissionFixture.create();
          final queue = await fixture.openQueue();
          final facade = SubmissionFacade(service: fixture.service(queue));
          final first = await fixture.request(withMaterials: false);
          final second = await fixture.request(
            id: 'request2',
            subjectId: 'subject2',
            withMaterials: false,
          );
          await facade.commit(first);
          await facade.commit(second);
          final workspace = SubmissionStatusWorkspace(
            facade: facade,
            presentationConfiguration: submissionPresentation(),
            now: fixture.now,
          );
          final gate = SubmissionGate();
          try {
            // When mounting, selecting the first request and explicitly requesting a run.
            await tester.pumpWidget(
              MaterialApp(home: SubmissionStatusPage(workspace: workspace)),
            );
            await settleSubmissionPage(tester, workspace);
            await workspace.viewModel.select(first.id);
            workspace.displayModel.openDetail();
            fixture.scheduler.fail = true;
            await workspace.viewModel.performAction('requestRun');
            await tester.pump();
            await showSubmissionDetail(
              tester,
              'Queued; background scheduling needs attention',
            );
            expect(
              // Then one exact-request scheduling warning is distinct from server acknowledgement.
              find.text('Queued; background scheduling needs attention'),
              findsOneWidget,
            );
            expect(
              workspace.binding.lastActionResult!.record.request.id,
              first.id,
            );
            expect((await queue.find(first.id))!.acknowledgement, isNull);
            // When selecting the other request.
            await workspace.viewModel.select(second.id);
            await tester.pump();
            expect(
              // Then the unrelated warning is hidden.
              find.text('Queued; background scheduling needs attention'),
              findsNothing,
            );
            // Given the first request selected again.
            await workspace.viewModel.select(first.id);
            fixture.scheduler.gate = gate;
            // When starting a held supported action.
            final action = workspace.viewModel.performAction('requestRun');
            await gate.entered.future;
            await tester.pump();
            // Then the previous notice is hidden while that exact action runs.
            expect(workspace.viewModel.actionRunning, isTrue);
            expect(
              find.text('Queued; background scheduling needs attention'),
              findsNothing,
            );
            final wakes = fixture.scheduler.calls;
            // When attempting a duplicate action during the reservation.
            await workspace.viewModel.performAction('requestRun');
            // Then no duplicate wake is issued.
            expect(fixture.scheduler.calls, wakes);
            // When releasing the accepted action and revealing the fresh detail notice.
            gate.release();
            await action;
            await tester.pump();
            await showSubmissionDetail(
              tester,
              'Queued; background scheduling needs attention',
            );
            expect(
              // Then the current warning returns without transport execution.
              find.text('Queued; background scheduling needs attention'),
              findsOneWidget,
            );
            expect(fixture.transport.submits, 0);
          } finally {
            // Release held work, remove presentation and drain borrowers before owner cleanup.
            gate.release();
            await tester.pumpWidget(const SizedBox.shrink());
            await workspace.detach();
            await fixture.dispose();
          }
        });
      },
    );

    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets(
      'CU4 typed Open item reserves once and fences owner replacement',
      (tester) async {
        // Use real host IO for navigation over durable immutable statuses.
        await tester.runAsync(() async {
          // Given two workspace owners, exact statuses and a held App navigation callback.
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
          await facade.commit(first);
          await facade.commit(second);
          final workspace = SubmissionStatusWorkspace(
            facade: facade,
            presentationConfiguration: submissionPresentation(),
            now: fixture.now,
          );
          final replacement = SubmissionStatusWorkspace(
            facade: facade,
            presentationConfiguration: submissionPresentation(),
            now: fixture.now,
          );
          final gate = SubmissionGate();
          final opened = <SubmissionTransferStatus>[];
          // Borrow typed App navigation; retain the selected status and hold only its completion.
          Future<void> open(SubmissionTransferStatus status) async {
            opened.add(status);
            await gate.wait();
            throw StateError('untrusted navigation details');
          }

          try {
            // Given the first selected detail and its actual rendered Open callback.
            await tester.pumpWidget(
              MaterialApp(
                home: SubmissionStatusPage(
                  workspace: workspace,
                  openSubject: open,
                ),
              ),
            );
            await settleSubmissionPage(tester, workspace);
            await workspace.viewModel.select(first.id);
            workspace.displayModel.openDetail();
            await tester.pump();
            await showSubmissionDetail(tester, 'Open item');
            final selected =
                (workspace.viewModel.selectedResource
                        as SubmissionStatusResourceRecord)
                    .status;
            final button = find.widgetWithText(TextButton, 'Open item');
            await tester.ensureVisible(button);
            final captured = tester.widget<TextButton>(button).onPressed!;
            // When invoking the captured Open callback twice.
            captured();
            captured();
            await gate.entered.future;
            await tester.pump();
            // Then one invocation receives the exact current immutable status.
            expect(opened, [same(selected)]);
            expect(opened.single.requestId, first.id);
            expect(opened.single.subjectId, first.subjectId);
            final wakes = fixture.scheduler.calls;
            // When replacing the owner and invoking the old callback before its future settles.
            await tester.pumpWidget(
              MaterialApp(
                home: SubmissionStatusPage(
                  workspace: replacement,
                  openSubject: open,
                ),
              ),
            );
            await settleSubmissionPage(tester, replacement);
            await replacement.viewModel.select(second.id);
            replacement.displayModel.openDetail();
            await tester.pump();
            await showSubmissionDetail(tester, 'Open item');
            captured();
            gate.release();
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            // Then neither stale navigation nor late fault/busy state reaches the replacement.
            expect(opened.length, 1);
            expect(find.text('Could not open item.'), findsNothing);
            expect(find.text('Opening…'), findsNothing);
            expect(fixture.scheduler.calls, wakes);
            expect(workspace.isDetached, isFalse);
            final unmounted = tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Open item'),
                )
                .onPressed!;
            // When unmounting and invoking the new captured callback.
            await tester.pumpWidget(const SizedBox.shrink());
            unmounted();
            // Then unmounted navigation and transport remain inert.
            expect(opened.length, 1);
            expect(fixture.transport.submits, 0);
          } finally {
            // Release held work, remove presentation and drain borrowers before owner cleanup.
            gate.release();
            await tester.pumpWidget(const SizedBox.shrink());
            await workspace.detach();
            await replacement.detach();
            await fixture.dispose();
          }
        });
      },
    );

    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets('CU8 status page keeps standard fold layout and large text', (
      tester,
    ) async {
      // Use real host IO for responsive presentation of durable intent.
      await tester.runAsync(() async {
        // Given exact current status and standard workspace/display policy.
        final fixture = await SubmissionFixture.create();
        final facade = SubmissionFacade(
          service: fixture.service(await fixture.openQueue()),
        );
        final request = await fixture.request();
        await facade.commit(request);
        final workspace = SubmissionStatusWorkspace(
          facade: facade,
          presentationConfiguration: submissionPresentation(),
          now: fixture.now,
        );
        Future<void> open(SubmissionTransferStatus status) async {
          // Supply an inert typed App navigation callback for layout-only intent.
        }
        try {
          // Given narrow, wide and hinged geometry with doubled text.
          for (final width in [320.0, 900.0, 1200.0]) {
            tester.view.physicalSize = Size(width, 1600);
            tester.view.devicePixelRatio = 1;
            final media = MediaQueryData(
              size: Size(width, 1600),
              textScaler: const TextScaler.linear(2),
              displayFeatures: width == 1200
                  ? [
                      const DisplayFeature(
                        bounds: Rect.fromLTWH(590, 0, 20, 1600),
                        type: DisplayFeatureType.hinge,
                        state: DisplayFeatureState.postureFlat,
                      ),
                    ]
                  : [],
            );
            // When rendering, selecting and scrolling the standard detail.
            await tester.pumpWidget(
              MaterialApp(
                // Pass actual geometry and text scaling into the existing standard layout.
                builder: (context, child) =>
                    MediaQuery(data: media, child: child!),
                home: SubmissionStatusPage(
                  workspace: workspace,
                  openSubject: open,
                  openSubjectLabel: 'Open the original item with its complete current submission status',
                ),
              ),
            );
            await settleSubmissionPage(tester, workspace);
            await workspace.viewModel.select(request.id);
            workspace.displayModel.openDetail();
            await tester.pumpAndSettle();
            await showSubmissionDetail(
              tester,
              'Open the original item with its complete current submission status',
            );
            // Then selection, layout and fold separation retain no build-time transfer work.
            expect(tester.takeException(), isNull);
            expect(find.byType(ResourceListDetail), findsOneWidget);
            expect(workspace.viewModel.selectedId, request.id);
            expect(fixture.scheduler.calls, 1);
            expect(fixture.storage.uploads, 0);
            expect(fixture.transport.submits, 0);
            if (width == 1200) {
              expect(find.byKey(const Key('fold-separation')), findsOneWidget);
            }
          }
        } finally {
          // Release held work, remove presentation and drain borrowers before owner cleanup.
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.pumpWidget(const SizedBox.shrink());
          await workspace.detach();
          await fixture.dispose();
        }
      });
    });
  });
}
