import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Core's public transport constructor accepts http.Client; this fixture exercises
// that real client using the declared http mock test dependency.
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

const mutationTitle = CncfDisplayFieldLocator('main', 'title');
const mutationDescription = CncfDisplayFieldLocator('main', 'description');

/// Trusted test configuration for the reference producer's ordinary operation.
CncfDisplayBusinessBinding referenceBusinessBinding({
  String componentId = 'org.simplemodeling.textus.EditingStudio',
  String actionId = 'request-review',
  String bindingId = 'ess.reference.request-review',
}) => CncfDisplayBusinessBinding(
  componentId: componentId,
  actionId: actionId,
  bindingId: bindingId,
  service: 'reference-business',
  operation: 'requestReview',
  expectedOutcome: 'review-requested',
);

Map<String, Object?> mutationFixture(String name) => Map<String, Object?>.from(
  jsonDecode(
    File('test/fixtures/cncf_display_reference_v1/$name.json')
        .readAsStringSync(),
  ) as Map,
);

http.Response mutationReply(Object? data, {int status = 200}) =>
    mutationRawReply(jsonEncode({'data': data}), status: status);
http.Response mutationRawReply(String raw, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(raw),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Finite gates are released by each scenario and by its owner's teardown.
final class MutationGate {
  final entered = Completer<void>();
  final settled = Completer<void>();
  final _released = Completer<void>();
  Future<void> wait() async {
    if (!entered.isCompleted) {
      entered.complete();
    }
    try {
      await _released.future;
    } finally {
      settled.complete();
    }
  }

  void release() {
    if (!_released.isCompleted) {
      _released.complete();
    }
  }
}

/// Controlled Core transport: derived revisions are not producer validation.
final class CncfDisplayMutationFixture {
  CncfDisplayMutationFixture({
    Duration timeout = const Duration(seconds: 3),
    List<CncfDisplayBusinessBinding> businessBindings = const [],
    this.presentationContext,
  }) {
    final initial = mutationFixture('detail-initial');
    id = ((initial['model']! as Map)['resource'] as Map)['entityId']! as String;
    transport = MockClient((request) async {
      requests.add(request);
      final kind = request.method == 'POST'
          ? 'business'
          : request.method == 'PUT'
          ? 'update'
          : request.url.path.endsWith('describeMutation.json')
          ? 'descriptor'
          : request.url.path.endsWith('read.json')
          ? 'read'
          : 'query';
      final gate = _gates.remove(kind);
      if (gate != null) {
        await gate.wait();
      }
      if (kind == 'descriptor') {
        return mutationReply(descriptorData);
      }
      if (kind == 'business') {
        final custom = businessResponse;
        if (custom != null) return custom(request);
        // Controlled response derived from the ordinary producer contract, not
        // a new genuine fixture or evidence of a live producer run.
        revision = (BigInt.parse(revision) + BigInt.one).toString();
        values['stage'] = 'レビュー待ち';
        reviewed = true;
        return mutationRawReply(businessResultWire());
      }
      if (kind == 'update') {
        final custom = updateResponse;
        if (custom != null) {
          return custom(request);
        }
        final body = jsonDecode(request.body) as Map;
        var changed = false;
        for (final item in body['changes'] as List) {
          final change = item as Map;
          final field = change['fieldId']! as String;
          final text = (change['value'] as Map)['text']! as String;
          if (values[field] != text) {
            changed = true;
          }
          values[field] = text;
        }
        final outcome = changed ? 'updated' : 'unchanged';
        if (changed) {
          revision = (BigInt.parse(revision) + BigInt.one).toString();
        }
        return mutationRawReply(resultWire(outcome: outcome));
      }
      if (kind == 'read' && failRead || kind == 'query' && failQuery) {
        return mutationRawReply('{"private":"do not display"}', status: 503);
      }
      return mutationReply(readWire(detail: kind == 'read'));
    });
    client = CncfDisplayReadClient(
      profile: CncfDisplayReadProfile(
        componentId: initial['componentId']! as String,
        resourceType: initial['resourceType']! as String,
        listScreenId: 'collecting-resources',
        detailScreenId: 'capture-detail',
        definitionRevision: 'ess-reference-definition-1',
        mutationRevision: 'ess-reference-mutation-1',
        semanticContract: initial['semanticContract']! as Map<String, Object?>,
        provenance: initial['provenance']! as Map<String, Object?>,
      ),
      endpoint: Uri.parse('https://studio.test/rest/v1/editing-studio/'),
      client: transport,
      bearerToken: () async => 'fixture-token',
      timeout: timeout,
    );
    source = CncfDisplayResourceDataSource(client: client);
    viewModel = ResourceViewModel(dataSource: source);
    controller = CncfDisplayMutationController(
      source: source,
      viewModel: viewModel,
      businessBindings: businessBindings,
    );
  }

  late final String id;
  late final http.Client transport;
  late final CncfDisplayReadClient client;
  late final CncfDisplayResourceDataSource source;
  late final ResourceViewModel viewModel;
  late final CncfDisplayMutationController controller;
  final requests = <http.Request>[];
  final descriptorData = mutationFixture('mutation-descriptor');
  final values = <String, String>{
    'title': '日本の民話',
    'stage': '収集中',
    'description': '地域に伝わる物語を集めた資料。',
  };
  String revision = '1';
  bool pending = false;
  bool failRead = false;
  bool failQuery = false;
  // Controlled family decoration, not a genuine golden or live authority.
  Map<String, Object?>? presentationContext;
  String? queryRevision;
  bool missingTitle = false;
  bool reviewed = false;
  String actionAvailability = 'enabled';
  String actionBindingId = 'ess.reference.request-review';
  Future<http.Response> Function(http.Request)? businessResponse;
  Future<http.Response> Function(http.Request)? updateResponse;
  final _gates = <String, MutationGate>{};
  final allGates = <MutationGate>[];
  List<http.Request> get puts =>
      requests.where((r) => r.method == 'PUT').toList();
  List<http.Request> get posts =>
      requests.where((r) => r.method == 'POST').toList();

  String businessResultWire({String outcome = 'review-requested'}) =>
      jsonEncode({
        'data': {
          'resourceId': id,
          'revision': '@revision@',
          'outcome': outcome,
        },
      }).replaceFirst('"@revision@"', revision);

  MutationGate hold(String kind) {
    final gate = MutationGate();
    _gates[kind] = gate;
    allGates.add(gate);
    return gate;
  }

  Future<void> select() async {
    await viewModel.load();
    await viewModel.select(id);
  }

  Future<void> edit() async {
    await select();
    await controller.beginEdit();
  }

  Map<String, Object?> readWire({required bool detail}) {
    final wire = mutationFixture(detail ? 'detail-initial' : 'list-initial');
    if (presentationContext != null) {
      wire['presentationContext'] = presentationContext;
    }
    final model = wire['model']! as Map;
    final resource = detail
        ? model['resource'] as Map
        : ((model['items'] as List).first as Map)['resource'] as Map;
    resource['revision'] = detail ? revision : queryRevision ?? revision;
    final fields = detail
        ? ((model['sections'] as List).first as Map)['fields'] as List
        : ((model['items'] as List).first as Map)['fields'] as List;
    for (final item in fields) {
      final field = item as Map;
      if (field['id'] == 'title' && missingTitle) {
        field['value'] = {'type': 'missing'};
      } else {
        (field['value'] as Map)['text'] = values[field['id']];
      }
    }
    if (detail) {
      for (final action in model['actions'] as List) {
        (action as Map)['availability'] = reviewed
            ? 'hidden'
            : actionAvailability;
        action['bindingId'] = actionBindingId;
      }
    }
    return wire;
  }

  String resultWire({String outcome = 'updated'}) => jsonEncode({
    'data': {
      'schema': 'cncf.display-mutation-result.v1',
      'version': 1,
      'componentId': descriptorData['componentId'],
      'resourceType': descriptorData['resourceType'],
      'definition': descriptorData['definition'],
      'provenance': descriptorData['provenance'],
      'outcome': outcome,
      'resource': {'entityId': id, 'revision': '@revision@'},
      'projection': pending
          ? {'type': 'pending', 'reason': 'view-not-current'}
          : {'type': 'ready', 'display': readWire(detail: true)},
      'retryCommand': false,
    },
  }).replaceFirst('"@revision@"', revision);

  http.Response failureReply({
    bool conflict = false,
    int status = 422,
    String path = 'capture-detail/main/title',
  }) => mutationRawReply(
    jsonEncode({
      'error': {
        'conclusion': {
          'message': 'PRIVATE server conclusion',
          'observation': {
            'taxonomy': {
              'category': conflict ? 'operation' : 'argument',
              'symptom': conflict ? 'conflict' : 'invalid',
            },
            'cause': {
              'diagnostic': {
                'code': conflict ? 'ANY_CODE' : 'DSP96_MUTATION_VALUE_INVALID',
                'path': path,
              },
              'facets': [],
            },
          },
        },
      },
    }),
    status: status,
  );

  void releaseAll() {
    for (final gate in allGates) {
      gate.release();
    }
  }

  void dispose() {
    releaseAll();
    controller.dispose();
    viewModel.dispose();
    client.dispose();
    transport.close();
  }
}
