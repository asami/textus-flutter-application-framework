import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqlite;
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _idle(SubmissionSettingsController owner) async {
  if (!owner.busy) return;
  final done = Completer<void>();
  void changed() {
    if (!owner.busy && !done.isCompleted) done.complete();
  }

  owner.addListener(changed);
  try {
    changed();
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    owner.removeListener(changed);
  }
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder,
  SubmissionSettingsController owner,
) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _idle(owner);
  await tester.pumpAndSettle();
}

void main() {
  sqlite.sqfliteFfiInit();
  testWidgets(
    'iOS generic settings persist exact TKL intent and drain their borrowed store',
    (tester) async {
      await tester.runAsync(() async {
        // Given a real test-owned iOS configuration file and a read-only credential port.
        final previousPlatform = debugDefaultTargetPlatformOverride;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('org.textus.flutter.core/submission');
        // A missing prior handler is preserved exactly; never overwrite another owner.
        expect(messenger.checkMockMessageHandler(channel.name, null), isTrue);
        final directory = await Directory.systemTemp.createTemp(
          'ios-settings-',
        );
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final credentials = _Credentials();
        final handles = <IosSubmissionConfigurationStore>[];
        SubmissionSettingsController? controller;
        _ObservedStore? borrowed;
        final nativeCalls = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          throw StateError('Unexpected native submission operation');
        });
        try {
          final store = await IosSubmissionConfigurationStore.open(
            databasePath: '${directory.path}/configuration.sqlite',
            factory: sqlite.databaseFactoryFfi,
            credentials: credentials,
          );
          handles.add(store);
          final drive = DriveSubmissionConnection(
            id: 'legacyDrive',
            accountId: 'synthetic@example.test',
            folderId: 'SyntheticFolder',
          );
          await store.putDrive(drive);
          final observed = _ObservedStore(store);
          borrowed = observed;
          final facade = SubmissionConfigurationFacade(store: observed);
          final owner = SubmissionSettingsController(facade: facade);
          controller = owner;
          expect(facade.hasDriveAuthorization, isFalse);
          expect(facade.hasHttpCredentialWriter, isFalse);

          // When the common TKL-only page mounts, construction and build stay inert.
          await tester.pumpWidget(
            MaterialApp(
              home: SubmissionSettingsPage(
                controller: owner,
                tklDeliveryOnly: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(observed.reads, 0);
          expect(observed.writes, 0);
          expect(find.text('送信設定はまだ読み込まれていません。'), findsOneWidget);
          await _tap(tester, find.widgetWithText(TextButton, '再読み込み'), owner);
          expect(observed.reads, 1);
          expect(_field('Drive接続ID'), findsNothing);
          expect(_field('Googleアカウント'), findsNothing);
          expect(_field('フォルダーID'), findsNothing);
          expect(find.text('原本の保存先'), findsNothing);
          expect(find.text('利用を許可'), findsNothing);
          expect(find.text('原本の参照設定を保存'), findsNothing);

          // When the operator explicitly saves a synthetic TKL definition and selection.
          await tester.enterText(_field('接続ID'), 'lake');
          await tester.enterText(
            _field('TKLのHTTPS接続先（末尾は /）'),
            'https://synthetic.example.test/delivery/',
          );
          await _tap(
            tester,
            find.widgetWithText(TextButton, 'HTTP接続を追加'),
            owner,
          );
          expect(_field('lakeの認可情報（検証・初期設定用）'), findsNothing);
          expect(find.text('認可情報を設定'), findsNothing);
          expect(find.text('認可情報を解除'), findsNothing);
          final selector = tester.widget<DropdownButton<String>>(
            find.byType(DropdownButton<String>),
          );
          selector.onChanged!('lake');
          await _idle(owner);
          await tester.pumpAndSettle();
          final accepted = (await store.snapshot()).toJson();
          expect(
            owner.snapshot!.httpConnections.single.endpoint.toString(),
            'https://synthetic.example.test/delivery/',
          );
          expect(
            owner.snapshot!.httpConnections.single.requiresBearerToken,
            isTrue,
          );
          expect(owner.snapshot!.selectedTransportConnectionId, 'lake');
          expect(
            owner.snapshot!.driveConnections.single.toJson(),
            drive.toJson(),
          );
          expect(credentials.reads, 0);
          expect(nativeCalls, isEmpty);

          // Given the closed Core diagnostic vocabulary, presentation uses Japanese
          // while the controller's public safe message API retains its original values.
          const errors = {
            'configurationUnavailable': '送信設定を読み込めませんでした。',
            'configurationInvalid': '送信設定を確認してください。',
            'connectionConflict': '同じ接続IDに別の設定が登録されています。',
            'connectionMissing': '接続先が設定されていません。',
            'configurationClosed': 'この送信設定は閉じられました。',
            'authorizationRequired': '認証が必要です。',
            'authorizationCancelled': '認証を取り消しました。',
            'authorizationBusy': '認証の処理中です。',
            'foregroundRequired': 'アプリを開いて認証してください。',
            'credentialUnavailable': '認可情報を利用できません。',
          };
          for (final error in errors.entries) {
            observed.failureCode = error.key;
            expect(await owner.load(), isFalse);
            await tester.pumpAndSettle();
            expect(find.text(error.value), findsOneWidget);
            expect(owner.failureCode, error.key);
            expect(
              owner.failureMessage,
              SubmissionConfigurationException.messages[error.key],
            );
          }
          observed.failureCode = 'unknown';
          expect(await owner.load(), isFalse);
          await tester.pumpAndSettle();
          expect(find.text('送信設定を読み込めませんでした。'), findsOneWidget);
          observed.failureCode = null;
          expect(await owner.load(), isTrue);
          await tester.pumpAndSettle();
          expect((await store.snapshot()).toJson(), accepted);

          // Given one accepted held configuration read, retirement must join it.
          observed.readEntered = Completer<void>();
          observed.readRelease = Completer<void>();
          final loading = owner.load();
          await observed.readEntered!.future;
          var drained = false;
          final detaching = owner.detach().then((_) => drained = true);
          await Future<void>.value();
          expect(drained, isFalse);
          observed.readRelease!.complete();
          expect(await loading, isFalse);
          await detaching;
          expect(drained, isTrue);
          expect(observed.closes, 0);
          expect((await store.snapshot()).toJson(), accepted);
          await tester.pumpWidget(const SizedBox.shrink());
          owner.dispose();
          controller = null;
          await store.close();

          // Then a new independently owned handle observes the exact durable intent.
          final reopened = await IosSubmissionConfigurationStore.open(
            databasePath: '${directory.path}/configuration.sqlite',
            factory: sqlite.databaseFactoryFfi,
            credentials: credentials,
          );
          handles.add(reopened);
          expect((await reopened.snapshot()).toJson(), accepted);
          expect(credentials.reads, 0);
          expect(nativeCalls, isEmpty);
        } finally {
          final release = borrowed?.readRelease;
          if (release != null && !release.isCompleted) release.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          await controller?.detach();
          controller?.dispose();
          try {
            for (final handle in handles) {
              await handle.close();
            }
            await directory.delete(recursive: true);
          } finally {
            messenger.setMockMethodCallHandler(channel, null);
            debugDefaultTargetPlatformOverride = previousPlatform;
          }
        }
      });
    },
  );
}

final class _Credentials implements SubmissionCredentialProvider {
  int reads = 0;

  @override
  Future<String?> bearerToken(String connectionId) async {
    reads++;
    return 'UNUSED_SYNTHETIC_TOKEN';
  }
}

// Test observation only; all persistence remains the actual Core iOS store.
final class _ObservedStore implements SubmissionConfigurationStore {
  _ObservedStore(this.inner);
  final IosSubmissionConfigurationStore inner;
  int reads = 0;
  int writes = 0;
  int closes = 0;
  String? failureCode;
  Completer<void>? readEntered;
  Completer<void>? readRelease;

  @override
  Future<SubmissionConfigurationSnapshot> snapshot() async {
    reads++;
    final entered = readEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    await readRelease?.future;
    final failure = failureCode;
    if (failure != null) throw SubmissionConfigurationException.safe(failure);
    return inner.snapshot();
  }

  @override
  Future<void> putDrive(DriveSubmissionConnection connection) {
    writes++;
    return inner.putDrive(connection);
  }

  @override
  Future<void> putHttp(HttpSubmissionConnection connection) {
    writes++;
    return inner.putHttp(connection);
  }

  @override
  Future<void> select({
    String? storageConnectionId,
    String? transportConnectionId,
  }) {
    writes++;
    return inner.select(
      storageConnectionId: storageConnectionId,
      transportConnectionId: transportConnectionId,
    );
  }

  @override
  Future<void> setReferenceAccess({
    required String transportConnectionId,
    required List<String> storageConnectionIds,
  }) {
    writes++;
    return inner.setReferenceAccess(
      transportConnectionId: transportConnectionId,
      storageConnectionIds: storageConnectionIds,
    );
  }

  @override
  Future<void> close() {
    closes++;
    return inner.close();
  }
}
