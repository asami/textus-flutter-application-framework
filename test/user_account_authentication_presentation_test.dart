import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

void main() {
  group('safe construction and command admission', () {
    testWidgets(
      'should construct and mount without IO and explain unavailable login',
      (tester) async {
        // Given a real configured client and an explicitly unavailable client.
        final backend = _ControlledBackend();
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        final unavailableClient = UserAccountAuthenticationClient.unavailable();
        final unavailable = UserAccountAuthenticationFacade(
          client: unavailableClient,
        );
        // When both presentations mount and the unavailable commands are attempted.
        await _mount(tester, facade);
        await _mount(tester, unavailable);
        await expectLater(
          unavailable.signIn(identifier: 'private-id', password: 'private-pw'),
          throwsStateError,
        );
        await expectLater(
          unavailable.verifyChallenge('private-code'),
          throwsStateError,
        );
        await expectLater(unavailable.refresh(), throwsStateError);
        await expectLater(unavailable.cancel(), throwsStateError);
        await expectLater(unavailable.signOut(), throwsStateError);
        // Then there are no backend calls, credential fields or working actions.
        expect(backend.calls, isEmpty);
        expect(find.text('ログインの接続を準備中です。'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.widgetWithText(FilledButton, 'ログイン'), findsNothing);
        expect(_flags(unavailable), everyElement(isFalse));
        await tester.pumpWidget(const SizedBox.shrink());
        facade.dispose();
        unavailable.dispose();
        await client.close();
        await unavailableClient.close();
      },
    );

    test('should forward refresh and cancellation through Core admission', () async {
      // Given an idle real client with a deferred refresh.
      final pending = Completer<UserAccountSignInResult>();
      final backend = _ControlledBackend();
      backend.onRefresh = () => pending.future;
      final client = UserAccountAuthenticationClient(backend: backend);
      final facade = UserAccountAuthenticationFacade(client: client);
      // When invalid actions are rejected and a real sign-in then refresh starts.
      await expectLater(facade.refresh(), throwsStateError);
      await expectLater(facade.cancel(), throwsStateError);
      await expectLater(facade.verifyChallenge('code'), throwsStateError);
      await facade.signIn(identifier: 'entered', password: ' pw ');
      expect(facade.snapshot, same(client.snapshot));
      expect(facade.canRefresh, isTrue);
      expect(facade.canSignIn, isFalse);
      final refresh = facade.refresh();
      expect(facade.busy, isTrue);
      expect(facade.snapshot.account, isNull);
      expect(facade.canCancel, isTrue);
      expect(facade.canSignOut, isTrue);
      await expectLater(facade.refresh(), throwsStateError);
      final cancellation = facade.cancel();
      expect(
        facade.snapshot.status,
        UserAccountAuthenticationStatus.cancelling,
      );
      expect(_flags(facade), everyElement(isFalse));
      await expectLater(
        facade.signIn(identifier: 'duplicate', password: 'pw'),
        throwsStateError,
      );
      pending.complete(UserAccountSignedIn(_account()));
      await Future.wait([refresh, cancellation]);
      // Then retirement prevents refresh success from resurrecting an account.
      expect(backend.calls, ['signIn', 'refresh']);
      expect(backend.operations.last.isCurrent, isFalse);
      expect(facade.snapshot.status, UserAccountAuthenticationStatus.signedOut);
      expect(facade.snapshot.account, isNull);
      expect(facade.canSignIn, isTrue);
      facade.dispose();
      await client.close();
    });

    test(
      'should withdraw and drain authentication before forwarding logout',
      () async {
        // Given sign-in accepted by Core but not yet completed by the backend.
        final pending = Completer<UserAccountSignInResult>();
        final backend = _ControlledBackend();
        backend.onSignIn = () => pending.future;
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        final signIn = facade.signIn(identifier: 'id', password: 'pw');
        // When logout supersedes that authentication operation.
        final logout = facade.signOut();
        expect(
          facade.snapshot.status,
          UserAccountAuthenticationStatus.signingOut,
        );
        expect(facade.snapshot.account, isNull);
        expect(backend.calls, ['signIn']);
        expect(backend.operations.single.isCurrent, isFalse);
        expect(_flags(facade), everyElement(isFalse));
        await expectLater(facade.signOut(), throwsStateError);
        pending.complete(UserAccountSignedIn(_account()));
        await signIn;
        final result = await logout;
        // Then only the fresh logout runs after drain and its exact safe result returns.
        expect(result.localCleared, isTrue);
        expect(result.remoteRevocation, UserAccountRemoteRevocation.confirmed);
        expect(facade.snapshot.lastLogoutResult, same(result));
        expect(facade.snapshot.isAuthenticated, isFalse);
        expect(backend.calls, ['signIn', 'signOut']);
        facade.dispose();
        await client.close();
      },
    );
  });

  group('borrowed facade observations of direct Core work', () {
    test('should notify idle command admission when another owner completes Core actions', () async {
      // Given a borrowed real Core client and synchronous facade observations.
      final signIn = Completer<UserAccountSignInResult>();
      final verification = Completer<UserAccountSignInResult>();
      final refresh = Completer<UserAccountSignInResult>();
      final logout = Completer<UserAccountLogoutResult>();
      final backend = _ControlledBackend();
      backend.onSignIn = () => signIn.future;
      backend.onVerify = () => verification.future;
      backend.onRefresh = () => refresh.future;
      backend.onSignOut = () => logout.future;
      final client = UserAccountAuthenticationClient(backend: backend);
      final facade = UserAccountAuthenticationFacade(client: client);
      final observations =
          <(UserAccountAuthenticationStatus, bool, bool, bool, bool)>[];
      facade.addListener(() {
        observations.add((
          facade.snapshot.status,
          facade.busy,
          facade.canVerifyChallenge,
          facade.canRefresh,
          facade.canSignIn,
        ));
      });
      // When another owner signs in directly through Core to an email challenge.
      final signingIn = client.signIn(identifier: 'id', password: 'pw');
      signIn.complete(
        const UserAccountChallengePending('private-reference', 'email'),
      );
      await signingIn;
      // Then the facade callback sees idle verification admission without a facade call.
      expect(observations.last, (
        UserAccountAuthenticationStatus.challengeRequired,
        false,
        true,
        false,
        false,
      ));
      expect(facade.snapshot.account, isNull);
      // When the owner directly verifies the challenge.
      final verifying = client.verifyChallenge('code');
      verification.complete(UserAccountSignedIn(_account()));
      await verifying;
      // Then the facade callback sees authenticated idle refresh admission.
      expect(observations.last, (
        UserAccountAuthenticationStatus.authenticated,
        false,
        false,
        true,
        false,
      ));
      // When that owner directly refreshes its authoritative account.
      final refreshing = client.refresh();
      refresh.complete(UserAccountSignedIn(_account()));
      await refreshing;
      // Then the final callback restores refresh admission after Core becomes idle.
      expect(observations.last, (
        UserAccountAuthenticationStatus.authenticated,
        false,
        false,
        true,
        false,
      ));
      // When the owner directly logs out with confirmed local clearance.
      final signingOut = client.signOut();
      const result = UserAccountLogoutResult(
        localCleared: true,
        remoteRevocation: UserAccountRemoteRevocation.failed,
      );
      logout.complete(result);
      await signingOut;
      // Then every action has a final idle admission callback with exact logout facts.
      expect(observations, [
        (UserAccountAuthenticationStatus.signingIn, true, false, false, false),
        (
          UserAccountAuthenticationStatus.challengeRequired,
          true,
          false,
          false,
          false,
        ),
        (
          UserAccountAuthenticationStatus.challengeRequired,
          false,
          true,
          false,
          false,
        ),
        (UserAccountAuthenticationStatus.signingIn, true, false, false, false),
        (
          UserAccountAuthenticationStatus.authenticated,
          true,
          false,
          false,
          false,
        ),
        (
          UserAccountAuthenticationStatus.authenticated,
          false,
          false,
          true,
          false,
        ),
        (UserAccountAuthenticationStatus.refreshing, true, false, false, false),
        (
          UserAccountAuthenticationStatus.authenticated,
          true,
          false,
          false,
          false,
        ),
        (
          UserAccountAuthenticationStatus.authenticated,
          false,
          false,
          true,
          false,
        ),
        (UserAccountAuthenticationStatus.signingOut, true, false, false, false),
        (UserAccountAuthenticationStatus.signedOut, true, false, false, false),
        (UserAccountAuthenticationStatus.signedOut, false, false, false, true),
      ]);
      expect(facade.snapshot.lastLogoutResult, same(result));
      expect(facade.snapshot.account, isNull);
      expect(backend.calls, [
        'signIn',
        'verifyChallenge',
        'refresh',
        'signOut',
      ]);
      expect(client.isClosed, isFalse);
      facade.dispose();
      await client.close();
    });

    for (final cancel in [false, true]) {
      test(
        'should notify idle sign-in admission after direct Core ${cancel ? 'cancellation' : 'rejection'}',
        () async {
          // Given deferred Core work and a borrowed facade listener recording admission.
          final pending = Completer<UserAccountSignInResult>();
          final backend = _ControlledBackend()..onSignIn = () => pending.future;
          final client = UserAccountAuthenticationClient(backend: backend);
          final facade = UserAccountAuthenticationFacade(client: client);
          final observations =
              <(UserAccountAuthenticationStatus, bool, bool, bool, bool)>[];
          facade.addListener(() {
            observations.add((
              facade.snapshot.status,
              facade.busy,
              facade.canVerifyChallenge,
              facade.canRefresh,
              facade.canSignIn,
            ));
          });
          // When another owner directly cancels or receives rejected sign-in.
          final work = client.signIn(identifier: 'id', password: 'pw');
          final cancellation = cancel ? client.cancel() : null;
          pending.complete(
            cancel
                ? UserAccountSignedIn(_account())
                : const UserAccountSignInRejected(
                    UserAccountAuthenticationFailure.invalidCredentials,
                  ),
          );
          await work;
          await cancellation;
          // Then callback-time state finally allows sign-in without reviving an account.
          final status = cancel
              ? UserAccountAuthenticationStatus.signedOut
              : UserAccountAuthenticationStatus.failure;
          expect(observations.last, (status, false, false, false, true));
          expect(observations[observations.length - 2], (
            status,
            true,
            false,
            false,
            false,
          ));
          expect(observations, hasLength(cancel ? 4 : 3));
          expect(
            observations.any(
              (entry) =>
                  entry.$1 == UserAccountAuthenticationStatus.authenticated,
            ),
            isFalse,
          );
          expect(
            facade.snapshot.failure,
            cancel
                ? UserAccountAuthenticationFailure.cancelled
                : UserAccountAuthenticationFailure.invalidCredentials,
          );
          expect(facade.snapshot.account, isNull);
          expect(facade.snapshot.challengeChannel, isNull);
          expect(backend.calls, ['signIn']);
          facade.dispose();
          await client.close();
        },
      );
    }
  });

  group('facade ownership and notification lifetime', () {
    test('should retire a borrowed facade without retiring its client work', () async {
      // Given pending work in a borrowed real client and a listening facade.
      final pending = Completer<UserAccountSignInResult>();
      final backend = _ControlledBackend();
      backend.onSignIn = () => pending.future;
      final client = UserAccountAuthenticationClient(backend: backend);
      final facade = UserAccountAuthenticationFacade(client: client);
      var notifications = 0;
      facade.addListener(() => notifications++);
      final work = facade.signIn(identifier: 'id', password: 'pw');
      // When close is repeated and disposal follows while work remains pending.
      final close = facade.close();
      expect(facade.close(), same(close));
      final closed = facade.snapshot;
      expect(closed.status, UserAccountAuthenticationStatus.closed);
      expect(closed.account, isNull);
      expect(closed.lastLogoutResult, isNull);
      expect(facade.busy, isFalse);
      expect(_flags(facade), everyElement(isFalse));
      await close;
      final retiredNotifications = notifications;
      facade.dispose();
      facade.dispose();
      pending.complete(UserAccountSignedIn(_account()));
      await work;
      // Then borrowed work completes for its owner without reviving the facade.
      expect(client.snapshot.isAuthenticated, isTrue);
      expect(client.isClosed, isFalse);
      expect(facade.snapshot, same(closed));
      expect(notifications, retiredNotifications);
      expect(backend.calls, ['signIn']);
      expect(backend.closes, 0);
      await expectLater(facade.refresh(), throwsStateError);
      await expectLater(facade.signOut(), throwsStateError);
      await client.close();
    });

    test('should close an owned client once and sanitize cleanup failures', () async {
      // Given an owned Core client whose owned backend fails during cleanup.
      final backend = _ControlledBackend();
      backend.closeFailure = StateError('private-backend-close');
      final client = UserAccountAuthenticationClient(
        backend: backend,
        ownsBackend: true,
      );
      final facade = UserAccountAuthenticationFacade(
        client: client,
        ownsClient: true,
      );
      await facade.signIn(identifier: 'id', password: 'pw');
      // When closing repeatedly and disposing after the safe failure.
      final close = facade.close();
      expect(facade.close(), same(close));
      expect(facade.snapshot.account, isNull);
      expect(client.isClosed, isTrue);
      await expectLater(
        close,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'safe close message',
            'Authentication close failed',
          ),
        ),
      );
      facade.dispose();
      facade.dispose();
      // Then cleanup happened once without an implicit logout or private cause.
      expect(backend.closes, 1);
      expect(backend.calls, ['signIn']);
      expect(_flags(facade), everyElement(isFalse));
    });

    test('should safely dispose inside a notification and observe async close errors', () async {
      // Given an owned facade disposed by its own first listener.
      final backend = _ControlledBackend();
      backend.closeFailure = StateError('untrusted-close-detail');
      final client = UserAccountAuthenticationClient(
        backend: backend,
        ownsBackend: true,
      );
      final facade = UserAccountAuthenticationFacade(
        client: client,
        ownsClient: true,
      );
      var notifications = 0;
      facade.addListener(() {
        notifications++;
        facade.dispose();
        facade.dispose();
      });
      // When Core synchronously publishes sign-in before backend invocation.
      await facade.signIn(identifier: 'id', password: 'pw');
      await Future<void>.delayed(Duration.zero);
      // Then reentrant disposal is safe, backend sign-in never starts and errors are observed.
      expect(facade.isClosed, isTrue);
      expect(client.isClosed, isTrue);
      expect(notifications, 1);
      expect(backend.calls, isEmpty);
      expect(backend.closes, 1);
    });
  });

  group('ephemeral credentials and authoritative presentation', () {
    testWidgets(
      'should clear exact password input before calling Core and display authority identity',
      (tester) async {
        // Given a bounded form and a deferred authoritative sign-in result.
        final pending = Completer<UserAccountSignInResult>();
        final backend = _ControlledBackend();
        backend.onSignIn = () => pending.future;
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await _mount(tester, facade);
        await tester.enterText(_field('ログインID'), ' entered-login ');
        await tester.enterText(_field('パスワード'), ' pw whitespace ');
        final password = tester.widget<TextField>(_field('パスワード'));
        expect(password.obscureText, isTrue);
        expect(password.autocorrect, isFalse);
        expect(password.enableSuggestions, isFalse);
        backend.onSignIn = () {
          expect(password.controller!.text, isEmpty);
          return pending.future;
        };
        // When login is submitted, then its ephemeral buffer is empty before backend IO.
        await _tap(tester, 'ログイン');
        expect(password.controller!.text, isEmpty);
        expect(backend.identifier, ' entered-login ');
        expect(backend.password, ' pw whitespace ');
        expect(find.text('処理中です。しばらくお待ちください。'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'ログイン'), findsNothing);
        expect(find.text('キャンセル'), findsOneWidget);
        // When the authority returns an account unrelated to entered login text.
        pending.complete(UserAccountSignedIn(_account()));
        await tester.pumpAndSettle();
        // Then only that authoritative name and exact account ID are displayed.
        expect(find.text('Authority Name'), findsOneWidget);
        expect(find.text('アカウントID: urn:account:exact'), findsOneWidget);
        expect(find.textContaining('entered-login'), findsNothing);
        expect(find.textContaining('pw whitespace'), findsNothing);
        expect(find.text('ログアウト'), findsOneWidget);
        expect(find.textContaining('refresh'), findsNothing);
        await _unmount(tester, facade, client);
      },
    );

    testWidgets(
      'should keep email challenge private and clear exact confirmation code before verification',
      (tester) async {
        // Given a real Core email challenge and a deferred verification.
        final pending = Completer<UserAccountSignInResult>();
        final backend = _ControlledBackend();
        backend.onSignIn = () => const UserAccountChallengePending(
          'private-challenge-reference',
          'email',
        );
        backend.onVerify = () => pending.future;
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await facade.signIn(identifier: 'id', password: 'pw');
        await _mount(tester, facade);
        expect(facade.snapshot.isAuthenticated, isFalse);
        expect(find.text('メールに届いた確認コードを入力してください。'), findsOneWidget);
        expect(find.textContaining('private-challenge'), findsNothing);
        expect(find.textContaining('アカウントID:'), findsNothing);
        await tester.enterText(_field('確認コード'), ' 123 456 ');
        final code = tester.widget<TextField>(_field('確認コード')).controller!;
        backend.onVerify = () {
          expect(code.text, isEmpty);
          return pending.future;
        };
        // When exact code confirmation is submitted.
        await _tap(tester, '確認する');
        expect(code.text, isEmpty);
        expect(backend.code, ' 123 456 ');
        expect(backend.challengeId, 'private-challenge-reference');
        pending.complete(
          UserAccountSignedIn(
            AuthenticatedUserAccount(
              userAccountId: 'opaque-only',
              displayName: '  ',
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Then only authoritative verification establishes the fallback account identity.
        expect(facade.snapshot.isAuthenticated, isTrue);
        expect(find.text('opaque-only'), findsOneWidget);
        expect(find.text('アカウントID: opaque-only'), findsOneWidget);
        expect(find.textContaining('123 456'), findsNothing);
        await _unmount(tester, facade, client);
      },
    );

    testWidgets(
      'should cancel pending login without accepting its late account',
      (tester) async {
        // Given a sign-in waiting on a controlled backend.
        final pending = Completer<UserAccountSignInResult>();
        final backend = _ControlledBackend();
        backend.onSignIn = () => pending.future;
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await _mount(tester, facade);
        await _enterLogin(tester);
        await _tap(tester, 'ログイン');
        // When explicit Cancel retires the pending work and that work later succeeds.
        await _tap(tester, 'キャンセル');
        expect(backend.operations.single.isCurrent, isFalse);
        expect(
          facade.snapshot.status,
          UserAccountAuthenticationStatus.cancelling,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.text('処理中です。しばらくお待ちください。'), findsOneWidget);
        pending.complete(UserAccountSignedIn(_account()));
        await tester.pumpAndSettle();
        // Then no stale account or error replaces the understandable cancelled state.
        expect(facade.snapshot.isAuthenticated, isFalse);
        expect(find.text('Authority Name'), findsNothing);
        expect(find.text('ログインをキャンセルしました。'), findsOneWidget);
        expect(_field('パスワード'), findsOneWidget);
        expect(
          tester.widget<TextField>(_field('パスワード')).controller!.text,
          isEmpty,
        );
        expect(backend.calls, ['signIn']);
        await _unmount(tester, facade, client);
      },
    );

    testWidgets('should clear sensitive input when external state changes', (
      tester,
    ) async {
      // Given input in a borrowing panel while another owner can use Core.
      final backend = _ControlledBackend();
      final client = UserAccountAuthenticationClient(backend: backend);
      final facade = UserAccountAuthenticationFacade(client: client);
      await _mount(tester, facade);
      await _enterLogin(tester);
      final password = tester.widget<TextField>(_field('パスワード')).controller!;
      // When an external owner authenticates then enters an email challenge.
      await client.signIn(identifier: 'external', password: 'external');
      expect(password.text, isEmpty);
      await client.signOut();
      backend.onSignIn = () =>
          const UserAccountChallengePending('private-ref', 'email');
      await client.signIn(identifier: 'external', password: 'external');
      await tester.pumpAndSettle();
      await tester.enterText(_field('確認コード'), 'ephemeral-code');
      final code = tester.widget<TextField>(_field('確認コード')).controller!;
      await client.cancel();
      // Then cancellation of that challenge lifetime clears the local code too.
      expect(code.text, isEmpty);
      await tester.pumpAndSettle();
      expect(find.textContaining('ephemeral-code'), findsNothing);
      await _unmount(tester, facade, client);
    });
  });

  group('logout facts and fixed failure copy', () {
    for (final revocation in UserAccountRemoteRevocation.values) {
      testWidgets(
        'should withdraw account immediately and report local logout with ${revocation.name} revocation',
        (tester) async {
          // Given an authenticated account and deferred local-success logout.
          final pending = Completer<UserAccountLogoutResult>();
          final backend = _ControlledBackend();
          backend.onSignOut = () => pending.future;
          final client = UserAccountAuthenticationClient(backend: backend);
          final facade = UserAccountAuthenticationFacade(client: client);
          await facade.signIn(identifier: 'id', password: 'pw');
          await _mount(tester, facade);
          // When logout starts before its backend result is available.
          await _tap(tester, 'ログアウト');
          expect(
            facade.snapshot.status,
            UserAccountAuthenticationStatus.signingOut,
          );
          expect(find.text('Authority Name'), findsNothing);
          expect(find.textContaining('アカウントID:'), findsNothing);
          expect(find.byType(TextField), findsNothing);
          pending.complete(
            UserAccountLogoutResult(
              localCleared: true,
              remoteRevocation: revocation,
            ),
          );
          await tester.pumpAndSettle();
          // Then presentation reports the independent facts without claiming unproved revocation.
          final expected = switch (revocation) {
            UserAccountRemoteRevocation.confirmed => 'ログアウトしました。',
            UserAccountRemoteRevocation.notAttempted => 'この端末からログアウトしました。',
            UserAccountRemoteRevocation.failed ||
            UserAccountRemoteRevocation.unknown =>
              'この端末からログアウトしました。サーバー側の失効は確認できていません。',
          };
          expect(find.text(expected), findsOneWidget);
          expect(_field('ログインID'), findsOneWidget);
          expect(facade.snapshot.account, isNull);
          await _unmount(tester, facade, client);
        },
      );
    }

    testWidgets(
      'should block a new login until failed local logout is retried successfully',
      (tester) async {
        // Given an authenticated client whose first local logout cannot clear credentials.
        final backend = _ControlledBackend();
        backend.onSignOut = () => const UserAccountLogoutResult(
          localCleared: false,
          remoteRevocation: UserAccountRemoteRevocation.unknown,
        );
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await facade.signIn(identifier: 'id', password: 'pw');
        await _mount(tester, facade);
        // When the first logout fails locally.
        await _tap(tester, 'ログアウト');
        await tester.pumpAndSettle();
        // Then no account or login form remains; only an explicit retry can admit new login.
        expect(
          find.text('この端末のログアウトを完了できませんでした。もう一度ログアウトしてください。'),
          findsOneWidget,
        );
        expect(find.text('Authority Name'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(facade.canSignIn, isFalse);
        await expectLater(
          facade.signIn(identifier: 'other', password: 'pw'),
          throwsStateError,
        );
        backend.onSignOut = () => const UserAccountLogoutResult(
          localCleared: true,
          remoteRevocation: UserAccountRemoteRevocation.confirmed,
        );
        // When the participant explicitly retries and clearance succeeds.
        await _tap(tester, 'ログアウトを再試行');
        await tester.pumpAndSettle();
        // Then the form returns without any implicit replacement login.
        expect(_field('ログインID'), findsOneWidget);
        expect(facade.canSignIn, isTrue);
        expect(backend.calls, ['signIn', 'signOut', 'signOut']);
        await _unmount(tester, facade, client);
      },
    );

    testWidgets(
      'should show fixed failure copy without backend or private input leakage',
      (tester) async {
        // Given a backend exception containing untrusted private details.
        final backend = _ControlledBackend();
        backend.onSignIn = () =>
            throw StateError('private-server-body private-password');
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await _mount(tester, facade);
        await tester.enterText(_field('ログインID'), 'private-identifier');
        await tester.enterText(_field('パスワード'), 'private-password');
        // When login fails and a subsequent structurally invalid attempt is made.
        await _tap(tester, 'ログイン');
        await tester.pumpAndSettle();
        expect(find.text('ログインサービスを利用できません。しばらくしてからお試しください。'), findsOneWidget);
        expect(find.textContaining('private-server-body'), findsNothing);
        expect(find.textContaining('private-password'), findsNothing);
        expect(
          tester.widget<TextField>(_field('ログインID')).controller!.text,
          'private-identifier',
        );
        await tester.enterText(_field('ログインID'), '');
        await _tap(tester, 'ログイン');
        await tester.pumpAndSettle();
        // Then local exception handling also uses fixed copy and never reflects causes.
        expect(find.text('操作を完了できませんでした。もう一度お試しください。'), findsOneWidget);
        expect(find.textContaining('ArgumentError'), findsNothing);
        expect(find.textContaining('Invalid authentication'), findsNothing);
        expect(backend.calls, ['signIn']);
        await _unmount(tester, facade, client);
      },
    );
  });

  group('borrowed widget attachment and retained caller work', () {
    testWidgets(
      'should ignore old completion after replacement and preserve new field input',
      (tester) async {
        // Given an old facade with pending sign-in and a fresh replacement owner.
        final pending = Completer<UserAccountSignInResult>();
        final oldBackend = _ControlledBackend();
        oldBackend.onSignIn = () => pending.future;
        final oldClient = UserAccountAuthenticationClient(backend: oldBackend);
        final oldFacade = UserAccountAuthenticationFacade(client: oldClient);
        final newBackend = _ControlledBackend();
        final newClient = UserAccountAuthenticationClient(backend: newBackend);
        final newFacade = UserAccountAuthenticationFacade(client: newClient);
        await _mount(tester, oldFacade);
        await _enterLogin(tester);
        final oldIdentifier = tester
            .widget<TextField>(_field('ログインID'))
            .controller!;
        await _tap(tester, 'ログイン');
        // When the same panel is attached to the replacement and new input is entered.
        await _mount(tester, newFacade);
        expect(oldIdentifier.text, isEmpty);
        await tester.enterText(_field('ログインID'), 'replacement-id');
        await tester.enterText(_field('パスワード'), 'replacement-password');
        expect(oldBackend.operations.single.isCurrent, isTrue);
        pending.completeError(StateError('old-private-error'));
        await tester.pumpAndSettle();
        // Then late old failure neither clears replacement buffers nor paints its error.
        expect(
          tester.widget<TextField>(_field('ログインID')).controller!.text,
          'replacement-id',
        );
        expect(
          tester.widget<TextField>(_field('パスワード')).controller!.text,
          'replacement-password',
        );
        expect(find.textContaining('old-private-error'), findsNothing);
        expect(find.text('ログインサービスを利用できません。しばらくしてからお試しください。'), findsNothing);
        expect(tester.takeException(), isNull);
        expect(newBackend.calls, isEmpty);
        expect(oldBackend.calls, ['signIn']);
        expect(oldClient.isClosed, isFalse);
        await _unmount(tester, newFacade, newClient);
        oldFacade.dispose();
        await oldClient.close();
      },
    );

    testWidgets(
      'should unmount without cancelling borrowed work or applying late UI effects',
      (tester) async {
        // Given a panel whose borrowed real client has pending authentication.
        final pending = Completer<UserAccountSignInResult>();
        final backend = _ControlledBackend();
        backend.onSignIn = () => pending.future;
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await _mount(tester, facade);
        await _enterLogin(tester);
        await _tap(tester, 'ログイン');
        // When the panel unmounts and the authority later succeeds for its owner.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(backend.operations.single.isCurrent, isTrue);
        pending.complete(UserAccountSignedIn(_account()));
        await tester.pumpAndSettle();
        // Then the owner retains its account without logout, cleanup or late setState.
        expect(client.snapshot.isAuthenticated, isTrue);
        expect(client.isClosed, isFalse);
        expect(facade.isClosed, isFalse);
        expect(backend.calls, ['signIn']);
        expect(backend.closes, 0);
        expect(tester.takeException(), isNull);
        facade.dispose();
        await client.close();
      },
    );

    testWidgets(
      'should keep controls reachable at 320 pixels and large text scale',
      (tester) async {
        // Given a narrow device, large text and long authoritative account strings.
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final backend = _ControlledBackend();
        backend.onSignIn = () => UserAccountSignedIn(
          AuthenticatedUserAccount(
            userAccountId: 'opaque-account-${'longidentity' * 30}',
            displayName: 'とても長いアカウントの表示名' * 20,
          ),
        );
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        // When the participant scrolls to login and later to logout.
        await _mount(tester, facade, textScale: 2.7);
        await _enterLogin(tester);
        await _tap(tester, 'ログイン');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tap(tester, 'ログアウト');
        await tester.pumpAndSettle();
        // Then controls remain reachable, with no overflow and both explicit actions delivered.
        expect(backend.calls, ['signIn', 'signOut']);
        expect(facade.snapshot.isAuthenticated, isFalse);
        expect(tester.takeException(), isNull);
        await _unmount(tester, facade, client);
      },
    );

    testWidgets(
      'should pop the shared page without changing caller draft or authentication',
      (tester) async {
        // Given a caller-owned draft controller and an authenticated shared owner.
        final draft = TextEditingController(text: 'retained caller draft');
        final backend = _ControlledBackend();
        final client = UserAccountAuthenticationClient(backend: backend);
        final facade = UserAccountAuthenticationFacade(client: client);
        await facade.signIn(identifier: 'id', password: 'pw');
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextField(controller: draft),
                    TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              UserAccountAuthenticationPage(facade: facade),
                        ),
                      ),
                      child: const Text('open-account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // When the page is pushed and ordinary back returns to its retained caller route.
        await tester.tap(find.text('open-account'));
        await tester.pumpAndSettle();
        expect(find.byType(UserAccountAuthenticationPage), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        // Then no auth/logout/data action or draft deletion was implicit in navigation.
        expect(find.byType(UserAccountAuthenticationPage), findsNothing);
        expect(draft.text, 'retained caller draft');
        expect(find.text('retained caller draft'), findsOneWidget);
        expect(client.snapshot.isAuthenticated, isTrue);
        expect(facade.isClosed, isFalse);
        expect(backend.calls, ['signIn']);
        await _unmount(tester, facade, client);
        draft.dispose();
      },
    );
  });
}

List<bool> _flags(UserAccountAuthenticationFacade facade) => [
  facade.canSignIn,
  facade.canVerifyChallenge,
  facade.canRefresh,
  facade.canCancel,
  facade.canSignOut,
];

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _mount(
  WidgetTester tester,
  UserAccountAuthenticationFacade facade, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: UserAccountAuthenticationPage(facade: facade),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterLogin(WidgetTester tester) async {
  await tester.ensureVisible(_field('ログインID'));
  await tester.enterText(_field('ログインID'), 'entered-id');
  await tester.ensureVisible(_field('パスワード'));
  await tester.enterText(_field('パスワード'), 'password');
}

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _unmount(
  WidgetTester tester,
  UserAccountAuthenticationFacade facade,
  UserAccountAuthenticationClient client,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  facade.dispose();
  await client.close();
}

AuthenticatedUserAccount _account() => AuthenticatedUserAccount(
  userAccountId: 'urn:account:exact',
  displayName: 'Authority Name',
);

/// Controlled authority outcomes only in tests; Core owns the real state engine.
class _ControlledBackend implements UserAccountAuthenticationBackend {
  final List<String> calls = [];
  final List<UserAccountAuthenticationOperation> operations = [];
  FutureOr<UserAccountSignInResult> Function()? onSignIn;
  FutureOr<UserAccountSignInResult> Function()? onVerify;
  FutureOr<UserAccountSignInResult> Function()? onRefresh;
  FutureOr<UserAccountLogoutResult> Function()? onSignOut;
  String? identifier;
  String? password;
  String? challengeId;
  String? code;
  Object? closeFailure;
  int closes = 0;

  @override
  Future<UserAccountSignInResult> signIn({
    required String identifier,
    required String password,
    required UserAccountAuthenticationOperation operation,
  }) async {
    calls.add('signIn');
    operations.add(operation);
    this.identifier = identifier;
    this.password = password;
    return onSignIn == null
        ? UserAccountSignedIn(_account())
        : await onSignIn!();
  }

  @override
  Future<UserAccountSignInResult> verifyChallenge({
    required String challengeId,
    required String code,
    required UserAccountAuthenticationOperation operation,
  }) async {
    calls.add('verifyChallenge');
    operations.add(operation);
    this.challengeId = challengeId;
    this.code = code;
    return onVerify == null
        ? UserAccountSignedIn(_account())
        : await onVerify!();
  }

  @override
  Future<UserAccountSignInResult> refresh({
    required UserAccountAuthenticationOperation operation,
  }) async {
    calls.add('refresh');
    operations.add(operation);
    return onRefresh == null
        ? UserAccountSignedIn(_account())
        : await onRefresh!();
  }

  @override
  Future<UserAccountLogoutResult> signOut({
    required UserAccountAuthenticationOperation operation,
  }) async {
    calls.add('signOut');
    operations.add(operation);
    return onSignOut == null
        ? const UserAccountLogoutResult(
            localCleared: true,
            remoteRevocation: UserAccountRemoteRevocation.confirmed,
          )
        : await onSignOut!();
  }

  @override
  Future<void> close() async {
    closes++;
    final failure = closeFailure;
    if (failure != null) throw failure;
  }
}
