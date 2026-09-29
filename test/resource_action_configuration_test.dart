import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

const _json = <String, dynamic>{
  'listTitle': 'Resources',
  'detailTitle': 'Detail',
  'primaryField': 'name',
  'detailFields': [
    {'key': 'status', 'label': 'Status'},
  ],
};

ResourceListDetailConfiguration _configuration(dynamic actions) =>
    ResourceListDetailConfiguration.fromJson({
      ..._json,
      'detailActions': actions,
    });

class _ActionBinding implements ResourceDataSource, ResourceActionHandler {
  int listReads = 0;
  int detailReads = 0;
  final executions = <String>[];
  bool completed = false;
  Completer<void>? pending;

  ResourceRecord get record => ResourceRecord(
    id: 'one',
    values: {
      'name': 'First resource',
      'status': completed ? 'Updated' : 'Draft',
    },
  );

  @override
  Future<List<ResourceRecord>> listResources() async {
    listReads++;
    return [record];
  }

  @override
  Future<ResourceRecord?> getResource(String id) async {
    detailReads++;
    return id == 'one' ? record : null;
  }

  @override
  List<ResourceAction> actionsFor(ResourceRecord record) => completed
      ? const []
      : const [
          ResourceAction(id: 'review', label: 'Runtime review'),
          ResourceAction(id: 'archive', label: 'Runtime archive'),
        ];

  @override
  Future<void> execute(String actionId, ResourceRecord record) async {
    executions.add(actionId);
    if (pending != null) await pending!.future;
    completed = true;
  }
}

Widget _screen(
  ResourceListDetailConfiguration configuration,
  ResourceViewModel model,
) => MaterialApp(
  home: ResourceListDetail(configuration: configuration, viewModel: model),
);

Future<ResourceViewModel> _show(
  WidgetTester tester,
  _ActionBinding binding,
  ResourceListDetailConfiguration configuration, {
  double width = 1000,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final model = ResourceViewModel(dataSource: binding, actionHandler: binding);
  addTearDown(model.dispose);
  await tester.pumpWidget(_screen(configuration, model));
  await tester.pumpAndSettle();
  await tester.tap(find.text('First resource'));
  await tester.pumpAndSettle();
  return model;
}

void main() {
  test(
    'Cozy handoff examples decode through the public configuration contracts',
    () {
      // Given the JSON examples published for compiler authors.
      final document = File('docs/notes/configuration-cozy-handoff.md')
          .readAsStringSync();
      final examples = RegExp(r'```json\n([\s\S]*?)\n```')
          .allMatches(document)
          .map((match) => jsonDecode(match.group(1)!) as Map<String, dynamic>)
          .toList();

      // When each example enters its corresponding public decoder.
      final resource = ResourceListDetailConfiguration.fromJson(
        examples.singleWhere((json) => json.containsKey('detailFields')),
      );
      final navigation = ApplicationNavigationConfiguration.fromJson(
        examples.singleWhere((json) => json.containsKey('destinations')),
      );

      // Then the documented compiler outputs are executable contract examples.
      expect(examples.length, 2);
      expect(resource.detailActions!.single.id, 'request-review');
      expect(resource.detailActions!.single.label, '確認依頼');
      expect(navigation.initialDestinationId, 'home');
      expect(navigation.destinations.map((destination) => destination.id), [
        'home',
        'collecting',
        'candidates',
      ]);
    },
  );

  testWidgets('configuration cannot create actions without a handler', (
    tester,
  ) async {
    // Given configured action IDs and a read source with no command handler.
    final binding = _ActionBinding();
    final model = ResourceViewModel(dataSource: binding);
    addTearDown(model.dispose);
    final configuration = _configuration([
      {'id': 'review', 'label': 'Configured review'},
    ]);

    // When the standard Widget opens a resource without a command binding.
    await tester.pumpWidget(_screen(configuration, model));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First resource'));
    await tester.pumpAndSettle();

    // Then configuration creates neither a button nor command capability.
    expect(find.text('Configured review'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(model.selectedActions, isEmpty);
    expect(binding.executions, isEmpty);
  });

  test('detail action presentation round-trips through JSON in order', () {
    // Given a compiler-produced ordered action presentation.
    const actions = [
      {'id': 'archive', 'label': 'Archive this resource'},
      {'id': 'review', 'label': 'Request review'},
    ];

    // When the public configuration is decoded and encoded.
    final configuration = _configuration(actions);
    final restored = ResourceListDetailConfiguration.fromJson(
      configuration.toJson(),
    );

    // Then semantic IDs, order, and presentation labels survive unchanged.
    expect(restored.toJson()['detailActions'], actions);
    expect(restored.detailActions!.map((action) => action.id), [
      'archive',
      'review',
    ]);
    expect(restored.toJson(), configuration.toJson());
  });

  test(
    'missing or null actions preserve the legacy handler-driven contract',
    () {
      // Given legacy JSON with no action presentation, or an explicit null.
      for (final json in [
        _json,
        {..._json, 'detailActions': null},
      ]) {
        // When it is decoded and encoded.
        final configuration = ResourceListDetailConfiguration.fromJson(json);

        // Then the absence remains distinct from an explicitly empty allowlist.
        expect(configuration.detailActions, isNull);
        expect(configuration.toJson().containsKey('detailActions'), isFalse);
      }
    },
  );

  test('an explicit empty action list survives serialization', () {
    // Given an intentionally read-only presentation.
    final configuration = _configuration(<dynamic>[]);

    // When it is serialized again.
    final json = configuration.toJson();

    // Then it does not become the legacy absent value.
    expect(configuration.detailActions, isEmpty);
    expect(json['detailActions'], isEmpty);
  });

  test('malformed or duplicate detail actions are rejected at JSON intake', () {
    // Given invalid container, entry, ID, label, and duplicate-ID inputs.
    final invalid = <dynamic>[
      'review',
      {},
      [null],
      [1],
      [
        {'label': 'Review'},
      ],
      [
        {'id': 'review'},
      ],
      [
        {'id': 1, 'label': 'Review'},
      ],
      [
        {'id': 'review', 'label': false},
      ],
      [
        {'id': ' ', 'label': 'Review'},
      ],
      [
        {'id': 'review', 'label': ' '},
      ],
      [
        {'id': 'review', 'label': 'Review'},
        {'id': 'review', 'label': 'Duplicate'},
      ],
    ];

    // When each invalid configuration enters the public decoder.
    for (final actions in invalid) {
      // Then it fails deterministically rather than producing ambiguous buttons.
      expect(() => _configuration(actions), throwsFormatException);
    }
  });

  test('decoded detail actions are detached and unmodifiable', () {
    // Given a mutable compiler input list.
    final input = [
      {'id': 'review', 'label': 'Review'},
    ];
    final configuration = _configuration(input);

    // When the producer mutates its original list.
    input.clear();

    // Then the decoded value retains its meaning and cannot be edited in place.
    expect(configuration.detailActions!.single.id, 'review');
    expect(() => configuration.detailActions!.clear(), throwsUnsupportedError);
  });

  for (final width in <double>[400, 1000]) {
    testWidgets(
      'configured actions intersect availability and dispatch IDs at width $width',
      (tester) async {
        // Given configured order/labels differing from the handler, plus an unavailable ID.
        final binding = _ActionBinding();
        final model = await _show(
          tester,
          binding,
          _configuration([
            {'id': 'archive', 'label': 'Configured archive'},
            {'id': 'not-authorized', 'label': 'Unavailable action'},
            {'id': 'review', 'label': 'Configured review'},
          ]),
          width: width,
        );
        expect(find.text('Configured archive'), findsOneWidget);
        expect(find.text('Configured review'), findsOneWidget);
        expect(find.text('Unavailable action'), findsNothing);
        expect(find.text('Runtime archive'), findsNothing);
        expect(find.text('Runtime review'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Configured archive')).dy,
          lessThan(tester.getTopLeft(find.text('Configured review')).dy),
        );

        // When the configured label is tapped.
        await tester.tap(find.text('Configured archive'));
        await tester.pumpAndSettle();

        // Then only its semantic ID reaches the handler and Views refresh availability.
        expect(binding.executions, ['archive']);
        expect(model.selectedResource!.value('status'), 'Updated');
        expect(model.resources!.single.value('status'), 'Updated');
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a configured subset hides other available actions', (
    tester,
  ) async {
    // Given two runtime actions but only one declared presentation action.
    final binding = _ActionBinding();

    // When the resource is selected through the standard Widget.
    final model = await _show(
      tester,
      binding,
      _configuration([
        {'id': 'review', 'label': 'Configured review'},
      ]),
    );

    // Then the undeclared action is hidden without changing handler authority.
    expect(find.text('Configured review'), findsOneWidget);
    expect(find.text('Runtime archive'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(model.selectedActions.length, 2);
    expect(binding.executions, isEmpty);
  });

  testWidgets(
    'explicit empty actions suppress buttons without removing capabilities',
    (tester) async {
      // Given an available command handler and a read-only presentation allowlist.
      final binding = _ActionBinding();

      // When the same resource is selected.
      final model = await _show(tester, binding, _configuration(<dynamic>[]));

      // Then presentation is read-only, not a domain-authorization change.
      expect(find.byType(FilledButton), findsNothing);
      expect(model.selectedActions.length, 2);
      expect(binding.executions, isEmpty);
    },
  );

  testWidgets('legacy presentations retain runtime labels and order', (
    tester,
  ) async {
    // Given an old configuration without detailActions and a compatible handler.
    final binding = _ActionBinding();

    // When the standard Widget opens detail.
    await _show(
      tester,
      binding,
      ResourceListDetailConfiguration.fromJson(_json),
    );

    // Then both handler-defined labels remain visible in their original order.
    expect(find.text('Runtime review'), findsOneWidget);
    expect(find.text('Runtime archive'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Runtime review')).dy,
      lessThan(tester.getTopLeft(find.text('Runtime archive')).dy),
    );
  });

  testWidgets(
    'action configuration can change without changing the screen or querying',
    (tester) async {
      // Given a selected resource with one configured action label.
      final binding = _ActionBinding();
      final model = await _show(
        tester,
        binding,
        _configuration([
          {'id': 'review', 'label': 'Original label'},
        ]),
      );

      // When configuration alone replaces its presentation with another action.
      await tester.pumpWidget(
        _screen(
          _configuration([
            {'id': 'archive', 'label': 'Replacement label'},
          ]),
          model,
        ),
      );
      await tester.pumpAndSettle();

      // Then the same selection/Views survive and no extra query or command runs.
      expect(find.text('Replacement label'), findsOneWidget);
      expect(find.text('Original label'), findsNothing);
      expect(model.selectedId, 'one');
      expect(binding.listReads, 1);
      expect(binding.detailReads, 1);
      expect(binding.executions, isEmpty);
    },
  );

  testWidgets('configured actions stay disabled while a command is running', (
    tester,
  ) async {
    // Given configured actions backed by a handler with an unfinished command.
    final binding = _ActionBinding()..pending = Completer<void>();
    await _show(
      tester,
      binding,
      _configuration([
        {'id': 'review', 'label': 'Configured review'},
        {'id': 'archive', 'label': 'Configured archive'},
      ]),
    );

    // When one configured action starts but has not completed.
    await tester.tap(find.text('Configured review'));
    await tester.pump();

    // Then both buttons are disabled and completion does not duplicate execution.
    for (final button in tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(binding.executions, ['review']);
    binding.pending!.complete();
    await tester.pumpAndSettle();
    expect(binding.executions, ['review']);
    expect(find.byType(FilledButton), findsNothing);
  });
}
