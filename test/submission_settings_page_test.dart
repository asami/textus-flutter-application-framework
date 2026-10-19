import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

// Locate the exact labeled TextField without issuing a configuration command.
Finder settingsField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

// Reveal/tap an explicit scrolling-form control and settle its UI completion.
Future<void> tapSettings(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  // Exercise explicit form commands, ephemeral credentials and responsive settings.
  group('CU2 explicit settings form', () {
    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets('CU2 inert page explicit Add defaults and access declaration', (
      tester,
    ) async {
      // Given empty borrowed configuration and an unloaded page owner.
      final store = MemorySubmissionConfiguration(
        submissionConfiguration(empty: true),
      );
      final controller = SubmissionSettingsController(
        facade: SubmissionConfigurationFacade(store: store),
      );
      try {
        // When mounting and rebuilding that page.
        await tester.pumpWidget(
          MaterialApp(home: SubmissionSettingsPage(controller: controller)),
        );
        await tester.pumpAndSettle();
        // Then construction, mount and build issue no configuration command.
        expect(store.reads, 0);
        expect(store.writes, 0);
        expect(find.text('Submission settings not loaded.'), findsOneWidget);
        // When explicitly tapping Reload.
        await tapSettings(tester, find.widgetWithText(TextButton, 'Reload'));
        expect(
          // Then actual empty state and new-intent selection meaning appear.
          find.text('No submission connections configured.'),
          findsOneWidget,
        );
        expect(
          find.text('Selections apply to new submissions'),
          findsOneWidget,
        );
        // Given explicit immutable Drive ID/account/folder input.
        await tester.enterText(settingsField('Drive ID'), 'storage');
        await tester.enterText(
          settingsField('Account ID'),
          'user@example.test',
        );
        await tester.enterText(settingsField('Folder ID'), 'folderA');
        // When explicitly adding that Drive connection.
        await tapSettings(tester, find.widgetWithText(TextButton, 'Add Drive'));
        // Then the exact definition is inserted without choosing a default.
        expect(store.value.driveConnections.single.id, 'storage');
        expect(store.value.selectedStorageConnectionId, isNull);
        // Given an unsafe HTTP definition.
        await tester.enterText(settingsField('HTTP ID'), 'transport');
        await tester.enterText(
          settingsField('HTTPS endpoint'),
          'http://unsafe.test/submit',
        );
        // When explicitly attempting Add HTTP.
        await tapSettings(tester, find.widgetWithText(TextButton, 'Add HTTP'));
        expect(
          // Then fixed validation prevents insertion.
          find.text('Submission configuration is invalid.'),
          findsOneWidget,
        );
        expect(store.value.httpConnections, isEmpty);
        await tester.enterText(
          settingsField('HTTPS endpoint'),
          // Given a corrected HTTPS endpoint.
          'https://example.test/submit',
        );
        // When explicitly adding the corrected definition.
        await tapSettings(tester, find.widgetWithText(TextButton, 'Add HTTP'));
        expect(
          // Then the exact definition retains unknown access and no native capability is invented.
          store.value.httpConnections.single.endpoint.toString(),
          'https://example.test/submit',
        );
        expect(store.value.selectedTransportConnectionId, isNull);
        expect(find.text('Reference access: Unknown'), findsOneWidget);
        expect(
          find.text('Does not grant or verify remote permissions'),
          findsOneWidget,
        );
        expect(find.text('Authorize'), findsNothing);
        expect(settingsField('Bearer token for transport'), findsNothing);
        await tapSettings(
          tester,
          // When changing only the local reference-access form.
          find.widgetWithText(CheckboxListTile, 'Reference access to storage'),
        );
        // Then the durable declaration has not changed.
        expect(store.value.referenceAccessBindings, isEmpty);
        await tapSettings(
          tester,
          // When explicitly saving the chosen HTTP access declaration.
          find.widgetWithText(TextButton, 'Save reference access declaration'),
        );
        // Then only the chosen storage ID is declared; no remote grant is inferred.
        expect(store.value.referenceAccessBindings['transport'], ['storage']);
        await tapSettings(
          tester,
          // When clearing the local access selection.
          find.widgetWithText(CheckboxListTile, 'Reference access to storage'),
        );
        await tapSettings(
          tester,
          // When explicitly saving the empty access set.
          find.widgetWithText(TextButton, 'Save reference access declaration'),
        );
        // Then explicit No access is distinct from Unknown.
        expect(store.value.referenceAccessBindings['transport'], isEmpty);
        expect(find.text('Reference access: No access'), findsOneWidget);
        // Given the exact default selector callbacks.
        final defaults = find.byType(DropdownButton<String>);
        final storageSelector = tester.widget<DropdownButton<String>>(
          defaults.first,
        );
        // When explicitly selecting storage and transport IDs.
        storageSelector.onChanged!('storage');
        await tester.pumpAndSettle();
        final transportSelector = tester.widget<DropdownButton<String>>(
          defaults.last,
        );
        transportSelector.onChanged!('transport');
        await tester.pumpAndSettle();
        // Then both exact desired defaults are stored.
        expect(store.value.selectedStorageConnectionId, 'storage');
        expect(store.value.selectedTransportConnectionId, 'transport');
        // Given an untrusted backing read fault.
        store.fault = StateError('secret backing configuration details');
        // When explicitly reloading the fault.
        await tapSettings(tester, find.widgetWithText(TextButton, 'Reload'));
        expect(
          // Then fixed failure appears without raw details.
          find.text('Submission configuration is unavailable.'),
          findsOneWidget,
        );
        expect(find.textContaining('secret backing'), findsNothing);
        // Given recovery of the backing configuration.
        store.fault = null;
        // When explicitly reloading the recovered definitions.
        await tapSettings(tester, find.widgetWithText(TextButton, 'Reload'));
        expect(
          // Then the old failure is removed.
          find.text('Submission configuration is unavailable.'),
          findsNothing,
        );
        // When explicitly clearing storage only.
        tester.widget<DropdownButton<String>>(defaults.first).onChanged!(null);
        await tester.pumpAndSettle();
        // Then transport is preserved and storage receives null.
        expect(store.value.selectedStorageConnectionId, isNull);
        expect(store.value.selectedTransportConnectionId, 'transport');
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        controller.dispose();
        await store.close();
      }
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets(
      'CU2 ephemeral bearer and exact authorization survive owner replacement',
      (tester) async {
        // Given exact Android capability bindings over controlled host observations.
        final channel = ControlledSubmissionConfigurationChannel()..attach();
        final native = AndroidSubmissionConfigurationStore();
        final facade = SubmissionConfigurationFacade.android(store: native);
        final controller = SubmissionSettingsController(facade: facade);
        final replacement = SubmissionSettingsController(facade: facade);
        try {
          // When explicitly loading and mounting the borrowed page.
          await controller.load();
          await tester.pumpWidget(
            MaterialApp(home: SubmissionSettingsPage(controller: controller)),
          );
          await tester.pumpAndSettle();
          final callsAfterLoad = channel.calls.length;
          await tester.pump();
          // Then ordinary build issues no authorization or credential write.
          expect(channel.calls.length, callsAfterLoad);
          expect(find.text('Authorization: Not checked'), findsOneWidget);
          await tapSettings(
            tester,
            // When explicitly refreshing the chosen Drive authorization.
            find.widgetWithText(TextButton, 'Refresh authorization'),
          );
          expect(
            // Then the literal required observation appears.
            find.text('Authorization: authorizationRequired'),
            findsOneWidget,
          );
          // Given an available next authorization observation.
          channel.authorization = SubmissionAuthorizationState.available;
          await tapSettings(
            tester,
            // When explicitly authorizing that Drive ID.
            find.widgetWithText(TextButton, 'Authorize'),
          );
          // Then its literal available enum is shown.
          expect(find.text('Authorization: available'), findsOneWidget);
          // Given an ephemeral bearer input and a held write gate.
          final tokenFinder = settingsField('Bearer token for transport');
          await tester.ensureVisible(tokenFinder);
          await tester.enterText(tokenFinder, 'ephemeral');
          final setButton = find
              .widgetWithText(TextButton, 'Set credential')
              .first;
          final stale = tester.widget<TextButton>(setButton).onPressed!;
          final gate = SubmissionGate();
          channel.gate = gate;
          await tester.ensureVisible(setButton);
          // When explicitly tapping Set credential.
          await tester.tap(setButton);
          await tester.pump();
          expect(
            // Then input is empty while the accepted write remains busy.
            tester.widget<TextField>(tokenFinder).controller!.text,
            isEmpty,
          );
          expect(controller.busy, isTrue);
          // When the controlled credential write settles.
          gate.release();
          await tester.pumpAndSettle();
          channel.gate = null;
          final tokenCall = channel.calls.last;
          // Then exact HTTP ID and ephemeral token reach the writer.
          expect(tokenCall.method, 'setHttpBearerToken');
          expect(tokenCall.arguments, {
            'connectionId': 'transport',
            'token': 'ephemeral',
          });
          await tapSettings(
            tester,
            // When explicitly clearing the exact HTTP credential.
            find.widgetWithText(TextButton, 'Clear credential').first,
          );
          // Then null reaches that exact ID.
          expect(channel.calls.last.arguments, {
            'connectionId': 'transport',
            'token': null,
          });
          // Given an unsent input buffer for the original owner.
          await tester.enterText(tokenFinder, 'discard-on-replacement');
          await replacement.load();
          // When replacing the page controller.
          await tester.pumpWidget(
            MaterialApp(home: SubmissionSettingsPage(controller: replacement)),
          );
          await tester.pumpAndSettle();
          expect(
            // Then replacement clears the local credential buffer.
            tester.widget<TextField>(tokenFinder).controller!.text,
            isEmpty,
          );
          final count = channel.calls.length;
          // When invoking the old rendered credential callback.
          stale();
          await tester.pump();
          // Then it performs no write through either owner.
          expect(channel.calls.length, count);
          // Given an input for the other exact HTTP target.
          final other = settingsField('Bearer token for otherTransport');
          await tester.ensureVisible(other);
          await tester.enterText(other, 'other-secret');
          await tapSettings(
            tester,
            // When explicitly setting that target credential.
            find.widgetWithText(TextButton, 'Set credential').last,
          );
          // Then only the other ID is dispatched and its input clears.
          expect(channel.calls.last.arguments, {
            'connectionId': 'otherTransport',
            'token': 'other-secret',
          });
          expect(tester.widget<TextField>(other).controller!.text, isEmpty);
          final unmounted = tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Set credential').last,
              )
              .onPressed!;
          // When unmounting and invoking its captured callback afterward.
          await tester.pumpWidget(const SizedBox.shrink());
          final beforeUnmountTap = channel.calls.length;
          unmounted();
          // Then no late write or credential read occurs and controller ownership stays borrowed.
          expect(channel.calls.length, beforeUnmountTap);
          expect(controller.isDetached, isFalse);
          expect(
            channel.calls.any((call) => call.method == 'bearerToken'),
            isFalse,
          );
        } finally {
          // Release held work, remove presentation and drain borrowers before owner cleanup.
          channel.gate?.release();
          channel.gate = null;
          await tester.pumpWidget(const SizedBox.shrink());
          await controller.detach();
          await replacement.detach();
          controller.dispose();
          replacement.dispose();
          await native.close();
          await channel.dispose();
        }
      },
    );

    // Specify the named existing behavior with its actual setup, commands and observations.
    testWidgets('CU8 settings wraps at 320 and 900 with text scale two', (
      tester,
    ) async {
      // Given safe long definitions, an explicit loaded owner and doubled text at both widths.
      final store = MemorySubmissionConfiguration(submissionConfiguration());
      store.value = SubmissionConfigurationSnapshot(
        driveConnections: [
          DriveSubmissionConnection(
            id: 'storage',
            accountId: 'the-current-original-media-owner-with-a-long-account@example.test',
            folderId: 'folderA',
          ),
        ],
        httpConnections: [
          HttpSubmissionConnection(
            id: 'transport',
            endpoint: Uri.parse(
              'https://example.test/current-original-materials-and-complete-provenance/submission',
            ),
          ),
        ],
      );
      final controller = SubmissionSettingsController(
        facade: SubmissionConfigurationFacade(store: store),
      );
      try {
        // Load configuration explicitly before recording the read baseline.
        await controller.load();
        final reads = store.reads;
        for (final width in [320.0, 900.0]) {
          tester.view.resetPhysicalSize();
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          // When rendering and scrolling the narrow or expanded form.
          await tester.pumpWidget(
            MaterialApp(
              // Retain the effective OS text scaler in this layout fixture.
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: SubmissionSettingsPage(controller: controller),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.widgetWithText(TextButton, 'Add HTTP'),
          );
          await tester.pump();
          // Then layout is usable and build issues no additional configuration command.
          expect(tester.takeException(), isNull);
          expect(store.reads, reads);
          expect(store.writeAttempts, 0);
        }
      } finally {
        // Release held work, remove presentation and drain borrowers before owner cleanup.
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        controller.dispose();
        await store.close();
      }
    });
  });
}
