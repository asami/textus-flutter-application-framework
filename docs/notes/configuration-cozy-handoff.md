# Configuration contract for the Cozy handoff

Date: 2026-09-29
Status: implemented Phase 1 subset; not a complete Cozy UI compiler

This document describes the JSON accepted by TFAF's public configuration
decoders and the application bindings needed to realize it. Cozy should emit
these values as configuration assets, not generate another standard List or
Detail Widget. The reference app currently authors those assets manually.

## Resource List/Detail schema

Decode one object with `ResourceListDetailConfiguration.fromJson`. The object
describes one resource presentation; it does not contain data, network paths,
Aggregate instances, or a complete application view-space definition.

| Property | JSON type | Required / default | Meaning |
| --- | --- | --- | --- |
| `listTitle` | string | required | List presentation title. |
| `detailTitle` | string | required | Compact detail title. |
| `primaryField` | string | required | Projection key for the list's primary text. |
| `secondaryField` | string or null | absent/null | Optional projection key for list secondary text. |
| `detailFields` | array of field objects | required, nonempty | Ordered detail fields, each with string `key` and `label`. |
| `detailActions` | array of action objects or null | absent/null | Ordered action presentation allowlist; see compatibility below. |
| `compactBreakpoint` | positive finite number | 700 | Ordinary width breakpoint in logical pixels. |
| `minimumFoldPaneWidth` | positive finite number | 280 | Minimum usable pane width under fold/hinge policy. |
| `minimumFoldPaneHeight` | positive finite number | 180 | Minimum usable pane height under fold/hinge policy. |
| `allowDetailFocus` | boolean | true | Offer explicit detail focus when split presentation is viable. |
| `defaultHingePolicy` | string | `automatic` | One of `automatic`, `avoid`, `span`. |
| `allowHingePolicySwitch` | boolean | true | Allow the common viable-policy menu. |
| `realization` | string | `framework` | One of `framework`, `generated`, `hybrid`, `custom`. |

Optional properties may be omitted or null to select their defaults. Unknown
properties are ignored by the current decoder and are not preserved by
`toJson`; they are not runtime extension points. Cozy must emit only this
implemented subset until another contract explicitly adds capabilities.
There is currently no schema-version property or application-manifest loader.

Field `key` values address `ResourceRecord.values`. Missing record properties
render as empty text. Cozy/binding validation should ensure projected fields
exist; a label is presentation text, not a model property or query expression.

An action object has string `id` and `label`, both nonblank. Action IDs must be
unique within `detailActions`; malformed objects and duplicate IDs are rejected
with `FormatException` at JSON intake. Decoded action lists are detached from
input and unmodifiable. Typed Dart callers must supply the same well-formed
values; the const configuration constructor is not a general schema validator.

Example compiler output:

```json
{
  "realization": "framework",
  "listTitle": "Knowledge Candidates",
  "detailTitle": "Candidate Detail",
  "primaryField": "title",
  "secondaryField": "reviewStatus",
  "detailFields": [
    {"key": "title", "label": "Title"},
    {"key": "reviewStatus", "label": "Review status"}
  ],
  "detailActions": [
    {"id": "request-review", "label": "確認依頼"}
  ],
  "compactBreakpoint": 700,
  "minimumFoldPaneWidth": 280,
  "minimumFoldPaneHeight": 180,
  "allowDetailFocus": true,
  "defaultHingePolicy": "automatic",
  "allowHingePolicySwitch": true
}
```

### Action presentation is not command authority

- Absent/null `detailActions` preserves legacy handler-defined actions, order,
  and labels. `toJson` omits the property for this case.
- Explicit `[]` displays no action buttons, even if the handler has available
  commands. It is not a security restriction or a change to Aggregate rules.
- An explicit nonempty list supplies order and labels. The Widget intersects
  its IDs with `ResourceViewModel.selectedActions`; undeclared runtime actions
  and configured but unavailable/unknown IDs are not displayed.
- Tapping sends the configured semantic ID, never the label, through
  `ResourceViewModel.performAction` and `ResourceDetailView`. The View checks
  current handler availability again and prevents overlapping actions.
- `ResourceActionHandler.execute` translates that intent to an application
  command. Aggregate/server validation remains authoritative for lifecycle,
  expected revision, and authorization. UI availability is not a substitute.
- Successful commands refresh the detail projection and invoke the configured
  collection-refresh callback. New availability is then reflected in the
  buttons. Errors retain the existing safe message and do not expose internal
  diagnostics. Configuration contains no mutation logic.

These semantics are identical in compact, split, and focused detail rendering.
No collection-toolbar, row-menu, bulk action, editor, or confirmation-dialog
schema is claimed by this initial detail-action subset.

## Navigation schema

Decode an independent object with `ApplicationNavigationConfiguration.fromJson`:

```json
{
  "initialDestinationId": "home",
  "destinations": [
    {"id": "home", "label": "Home", "symbol": "home"},
    {"id": "collecting", "label": "Collecting", "symbol": "folder"},
    {"id": "candidates", "label": "Candidates", "symbol": "lightbulb"}
  ]
}
```

`initialDestinationId` is a required string naming one configured destination.
`destinations` is a required ordered array of at least two objects with string
`id`, `label`, and `symbol`. IDs and labels must be nonblank; IDs must be unique.
Symbols are the framework-defined `home`, `folder`, and `lightbulb`, not arbitrary
Flutter icon names. `ApplicationNavigationShell.pages` must contain exactly the
configured destination IDs. The shell owns selected/visited page state.
The reference app still constructs this typed configuration synchronously;
this JSON example defines the existing decoder target, not a new asset loader.

## Model-to-runtime mapping and ownership

| Model/compiler input | Configuration output | Application/runtime binding |
| --- | --- | --- |
| Read projection and visible properties | `primaryField`, `secondaryField`, ordered `detailFields` | `ResourceDataSource` supplies `ResourceRecord` identity, values, revision. |
| Detail view intents and presentation text | ordered `detailActions` IDs/labels | `ResourceActionHandler` supplies availability and Aggregate command dispatch. |
| Destination identity and presentation | navigation IDs, labels, symbols, initial ID | Application maps each ID to a screen; TFAF renders the shell. |
| Resource collection/detail relationship | one List/Detail configuration | Application binds collection and detail Views to one presentation adapter. |
| Adaptive presentation preferences | dimensions, focus capability, hinge policy | TFAF composes panes; Core supplies device/display regions. |
| Realization selection | `realization` | Application/compiler selects the appropriate implementation. |

Bindings are typed Dart composition today, potentially generated by Cozy later;
there is no JSON-to-service registry or automatic endpoint discovery. For a
standalone presentation, create a `ResourceViewModel` with its data source and
optional action handler. For a shared application view space, create named
`ResourceCollectionView`/`ResourceDetailView` instances in
`ApplicationViewModel`, connect `onActionSucceeded` to the collection's `load`,
then use `ResourceViewModel.fromViews`. Dispose adapters separately from the
application-owned Views. Supply a separate `ResourceListDetailDisplayModel`
when a tab's presentation-session preference must survive navigation.

Resource/view IDs and action IDs are semantic identities chosen by the
application model. Do not derive them from labels, endpoint URLs, Flutter
class names, or device posture. The app's `request-review` binding is an
example, not a framework-specific Candidate rule.

`ResourceListDetail` interprets **only** `framework` realization. Other values
round-trip but must be dispatched by the compiler/application to generated,
hybrid, or custom implementations; they must not be passed to this Widget as
though supported. Those realization-specific builders are not implemented here.

## Compiler checks and acceptance boundary

Before writing an asset, Cozy should validate field/projection keys, unique
action/destination IDs, supported enum values, finite positive dimensions,
navigation page coverage, and action-to-handler bindings. Unknown action IDs
remain safely hidden at runtime, but are a compiler/binding diagnostic, not an
invitation to execute an inferred command. Keep generated configuration and
binding source separate from handwritten application extensions.

`test/resource_action_configuration_test.dart` verifies serialization, legacy
compatibility, action validation, ordering/filtering, configuration replacement,
compact/expanded execution, projection refresh, and in-flight disabling. The
reference app also tests its real Candidate JSON against a fake Aggregate in
both widths and tests configuration asset/bundle replacement.

This handoff documents the implemented TFAF-02/03/04/07 subset. It does not
claim complete UI generation, a server ViewSpace/Aggregate interface, CRUD
screen/lifecycle support, persistent Settings, or Phase 1 acceptance. Physical
posture checks and independent full Phase acceptance remain separate.
