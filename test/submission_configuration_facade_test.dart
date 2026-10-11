import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

Map<String, Object?> oldConfigurationJson() {
  // Literal deployed v1 safe definitions retain unrelated selected defaults;
  // neither selection nor definition presence declares a reference grant.
  return {
    'version': 1,
    'driveConnections': [
      {
        'version': 1,
        'type': 'googleDrive',
        'id': 'storage',
        'accountId': 'user@example.test',
        'folderId': 'folderA',
      },
      {
        'version': 1,
        'type': 'googleDrive',
        'id': 'otherStorage',
        'accountId': 'other@example.test',
        'folderId': 'folderB',
      },
    ],
    'httpConnections': [
      {
        'version': 1,
        'type': 'http',
        'id': 'transport',
        'endpoint': 'https://example.test/submit',
        'requiresBearerToken': true,
      },
      {
        'version': 1,
        'type': 'http',
        'id': 'otherTransport',
        'endpoint': 'https://example.test/other',
        'requiresBearerToken': false,
      },
    ],
    'selectedStorageConnectionId': 'otherStorage',
    'selectedTransportConnectionId': 'otherTransport',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Submission configuration exact borrowed forwarding', () {
    test('CF5 generic capabilities fail before IO and preserve exact backing errors', () async {
      // Given a controlled config-only store and its exact immutable snapshot.
      final snapshot = SubmissionConfigurationSnapshot.fromJson(
        oldConfigurationJson(),
      );
      final store = MemorySubmissionConfiguration(snapshot);
      final facade = SubmissionConfigurationFacade(store: store);
      try {
        // When generic native operations are attempted without any native binding.
        expect(facade.hasDriveAuthorization, isFalse);
        expect(facade.hasHttpCredentialWriter, isFalse);
        expect(
          () => facade.authorizationState('storage'),
          throwsUnsupportedError,
        );
        expect(() => facade.authorizeDrive('storage'), throwsUnsupportedError);
        expect(
          () => facade.setHttpBearerToken('transport', 'ephemeral'),
          throwsUnsupportedError,
        );
        // Then unsupported calls make no backing IO and ordinary reads retain identity.
        expect(store.reads, 0);
        expect(store.writes, 0);
        expect(await facade.snapshot(), same(snapshot));
        // Given a controlled exact backing fault.
        final fault = StateError('Controlled backing fault');
        // When that fault reaches snapshot reads and selection forwarding.
        store.fault = fault;
        await expectLater(facade.snapshot(), throwsA(same(fault)));
        await expectLater(facade.select(), throwsA(same(fault)));
        store.fault = null;
        // Then restored backing retains the exact snapshot and its borrowed lifetime.
        expect(await store.snapshot(), same(snapshot));
        expect(store.closed, isFalse);
      } finally {
        // The test owner closes the backing borrowed by the facade.
        await store.close();
      }
    });

    test('CF6 literal v1 reload and explicit v2 access changes preserve missing versus empty', () async {
      // Given literal old data with arbitrary selections and no access declaration.
      final store = MemorySubmissionConfiguration(
        SubmissionConfigurationSnapshot.fromJson(oldConfigurationJson()),
      );
      final facade = SubmissionConfigurationFacade(store: store);
      try {
        // When reading old data through the generic facade and selecting exact definitions.
        final before = await facade.snapshot();
        await facade.select(
          storageConnectionId: 'storage',
          transportConnectionId: 'transport',
        );
        final selected = await facade.snapshot();
        // Then selection never invents a grant, and immutable snapshots remain detached.
        expect(
          before.referenceAccessBindings.containsKey('transport'),
          isFalse,
        );
        expect(selected.referenceAccessBindings, isEmpty);
        expect(before.selectedStorageConnectionId, 'otherStorage');
        expect(selected.selectedStorageConnectionId, 'storage');
        expect(() => before.driveConnections.clear(), throwsUnsupportedError);
        // Given explicit mutable operator access identifiers.
        final ids = ['storage'];
        // When writing declared access and then mutating the caller's input.
        await facade.setReferenceAccess(
          transportConnectionId: 'transport',
          storageConnectionIds: ids,
        );
        ids.clear();
        final granted = await facade.snapshot();
        // Then granted data is detached from caller input and immutable.
        expect(granted.referenceAccessBindings['transport'], ['storage']);
        expect(
          () => granted.referenceAccessBindings['transport']!.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => granted.referenceAccessBindings.clear(),
          throwsUnsupportedError,
        );
        // When access is explicitly revoked and a distinct owner rehydrates v2 JSON.
        await facade.setReferenceAccess(
          transportConnectionId: 'transport',
          storageConnectionIds: [],
        );
        final revoked = await facade.snapshot();
        final decoded = Map<String, Object?>.from(
          jsonDecode(jsonEncode(revoked.toJson())) as Map,
        );
        final reloadedStore = MemorySubmissionConfiguration(
          SubmissionConfigurationSnapshot.fromJson(decoded),
        );
        try {
          final reloaded = await SubmissionConfigurationFacade(
            store: reloadedStore,
          ).snapshot();
          // Then empty revocation and unchanged selected definitions survive reload.
          expect(reloaded.referenceAccessBindings['transport'], isEmpty);
          expect(
            reloaded.referenceAccessBindings.containsKey('otherTransport'),
            isFalse,
          );
          expect(reloaded.selectedStorageConnectionId, 'storage');
          expect(reloaded.selectedTransportConnectionId, 'transport');
          expect(
            reloaded.driveConnections.map((connection) => connection.toJson()),
            before.driveConnections.map((connection) => connection.toJson()),
          );
          expect(
            reloaded.httpConnections.map((connection) => connection.toJson()),
            before.httpConnections.map((connection) => connection.toJson()),
          );
        } finally {
          // Close the distinct config-only owner independently.
          await reloadedStore.close();
        }
        // When invalid access and defaults are forwarded after accepted revocation.
        await expectLater(
          facade.setReferenceAccess(
            transportConnectionId: 'transport',
            storageConnectionIds: ['storage', 'storage'],
          ),
          throwsArgumentError,
        );
        await expectLater(
          facade.select(transportConnectionId: 'missing'),
          throwsArgumentError,
        );
        // Then errors preserve the identical accepted backing value.
        expect(await facade.snapshot(), same(revoked));
        // When omitted selection explicitly clears both defaults.
        await facade.select();
        // Then both selected defaults are absent.
        expect((await facade.snapshot()).selectedStorageConnectionId, isNull);
        expect((await facade.snapshot()).selectedTransportConnectionId, isNull);
      } finally {
        // Close the backing owned by this scenario.
        await store.close();
      }
    });

    test(
      'CF5 put forwards immutable definitions without retargeting',
      () async {
        // Given empty controlled configuration and explicit safe definitions.
        final store = MemorySubmissionConfiguration(
          SubmissionConfigurationSnapshot(
            driveConnections: [],
            httpConnections: [],
          ),
        );
        final facade = SubmissionConfigurationFacade(store: store);
        final drive = DriveSubmissionConnection(
          id: 'storage',
          accountId: 'user@example.test',
          folderId: 'folderA',
        );
        final http = HttpSubmissionConnection(
          id: 'transport',
          endpoint: Uri.parse('https://example.test/a%20b'),
        );
        try {
          // When forwarding exact objects and identical repeated definitions.
          await facade.putDrive(drive);
          await facade.putHttp(http);
          await facade.putDrive(drive);
          final snapshot = await facade.snapshot();
          // Then backing retains the original object, defaults, encoded URI and conflict rule.
          expect(snapshot.driveConnections.single, same(drive));
          expect(snapshot.httpConnections.single, same(http));
          expect(snapshot.httpConnections.single.requiresBearerToken, isTrue);
          expect(
            snapshot.httpConnections.single.endpoint.toString(),
            'https://example.test/a%20b',
          );
          await expectLater(
            facade.putDrive(
              DriveSubmissionConnection(
                id: 'storage',
                accountId: 'user@example.test',
                folderId: 'different',
              ),
            ),
            throwsStateError,
          );
          expect(
            (await facade.snapshot()).driveConnections.single,
            same(drive),
          );
        } finally {
          // Drain and close only the test owner's backing.
          await store.close();
        }
      },
    );

    test(
      'CF6 literal v2 explicit empty access survives generic reads unchanged',
      () async {
        // Given current v2 data with explicit revocation independent of selected defaults.
        final literal = {
          ...oldConfigurationJson(),
          'version': 2,
          'referenceAccessBindings': {
            'transport': <String>[],
            'otherTransport': ['storage'],
          },
        };
        final snapshot = SubmissionConfigurationSnapshot.fromJson(literal);
        final store = MemorySubmissionConfiguration(snapshot);
        final facade = SubmissionConfigurationFacade(store: store);
        try {
          // When reading and rehydrating current safe data.
          final first = await facade.snapshot();
          final rehydrated = SubmissionConfigurationSnapshot.fromJson(
            first.toJson(),
          );
          // Then no grant or default migration occurs.
          expect(first, same(snapshot));
          expect(rehydrated.toJson(), literal);
          expect(rehydrated.referenceAccessBindings['transport'], isEmpty);
          expect(rehydrated.referenceAccessBindings['otherTransport'], [
            'storage',
          ]);
          expect(rehydrated.selectedStorageConnectionId, 'otherStorage');
          expect(rehydrated.selectedTransportConnectionId, 'otherTransport');
          expect(store.writes, 0);
        } finally {
          // Close only the config-only backing owned by this test.
          await store.close();
        }
      },
    );
  });

  group('Actual Android store with controlled channel', () {
    const channel = MethodChannel('tfaf-test/submission');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late MemorySubmissionConfiguration backing;
    late AndroidSubmissionConfigurationStore store;
    late List<MethodCall> calls;
    String? nativeFailure;

    setUp(() {
      // Install the public store's controlled channel on the declared Android platform.
      // Config-only mock persistence supplies no proof of native durability.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      backing = MemorySubmissionConfiguration(
        SubmissionConfigurationSnapshot.fromJson(oldConfigurationJson()),
      );
      store = AndroidSubmissionConfigurationStore(channel: channel);
      calls = [];
      nativeFailure = null;
      Future<Object?> handle(MethodCall call) async {
        // Retain exact real Core channel arguments in the controlled handler;
        // Core retains decoding and safe-error authority over each response.
        calls.add(call);
        if (nativeFailure != null) {
          throw PlatformException(
            code: nativeFailure!,
            message: 'untrusted ephemeral detail',
          );
        }
        final args = Map<String, Object?>.from(call.arguments as Map);
        switch (call.method) {
          case 'snapshot':
            return backing.value.toJson();
          case 'putDrive':
            await backing.putDrive(
              DriveSubmissionConnection.fromJson(
                Map<String, Object?>.from(args['connection'] as Map),
              ),
            );
          case 'putHttp':
            await backing.putHttp(
              HttpSubmissionConnection.fromJson(
                Map<String, Object?>.from(args['connection'] as Map),
              ),
            );
          case 'select':
            await backing.select(
              storageConnectionId: args['storageConnectionId'] as String?,
              transportConnectionId: args['transportConnectionId'] as String?,
            );
          case 'setReferenceAccess':
            await backing.setReferenceAccess(
              transportConnectionId: args['transportConnectionId'] as String,
              storageConnectionIds: List<String>.from(
                args['storageConnectionIds'] as List,
              ),
            );
          case 'authorizationState':
            return 'authorizationRequired';
          case 'authorizeDrive':
            return 'available';
          case 'setHttpBearerToken':
          case 'closeConfiguration':
            return null;
          default:
            throw StateError('Unexpected mock channel call');
        }
        return null;
      }

      messenger.setMockMethodCallHandler(channel, handle);
    });
    tearDown(() async {
      // The test owner closes Core on Android and its backing before removing
      // the channel mock and platform override.
      nativeFailure = null;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await store.close();
        await backing.close();
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('CF5 Android forwards explicit auth token write and access with Core safe errors', () async {
      // Given one actual Android store borrowed by the facade.
      final facade = SubmissionConfigurationFacade.android(store: store);
      expect(facade.hasDriveAuthorization, isTrue);
      expect(facade.hasHttpCredentialWriter, isTrue);
      expect(calls, isEmpty);
      // When explicitly observing/authorizing/writing/revoking and querying that same store.
      expect(
        await facade.authorizationState('storage'),
        SubmissionAuthorizationState.authorizationRequired,
      );
      expect(
        await facade.authorizeDrive('storage'),
        SubmissionAuthorizationState.available,
      );
      await facade.setHttpBearerToken('transport', 'test.ephemeral');
      await facade.setHttpBearerToken('transport', null);
      await facade.select(
        storageConnectionId: 'storage',
        transportConnectionId: 'transport',
      );
      await facade.setReferenceAccess(
        transportConnectionId: 'transport',
        storageConnectionIds: ['storage'],
      );
      await facade.setReferenceAccess(
        transportConnectionId: 'transport',
        storageConnectionIds: [],
      );
      final snapshot = await facade.snapshot();
      // Then exact native arguments and safe snapshot contain no credential retrieval or secret.
      expect(calls.map((call) => call.method), [
        'authorizationState',
        'authorizeDrive',
        'setHttpBearerToken',
        'setHttpBearerToken',
        'select',
        'setReferenceAccess',
        'setReferenceAccess',
        'snapshot',
      ]);
      expect(calls[2].arguments, {
        'connectionId': 'transport',
        'token': 'test.ephemeral',
      });
      expect(calls[3].arguments, {'connectionId': 'transport', 'token': null});
      expect(snapshot.referenceAccessBindings['transport'], isEmpty);
      expect(jsonEncode(snapshot.toJson()), isNot(contains('test.ephemeral')));
      expect(
        (await store.snapshot()).selectedTransportConnectionId,
        'transport',
      );
      // Given unsafe input and an observation of the current channel call count.
      final beforeInvalid = calls.length;
      // When forwarding invalid arguments.
      expect(
        () => facade.setHttpBearerToken('transport', 'invalid token'),
        throwsArgumentError,
      );
      expect(
        () => facade.setReferenceAccess(
          transportConnectionId: 'transport',
          storageConnectionIds: ['storage', 'storage'],
        ),
        throwsArgumentError,
      );
      // Then invalid arguments cause no channel IO.
      expect(calls.length, beforeInvalid);
      // When controlled native authorization cancellation is selected.
      nativeFailure = 'authorizationCancelled';
      // Then authorization retains Core's existing safe code and message.
      await expectLater(
        facade.authorizeDrive('storage'),
        throwsA(
          isA<SubmissionConfigurationException>()
              .having(
                (error) => error.code,
                'safe code',
                'authorizationCancelled',
              )
              .having(
                (error) => error.message,
                'safe message',
                SubmissionConfigurationException
                    .messages['authorizationCancelled'],
              ),
        ),
      );
      // When an unknown controlled native failure is selected.
      nativeFailure = 'untrustedUnknown';
      // Then snapshot failure uses Core's sanitized fallback code.
      await expectLater(
        facade.snapshot(),
        throwsA(
          isA<SubmissionConfigurationException>().having(
            (error) => error.code,
            'safe unknown code',
            'configurationUnavailable',
          ),
        ),
      );
    });

    test('CF5 Android binding flags do not invent platform readiness', () {
      // Given an Android-bound facade on a currently unsupported platform.
      final facade = SubmissionConfigurationFacade.android(store: store);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      // When checking binding flags and invoking an explicitly bound native operation.
      expect(facade.hasDriveAuthorization, isTrue);
      expect(
        () => facade.authorizationState('storage'),
        throwsUnsupportedError,
      );
      // Then the unsupported platform causes no channel IO.
      expect(calls, isEmpty);
    });

    test('CF5 actual Android definitions and default clearing use the same native handle', () async {
      // Given one actual public Android store and explicit safe new definitions.
      final facade = SubmissionConfigurationFacade.android(store: store);
      final drive = DriveSubmissionConnection(
        id: 'newStorage',
        accountId: 'new@example.test',
        folderId: 'newFolder',
      );
      final http = HttpSubmissionConnection(
        id: 'newTransport',
        endpoint: Uri.parse('https://example.test/new'),
        requiresBearerToken: false,
      );
      // When forwarding definitions and omitted selection.
      await facade.putDrive(drive);
      await facade.putHttp(http);
      await facade.select();
      final snapshot = await store.snapshot();
      // Then exact Core channel values apply and omitted selection clears defaults.
      expect(calls[0].arguments, {'connection': drive.toJson()});
      expect(calls[1].arguments, {'connection': http.toJson()});
      expect(calls[2].arguments, {
        'storageConnectionId': null,
        'transportConnectionId': null,
      });
      expect(snapshot.driveConnections.last.toJson(), drive.toJson());
      expect(snapshot.httpConnections.last.toJson(), http.toJson());
      expect(snapshot.selectedStorageConnectionId, isNull);
      expect(snapshot.selectedTransportConnectionId, isNull);
      expect(
        calls.any(
          (call) =>
              call.method == 'bearerToken' || call.method == 'authorizeDrive',
        ),
        isFalse,
      );
    });
  });
}
