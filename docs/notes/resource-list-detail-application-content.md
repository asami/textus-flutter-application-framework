# Application content in Resource List/Detail

Authored 2026-10-06 for PHASE-6 / ESA6-05 / ESA6-05-A. Parent validation and
complete ESA6-05 independent acceptance remain pending.

| Optional input | Type/default | Placement |
| --- | --- | --- |
| `detailSupplementBuilder` | `Widget Function(BuildContext context, ResourceRecord record)?`, null | After configured fields, action diagnostics and aggregate buttons in the existing scrolling Detail ListView |
| `additionalActions` | `List<Widget>`, `const []` | After common hinge/layout controls in the AppBar in every presentation |

Defaults retain existing configuration, selection, action labels and layouts.
Aggregate buttons still intersect handler availability and dispatch existing
semantic commands. These caller presentation slots grant no command/storage
authority, persisted configuration, ResourceAction intent, schema, framework
refresh/loading flag or retry policy.

Only actually built ready selected Detail invokes the builder, after failure,
loading and missing-record guards, with the exact current ResourceRecord and
Detail build context. No selection, hidden compact-list Detail, pending, failed
or missing data admit no supplement. Ordinary rebuild invocation counts are
unspecified. Content follows configured fields/diagnostics/actions in the same
ListView with natural height; use wrapping content suitable for narrow/enlarged
text. Material/text scaling, safe areas, compact back, focus/restore and hinge
controls keep existing ownership.

The returned widget uses a KeyedSubtree keyed by `record.id`. A mounted same-ID
subtree follows ordinary updates; different identity replaces it. Refreshed same-ID
records reach the callback on normal rebuild; supplied StatefulWidgets own their
`didUpdateWidget` and request policy. Loading/error/hidden states can remove the
subtree, so identity does not promise retention while absent. Flutter disposes
removed/unmounted content. TFAF neither manually disposes arbitrary supplied
widgets nor disposes borrowed ViewModel/display authorities.

Caller content owns domain reads, navigation, state, retries and its async
lifetime. Avoid starting a new domain request on every build. Stateful content
can initialize reads, update on meaningful record changes, suppress late publication
after removal and release its resources in disposal. Existing Resource Views
retain selected-read generation protection; the hook adds no cache/registry/async
owner or domain IO. Caller requests need their own lifetime policy.

Toolbar widgets remain available in list/no-selection/detail, loading, empty and
safe errors for explicit caller recovery. TFAF appends widgets without invoking
callbacks during build. Supplied widgets own callbacks/enabled state/navigation
and may be disabled.

## Public consumer sample

```dart
import 'package:flutter/material.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

Widget resourcePage({
  required ResourceListDetailConfiguration configuration,
  required ResourceViewModel model,
  required ResourceListDetailDisplayModel display,
  required bool canReload,
}) => ResourceListDetail(
  configuration: configuration,
  viewModel: model,
  displayModel: display,
  detailSupplementBuilder: (context, record) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text('Application content for ${record.id}'),
  ),
  additionalActions: [
    IconButton(
      tooltip: 'Reload',
      icon: const Icon(Icons.refresh),
      onPressed: canReload
          ? () async {
              await model.load();
              await model.detailView.refresh();
            }
          : null,
    ),
  ],
);
```

The caller chooses collection/detail refresh here. The application owner unmounts
the borrowed page before disposing models and owns async route/read/retry lifetime.
An application can supply its domain callback and stateful original-material
content through these slots.

## Authored public executable scenarios

The [extension specification](../../test/resource_list_detail_extension_test.dart)
uses public imports/ResourceDataSource/ResourceViewModel and adjacent
Given/When/Then at actual setup/actions/assertions:

- G1: compact400/expanded1000 defaults, configured fields/actions and actual
  selection without invented supplied content/actions.
- G2: exact selected/same-ID refreshed object, configured buttons and reachable
  same scrolling detail at both widths.
- G3: no selection/hidden compact Detail, finite observed delayed reads, success
  admission and separate safe failure/missing diagnostics without stale content.
- G4: child initialization/update/disposal, identity replacement, same-ID update,
  removal/unmount, borrowed-owner survival and old-read generation suppression.
- G5: explicit/disabled toolbar callbacks across all states, common back/focus/
  restore/hinge controls and narrow320/OS2/common1.3 natural-height reachability
  with no overflow/exception expectations waived.

All gates release and terminal futures are observed; test owners unmount before
disposing borrowed authorities. Scenarios are authored/pending with no pass/count.
Parent-selected analysis, representative and common List/Detail/action/adaptive/
hinge/settings/navigation accumulator are planned/unsubmitted. Historical passes
do not prove these new APIs. App ESA6-05-B lazy local Candidates/original review/
exact-ID edit/reopen/refresh/retry and post-edit reload remain next, consuming
accepted repository/guarded-original APIs. Complete A+B review, separate03
conformance, physical P1–P8/P7 actual List/Detail and release remain pending.
App aggregate validation belongs to never-started Phase6.1.
