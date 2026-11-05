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
        await _tap(tester, find.widgetWithText(TextButton, '再読み込み'));
        // Then mobile users are never asked to provision physical Google storage.
        expect(_field('Drive接続ID'), findsNothing);
        expect(_field('Googleアカウント'), findsNothing);
        expect(_field('フォルダーID'), findsNothing);
        expect(find.text('原本の保存先'), findsNothing);
        expect(find.text('原本の参照設定を保存'), findsNothing);
        expect(find.text('利用を許可'), findsNothing);
        expect(find.text('TKL接続'), findsOneWidget);
        expect(
          find.text(
            '保存先と転送方法はTKLが指定します。Google側の保存先はサーバーで設定します。',
          ),
          findsOneWidget,
        );
        // Given the TKL setup form and a new HTTP connection ID.
        await tester.enterText(_field('接続ID'), 'lake');
        await tester.enterText(
          _field('TKLのHTTPS接続先（末尾は /）'),
          'https://lake.example.test/finalize',
        );
        // When Add HTTP receives an operation URL instead of a service root ending in a slash.
        await _tap(tester, find.widgetWithText(TextButton, 'HTTP接続を追加'));
        // Then the invalid connection is not stored.
        expect(
          store.value.httpConnections.any(
            (connection) => connection.id == 'lake',
          ),
          isFalse,
        );
        // Given the same connection ID with a valid HTTPS delivery service root.
        await tester.enterText(
          _field('TKLのHTTPS接続先（末尾は /）'),
          'https://lake.example.test/delivery/',
        );
        // When Add HTTP receives that valid service root.
        await _tap(tester, find.widgetWithText(TextButton, 'HTTP接続を追加'));
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
