import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'support/submission_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Exercise exact borrowed settings commands, safe observations and owner retirement.
  group('CU1 explicit configuration and owner lifetime', () {
    late MemorySubmissionConfiguration store;
    late SubmissionSettingsController controller;

    // Construct fresh borrowed configuration and an inert settings owner for each scenario.
    setUp(() {
      // Given fresh borrowed configuration for the current scenario.
      store = MemorySubmissionConfiguration(submissionConfiguration());
      // When constructing an inert owner over that exact borrowed facade.
      controller = SubmissionSettingsController(
        facade: SubmissionConfigurationFacade(store: store),
      );
    });
    // Release finite gates, drain the controller and close only fixture-owned backing.
    tearDown(() async {
      store.readGate?.release();
      store.writeGate?.release();
      await controller.detach();
      controller.dispose();
      await store.close();
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU1 legacy configuration load keeps unknown access until explicit v2 declaration', () async {
      // Given deployed v1 configuration without an access declaration.
      final legacy = store.value.toJson();
      legacy['version'] = 1;
      legacy.remove('referenceAccessBindings');
      store.value = SubmissionConfigurationSnapshot.fromJson(legacy);
      // When the owner explicitly loads that configuration.
      expect(await controller.load(), isTrue);
      // Given the immutable loaded snapshot retained before the write.
      final before = controller.snapshot!;
      expect(
        // When explicitly declaring an empty set for the exact HTTP ID.
        await controller.setReferenceAccess(
          transportConnectionId: 'transport',
          storageConnectionIds: [],
        ),
        isTrue,
      );
      // Then the old snapshot stays unknown and v2 records explicit empty access.
      expect(before.referenceAccessBindings, isEmpty);
      expect(controller.snapshot!.toJson()['version'], 2);
      expect(
        controller.snapshot!.referenceAccessBindings['transport'],
        isEmpty,
      );
      expect(
        controller.snapshot!.referenceAccessBindings.containsKey(
          'otherTransport',
        ),
        isFalse,
      );
      expect(controller.snapshot!.selectedStorageConnectionId, isNull);
      expect(controller.snapshot!.selectedTransportConnectionId, isNull);
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test(
      'CU1 exact writes refresh snapshots and keep missing versus empty',
      () async {
        // Then fresh construction has no reads, writes, snapshot or bound native capability.
        expect(store.reads, 0);
        expect(store.writeAttempts, 0);
        expect(controller.snapshot, isNull);
        expect(controller.configurationMayHaveChanged, isFalse);
        expect(controller.hasDriveAuthorization, isFalse);
        expect(controller.hasHttpCredentialWriter, isFalse);
        // When explicitly loading the borrowed definitions.
        expect(await controller.load(), isTrue);
        final original = controller.snapshot!;
        // Then missing access remains absent.
        expect(original.referenceAccessBindings, isEmpty);
        expect(
          // When explicitly selecting the two desired default IDs.
          await controller.select(
            storageConnectionId: 'storage',
            transportConnectionId: 'transport',
          ),
          isTrue,
        );
        // Then the exact selection applies and the possible-write flag is set.
        expect(controller.snapshot!.selectedStorageConnectionId, 'storage');
        expect(controller.configurationMayHaveChanged, isTrue);
        // When explicitly clearing both defaults.
        expect(await controller.select(), isTrue);
        // Then null clears both future defaults.
        expect(controller.snapshot!.selectedStorageConnectionId, isNull);
        expect(controller.snapshot!.selectedTransportConnectionId, isNull);
        // Given a caller-owned access list.
        final ids = ['storage'];
        // When dispatching an access declaration and changing the caller list afterward.
        final write = controller.setReferenceAccess(
          transportConnectionId: 'transport',
          storageConnectionIds: ids,
        );
        ids.clear();
        expect(await write, isTrue);
        // Then accepted intent retains the original list contents.
        expect(controller.snapshot!.referenceAccessBindings['transport'], [
          'storage',
        ]);
        expect(
          // When explicitly replacing that declaration with an empty set.
          await controller.setReferenceAccess(
            transportConnectionId: 'transport',
            storageConnectionIds: [],
          ),
          isTrue,
        );
        expect(
          // Then empty differs from an unrelated missing declaration and old snapshots stay intact.
          controller.snapshot!.referenceAccessBindings['transport'],
          isEmpty,
        );
        expect(
          controller.snapshot!.referenceAccessBindings.containsKey(
            'otherTransport',
          ),
          isFalse,
        );
        expect(original.referenceAccessBindings, isEmpty);
        expect(
          () => controller.authorizationStates.clear(),
          throwsUnsupportedError,
        );
        expect(
          // When explicitly adding a new immutable Drive definition.
          await controller.putDrive(
            DriveSubmissionConnection(
              id: 'newStorage',
              accountId: 'new@example.test',
              folderId: 'folderB',
            ),
          ),
          isTrue,
        );
        expect(
          // When explicitly adding a new immutable HTTPS definition.
          await controller.putHttp(
            HttpSubmissionConnection(
              id: 'newTransport',
              endpoint: Uri.parse('https://example.test/new'),
            ),
          ),
          isTrue,
        );
        // Then Add does not select a default and both definitions are present.
        expect(controller.snapshot!.selectedTransportConnectionId, isNull);
        expect(controller.snapshot!.driveConnections.length, 2);
        expect(controller.snapshot!.httpConnections.length, 3);
      },
    );

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU1 fixed safe failures and explicit recovery', () async {
      // Given an untrusted read failure with raw secret details.
      store.fault = StateError('secret-token raw endpoint');
      // When explicitly loading through the safe owner.
      expect(await controller.load(), isFalse);
      // Then only the closed safe diagnostic is exposed, with no fabricated empty snapshot.
      expect(controller.failed, isTrue);
      expect(controller.snapshot, isNull);
      expect(controller.failureCode, 'configurationUnavailable');
      expect(
        controller.failureMessage,
        SubmissionConfigurationException.messages['configurationUnavailable'],
      );
      // Given an argument failure for the next explicit write.
      store.fault = ArgumentError('secret-token');
      // When explicitly selecting defaults.
      expect(await controller.select(), isFalse);
      // Then the fixed invalid-configuration code replaces the raw details.
      expect(controller.failureCode, 'configurationInvalid');
      // Given an exact safe Core configuration failure.
      final safe = SubmissionConfigurationException.safe('connectionConflict');
      store.fault = safe;
      // When explicitly reading that failure.
      expect(await controller.load(), isFalse);
      // Then the exact safe code and message are retained.
      expect(controller.failureCode, safe.code);
      expect(controller.failureMessage, safe.message);
      // Given recovered backing configuration.
      store.fault = null;
      // When explicitly retrying the read.
      expect(await controller.load(), isTrue);
      // Then the previous fault is cleared.
      expect(controller.failed, isFalse);
      expect(controller.failureMessage, isNull);
      // When requesting authorization through a generic facade without that capability.
      expect(await controller.refreshAuthorization('storage'), isFalse);
      // Then failure is closed and no write occurs.
      expect(controller.failureCode, 'configurationUnavailable');
      expect(store.writeAttempts, 0);
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test('CU1 reserve before notification and reentrant dispose prevents dispatch', () async {
      // Given listeners that retire before dispatch and observe any later notification.
      var laterNotifications = 0;
      // Assert busy reservation and retire synchronously from notification.
      void retire() {
        // Then notification sees the synchronous busy reservation.
        expect(controller.busy, isTrue);
        // When the listener retires its current owner synchronously.
        controller.dispose();
      }

      // Count any notification that incorrectly follows retirement.
      void later() {
        laterNotifications++;
      }

      controller.addListener(retire);
      controller.addListener(later);
      // When explicit selection reserves busy before notifying those listeners.
      expect(await controller.select(), isFalse);
      // Then no backing dispatch, possible-write flag or later publication escapes.
      expect(store.reads, 0);
      expect(store.writeAttempts, 0);
      expect(controller.configurationMayHaveChanged, isFalse);
      expect(laterNotifications, 0);
      // When attempting another command after retirement.
      expect(await controller.load(), isFalse);
      // Then borrowed configuration remains open and reusable.
      expect(store.closed, isFalse);
      expect(await store.snapshot(), same(store.value));
    });

    // Specify the named existing behavior with its actual setup, commands and observations.
    test(
      'CU1 late write drains and never refreshes retired snapshot',
      () async {
        // Given loaded configuration and a gate for an issued durable write.
        await controller.load();
        final before = controller.snapshot;
        final gate = SubmissionGate();
        store.writeGate = gate;
        // When selection enters backing and a duplicate load is attempted.
        final operation = controller.select(transportConnectionId: 'transport');
        await gate.entered.future;
        expect(await controller.load(), isFalse);
        // Then only one dispatch holds the reservation.
        expect(store.writeAttempts, 1);
        final reads = store.reads;
        // When the owner detaches while that write is held.
        final detached = controller.detach();
        var joined = false;
        // Record join settlement without changing controller authority.
        detached.then((_) => joined = true);
        await Future<void>.value();
        // Then detach remains a pending idempotent join and marks possible change.
        expect(joined, isFalse);
        expect(controller.detach(), same(detached));
        expect(controller.configurationMayHaveChanged, isTrue);
        // When the accepted durable write is released.
        gate.release();
        expect(await operation, isFalse);
        await detached;
        // Then its retired result performs no follow-up read or snapshot publication.
        expect(controller.snapshot, same(before));
        expect(store.reads, reads);
        expect(store.value.selectedTransportConnectionId, 'transport');
        expect(store.closed, isFalse);
      },
    );
  });

  // Specify the named existing behavior with its actual setup, commands and observations.
  test('CU1 Android enum observation auth token and late result fences', () async {
    // Given an Android facade bound to controlled host channel observations.
    final channel = ControlledSubmissionConfigurationChannel()..attach();
    final native = AndroidSubmissionConfigurationStore();
    final controller = SubmissionSettingsController(
      facade: SubmissionConfigurationFacade.android(store: native),
    );
    try {
      // Then constructor capability binding performs no native operation.
      expect(channel.calls, isEmpty);
      expect(controller.hasDriveAuthorization, isTrue);
      expect(controller.hasHttpCredentialWriter, isTrue);
      // When explicitly loading and refreshing exact storage authorization.
      await controller.load();
      expect(await controller.refreshAuthorization('storage'), isTrue);
      expect(
        // Then the literal enum is observed without connectivity inference.
        controller.authorizationStates['storage'],
        SubmissionAuthorizationState.authorizationRequired,
      );
      expect(controller.configurationMayHaveChanged, isFalse);
      // Given the next literal available authorization observation.
      channel.authorization = SubmissionAuthorizationState.available;
      // When explicitly authorizing the exact Drive ID.
      expect(await controller.authorizeDrive('storage'), isTrue);
      expect(
        // Then that exact available observation is published.
        controller.authorizationStates['storage'],
        SubmissionAuthorizationState.available,
      );
      expect(
        // When explicitly setting a bearer for the exact HTTP ID.
        await controller.setHttpBearerToken('transport', 'ephemeral'),
        isTrue,
      );
      // When explicitly clearing the same bearer with null.
      expect(await controller.setHttpBearerToken('transport', null), isTrue);
      // Filter recorded command calls without a credential read.
      final writes = channel.calls
          .where((call) => call.method == 'setHttpBearerToken')
          .toList();
      // Then exact ID/token/null arguments were dispatched and no getter was used.
      expect(writes[0].arguments, {
        'connectionId': 'transport',
        'token': 'ephemeral',
      });
      expect(writes[1].arguments, {'connectionId': 'transport', 'token': null});
      expect(
        channel.calls.any((call) => call.method == 'bearerToken'),
        isFalse,
      );
      // Given a held authorization read and its existing published observation.
      final gate = SubmissionGate();
      channel.gate = gate;
      // When that read starts and the owner retires before release.
      final operation = controller.refreshAuthorization('storage');
      await gate.entered.future;
      final detached = controller.detach();
      channel.authorization = SubmissionAuthorizationState.unavailable;
      gate.release();
      // Then the late read fails current validity and keeps the previous enum.
      expect(await operation, isFalse);
      await detached;
      expect(
        controller.authorizationStates['storage'],
        SubmissionAuthorizationState.available,
      );
    } finally {
      // Release held work, remove presentation and drain borrowers before owner cleanup.
      channel.gate?.release();
      await controller.detach();
      controller.dispose();
      channel.gate = null;
      await native.close();
      await channel.dispose();
    }
  });
}
