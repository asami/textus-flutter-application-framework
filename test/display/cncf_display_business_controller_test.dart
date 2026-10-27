import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';

void main() {
  test('empty default and trusted immutable identity list require no I/O', () async {
    // Given legacy defaults and a trusted binding declaration.
    final legacy = CncfDisplayMutationFixture();
    addTearDown(legacy.dispose);
    final binding = referenceBusinessBinding();
    final declared = [binding];
    // When construction copies the declaration and the caller clears its list.
    final fixture = CncfDisplayMutationFixture(businessBindings: declared);
    addTearDown(fixture.dispose);
    declared.clear();
    // Then bindings remain immutable and construction performs no eager read.
    expect(legacy.controller.businessBindings, isEmpty);
    expect(fixture.requests, isEmpty);
    expect(fixture.controller.businessBindings.single, same(binding));
    expect(
      () => fixture.controller.businessBindings.clear(),
      throwsUnsupportedError,
    );
    expect(fixture.controller.businessAvailability(binding), isNull);
    // When invocation is attempted without a selected formal Detail.
    // Then it is rejected without I/O.
    expect(await fixture.controller.executeBusiness(binding), isFalse);
    expect(fixture.requests, isEmpty);
    // Given a selected Detail and an undeclared object with matching wire IDs.
    await fixture.select();
    final equivalent = referenceBusinessBinding();
    // When availability is inspected, then object identity rejects the declaration.
    expect(fixture.controller.businessAvailability(equivalent), isNull);
    expect(fixture.controller.canInvokeBusiness(equivalent), isFalse);
    // When the equivalent object is invoked, then execution is rejected.
    expect(await fixture.controller.executeBusiness(equivalent), isFalse);
    // Then no POST was sent and the legacy owner remains idle.
    expect(fixture.posts, isEmpty);
    expect(legacy.requests, isEmpty);
  });

  test('duplicate action, duplicate binding, component and source mismatches reject locally', () {
    // Given independent borrowed sources and invalid trusted declarations.
    final fixture = CncfDisplayMutationFixture();
    final other = CncfDisplayMutationFixture();
    addTearDown(fixture.dispose);
    addTearDown(other.dispose);
    for (final bindings in [
      [
        referenceBusinessBinding(),
        referenceBusinessBinding(bindingId: 'other'),
      ],
      [referenceBusinessBinding(), referenceBusinessBinding(actionId: 'other')],
      [referenceBusinessBinding(componentId: 'wrong-component')],
    ]) {
      // When constructed with this invalid declaration, then it fails locally.
      expect(
        () => CncfDisplayMutationController(
          source: fixture.source,
          viewModel: fixture.viewModel,
          businessBindings: bindings,
        ),
        throwsArgumentError,
      );
      expect(fixture.requests, isEmpty);
    }
    // When constructed with a different borrowed source, then the ownership guard rejects it.
    expect(
      () => CncfDisplayMutationController(
        source: fixture.source,
        viewModel: other.viewModel,
        businessBindings: [referenceBusinessBinding()],
      ),
      throwsArgumentError,
    );
    expect(other.requests, isEmpty);
  });

  for (final availability in [
    'enabled',
    'disabled',
    'hidden',
    'wrong-binding',
  ]) {
    test(
      'formal selected action $availability determines availability without descriptor I/O',
      () async {
        // Given a trusted binding and the selected wire action metadata.
        final binding = referenceBusinessBinding();
        final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
        addTearDown(fixture.dispose);
        if (availability == 'wrong-binding') {
          fixture.actionBindingId = 'different.binding';
        } else {
          fixture.actionAvailability = availability;
        }
        // When formal Detail is selected and availability is inspected.
        await fixture.select();
        final requests = fixture.requests.length;
        // Then the exact action and binding govern availability without descriptor I/O.
        expect(
          fixture.controller.businessAvailability(binding),
          availability == 'wrong-binding' ? null : availability,
        );
        expect(
          fixture.controller.canInvokeBusiness(binding),
          availability == 'enabled',
        );
        expect(fixture.requests, hasLength(requests));
        expect(
          fixture.requests.any(
            (r) => r.url.path.endsWith('describeMutation.json'),
          ),
          isFalse,
        );
        if (availability != 'enabled') {
          // Given unavailable metadata, when intent is attempted.
          await fixture.controller.executeBusiness(binding);
          // Then no command is dispatched.
          expect(fixture.posts, isEmpty);
        }
      },
    );
  }

  test('one held ordinary POST captures formal observation and excludes every competing owner', () async {
    // Given a selected formal observation and a held Business delivery.
    final binding = referenceBusinessBinding();
    final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
    addTearDown(fixture.dispose);
    await fixture.select();
    final controller = fixture.controller;
    final observation = fixture.source.lastDetail;
    final gate = fixture.hold('business');
    // When Business starts and every competing action is attempted while held.
    final running = controller.executeBusiness(binding);
    await gate.entered.future;
    await controller.beginEdit();
    controller.discard();
    controller.setText(mutationTitle, 'not editable');
    final duplicate = await controller.executeBusiness(binding);
    final save = await controller.save();
    final reload = await controller.reload();
    // Then one synchronous owner retains capture and dispatches one ordinary POST.
    expect(controller.observation, same(observation));
    expect(controller.businessOperation, same(binding));
    expect(controller.businessRunning, isTrue);
    expect(controller.businessAvailability(binding), 'enabled');
    expect(controller.canInvokeBusiness(binding), isFalse);
    expect([duplicate, save, reload], everyElement(isFalse));
    expect(controller.editorOpen, isFalse);
    expect(controller.draftValues, isEmpty);
    expect(fixture.posts, hasLength(1));
    expect(fixture.puts, isEmpty);
    expect(fixture.requests, hasLength(3));
    expect(
      fixture.posts.single.url.path,
      endsWith('reference-business/requestReview.json'),
    );
    expect(fixture.posts.single.headers['If-Match'], '"revision-1"');
    expect(
      fixture.posts.single.body,
      'resourceId=${Uri.encodeQueryComponent(fixture.id)}',
    );
    expect(fixture.posts.single.body, isNot(contains('screenId')));
    // Given the held request, when delivery is released to return its ordinary ACK.
    gate.release();
    final accepted = await running;
    // Then only receipt state changes; the captured projection remains unchanged.
    expect(accepted, isTrue);
    expect(controller.businessRunning, isFalse);
    expect(controller.businessReceipt!.binding, same(binding));
    expect(controller.businessReceipt!.revision, '2');
    expect(controller.needsReconciliation, isTrue);
    expect(fixture.source.lastDetail, same(observation));
    expect(fixture.viewModel.selectedResource!.value('stage'), '収集中');
    expect(fixture.requests, hasLength(3));
  });

  test('ACK notifies before any safe GET and explicit coherent Reload retains receipt', () async {
    // Given a selected Detail and listeners that attempt reentrant commands on ACK.
    final binding = referenceBusinessBinding();
    final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
    addTearDown(fixture.dispose);
    await fixture.select();
    final controller = fixture.controller;
    final notifications = <String>[];
    controller.addListener(() {
      if (controller.businessReceipt != null) {
        notifications.add(fixture.requests.last.method);
        unawaitedIntent(controller, binding);
      }
    });
    // When the ordinary command returns its ACK.
    await controller.executeBusiness(binding);
    final receipt = controller.businessReceipt;
    // Then listeners observe the ACK before any read or reentrant command.
    expect(notifications, isNotEmpty);
    expect(notifications, everyElement('POST'));
    expect(fixture.posts, hasLength(1));
    expect(controller.receipt, isNull);
    // Given the known ACK and a held safe read.
    final read = fixture.hold('read');
    // When explicit Reload enters the held read.
    final refreshing = controller.reload();
    await read.entered.future;
    // Then the exact ACK remains known and commands stay disabled.
    expect(controller.businessReceipt, same(receipt));
    expect(controller.needsReconciliation, isTrue);
    expect(controller.canInvokeBusiness(binding), isFalse);
    // When fresh matching Detail/query delivery is released.
    read.release();
    final reconciled = await refreshing;
    // Then the projection changes without command replay and retains the receipt.
    expect(reconciled, isTrue);
    expect(controller.needsReconciliation, isFalse);
    expect(controller.failure, isNull);
    expect(controller.businessOperation, same(binding));
    expect(controller.businessReceipt, same(receipt));
    expect(fixture.viewModel.selectedResource!.value('stage'), 'レビュー待ち');
    expect(controller.businessAvailability(binding), 'hidden');
    expect(fixture.posts, hasLength(1));
    expect(fixture.requests.map((r) => r.method), [
      'GET',
      'GET',
      'POST',
      'GET',
      'GET',
    ]);
  });

  for (final failure in ['read', 'query', 'stale', 'mismatch']) {
    test(
      '$failure projection retains known ACK and prohibits replay until coherent safe reads',
      () async {
        // Given a known Business ACK and a failed, stale, or incoherent projection.
        final binding = referenceBusinessBinding();
        final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
        addTearDown(fixture.dispose);
        await fixture.select();
        await fixture.controller.executeBusiness(binding);
        final receipt = fixture.controller.businessReceipt;
        if (failure == 'read') fixture.failRead = true;
        if (failure == 'query') fixture.failQuery = true;
        if (failure == 'stale') fixture.revision = '1';
        if (failure == 'mismatch') fixture.queryRevision = '1';
        // When explicit Reload and a repeated intent are attempted.
        final result = await fixture.controller.reload();
        final repeated = await fixture.controller.executeBusiness(binding);
        // Then the receipt and reconciliation obligation survive without replay.
        expect(result, isFalse);
        expect(repeated, isFalse);
        expect(fixture.controller.businessReceipt, same(receipt));
        expect(fixture.controller.needsReconciliation, isTrue);
        expect(fixture.posts, hasLength(1));
        // Given restored coherent read responses.
        fixture.failRead = false;
        fixture.failQuery = false;
        fixture.revision = '2';
        fixture.queryRevision = null;
        // When explicitly reloaded again.
        final recovered = await fixture.controller.reload();
        // Then the same ACK reconciles without replay.
        expect(recovered, isTrue);
        expect(fixture.controller.needsReconciliation, isFalse);
        expect(fixture.controller.businessReceipt, same(receipt));
        expect(fixture.posts, hasLength(1));
      },
    );
  }

  test(
    'formal BigInt floor stays exact beyond JavaScript integer precision',
    () async {
      // Given a formal revision beyond JavaScript integer precision.
      final binding = referenceBusinessBinding();
      final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
      addTearDown(fixture.dispose);
      fixture.revision = '9007199254740993';
      // When the formal observation is selected and dispatched.
      await fixture.select();
      await fixture.controller.executeBusiness(binding);
      // Then Core receives the exact string observation and returns the exact next revision.
      expect(
        fixture.posts.single.headers['If-Match'],
        '"revision-9007199254740993"',
      );
      expect(fixture.controller.businessReceipt!.revision, '9007199254740994');
      // Given matching read revisions below the known ACK.
      fixture.revision = '9007199254740993';
      // When explicitly reloaded.
      final stale = await fixture.controller.reload();
      // Then a rounded floor cannot fabricate reconciliation.
      expect(stale, isFalse);
      expect(fixture.controller.needsReconciliation, isTrue);
      // Given exact matching receipt revisions.
      fixture.revision = '9007199254740994';
      // When explicitly reloaded.
      final fresh = await fixture.controller.reload();
      // Then reconciliation succeeds with the exact revision.
      expect(fresh, isTrue);
      expect(
        fixture.source.lastDetail!.resources.single.revision,
        '9007199254740994',
      );
    },
  );

  test('standard update2 then Business3 and fresh normal Edit preserve immutable history', () async {
    // Given a completed standard update with receipt revision 2.
    final binding = referenceBusinessBinding();
    final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
    addTearDown(fixture.dispose);
    await fixture.edit();
    fixture.controller.setText(mutationTitle, 'updated title');
    await fixture.controller.save();
    final prior = fixture.controller.receipt!;
    // When Business returns its revision 3 ACK.
    await fixture.controller.executeBusiness(binding);
    final business = fixture.controller.businessReceipt!;
    // Then both immutable histories remain distinguishable.
    expect(prior.revision, '2');
    expect(fixture.controller.receipt, same(prior));
    expect(business.revision, '3');
    // Given Business revision 3 and a failing Detail read.
    fixture.failRead = true;
    // When explicit Reload fails.
    await fixture.controller.reload();
    // Then the current receipt never falls back to mutation revision 2.
    expect(fixture.controller.businessOperation, same(binding));
    expect(fixture.controller.businessReceipt, same(business));
    expect(fixture.controller.needsReconciliation, isTrue);
    expect(fixture.posts, hasLength(1));
    // Given a restored safe read.
    fixture.failRead = false;
    // When Business reconciles and fresh normal Edit begins.
    await fixture.controller.reload();
    await fixture.controller.beginEdit();
    // Then only the current-kind marker and older mutation slot clear.
    expect(fixture.controller.businessOperation, isNull);
    expect(fixture.controller.receipt, isNull);
    expect(fixture.controller.businessReceipt, same(business));
    expect(prior.revision, '2');
    expect(business.revision, '3');
    expect(fixture.controller.canSave, isTrue);
    expect(fixture.controller.initialValues[mutationTitle], 'updated title');
    expect(fixture.puts, hasLength(1));
    expect(fixture.posts, hasLength(1));
  });

  for (final kind in ['unknown', 'conflict', 'malformed', 'editable-message']) {
    test(
      '$kind Business failure requires safe read and never invents ACK or field editability',
      () async {
        // Given selected Detail and a failing ordinary command response.
        final binding = referenceBusinessBinding();
        final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
        addTearDown(fixture.dispose);
        await fixture.select();
        fixture.businessResponse = (_) async {
          if (kind == 'unknown') throw StateError('PRIVATE transport');
          if (kind == 'conflict') {
            return fixture.failureReply(conflict: true, status: 400);
          }
          if (kind == 'editable-message') return fixture.failureReply();
          return mutationRawReply(
            jsonEncode({
              'data': {'outcome': 'review-requested'},
            }),
          );
        };
        // When the command settles and a retry is attempted before reconciliation.
        final result = await fixture.controller.executeBusiness(binding);
        final retry = await fixture.controller.executeBusiness(binding);
        // Then no ACK or editable draft is fabricated from status or prose.
        expect(result, isFalse);
        expect(retry, isFalse);
        expect(fixture.controller.businessReceipt, isNull);
        expect(fixture.controller.failure, isNotNull);
        expect(fixture.controller.fieldErrors, isEmpty);
        expect(fixture.controller.canSave, isFalse);
        expect(fixture.controller.needsReconciliation, isTrue);
        expect(fixture.posts, hasLength(1));
        // When a fresh safe read resolves the uncertainty.
        final recovered = await fixture.controller.reload();
        // Then no replay occurs and a new enabled intent becomes possible.
        expect(recovered, isTrue);
        expect(fixture.controller.needsReconciliation, isFalse);
        expect(fixture.controller.failure, isNull);
        expect(fixture.controller.businessReceipt, isNull);
        expect(fixture.controller.canInvokeBusiness(binding), isTrue);
        expect(fixture.posts, hasLength(1));
        // Given reconciled enabled metadata and a successful command response.
        fixture.businessResponse = null;
        // When a fresh explicit intent occurs.
        await fixture.controller.executeBusiness(binding);
        // Then a second distinct POST returns its own ACK.
        expect(fixture.posts, hasLength(2));
        expect(fixture.controller.businessReceipt!.revision, '2');
      },
    );
  }

  test('captured selection change blocks read I/O and explicit return recovers the affected identity', () async {
    // Given a selected observation and held Business delivery.
    final binding = referenceBusinessBinding();
    final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
    addTearDown(fixture.dispose);
    await fixture.select();
    final observed = fixture.source.lastDetail;
    final gate = fixture.hold('business');
    // When selection changes during dispatch and ACK/Reload settle.
    final business = fixture.controller.executeBusiness(binding);
    await gate.entered.future;
    await fixture.viewModel.select('other-resource');
    gate.release();
    await business;
    final requests = fixture.requests.length;
    final receipt = fixture.controller.businessReceipt;
    final reloaded = await fixture.controller.reload();
    // Then capture survives and another selected resource remains untouched without read I/O.
    expect(reloaded, isFalse);
    expect(fixture.requests, hasLength(requests));
    expect(fixture.controller.observation, same(observed));
    expect(fixture.controller.businessReceipt, same(receipt));
    expect(fixture.controller.needsReconciliation, isTrue);
    expect(fixture.viewModel.selectedId, 'other-resource');
    // When the affected identity is explicitly selected and Reload is chosen.
    await fixture.viewModel.select(fixture.id);
    final recovered = await fixture.controller.reload();
    // Then its known receipt reconciles without POST replay.
    expect(recovered, isTrue);
    expect(fixture.posts, hasLength(1));
    expect(fixture.viewModel.selectedId, fixture.id);
  });

  test('selection changed during held safe read cannot close another selected resource', () async {
    // Given a known Business ACK and held safe read.
    final binding = referenceBusinessBinding();
    final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
    addTearDown(fixture.dispose);
    await fixture.select();
    await fixture.controller.executeBusiness(binding);
    final read = fixture.hold('read');
    // When selection changes during Reload and the held read completes.
    final reloading = fixture.controller.reload();
    await read.entered.future;
    await fixture.viewModel.select('other-resource');
    final requests = fixture.requests.length;
    read.release();
    final result = await reloading;
    // Then no query or fabricated closure follows for the other selected resource.
    expect(result, isFalse);
    expect(fixture.requests, hasLength(requests));
    expect(fixture.viewModel.selectedId, 'other-resource');
    expect(fixture.controller.needsReconciliation, isTrue);
    expect(fixture.controller.businessReceipt!.revision, '2');
  });

  test('disposal retires held Business publication while preserving borrowed owners', () async {
    // Given selected Detail, a notification listener, and held Business delivery.
    final binding = referenceBusinessBinding();
    final fixture = CncfDisplayMutationFixture(businessBindings: [binding]);
    addTearDown(fixture.dispose);
    await fixture.select();
    var notifications = 0;
    fixture.controller.addListener(() => notifications++);
    final gate = fixture.hold('business');
    // When the controller is disposed before late delivery returns.
    final running = fixture.controller.executeBusiness(binding);
    await gate.entered.future;
    final before = notifications;
    fixture.controller.dispose();
    gate.release();
    final result = await running;
    // Then no notifier, safe read, or fake ACK follows retirement.
    expect(result, isFalse);
    expect(notifications, before);
    expect(fixture.controller.needsReconciliation, isTrue);
    expect(fixture.controller.failure!.outcomeUnknown, isTrue);
    expect(fixture.controller.businessReceipt, isNull);
    expect(fixture.requests, hasLength(3));
    expect(fixture.posts, hasLength(1));
    // When borrowed read owners are used after controller retirement.
    await fixture.viewModel.select(fixture.id);
    final query = await fixture.client.query();
    // Then the source, View, and transport still function.
    expect(query.resources, hasLength(2));
    expect(fixture.viewModel.selectedResource!.value('stage'), 'レビュー待ち');
  });
}

void unawaitedIntent(
  CncfDisplayMutationController controller,
  CncfDisplayBusinessBinding binding,
) {
  controller.executeBusiness(binding);
  controller.beginEdit();
  controller.save();
  controller.reload();
  controller.discard();
}
