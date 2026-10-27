import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

import '../support/cncf_display_mutation_fixture.dart';

const editKey = Key('cncf-display-edit');
const businessKey = Key('cncf-display-business-request-review');
const reloadKey = Key('cncf-display-presentation-reload');
const editorKey = Key('cncf-display-editor');
const titleKey = ValueKey(('cncf-display-field', 'main', 'title'));
const unavailable = 'This screen configuration is unavailable.';

// Explicitly controlled family data on the genuine local read baselines.
// These values are neither a new golden nor a trusted live server Session.
Map<String, Object?> context(String variant) => {
  'version': 1,
  'families': [
    {
      'name': 'cncf.locale',
      'version': 1,
      'data': {'languageTag': 'ja-JP'},
    },
    {
      'name': 'cncf.presentation',
      'version': 1,
      'data': {'variant': variant},
    },
    {
      'name': 'cncf.display-flow',
      'version': 1,
      'data': {
        'displayInstance': 'controlled-widget-display',
        'correlation': 'controlled-widget-correlation',
        'expiresAt': '2026-10-27T01:00:00Z',
      },
    },
  ],
};

ResourceListDetailConfiguration configuration(
  String name, {
  List<ResourceActionConfiguration>? actions,
}) => ResourceListDetailConfiguration(
  listTitle: '$name list',
  detailTitle: '$name detail',
  primaryField: 'title',
  secondaryField: 'stage',
  detailFields: [
    ResourceFieldConfiguration(key: 'title', label: '$name title'),
    ResourceFieldConfiguration(key: 'stage', label: '$name stage'),
    ResourceFieldConfiguration(key: 'description', label: '$name description'),
  ],
  detailActions: actions,
);

CncfDisplayPresentationRegistry registry(
  CncfDisplayMutationFixture fixture, {
  CncfDisplayReadProfile? profile,
}) => CncfDisplayPresentationRegistry(
  profile: profile ?? fixture.client.profile,
  neutralConfiguration: configuration('Neutral'),
  variants: {
    'reference-variant': configuration(
      'Reference',
      actions: const [
        ResourceActionConfiguration(
          id: 'request-review',
          label: 'Reference review',
        ),
      ],
    ),
    'alternate-variant': configuration('Alternate', actions: const []),
  },
);

CncfDisplayMutationFixture session(
  WidgetTester tester, {
  Map<String, Object?>? presentationContext,
}) {
  final fixture = CncfDisplayMutationFixture(
    presentationContext: presentationContext,
    businessBindings: [referenceBusinessBinding()],
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() async {
    fixture.releaseAll();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    fixture.dispose();
  });
  return fixture;
}

Widget view(
  CncfDisplayMutationFixture fixture, {
  CncfDisplayPresentationRegistry? presentationRegistry,
  ResourceListDetailDisplayModel? display,
  ResourceListDetailConfiguration? legacy,
}) => CncfDisplayResourceView(
  configuration: legacy ?? configuration('Legacy'),
  viewModel: fixture.viewModel,
  mutationController: fixture.controller,
  presentationRegistry: presentationRegistry,
  displayModel: display,
);

Future<void> mount(
  WidgetTester tester,
  CncfDisplayMutationFixture fixture, {
  CncfDisplayPresentationRegistry? presentationRegistry,
  ResourceListDetailDisplayModel? display,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: view(
        fixture,
        presentationRegistry: presentationRegistry,
        display: display,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> select(WidgetTester tester) async {
  await tester.tap(find.text('日本の民話'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(editKey));
}

bool within(BuildContext? context, Element ancestor) {
  if (context == null) return false;
  var found = identical(context, ancestor);
  context.visitAncestorElements((element) {
    if (identical(element, ancestor)) found = true;
    return !found;
  });
  return found;
}

void main() {
  for (final width in [400.0, 1000.0]) {
    testWidgets(
      'supplied reference configuration realizes common Text and Business at $width',
      (tester) async {
        // Given the actual common UI, borrowed layout and controlled formal families.
        final supplied = context('reference-variant');
        final fixture = session(tester, presentationContext: supplied);
        final display = ResourceListDetailDisplayModel();
        addTearDown(display.dispose);
        tester.view.physicalSize = Size(width, 900);
        // When the common child's first automatic query completes.
        await mount(
          tester,
          fixture,
          presentationRegistry: registry(fixture),
          display: display,
        );
        // Then the first supplied query visibly selects the declared List configuration.
        expect(find.text('Reference list'), findsOneWidget);
        expect(find.text('Legacy list'), findsNothing);
        expect(fixture.requests, hasLength(1));
        // Given a user selecting the real resource row.
        // When common Detail opens with the same registered configuration.
        await select(tester);
        final state = tester.state(find.byType(ResourceListDetail));
        final compactDetail = display.compactDetailRequested;
        final preference = display.preferenceOverride;
        // Then declared labels and Business presentation are visible in common UI.
        expect(find.text('Reference title'), findsOneWidget);
        expect(find.text('Reference stage'), findsOneWidget);
        expect(find.text('Reference review'), findsOneWidget);
        if (width == 400) expect(find.text('Reference detail'), findsOneWidget);
        // Given common Edit captures the current formal descriptor and observation.
        // When the user edits Text and saves through the existing modal Editor.
        await tester.tap(find.byKey(editKey));
        await tester.pumpAndSettle();
        // Then producer semantic labels remain independent of the variant's visual labels.
        expect(find.text('Title *'), findsOneWidget);
        expect(find.text('Reference title'), findsNothing);
        // Given the active formal Text field.
        // When its value changes and Save completes one update plus safe read/query.
        const edited = '日本の民話・formal context';
        await tester.enterText(find.byKey(titleKey), edited);
        await tester.ensureVisible(find.byKey(const Key('cncf-display-save')));
        await tester.tap(find.byKey(const Key('cncf-display-save')));
        await tester.pumpAndSettle();
        // Then revision 1 to 2 has one matching receipt and the common State returns.
        expect(find.byKey(editorKey), findsNothing);
        expect(fixture.puts, hasLength(1));
        expect(fixture.puts.single.headers['If-Match'], '"revision-1"');
        expect(fixture.controller.receipt!.revision, '2');
        expect(fixture.controller.receipt!.resourceId, fixture.id);
        expect(fixture.source.lastDetail!.resources.single.revision, '2');
        expect(fixture.source.lastQuery!.resources.first.revision, '2');
        expect(fixture.viewModel.selectedResource!.value('title'), edited);
        expect(find.text(edited), findsWidgets);
        expect(tester.state(find.byType(ResourceListDetail)), same(state));
        expect(fixture.viewModel.selectedId, fixture.id);
        expect(display.compactDetailRequested, compactDetail);
        expect(display.preferenceOverride, preference);
        // Given the current common Detail with its installed Business action.
        final business = fixture.hold('business');
        final read = fixture.hold('read');
        // When ordinary Business dispatches once and its ACK precedes safe Reload.
        await tester.ensureVisible(find.byKey(businessKey));
        await tester.tap(find.byKey(businessKey));
        await tester.pump();
        await business.entered.future;
        business.release();
        await tester.pump();
        await read.entered.future;
        // Then the revision 2 to 3 receipt is retained while its read is pending.
        expect(fixture.posts, hasLength(1));
        expect(fixture.posts.single.headers['If-Match'], '"revision-2"');
        expect(fixture.controller.businessReceipt!.revision, '3');
        expect(fixture.controller.businessReceipt!.resourceId, fixture.id);
        // Given the accepted command still owns its finite safe read gate.
        // When the read/query finishes.
        read.release();
        await tester.pumpAndSettle();
        // Then the completed projection visibly retains the receipt, fresh stage, selection and borrowed layout without replay.
        expect(
          find.text('Committed review-requested, revision 3'),
          findsOneWidget,
        );
        expect(find.text('レビュー待ち'), findsWidgets);
        expect(fixture.source.lastDetail!.resources.single.revision, '3');
        expect(fixture.source.lastQuery!.resources.first.revision, '3');
        expect(fixture.source.lastDisplay, same(fixture.source.lastQuery));
        expect(fixture.viewModel.selectedResource!.value('stage'), 'レビュー待ち');
        expect(tester.state(find.byType(ResourceListDetail)), same(state));
        expect(fixture.viewModel.selectedId, fixture.id);
        expect(display.compactDetailRequested, compactDetail);
        expect(display.preferenceOverride, preference);
        expect(fixture.puts, hasLength(1));
        expect(fixture.posts, hasLength(1));
        expect(fixture.requests, hasLength(9));
        expect(
          jsonDecode(
            fixture.requests.first.headers['X-CNCF-Presentation-Context']!,
          ),
          {'version': 1, 'families': []},
        );
        for (final request in fixture.requests.skip(1)) {
          expect(
            jsonDecode(request.headers['X-CNCF-Presentation-Context']!),
            supplied,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final withRegistry in [false, true]) {
    testWidgets(
      '${withRegistry ? 'no-context registry' : 'registry-null'} preserves its declared configuration',
      (tester) async {
        // Given either the legacy path or an installed registry with no supplied family.
        final fixture = session(tester);
        // When the common first query and Detail complete.
        await mount(
          tester,
          fixture,
          presentationRegistry: withRegistry ? registry(fixture) : null,
        );
        await select(tester);
        // Then the declared legacy or neutral labels render without another eager read.
        expect(
          find.text('${withRegistry ? 'Neutral' : 'Legacy'} list'),
          findsOneWidget,
        );
        expect(
          find.text('${withRegistry ? 'Neutral' : 'Legacy'} title'),
          findsOneWidget,
        );
        expect(fixture.requests, hasLength(2));
        expect(fixture.puts, isEmpty);
        expect(fixture.posts, isEmpty);
      },
    );
  }

  testWidgets(
    'before data neutral is available and registry replacement resets the retained child configuration',
    (tester) async {
      // Given a registry and a finite gate on the common child's first automatic query.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      final selected = registry(fixture);
      final query = fixture.hold('query');
      // When the child mounts before any Display has been accepted.
      await tester.pumpWidget(
        MaterialApp(home: view(fixture, presentationRegistry: selected)),
      );
      await tester.pump();
      await query.entered.future;
      // Then neutral configuration is available with no unavailable overlay or extra read.
      expect(find.text('Neutral list'), findsOneWidget);
      expect(find.text(unavailable), findsNothing);
      expect(fixture.requests, hasLength(1));
      // Given the initial query is ready to supply the installed Reference variant.
      // When its gate is released.
      query.release();
      await tester.pumpAndSettle();
      // Then the same mounted child realizes that stable registry entry.
      expect(find.text('Reference list'), findsOneWidget);
      final state = tester.state(find.byType(ResourceListDetail));
      final replacement = CncfDisplayPresentationRegistry(
        profile: fixture.client.profile,
        neutralConfiguration: configuration('Replacement neutral'),
        variants: const {},
      );
      // Given another registry with no declaration for the already supplied variant.
      // When only the registry/configuration attachment changes.
      await tester.pumpWidget(
        MaterialApp(home: view(fixture, presentationRegistry: replacement)),
      );
      await tester.pumpAndSettle();
      // Then cached configuration belongs to the replacement while the opaque overlay protects visibility.
      expect(find.text(unavailable), findsOneWidget);
      expect(
        tester
            .widget<ResourceListDetail>(find.byType(ResourceListDetail))
            .configuration,
        same(replacement.neutralConfiguration),
      );
      expect(tester.state(find.byType(ResourceListDetail)), same(state));
      expect(fixture.requests, hasLength(1));
    },
  );

  testWidgets(
    'fresh query switches installed configuration without resetting common State or issuing more reads',
    (tester) async {
      // Given a selected Reference presentation with an explicit borrowed focus preference.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      final display = ResourceListDetailDisplayModel();
      addTearDown(display.dispose);
      await mount(
        tester,
        fixture,
        presentationRegistry: registry(fixture),
        display: display,
      );
      await select(tester);
      display.focusDetail();
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(ResourceListDetail));
      final oldBusiness = tester
          .widget<TextButton>(find.byKey(businessKey))
          .onPressed!;
      final count = fixture.requests.length;
      fixture.presentationContext = context('alternate-variant');
      // When one fresh query supplies the other installed configuration.
      await fixture.viewModel.load();
      await tester.pumpAndSettle();
      // Then titles, labels and Business allowlist update in the same borrowed State.
      expect(find.text('Alternate detail'), findsOneWidget);
      expect(find.text('Alternate title'), findsOneWidget);
      expect(find.byKey(businessKey), findsNothing);
      expect(tester.state(find.byType(ResourceListDetail)), same(state));
      expect(fixture.viewModel.selectedId, fixture.id);
      expect(
        display.preference,
        ResourceListDetailDisplayPreference.detailFocused,
      );
      expect(display.compactDetailRequested, isTrue);
      expect(fixture.requests, hasLength(count + 1));
      // Given a previously captured action now outside the new allowlist.
      // When that stale callback is invoked.
      oldBusiness();
      await tester.pumpAndSettle();
      // Then presentation changes cannot dispatch a now-hidden action.
      expect(fixture.posts, isEmpty);
      expect(fixture.requests, hasLength(count + 1));
    },
  );

  testWidgets(
    'unknown variant is opaque and blocks semantics keyboard and stale commands until GET recovery',
    (tester) async {
      // Given a current selected common Detail and captured enabled command callbacks.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      final display = ResourceListDetailDisplayModel();
      addTearDown(display.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await mount(
          tester,
          fixture,
          presentationRegistry: registry(fixture),
          display: display,
        );
        await select(tester);
        final state = tester.state(find.byType(ResourceListDetail));
        final common = tester.element(find.byType(ResourceListDetail));
        final oldEdit = tester
            .widget<TextButton>(find.byKey(editKey))
            .onPressed!;
        final oldBusiness = tester
            .widget<TextButton>(find.byKey(businessKey))
            .onPressed!;
        fixture.presentationContext = context('PRIVATE-uninstalled-variant');
        // When a fresh query reports a valid but uninstalled supplied variant.
        await fixture.viewModel.load();
        await tester.pumpAndSettle();
        // Then only a fixed opaque unavailable surface is exposed to accessibility.
        expect(find.text(unavailable), findsOneWidget);
        expect(find.text('PRIVATE-uninstalled-variant'), findsNothing);
        expect(find.semantics.byLabel(unavailable), findsOne);
        expect(find.semantics.byLabel('Reference title'), findsNothing);
        expect(find.semantics.byLabel('Reference review'), findsNothing);
        final surface = tester.widget<Material>(
          find
              .ancestor(
                of: find.text(unavailable),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          surface.color,
          Theme.of(tester.element(find.text(unavailable))).colorScheme.surface
              .withAlpha(255),
        );
        expect(
          tester
              .widget<ExcludeFocus>(
                find
                    .ancestor(
                      of: find.byType(ResourceListDetail),
                      matching: find.byType(ExcludeFocus),
                    )
                    .first,
              )
              .excluding,
          isTrue,
        );
        expect(
          tester
              .widget<AbsorbPointer>(
                find
                    .ancestor(
                      of: find.byType(ResourceListDetail),
                      matching: find.byType(AbsorbPointer),
                    )
                    .first,
              )
              .absorbing,
          isTrue,
        );
        final count = fixture.requests.length;
        // Given the underlying common child remains mounted under the opaque overlay.
        // When keyboard traversal and both captured old command callbacks are attempted.
        for (var step = 0; step < 6; step++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          // Then keyboard focus never enters the unavailable common subtree.
          expect(
            within(FocusManager.instance.primaryFocus?.context, common),
            isFalse,
          );
        }
        oldEdit();
        oldBusiness();
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        // Then no Editor, descriptor, PUT or POST can start and common State is retained.
        expect(find.byKey(editorKey), findsNothing);
        expect(fixture.requests, hasLength(count));
        expect(fixture.puts, isEmpty);
        expect(fixture.posts, isEmpty);
        expect(tester.state(find.byType(ResourceListDetail)), same(state));
        // Given the peer supplies an installed variant again.
        fixture.presentationContext = context('alternate-variant');
        final query = fixture.hold('query');
        // When the explicit presentation Reload starts one safe GET.
        await tester.tap(find.byKey(reloadKey));
        await tester.pump();
        await query.entered.future;
        // Then Reload is disabled while that read is pending.
        expect(
          tester.widget<TextButton>(find.byKey(reloadKey)).onPressed,
          isNull,
        );
        // Given the only recovery request is held.
        // When it returns the installed configuration.
        query.release();
        await tester.pumpAndSettle();
        // Then the overlay clears with no common State reset or command replay.
        expect(find.text(unavailable), findsNothing);
        expect(find.text('Alternate title'), findsOneWidget);
        expect(tester.state(find.byType(ResourceListDetail)), same(state));
        expect(fixture.viewModel.selectedId, fixture.id);
        expect(display.compactDetailRequested, isTrue);
        expect(fixture.requests, hasLength(count + 1));
        expect(fixture.requests.last.method, 'GET');
        expect(fixture.puts, isEmpty);
        expect(fixture.posts, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'wrong independent profile visibly makes accepted Display unavailable',
    (tester) async {
      // Given a client admitted by its own profile and a registry pinned to another definition.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      final original = fixture.client.profile;
      final wrong = CncfDisplayReadProfile(
        componentId: original.componentId,
        resourceType: original.resourceType,
        listScreenId: original.listScreenId,
        detailScreenId: original.detailScreenId,
        semanticContract: original.semanticContract,
        provenance: original.provenance,
        definitionRevision: 'another-definition',
      );
      // When the successful initial query is independently re-admitted by the registry.
      await mount(
        tester,
        fixture,
        presentationRegistry: registry(fixture, profile: wrong),
      );
      // Then the common child stays mounted behind the unavailable surface with GET-only retry.
      expect(find.text(unavailable), findsOneWidget);
      expect(find.byType(ResourceListDetail), findsOneWidget);
      expect(find.byKey(reloadKey), findsOneWidget);
      expect(fixture.requests, hasLength(1));
      expect(fixture.source.lastDisplay, isNotNull);
      expect(fixture.puts, isEmpty);
      expect(fixture.posts, isEmpty);
    },
  );

  testWidgets(
    'already opened Editor retains captured bindings across unavailable presentation and can Cancel',
    (tester) async {
      // Given a ready common Editor with captured formal semantic labels and bindings.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      await mount(tester, fixture, presentationRegistry: registry(fixture));
      await select(tester);
      await tester.tap(find.byKey(editKey));
      await tester.pumpAndSettle();
      final descriptor = fixture.controller.descriptor;
      final observation = fixture.controller.observation;
      fixture.presentationContext = context('uninstalled');
      // When a query changes presentation while the Editor is already open.
      await fixture.viewModel.load();
      await tester.pumpAndSettle();
      // Then the Editor retains its descriptor, original observation and semantic field binding.
      expect(find.byKey(editorKey), findsOneWidget);
      expect(find.text('Title *'), findsOneWidget);
      expect(fixture.controller.descriptor, same(descriptor));
      expect(fixture.controller.observation, same(observation));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('cncf-display-save')))
            .onPressed,
        isNotNull,
      );
      // Given an unchanged draft whose owner remains current.
      // When the user chooses Cancel explicitly.
      await tester.tap(find.byKey(const Key('cncf-display-cancel')));
      await tester.pumpAndSettle();
      // Then only that Editor closes and the unavailable common surface remains.
      expect(find.byKey(editorKey), findsNothing);
      expect(find.text(unavailable), findsOneWidget);
      expect(fixture.puts, isEmpty);
      expect(fixture.posts, isEmpty);
    },
  );

  testWidgets(
    'committed Business still reconciles when presentation registry becomes unavailable before ACK',
    (tester) async {
      // Given a selected common Business command with delivery held after dispatch.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      await mount(tester, fixture, presentationRegistry: registry(fixture));
      await select(tester);
      final state = tester.state(find.byType(ResourceListDetail));
      final oldEdit = tester.widget<TextButton>(find.byKey(editKey)).onPressed!;
      final oldBusiness = tester
          .widget<TextButton>(find.byKey(businessKey))
          .onPressed!;
      final business = fixture.hold('business');
      await tester.ensureVisible(find.byKey(businessKey));
      await tester.tap(find.byKey(businessKey));
      await tester.pump();
      await business.entered.future;
      // Given registration can change while the dispatched command exclusively owns delivery.
      // When the registry removes the supplied variant before ACK, without a new server response.
      await tester.pumpWidget(
        MaterialApp(
          home: view(
            fixture,
            presentationRegistry: CncfDisplayPresentationRegistry(
              profile: fixture.client.profile,
              neutralConfiguration: configuration('Neutral'),
              variants: const {},
            ),
          ),
        ),
      );
      await tester.pump();
      // Then unavailable presentation protects new intents while Business stays owned.
      expect(find.text(unavailable), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byKey(reloadKey)).onPressed,
        isNull,
      );
      final beforeAck = fixture.requests.length;
      // Given the unavailable registry protects the same child and existing command owner.
      // When captured command callbacks are attempted before ACK.
      oldEdit();
      oldBusiness();
      await tester.pump();
      // Then no new command or request starts while the held POST remains owned.
      expect(find.byKey(editorKey), findsNothing);
      expect(fixture.requests, hasLength(beforeAck));
      expect(fixture.puts, isEmpty);
      expect(fixture.posts, hasLength(1));
      // Given the existing command will return an authoritative revision 2 receipt.
      // When its finite delivery gate is released.
      business.release();
      await tester.pumpAndSettle();
      // Then existing post-ACK reconciliation performs read/query despite unavailable presentation.
      expect(fixture.controller.businessReceipt!.revision, '2');
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.source.lastDetail!.resources.single.revision, '2');
      expect(fixture.source.lastQuery!.resources.first.revision, '2');
      expect(fixture.requests, hasLength(beforeAck + 2));
      expect(fixture.requests[beforeAck].method, 'GET');
      expect(fixture.requests[beforeAck].url.path, endsWith('read.json'));
      expect(fixture.requests[beforeAck + 1].method, 'GET');
      expect(fixture.requests[beforeAck + 1].url.path, endsWith('query.json'));
      expect(fixture.posts, hasLength(1));
      expect(find.text(unavailable), findsOneWidget);
      expect(tester.state(find.byType(ResourceListDetail)), same(state));
    },
  );

  testWidgets(
    'presentation Reload uses exclusive controller reconciliation without command replay',
    (tester) async {
      // Given a common Business ACK whose safe read fails and leaves reconciliation required.
      final fixture = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      await mount(tester, fixture, presentationRegistry: registry(fixture));
      await select(tester);
      fixture.failRead = true;
      fixture.presentationContext = context('uninstalled');
      // When the command ACK is followed by a failed safe read and a new supplied query.
      await tester.ensureVisible(find.byKey(businessKey));
      await tester.tap(find.byKey(businessKey));
      await tester.pumpAndSettle();
      // Then the committed receipt survives behind the unavailable surface.
      expect(fixture.controller.businessReceipt!.revision, '2');
      expect(fixture.controller.needsReconciliation, isTrue);
      expect(find.text(unavailable), findsOneWidget);
      final state = tester.state(find.byType(ResourceListDetail));
      final count = fixture.requests.length;
      fixture.failRead = false;
      fixture.presentationContext = context('reference-variant');
      // When explicit presentation Reload reconciles using the current controller.
      await tester.tap(find.byKey(reloadKey));
      await tester.pumpAndSettle();
      // Then exactly read/query reconcile the receipt without a second POST or common State reset.
      expect(fixture.requests, hasLength(count + 2));
      expect(fixture.requests[count].url.path, endsWith('read.json'));
      expect(fixture.requests[count + 1].url.path, endsWith('query.json'));
      expect(fixture.controller.needsReconciliation, isFalse);
      expect(fixture.controller.businessReceipt!.revision, '2');
      expect(fixture.posts, hasLength(1));
      expect(fixture.puts, isEmpty);
      expect(find.text(unavailable), findsNothing);
      expect(find.text('Reference stage'), findsOneWidget);
      expect(tester.state(find.byType(ResourceListDetail)), same(state));
    },
  );

  testWidgets(
    'replacement and unmount detach old notifications without disposing borrowed owners',
    (tester) async {
      // Given a selected old attachment and another independently borrowed owner set.
      final first = session(
        tester,
        presentationContext: context('reference-variant'),
      );
      final second = session(
        tester,
        presentationContext: context('alternate-variant'),
      );
      final display = ResourceListDetailDisplayModel();
      addTearDown(display.dispose);
      await mount(
        tester,
        first,
        presentationRegistry: registry(first),
        display: display,
      );
      await select(tester);
      final state = tester.state(find.byType(ResourceListDetail));
      final oldEdit = tester.widget<TextButton>(find.byKey(editKey)).onPressed!;
      final oldBusiness = tester
          .widget<TextButton>(find.byKey(businessKey))
          .onPressed!;
      // When the widget transfers its borrowed VM and controller to the second owner.
      await mount(
        tester,
        second,
        presentationRegistry: registry(second),
        display: display,
      );
      final count = second.requests.length;
      first.presentationContext = context('uninstalled');
      await first.viewModel.load();
      await first.controller.beginEdit();
      oldEdit();
      oldBusiness();
      await tester.pumpAndSettle();
      // Then old VM/controller notifications and captured callbacks cannot alter the current attachment.
      expect(find.text('Alternate list'), findsOneWidget);
      expect(find.text(unavailable), findsNothing);
      expect(find.byKey(editorKey), findsNothing);
      expect(tester.state(find.byType(ResourceListDetail)), same(state));
      expect(second.requests, hasLength(count));
      expect(first.posts, isEmpty);
      expect(second.posts, isEmpty);
      expect(first.controller.isDisposed, isFalse);
      expect(second.controller.isDisposed, isFalse);
      // Given current and retired owners remain borrowed across unmount.
      // When all owners notify or read after the widget is removed.
      await tester.pumpWidget(const SizedBox.shrink());
      first.controller.discard();
      second.controller.discard();
      await first.viewModel.load();
      await second.viewModel.load();
      display.focusDetail();
      await tester.pump();
      // Then neither VM, controller, layout nor transport was disposed by the view.
      expect(first.controller.isDisposed, isFalse);
      expect(second.controller.isDisposed, isFalse);
      expect(first.viewModel.listFailed, isFalse);
      expect(second.viewModel.listFailed, isFalse);
      expect(
        display.preference,
        ResourceListDetailDisplayPreference.detailFocused,
      );
      expect((await first.client.query()).resources, hasLength(2));
      expect((await second.client.query()).resources, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
