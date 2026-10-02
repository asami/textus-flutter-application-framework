import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

DisplayFieldLocator locator(String field, {String section = 'main'}) =>
    DisplayFieldLocator(screenId: 'detail', sectionId: section, fieldId: field);
DisplayDefinitionKey definitionKey({
  String namespace = 'example',
  String set = 'reading',
  String arm = 'A',
  int version = 1,
}) => DisplayDefinitionKey(
  namespace: namespace,
  presentationSet: set,
  armId: arm,
  definitionVersion: version,
);
DisplayUiDefinition definition({
  String id = 'standard',
  int version = 1,
  String type = 'documents',
  String list = 'list',
  String detail = 'detail',
  DisplayDefinitionStyle style = DisplayDefinitionStyle.standard,
  bool available = true,
}) => DisplayUiDefinition(
  id: id,
  version: version,
  resourceType: type,
  listScreenId: list,
  detailScreenId: detail,
  style: style,
  available: available,
);
DisplayDefinitionRegistry registry({
  DisplayUiDefinition? a,
  bool neutral = true,
}) => DisplayDefinitionRegistry(
  registrations: [
    DisplayDefinitionRegistration(
      key: definitionKey(),
      definition: a ?? definition(),
    ),
    DisplayDefinitionRegistration(
      key: definitionKey(arm: 'B'),
      definition: definition(id: 'cards', style: DisplayDefinitionStyle.cards),
    ),
    DisplayDefinitionRegistration(
      key: definitionKey(arm: 'C'),
      definition: definition(
        id: 'sections',
        style: DisplayDefinitionStyle.sections,
      ),
    ),
  ],
  neutralDefinition: neutral ? definition(id: 'neutral') : null,
);

PresentationContext presentationContext({
  String? arm = 'A',
  String flow = 'flow-A',
  String namespace = 'example',
  String set = 'reading',
  int version = 1,
  String locale = 'en',
  bool extensions = false,
}) => PresentationContext(
  flowId: flow,
  sourceId: 'neutral-source',
  componentId: 'neutral-component',
  families: [
    PresentationContextFamily(
      namespace: 'textus.presentation.locale',
      version: 1,
      producerId: 'producer',
      isRequired: false,
      expiresAt: null,
      payload: LocalePresentationPayload(localeTag: locale),
    ),
    if (arm != null)
      PresentationContextFamily(
        namespace: 'textus.presentation.arm',
        version: 1,
        producerId: 'producer',
        isRequired: true,
        expiresAt: null,
        payload: SuppliedArmPresentationPayload(
          namespace: namespace,
          presentationSet: set,
          armId: arm,
          definitionVersion: version,
          assignmentReference: 'assignment-$flow',
        ),
      ),
    PresentationContextFamily(
      namespace: 'textus.presentation.correlation',
      version: 1,
      producerId: 'producer',
      isRequired: false,
      expiresAt: null,
      payload: CorrelationPresentationPayload(
        flowReference: flow,
        attemptReference: 'attempt-1',
      ),
    ),
    if (extensions)
      PresentationContextFamily(
        namespace: 'example.hints',
        version: 1,
        producerId: 'producer',
        isRequired: false,
        expiresAt: null,
        payload: OpaquePresentationPayload({'density': 'comfortable'}),
      ),
    if (extensions)
      PresentationContextFamily(
        namespace: 'example.omitted',
        version: 1,
        producerId: 'producer',
        isRequired: false,
        expiresAt: null,
        payload: OpaquePresentationPayload({'note': 'optional'}),
      ),
  ],
);
PresentationContextPolicy neutralPolicy() => PresentationContextPolicy(
  allowedProducerIds: {'producer'},
  optionalExtensions: [
    PresentationExtensionSupport(
      namespace: 'example.hints',
      version: 1,
      producerId: 'producer',
    ),
  ],
);

DisplayPrototypeFixture neutralFixture(List<PresentationContext> contexts) {
  // Given producer fixtures obey the same declared support policy as their ports.
  // When initial producer contexts are admitted at the fixture's fixed UTC clock.
  final producerContexts = [
    for (final supplied in contexts)
      neutralPolicy()
          .admit(
            supplied,
            sourceId: 'neutral-source',
            componentId: 'neutral-component',
            flowId: supplied.flowId,
            nowUtc: DateTime.utc(2026, 10, 3),
          )
          .context,
  ];
  // Then source baselines contain supported families; client bootstrap retains omission diagnostics.
  final context = producerContexts.first;
  final fields = [
    DisplayField(
      id: 'title',
      label: 'Title',
      role: 'title',
      value: const TextDisplayValue('First document'),
    ),
    DisplayField(
      id: 'description',
      label: 'Description',
      role: 'description',
      value: const TextDisplayValue('First description'),
    ),
    DisplayField(
      id: 'stage',
      label: 'Stage',
      role: 'status',
      value: const TextDisplayValue('Collecting'),
    ),
  ];
  final detail = DisplayDetailData(
    resourceId: 'doc:1',
    sourceRevision: 1,
    provenance: DisplayProvenance(
      producerId: 'producer',
      sourceId: 'neutral-source',
      revision: '1',
    ),
    bindings: [
      for (final field in fields)
        DisplayEditBinding(
          locator: locator(field.id),
          writable: field.id != 'stage',
          inputValue: field.id == 'stage'
              ? const MissingDisplayValue()
              : field.value,
          requiredNonBlank: field.id == 'title',
        ),
    ],
    model: DisplayDetailModel(
      screenId: 'detail',
      title: 'Document detail',
      sections: [DisplaySection(id: 'main', fields: fields)],
      actions: [DisplayAction(id: 'advance', label: 'Advance', enabled: true)],
    ),
  );
  final list = DisplayListData(
    resourceType: 'documents',
    snapshotId: 'snapshot-1',
    provenance: DisplayProvenance(
      producerId: 'producer',
      sourceId: 'neutral-source',
      revision: 'snapshot-1',
    ),
    model: DisplayListModel(
      screenId: 'list',
      title: 'Documents',
      detailScreenId: 'detail',
      items: [
        DisplayResourceSummary(
          resourceId: 'doc:1',
          sourceRevision: 1,
          fields: [fields.first, fields.last],
        ),
      ],
    ),
  );
  return DisplayPrototypeFixture.fromJson({
    'schema': 'textus.display.fixture.v1',
    'reference': {
      'sampleId': 'neutral-source',
      'sampleRevision': 1,
      'provisionalVersion': 1,
      'developmentOnly': true,
    },
    'resourceType': 'documents',
    'contexts': {
      for (final supplied in producerContexts)
        supplied.flowId: supplied.toJson(),
    },
    'displayResponses': {
      'list': DisplayListResponse(context: context, data: list).toJson(),
      'detail': DisplayDetailResponse(context: context, data: detail).toJson(),
    },
    'operationResponses': <String, Object?>{},
    'semanticSeed': [
      for (final item in [
        ('doc:1', 'First document'),
        ('doc:2', 'Second document'),
      ])
        {
          'resourceId': item.$1,
          'sourceRevision': 1,
          'fields': {
            'name': TextDisplayValue(item.$2).toJson(),
            'description': const TextDisplayValue('First description').toJson(),
            'state': const TextDisplayValue('collecting').toJson(),
          },
        },
    ],
    'projectionBindings': {
      'screenId': 'detail',
      'sectionId': 'main',
      'fields': [
        {
          'fieldId': 'title',
          'semanticField': 'name',
          'writable': true,
          'requiredNonBlank': true,
        },
        {
          'fieldId': 'description',
          'semanticField': 'description',
          'writable': true,
          'requiredNonBlank': false,
        },
        {
          'fieldId': 'stage',
          'semanticField': 'state',
          'writable': false,
          'requiredNonBlank': false,
          'lookup': {'collecting': 'Collecting', 'review': 'Review'},
        },
      ],
    },
    'operationBindings': {
      'advance': {
        'developmentOnly': true,
        'inputFields': ['resourceId'],
        'expected': {'state': 'collecting'},
        'transition': {'state': 'review'},
      },
    },
  });
}

/// Controllable raw boundary around a real independent semantic source.
class ControlledDisplayPort implements DisplayTransport {
  ControlledDisplayPort(this.source);
  final FixtureDisplaySource source;
  final List<DisplayRequest> requests = [];
  Completer<void>? readGate;
  Completer<void>? updateGate;
  Completer<void> readArrived = Completer<void>();
  Completer<void> updateArrived = Completer<void>();
  Map<String, Object?> Function(Map<String, Object?>)? readTransform;
  Map<String, Object?> Function(Map<String, Object?>)? updateTransform;
  Future<Map<String, Object?>> Function(DisplayUpdateRequest)? updateOverride;
  @override
  Future<Map<String, Object?>> query(DisplayQueryRequest request) {
    requests.add(request);
    return source.query(request);
  }

  @override
  Future<Map<String, Object?>> read(DisplayReadRequest request) async {
    requests.add(request);
    final gate = readGate;
    readGate = null;
    final wire = await source.read(request);
    if (gate != null) {
      if (!readArrived.isCompleted) {
        readArrived.complete();
      }
      await gate.future;
    }
    return readTransform?.call(wire) ?? wire;
  }

  @override
  Future<Map<String, Object?>> update(DisplayUpdateRequest request) async {
    requests.add(request);
    final gate = updateGate;
    updateGate = null;
    final wire =
        await (updateOverride?.call(request) ?? source.update(request));
    if (gate != null) {
      if (!updateArrived.isCompleted) {
        updateArrived.complete();
      }
      await gate.future;
    }
    return updateTransform?.call(wire) ?? wire;
  }

  @override
  Future<Map<String, Object?>> create(DisplayCreateRequest request) {
    requests.add(request);
    return source.create(request);
  }

  @override
  Future<Map<String, Object?>> delete(DisplayDeleteRequest request) {
    requests.add(request);
    return source.delete(request);
  }
}

class PresentationFixture {
  PresentationFixture({
    PresentationContext? context,
    DisplayDefinitionRegistry? definitions,
  }) {
    final supplied = context ?? presentationContext();
    fixture = neutralFixture([supplied]);
    source = FixtureDisplaySource(
      fixture: fixture,
      listTemplateId: 'list',
      detailTemplateId: 'detail',
      componentId: 'neutral-component',
      contextPolicy: neutralPolicy(),
      nowUtc: () => DateTime.utc(2026, 10, 3),
    );
    port = ControlledDisplayPort(source);
    session = newSession(supplied);
    controller = DisplayPresentationController(
      session: session,
      registry: definitions ?? registry(),
    );
  }
  late final DisplayPrototypeFixture fixture;
  late final FixtureDisplaySource source;
  late final ControlledDisplayPort port;
  late final DisplaySession session;
  late final DisplayPresentationController controller;
  DisplaySession newSession(PresentationContext context) => DisplaySession(
    resourceType: 'documents',
    sourceId: 'neutral-source',
    componentId: 'neutral-component',
    listScreenId: 'list',
    detailScreenId: 'detail',
    initialContext: context,
    contextPolicy: neutralPolicy(),
    displayTransport: port,
    operationTransport: FixtureOrdinaryOperationTransport(source: source),
    nowUtc: () => DateTime.utc(2026, 10, 3),
  );
  void dispose() {
    // Given the fixture owns its presentation controller and fixed session.
    // When fixture cleanup explicitly discards the owner.
    controller.dispose();
    // Then the Core owner is immediately disposed, independent of notifier release.
    expect(controller.isDisposed, isTrue);
    expect(controller.session.isDisposed, isTrue);
  }
}

Future<void> openController(
  PresentationFixture fixture, {
  bool edit = false,
}) async {
  // Given an idle controller and a real ordered neutral source.
  // When the collection is explicitly loaded.
  await fixture.controller.load();
  // Then the collection is ready with no eager Detail or command.
  expect(fixture.session.state.list.phase, DisplaySessionReadPhase.ready);
  expect(fixture.source.calls.last.kind, DisplayRequestKind.query);
  // Given doc:1 is an accepted ordered resource identity.
  // When its Detail is explicitly selected.
  expect(
    await fixture.controller.select('doc:1'),
    DisplayNavigationOutcome.selected,
  );
  // Then the selected projection is coherent and eligible.
  expect(fixture.controller.state.canEdit, isTrue);
  expect(fixture.session.state.selectedResourceId, 'doc:1');
  if (edit) {
    // Given a coherent Detail and no existing draft.
    // When editing is explicitly opened.
    fixture.controller.beginEdit();
    // Then semantic input is copied at the accepted revision.
    expect(fixture.controller.state.draft!.observedRevision, 1);
    expect(
      fixture.controller.state.draft!.values[locator('title')],
      fixture.session.state.detail.data!.bindings
          .singleWhere((binding) => binding.locator == locator('title'))
          .inputValue,
    );
  }
}

Map<String, Object?> duplicateSection(
  Map<String, Object?> wire, {
  bool differentInput = false,
  bool disabledAction = false,
}) {
  final response = DisplayDetailResponse.fromJson(wire);
  final data = response.data;
  final title = data.model.sections.first.fields.first;
  final extra = DisplayField(
    id: 'title',
    label: 'Other title',
    role: title.role,
    value: title.value,
  );
  return DisplayDetailResponse(
    context: response.context,
    data: DisplayDetailData(
      resourceId: data.resourceId,
      sourceRevision: data.sourceRevision,
      provenance: data.provenance,
      bindings: [
        for (final binding in data.bindings)
          DisplayEditBinding(
            locator: binding.locator,
            writable: binding.writable,
            inputValue: differentInput && binding.locator.fieldId == 'title'
                ? const TextDisplayValue('Semantic input')
                : binding.inputValue,
            requiredNonBlank: binding.requiredNonBlank,
          ),
        DisplayEditBinding(
          locator: locator('title', section: 'other'),
          writable: true,
          inputValue: const TextDisplayValue('Other input'),
          requiredNonBlank: true,
        ),
      ],
      model: DisplayDetailModel(
        screenId: 'detail',
        title: data.model.title,
        sections: [
          ...data.model.sections,
          DisplaySection(id: 'other', fields: [extra]),
        ],
        actions: [
          for (final action in data.model.actions)
            DisplayAction(
              id: action.id,
              label: action.label,
              enabled: !disabledAction && action.enabled,
            ),
        ],
      ),
    ),
  ).toJson();
}

Future<void> mountView(
  WidgetTester tester,
  DisplayPresentationController controller, {
  double width = 400,
  bool autoLoad = true,
  SettingsView? settings,
}) async {
  // Given a caller-owned controller and explicit ordinary viewport capability.
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  // When the public borrowed view is mounted with the existing optional text boundary.
  await tester.pumpWidget(
    MaterialApp(
      builder: settings == null
          ? null
          : (context, child) =>
                ApplicationTextScaling(view: settings, child: child!),
      home: DisplaySessionView(controller: controller, autoLoad: autoLoad),
    ),
  );
  await tester.pumpAndSettle();
  // Then mounting preserves ownership and performs no command.
  expect(controller.isDisposed, isFalse);
  expect(controller.session.state.command.sequence, 0);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  // Given the keyed public control is present in its scrollable pane.
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  // When the explicit UI control is activated.
  await tester.tap(finder);
  await tester.pumpAndSettle();
  // Then the UI remains free of framework exceptions.
  expect(tester.takeException(), isNull);
}

Future<void> openView(
  WidgetTester tester,
  PresentationFixture fixture, {
  double width = 400,
  bool edit = false,
}) async {
  await mountView(tester, fixture.controller, width: width);
  // Given autoLoad accepted the ordered List and no Detail was read eagerly.
  expect(fixture.source.callCount, 1);
  // When the public resource row is selected.
  await tester.tap(find.byKey(const ValueKey(('display-resource', 'doc:1'))));
  await tester.pumpAndSettle();
  // Then the public view displays the accepted Detail.
  expect(fixture.session.state.selectedResourceId, 'doc:1');
  expect(find.text('Document detail'), findsOneWidget);
  if (edit) {
    // Given an accepted editable Detail.
    // When the ordinary Edit control is selected.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    // Then only writable semantic fields become editors.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(fixture.controller.state.draft, isNotNull);
  }
}

Future<void> typeTitle(
  WidgetTester tester,
  String text, {
  String section = 'main',
}) async {
  // Given a scoped writable Text editor in the current draft.
  final finder = find.byKey(
    ValueKey(('display-field', 'detail', section, 'title')),
  );
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  // When exact user text is entered.
  await tester.enterText(finder, text);
  await tester.pump();
  // Then editor text preserves its exact bytes.
  expect(tester.widget<TextField>(finder).controller!.text, text);
}

Future<void> competingUpdate(PresentationFixture fixture, String text) async {
  // Given an independent common session shares only the neutral semantic source.
  final session = fixture.newSession(fixture.session.state.context);
  // When that independent consumer explicitly queries and selects the resource.
  await session.query();
  await session.read('doc:1');
  // Then it has coherent revision evidence without inheriting the first draft.
  expect(session.state.canMutate, isTrue);
  // Given an accepted independent Detail revision.
  // When the competing common consumer changes its semantic title.
  await session.update(
    observedRevision: session.state.detail.data!.sourceRevision,
    fields: [
      DisplayFieldInput(
        locator: locator('title'),
        value: TextDisplayValue(text),
      ),
    ],
  );
  // Then the shared semantic source changed and the original consumer draft was not replayed.
  expect(fixture.source.resources.first.fields['name'], TextDisplayValue(text));
  expect(
    session.state.command.mutation!.outcome,
    DisplayCommandOutcome.changed,
  );
  // Given the independent consumer has finished its source activity.
  // When that consumer is explicitly disposed.
  session.dispose();
  // Then only that session was disposed.
  expect(session.isDisposed, isTrue);
  expect(fixture.session.isDisposed, isFalse);
}

Map<String, Object?> incompatibleProducer(Map<String, Object?> wire) {
  final response = DisplayDetailResponse.fromJson(wire);
  final old = response.context;
  final next = PresentationContext(
    flowId: old.flowId,
    sourceId: old.sourceId,
    componentId: old.componentId,
    families: [
      for (final family in old.families)
        PresentationContextFamily(
          namespace: family.namespace,
          version: family.version,
          producerId: 'intruder',
          isRequired: family.isRequired,
          expiresAt: family.expiresAt,
          payload: family.payload,
        ),
    ],
  );
  return DisplayDetailResponse(context: next, data: response.data).toJson();
}

Future<Map<String, Object?>> rejectUpdate(DisplayUpdateRequest request) async =>
    DisplayMutationResponse(
      context: request.metadata.context,
      result: DisplayMutationResult(
        resourceId: request.resourceId,
        outcome: DisplayCommandOutcome.rejected,
        currentRevision: 1,
        committedRevision: null,
        fieldErrors: [
          DisplayFieldError(
            locator: locator('title'),
            code: 'constraint',
            message: 'Title constraint',
          ),
          DisplayFieldError(
            locator: null,
            code: 'global',
            message: 'Global constraint',
          ),
        ],
        message: 'Rejected',
        display: null,
      ),
    ).toJson();

void setDraftValue(
  DisplayPresentationController controller,
  DisplayFieldLocator locator,
  DisplayValue? value,
) {
  // Given a current writable scoped semantic draft and no command activity.
  final beforeSequence = controller.session.state.command.sequence;
  final beforeRevision = controller.state.draft!.observedRevision;
  // When the exact typed local input is explicitly changed.
  controller.setValue(locator, value);
  // Then values preserve their exact type/bytes without changing the observed revision or command sequence.
  expect(controller.state.draft!.values[locator], value);
  expect(controller.state.draft!.observedRevision, beforeRevision);
  expect(controller.session.state.command.sequence, beforeSequence);
}
