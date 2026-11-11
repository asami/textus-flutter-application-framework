import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

const participantHint = 'アカウントでログインして送信します。送信先は担当者が管理します。';
const pendingDestination = '送信先を準備中です。担当者に確認してください。';

void main() {
  for (final explicit in [true, false]) {
    testWidgets(
      '${explicit ? 'required hint without declaration' : 'stored v3 declaration'} exposes only participant intent',
      (tester) async {
        // Given actual Core snapshots and Android capabilities behind a controlled port.
        final channel = ControlledSubmissionConfigurationChannel()..attach();
        channel.backing.value = participantSnapshot(declared: !explicit);
        final native = AndroidSubmissionConfigurationStore();
        final controller = SubmissionSettingsController(
          facade: SubmissionConfigurationFacade.android(store: native),
        );
        var accountOpens = 0;
        void openAccount() => accountOpens++;
        try {
          await controller.load();
          final before = channel.calls.length;
          // When the borrowed participant page builds, it performs no account or native command.
          await tester.pumpWidget(
            MaterialApp(
              home: SubmissionSettingsPage(
                controller: controller,
                participantAuthenticationRequired: explicit,
                onOpenAccount: openAccount,
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Then private definitions are absent while participant copy remains truthful.
          expect(find.text(participantHint), findsOneWidget);
          expect(
            find.text(pendingDestination),
            explicit ? findsOneWidget : findsNothing,
          );
          expectCompactPage();
          expect(accountOpens, 0);
          expect(channel.calls.length, before);
          // When the participant explicitly opens Account once.
          await tester.tap(find.widgetWithText(TextButton, 'アカウントを開く'));
          await tester.pump();
          // Then only the supplied navigation intent fires, with no native authority acquisition.
          expect(accountOpens, 1);
          expect(channel.calls.length, before);
          // When explicitly reloading configuration in participant mode.
          await tester.tap(find.widgetWithText(TextButton, '再読み込み'));
          await tester.pumpAndSettle();
          // Then one snapshot read occurs and no token read, writer, consent or authorization is dispatched.
          expect(channel.calls.skip(before).map((call) => call.method), [
            'snapshot',
          ]);
          expect(channel.backing.writeAttempts, 0);
          expect(accountOpens, 1);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await controller.detach();
          controller.dispose();
          await native.close();
          await channel.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'participant reload reports absent loading failure and missing transport literally',
    (tester) async {
      // Given an unloaded, explicitly required owner and unrelated caller-owned user content.
      final store = MemorySubmissionConfiguration(
        participantSnapshot(declared: false),
      );
      final controller = SubmissionSettingsController(
        facade: SubmissionConfigurationFacade(store: store),
      );
      final gate = SubmissionGate();
      try {
        // When the participant settings first render before any explicit configuration read.
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                const Text('利用者のメモ private-marker はそのまま'),
                Expanded(
                  child: SubmissionSettingsPage(
                    controller: controller,
                    participantAuthenticationRequired: true,
                  ),
                ),
              ],
            ),
          ),
        );
        // Then absent configuration is not presented as loaded or ready; no dead Account button appears.
        expect(find.text('送信設定はまだ読み込まれていません。'), findsOneWidget);
        expect(find.text(pendingDestination), findsNothing);
        expect(find.text('アカウントを開く'), findsNothing);
        expect(store.reads, 0);
        // When an explicit read is held at its actual port.
        store.readGate = gate;
        await tester.tap(find.widgetWithText(TextButton, '再読み込み'));
        await tester.pump();
        // Then the real loading state appears and the read has entered without writes.
        expect(gate.entered.isCompleted, isTrue);
        expect(find.text('送信設定を読み込んでいます…'), findsOneWidget);
        expect(controller.busy, isTrue);
        // When the held configuration read fails with private backing details.
        store.fault = StateError(
          'private-marker credential-value https://private.test/',
        );
        gate.release();
        await tester.pumpAndSettle();
        // Then fixed failure copy replaces loading without copying the backing error.
        expect(find.text('送信設定を読み込めませんでした。'), findsOneWidget);
        expect(find.textContaining('credential-value'), findsNothing);
        expect(find.textContaining('https://private.test/'), findsNothing);
        expect(find.text('利用者のメモ private-marker はそのまま'), findsOneWidget);
        // When recovery loads a participant declaration with no selected transport.
        store.fault = null;
        store.readGate = null;
        store.value = participantSnapshot(selected: false);
        await tester.tap(find.widgetWithText(TextButton, '再読み込み'));
        await tester.pumpAndSettle();
        // Then pending configuration is explicit and technical controls remain absent.
        expect(find.text(pendingDestination), findsOneWidget);
        expect(find.text('送信設定を読み込めませんでした。'), findsNothing);
        expectCompactPage();
        expect(store.writeAttempts, 0);
      } finally {
        gate.release();
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        controller.dispose();
        await store.close();
      }
    },
  );

  testWidgets(
    'captured technical callbacks recheck snapshot mode before rebuild and replacement or detach',
    (tester) async {
      // Given the complete legacy form with real native capability bindings.
      final channel = ControlledSubmissionConfigurationChannel()..attach();
      final native = AndroidSubmissionConfigurationStore();
      final facade = SubmissionConfigurationFacade.android(store: native);
      final controller = SubmissionSettingsController(facade: facade);
      final replacement = SubmissionSettingsController(facade: facade);
      try {
        await controller.load();
        await tester.pumpWidget(
          MaterialApp(home: SubmissionSettingsPage(controller: controller)),
        );
        await tester.pumpAndSettle();
        final callbacks = technicalCallbacks(tester);
        final reload = tester
            .widget<TextButton>(find.widgetWithText(TextButton, '再読み込み'))
            .onPressed!;
        final account = <String>[];
        // When explicit participant policy replaces the rendered full form.
        await tester.pumpWidget(
          MaterialApp(
            home: SubmissionSettingsPage(
              controller: controller,
              participantAuthenticationRequired: true,
              onOpenAccount: () => account.add('intent'),
            ),
          ),
        );
        final count = channel.calls.length;
        for (final callback in callbacks) {
          callback();
        }
        await tester.pump();
        // Then old selectors, editors, writers and native auth callbacks cannot dispatch.
        expect(channel.calls.length, count);
        expectCompactPage();
        // When that same old Reload callback is intentionally used in participant mode.
        reload();
        await tester.pumpAndSettle();
        // Then general current ownership still allows exactly one configuration read.
        expect(channel.calls.skip(count).map((call) => call.method), [
          'snapshot',
        ]);
        expect(account, isEmpty);
        // Given a legacy render again, capture every mutator before a stored v3 mode read.
        await tester.pumpWidget(
          MaterialApp(home: SubmissionSettingsPage(controller: controller)),
        );
        await tester.pumpAndSettle();
        final beforeSnapshotChange = technicalCallbacks(tester);
        channel.backing.value = participantSnapshot();
        await controller.load();
        final loaded = channel.calls.length;
        // When callbacks run before the scheduled rebuild, current snapshot policy already blocks them.
        for (final callback in beforeSnapshotChange) {
          callback();
        }
        expect(channel.calls.length, loaded);
        await tester.pumpAndSettle();
        expectCompactPage();
        // When a different legacy owner is attached, old callback ownership remains revoked.
        channel.backing.value = submissionConfiguration();
        await replacement.load();
        await tester.pumpWidget(
          MaterialApp(home: SubmissionSettingsPage(controller: replacement)),
        );
        await tester.pumpAndSettle();
        final replaced = channel.calls.length;
        for (final callback in callbacks) {
          callback();
        }
        for (final callback in beforeSnapshotChange) {
          callback();
        }
        expect(channel.calls.length, replaced);
        final detachedCallbacks = technicalCallbacks(tester);
        // When the current owner detaches and later unmounts, its captured controls stay inert.
        await replacement.detach();
        for (final callback in detachedCallbacks) {
          callback();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        for (final callback in detachedCallbacks) {
          callback();
        }
        expect(channel.calls.length, replaced);
        expect(channel.backing.writeAttempts, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        await replacement.detach();
        controller.dispose();
        replacement.dispose();
        await native.close();
        await channel.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Account intent requires its current mounted attached idle owner',
    (tester) async {
      // Given two borrowed controller identities and an explicitly required participant view.
      final store = MemorySubmissionConfiguration(
        participantSnapshot(declared: false),
      );
      final facade = SubmissionConfigurationFacade(store: store);
      final controller = SubmissionSettingsController(facade: facade);
      final replacement = SubmissionSettingsController(facade: facade);
      final gate = SubmissionGate();
      var opens = 0;
      void openAccount() => opens++;
      Widget page(SubmissionSettingsController owner) => MaterialApp(
        home: SubmissionSettingsPage(
          controller: owner,
          participantAuthenticationRequired: true,
          onOpenAccount: openAccount,
        ),
      );
      try {
        await tester.pumpWidget(page(controller));
        final stale = tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'アカウントを開く'))
            .onPressed!;
        // When a real explicit read makes the same controller busy and old Account intent runs.
        store.readGate = gate;
        final loading = controller.load();
        await tester.pump();
        stale();
        // Then account navigation cannot race the busy owner, and the read remains accepted.
        expect(gate.entered.isCompleted, isTrue);
        expect(opens, 0);
        gate.release();
        await loading;
        await tester.pumpAndSettle();
        // When ordinary idle Account intent is explicitly tapped.
        await tester.tap(find.widgetWithText(TextButton, 'アカウントを開く'));
        // Then one user intent reaches the callback without any configuration mutation.
        expect(opens, 1);
        expect(store.writeAttempts, 0);
        // When a replacement owner attaches and the old button's callback runs.
        await tester.pumpWidget(page(replacement));
        stale();
        // Then old ownership is rejected even though the navigation callback identity is unchanged.
        expect(opens, 1);
        final detached = tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'アカウントを開く'))
            .onPressed!;
        // When that replacement detaches and later unmounts, captured intent stays revoked.
        await replacement.detach();
        detached();
        await tester.pumpWidget(const SizedBox.shrink());
        detached();
        // Then no detached or disposed owner invokes Account or writes configuration.
        expect(opens, 1);
        expect(store.writeAttempts, 0);
        expect(tester.takeException(), isNull);
      } finally {
        gate.release();
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        await replacement.detach();
        controller.dispose();
        replacement.dispose();
        await store.close();
      }
    },
  );

  testWidgets(
    'legacy false and null mode retains actual selectors credential writer and Drive authorization',
    (tester) async {
      // Given ordinary legacy configuration with Android's genuine public capability surface.
      final channel = ControlledSubmissionConfigurationChannel()..attach();
      final native = AndroidSubmissionConfigurationStore();
      final controller = SubmissionSettingsController(
        facade: SubmissionConfigurationFacade.android(store: native),
      );
      try {
        await controller.load();
        await tester.pumpWidget(
          MaterialApp(home: SubmissionSettingsPage(controller: controller)),
        );
        await tester.pumpAndSettle();
        // When selecting an actual legacy transport through its captured UI control.
        tester
            .widget<DropdownButton<String>>(
              find.byType(DropdownButton<String>).last,
            )
            .onChanged!('transport');
        await tester.pumpAndSettle();
        // Then the exact configuration selection is persisted.
        expect(
          channel.backing.value.selectedTransportConnectionId,
          'transport',
        );
        expect(find.text(participantHint), findsNothing);
        // When explicitly authorizing the legacy Drive connection.
        await tester.ensureVisible(find.widgetWithText(TextButton, '利用を許可'));
        await tester.tap(find.widgetWithText(TextButton, '利用を許可'));
        await tester.pumpAndSettle();
        // Then the public native authorization operation receives the exact ID.
        expect(channel.calls.last.method, 'authorizeDrive');
        expect(channel.calls.last.arguments, {'connectionId': 'storage'});
        final tokenField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'transportの認可情報（検証・初期設定用）',
        );
        await tester.ensureVisible(tokenField);
        await tester.enterText(tokenField, 'ephemeral-test-credential');
        // When an ordinary legacy participant explicitly writes that credential.
        final set = find.widgetWithText(TextButton, '認可情報を設定').first;
        await tester.ensureVisible(set);
        await tester.tap(set);
        await tester.pumpAndSettle();
        // Then the exact writer still works and its local sensitive buffer clears.
        expect(channel.calls.last.method, 'setHttpBearerToken');
        expect(channel.calls.last.arguments, {
          'connectionId': 'transport',
          'token': 'ephemeral-test-credential',
        });
        expect(tester.widget<TextField>(tokenField).controller!.text, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await controller.detach();
        controller.dispose();
        await native.close();
        await channel.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

SubmissionConfigurationSnapshot participantSnapshot({
  bool declared = true,
  bool selected = true,
}) => SubmissionConfigurationSnapshot(
  driveConnections: [
    DriveSubmissionConnection(
      id: 'private-drive',
      accountId: 'private-account',
      folderId: 'private-folder',
    ),
  ],
  httpConnections: [
    HttpSubmissionConnection(
      id: 'private-transport',
      endpoint: Uri.parse('https://private.test/delivery/'),
    ),
  ],
  selectedTransportConnectionId: selected ? 'private-transport' : null,
  participantAuthentication: declared
      ? SubmissionParticipantAuthenticationConfiguration(
          authorityProfileId: 'private-profile',
          authorityBaseUri: 'https://private.test/account/',
          trustedConnectionIds: ['private-transport'],
        )
      : null,
);

void expectCompactPage() {
  expect(find.byType(TextField), findsNothing);
  expect(find.byType(DropdownButton<String>), findsNothing);
  expect(find.byType(CheckboxListTile), findsNothing);
  for (final text in [
    'Drive接続を追加',
    'HTTP接続を追加',
    '利用を許可',
    '許可状態を確認',
    '認可情報を設定',
    '認可情報を解除',
    '原本の参照設定を保存',
  ]) {
    expect(find.text(text), findsNothing);
  }
  for (final marker in [
    'private-drive',
    'private-account',
    'private-folder',
    'private-transport',
    'private-profile',
  ]) {
    expect(find.textContaining(marker), findsNothing);
  }
  expect(find.textContaining('https://private.test/'), findsNothing);
}

List<VoidCallback> technicalCallbacks(WidgetTester tester) => [
  for (final button in tester.widgetList<TextButton>(find.byType(TextButton)))
    if (button.onPressed != null &&
        button.child is Text &&
        (button.child! as Text).data != '再読み込み')
      button.onPressed!,
  for (final dropdown in tester.widgetList<DropdownButton<String>>(
    find.byType(DropdownButton<String>),
  ))
    if (dropdown.onChanged != null) () => dropdown.onChanged!(null),
  for (final checkbox in tester.widgetList<CheckboxListTile>(
    find.byType(CheckboxListTile),
  ))
    if (checkbox.onChanged != null) () => checkbox.onChanged!(true),
];
