import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  testWidgets(
    'pending refresh hides protected input and successful same-account refresh retains its draft',
    (tester) async {
      // Given an authenticated protected view with a caller's unsaved text.
      final backend = _Backend();
      final client = UserAccountAuthenticationClient(backend: backend);
      final facade = UserAccountAuthenticationFacade(client: client);
      addTearDown(client.close);
      addTearDown(facade.dispose);
      await facade.signIn(identifier: 'synthetic', password: 'synthetic');
      await tester.pumpWidget(
        MaterialApp(
          home: UserAccountProtectedView(
            facade: facade,
            builder: (_) =>
                const Scaffold(body: TextField(key: ValueKey('draft'))),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'unsaved interpretation',
      );
      // When same-account refresh is pending and later succeeds.
      final refreshing = facade.refresh();
      await tester.pump();
      expect(find.byKey(const ValueKey('draft')), findsNothing);
      expect(find.text('処理中です。しばらくお待ちください。'), findsOneWidget);
      backend.refreshed.complete(
        UserAccountSignedIn(
          AuthenticatedUserAccount(userAccountId: 'synthetic/owner'),
        ),
      );
      await refreshing;
      await tester.pumpAndSettle();
      // Then the protected text is hidden while pending and retained on success.
      expect(find.text('unsaved interpretation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'protected entry builds only after accepted login and retires on logout',
    (tester) async {
      // Given a signed-out client whose protected builder has never run.
      final backend = _Backend();
      final client = UserAccountAuthenticationClient(backend: backend);
      final facade = UserAccountAuthenticationFacade(client: client);
      addTearDown(client.close);
      addTearDown(facade.dispose);
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: UserAccountProtectedView(
            facade: facade,
            builder: (_) {
              builds++;
              return const Text('Private workspace');
            },
          ),
        ),
      );
      expect(builds, 0);
      expect(find.text('ログインID'), findsOneWidget);
      // When login is accepted, then the protected entry becomes visible exactly once.
      await facade.signIn(identifier: 'synthetic', password: 'synthetic');
      await tester.pumpAndSettle();
      expect(find.text('Private workspace'), findsOneWidget);
      expect(builds, 1);
      // When logout completes, then protected content retires without owning the borrowed client.
      await facade.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Private workspace'), findsNothing);
      expect(find.text('ログインID'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(client.isClosed, isFalse);
    },
  );
}

class _Backend implements UserAccountAuthenticationBackend {
  final refreshed = Completer<UserAccountSignInResult>();
  @override
  Future<UserAccountSignInResult> signIn({
    required String identifier,
    required String password,
    required UserAccountAuthenticationOperation operation,
  }) async => UserAccountSignedIn(
    AuthenticatedUserAccount(userAccountId: 'synthetic/owner'),
  );
  @override
  Future<UserAccountSignInResult> verifyChallenge({
    required String challengeId,
    required String code,
    required UserAccountAuthenticationOperation operation,
  }) => throw UnimplementedError();
  @override
  Future<UserAccountSignInResult> refresh({
    required UserAccountAuthenticationOperation operation,
  }) => refreshed.future;
  @override
  Future<UserAccountLogoutResult> signOut({
    required UserAccountAuthenticationOperation operation,
  }) async => const UserAccountLogoutResult(
    localCleared: true,
    remoteRevocation: UserAccountRemoteRevocation.confirmed,
  );
  @override
  Future<void> close() async {}
}
