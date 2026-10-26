import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import 'support/submission_fixture.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'TKL setup asks only for service bootstrap and retains legacy Drive definitions',
    (tester) async {
      // Given existing legacy connections needed by previously committed work.
      final initial = submissionConfiguration();
      final store = MemorySubmissionConfiguration(initial);
      final controller = SubmissionSettingsController(
        facade: SubmissionConfigurationFacade(store: store),
      );
      try {
        // When explicitly loading the TKL-specific common settings page.
        await tester.pumpWidget(
          MaterialApp(
            home: SubmissionSettingsPage(
              controller: controller,
              tklDeliveryOnly: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.reads, 0);
        await _tap(tester, find.widgetWithText(TextButton, 'Reload'));
        // Then mobile users are never asked to provision physical Google storage.
        expect(_field('Drive ID'), findsNothing);
        expect(_field('Account ID'), findsNothing);
        expect(_field('Folder ID'), findsNothing);
        expect(find.text('Default storage'), findsNothing);
        expect(find.text('Save reference access declaration'), findsNothing);
        expect(find.text('Authorize'), findsNothing);
        expect(find.text('TKL service connection'), findsOneWidget);
        expect(
          find.text(
            'TKL supplies the destination and transfer instructions. Google storage is configured on the server.',
          ),
          findsOneWidget,
        );
        // Given the TKL setup form and a new HTTP connection ID.
        await tester.enterText(_field('HTTP ID'), 'lake');
        await tester.enterText(
          _field('TKL HTTPS service root (ends with /)'),
          'https://lake.example.test/finalize',
        );
        // When Add HTTP receives an operation URL instead of a service root ending in a slash.
        await _tap(tester, find.widgetWithText(TextButton, 'Add HTTP'));
        // Then the invalid connection is not stored.
        expect(
          store.value.httpConnections.any(
            (connection) => connection.id == 'lake',
          ),
          isFalse,
        );
        // Given the same connection ID with a valid HTTPS delivery service root.
        await tester.enterText(
          _field('TKL HTTPS service root (ends with /)'),
          'https://lake.example.test/delivery/',
        );
        // When Add HTTP receives that valid service root.
        await _tap(tester, find.widgetWithText(TextButton, 'Add HTTP'));
        // Then the stored connection requires a bearer and retains the exact service root.
        final connection = store.value.httpConnections.singleWhere(
          (connection) => connection.id == 'lake',
        );
        expect(connection.requiresBearerToken, isTrue);
        expect(
          connection.endpoint.toString(),
          'https://lake.example.test/delivery/',
        );
        // Then old definitions, selections and access bindings survive this addition.
        expect(store.value.driveConnections, initial.driveConnections);
        expect(
          store.value.selectedStorageConnectionId,
          initial.selectedStorageConnectionId,
        );
        expect(
          store.value.selectedTransportConnectionId,
          initial.selectedTransportConnectionId,
        );
        expect(
          store.value.referenceAccessBindings,
          initial.referenceAccessBindings,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
      }
    },
  );
}
