# Adaptive List/Detail Display Model

Date: 2026-09-29

Status: width, full-span content regions, and selectable hinge policy verified by full Flutter tests and fresh parent review; physical-device transition acceptance pending

Owner: TFAF application-level presentation and adaptive layout

Phase: [TFAF Phase 1, TFAF-05](../phase/phase-1.md)

## Purpose

Define one reusable display model for a semantic Resource List + Resource
Detail relationship. Applications supply Views, bindings, and declarative
presentation configuration; TFAF owns adaptive composition and the display-mode
interaction. This is not an Editing Studio or Fold-specific screen model.

The reference-application requirement is to keep the selected resource when a
compact detail screen gains enough space, then show the list on the left and
that detail on the right. A user may also explicitly focus the detail across
the available content area when a two-pane presentation is possible.

## Separate state dimensions

The model separates four concerns:

1. Semantic View state: collection, selected resource identity, and its detail
   projection. Changing layout must not replace this selection or dispatch a
   domain command.
2. Layout capability: whether the current usable display regions can support
   List + Detail side by side or above/below under the configured constraints.
3. Presentation preference: split presentation by default, or detail-focused
   presentation explicitly requested by the user in a split-capable layout.
4. Hinge policy: automatic, avoid, or span, independent of split/detail focus
   and compact navigation. An explicit session choice survives size/posture
   changes without becoming semantic View or Aggregate state.

Presentation preference belongs to the client-side presentation session, not
to the Resource/Aggregate or a server ViewSpace contract.

The public runtime contract is `ResourceListDetailDisplayModel`. It stores
`ResourceListDetailDisplayPreference` (`split` / `detailFocused`) and a separate
compact-detail request; `resolve` returns `ResourceListDetailPresentation`
(`compactList` / `compactDetail` / `split` / `detailFocused`) from current
capability and selection. `openDetail` and `showList` govern compact navigation;
`focusDetail` and `restoreSplit` change the expanded preference. Resolving a
layout does not mutate semantic Views or retain device posture as state.

The public `ResourceListDetailHingePolicy` enum has stable JSON names
`automatic`, `avoid`, and `span`; unknown names throw `FormatException`.
`hingePolicyOverride` is nullable until `setHingePolicy` stores an explicit
session choice. `resolveHingePolicy(hasOcclusion:, defaultPolicy:)` purely
resolves override, then configuration, then automatic avoidance of positive
physical gaps or spanning of zero-thickness folds. Resolution does not notify
listeners or save device-derived state; repeated setters do not notify.
The setter never changes focus preference or compact-detail intent.

`ResourceListDetail` accepts an optional application-owned `displayModel`.
Without one, the Widget owns and disposes its default model; it never disposes
a supplied model. `ResourceListDetailConfiguration.allowDetailFocus` is an
optional Boolean JSON field, defaulting to `true` for existing configurations.
Optional `defaultHingePolicy` and `allowHingePolicySwitch` default to
`automatic` and `true`. Existing JSON and constructor calls remain valid.

## Capability, not device posture

Two-pane eligibility is determined by usable layout constraints and display
regions, not a device model, platform name, or a Boolean folded/open flag.
Tablet windows, desktop windows, rotation, split-screen sizing, and Fold
expansion use the same rule.

TFAF consumes Core's display-feature/region primitives and combines them with
the presentation's available width/height, safe areas, and minimum pane sizes. A
large device does not imply a large application content region. A separating
hinge must not be counted as usable pane width under `avoid`, and both
resulting panes must be viable before that split presentation is eligible.

The existing `compactBreakpoint` (700) and `minimumFoldPaneWidth` (280) retain
their logical-pixel units and defaults. The optional `minimumFoldPaneHeight`
defaults to 180 for old JSON configurations. Both clipped panes must satisfy
the minimum width and height. A horizontal fold can therefore use stacked
panes even when the full width is below the ordinary width breakpoint.

With an intersecting separator, `span` eligibility instead uses the actual
safe body's width (at least two minimum-width panes plus the one-pixel divider)
and minimum height. Spanning split uses an ordinary horizontal Row; its list
width is at least the configured pane minimum while leaving the same minimum
for Detail. Without an intersecting separator, the existing breakpoint and
35% list-width Row remain unchanged, with the hinge override retained latently.

The standard AppBar `ヒンジの扱い` menu is independent of focus/selection. It
offers checked `ヒンジを避ける` / `ヒンジをまたぐ` items, disabling a choice
whose composition is not viable. The menu requires an actual separator in the
measured body, `allowHingePolicySwitch`, and at least one viable two-pane policy.
This allows an asymmetric avoid-compact layout to recover by choosing viable
span. If neither is viable or no feature intersects, it is hidden. Automatic
is a configuration/model value, not a third visible menu choice.

For a positive physical gap the span item, and the tooltip while span is active,
warn `ヒンジ部分では内容が隠れる場合があります`. Span deliberately permits
occlusion; it does not promise readable pixels at the hinge. Zero-thickness
folds do not need this warning. No banner or chrome-height change is introduced.

## Visible modes

### Compact / insufficient space

- Present List and Detail sequentially: List -> Detail -> List.
- Detail occupies the available content region because two panes are not
  viable. This is ordinary compact navigation, not a request for the
  detail-focused preference.
- Under `avoid`, List or Detail uses the largest nonempty
  continuous region instead of spanning the gap; a tie selects the leading
  region, including zero-thickness folds. If no content region remains, the
  body is empty safely. Under `span`, compact content uses the full safe body.
- Do not expose a split/detail-focused toggle or redundant full-screen control
  in this layout. The independent hinge menu follows its viability rule above.
- Keep the selected resource identity independent of route realization.

### Split-capable / sufficient space

- The default presentation is List on the left and Detail on the right;
  under `avoid`, a horizontal separator places List above and Detail below.
  `span` retains ordinary left/right composition for either separator axis.
- Keep the selected resource visible in the detail pane; without a selection,
  the detail pane shows the standard selection placeholder.
- Offer a detail-focused action when a detail is selected. It expands that
  detail across the available content area and hides the list.
- Offer a restore-split action in detail-focused presentation. It restores
  List | Detail with the same selected resource.
- The full-screen meaning here is content focus, not OS-level immersive mode.
  Honor safe areas in both presentations; explicit spanning may cross physical
  occlusion with the warning above.
- Under `avoid`, focused Detail uses the trailing continuous region (right or
  bottom), even for a zero-thickness crease. Under `span`, focused Detail uses
  the full safe body. Automatic resolves positive gaps to avoid and
  non-occluding folds to span; an explicit choice wins.

## Size-change and preference rules

Opening a detail in compact layout never sets the detail-focused preference.
Therefore, a compact detail screen that becomes split-capable must reveal
List | Detail by default rather than leaving a compact detail route over the
expanded composition.

An explicit detail-focused choice is different from compact navigation. Keep
that choice within the current presentation session when space temporarily
shrinks; hide its controls in compact layout and honor the remembered choice
when split capability returns. Initial preference remains split. This does
not require cross-session persistence.

Changing hinge policy leaves the selected resource, compact-detail request,
and explicit split/detail-focus preference unchanged. Focus/restore likewise
leaves the hinge policy unchanged. Applications can supply separate display
models to isolate presentation-session state across resource tabs.

| Current presentation | Event | Result |
| --- | --- | --- |
| Compact list | Select resource A | Compact detail A; preference remains unchanged. |
| Compact detail A, default preference | Region becomes split-capable | List on the left, detail A on the right. |
| Split with detail A | Request detail focus | Detail A fills available content; list is hidden. |
| Detail-focused A | Restore split | List on the left, detail A on the right. |
| Split or detail-focused A | Region becomes compact | Compact detail A; mode controls are absent. |
| Compact detail A after an explicit detail-focus choice | Split capability returns | Detail-focused A; restore-split control is available. |

Framework route and pane realization must obey these transitions. Do not
leave duplicate detail pages, stale overlay routes, or a second selection
owner merely to implement the adaptive switch. Mode changes preserve the
same View bindings and their loading/action/error state rather than recreating
domain state. A missing/deleted selection must use the normal no-selection
handling rather than forcing an invalid detail-only presentation.

## Ownership and configuration

- Core owns low-level display features and region geometry.
- TFAF owns capability resolution, presentation and hinge preferences,
  compact-to-split reconciliation, and standard focus/restore/hinge interactions.
- Applications own resource Views/bindings and declarative configuration;
  they must not implement a private Fold route-pop or a custom List/Detail
  Widget to obtain this standard behavior.
- Cozy's UI Model can express the List/Detail relationship, adaptive policy,
  default split intent, and optional detail-focus capability without encoding
  Flutter Navigator or Widget structure.
- Focus/restore are presentation actions, not Resource mutation actions or
  Aggregate commands. They do not require REST, CRUD, or CNCF Phase 95.

## Implementation and acceptance work

The implementation now uses one adaptive Scaffold rather than pushing an
independent compact detail route. Both reference-app resource tabs provide
separate display models and consume the same framework Widget. Compact back
returns to the list without clearing selection; inactive tabs do not intercept
the active route's back handling. Layout changes do not reload the resource
Views or dispatch Aggregate commands.

Focused verification and the reported physical-device path must be recorded
separately. This implementation does not close TFAF Phase 1 or reopen the
reference app's completed Phase 2 fake-driver milestone.

The initial implementation is verified by focused executable specifications:

- [x] Selecting a detail in compact layout and increasing usable width reveals
  the list and the same selected detail without an overlay route.
- [x] Detail-focus and restore-split controls work only in split-capable layout.
- [x] Compact navigation never implicitly changes the expanded preference.
- [x] Shrink/grow transitions preserve selection and an explicit preference,
  while keeping mode controls absent in compact layout.
- [x] Back navigation remains consistent without duplicated detail pages.
- [x] Vertical hinge-separated regions use the same capability policy and reject
  undersized panes; non-fold width changes exercise the same semantics.
- [x] Both Editing Studio fake resource bindings consume the shared behavior
  without application-owned standard List/Detail Widgets.
- [x] Under avoidance, full-width horizontal hinges stack viable panes
  above/below the gap; focused and compact fallback content occupies a
  continuous region, including explicitly avoided zero-thickness folds.
- [x] Actual body offsets, safe areas, and bottom navigation are excluded from
  pane size and included in screen-coordinate alignment.
- [x] Orientation changes preserve selection/focus without additional Resource
  queries; separators merely touching the body edge leave ordinary layout.
- [x] Both separator axes and thicknesses support an independent avoid/span
  choice; focused detail and restored split retain that choice and selection.
- [x] Menu check/enablement and occlusion warnings follow policy capability;
  viable span can recover an asymmetric avoid-compact layout.
- [x] Explicit configuration and legacy JSON round-trip with compatible defaults;
  pure resolution and repeated setters do not create redundant notifications.
- [x] Both actual resource tabs preserve independent policy across shrink/grow
  and orientation; spanning at 640 pixels retains two minimum-width panes.

Use focused executable specifications for state transitions and route/pane
composition, plus the reported real-device path (open a detail, then expand
the Fold). Broader production-device acceptance and transport integration
remain separate work.

On 2026-09-29, the framework's selected display-model, adaptive, List/Detail,
navigation, and View-space suites passed 34 tests. The reference app's selected
adaptive, app, driver, aggregate, and Book Capture suites passed 22 tests.
Framework analysis found no issues; app analysis retained two pre-existing
Book Capture deprecation infos. The original compact-detail resize regression
failed before implementation and passed on this tree. Real fold/unfold visual
confirmation of this new implementation is still pending.

The successor full-span horizontal-region extension passed the full Flutter
test suites: Core 25, TFAF 47, and Editing Studio 31 tests. Core and TFAF
`flutter analyze` found no issues; Editing Studio
`flutter analyze --no-fatal-infos` passed with the same two pre-existing Book
Capture infos. Both resource-tab integration checks inspect complete scroll
regions, the exact global gap, and exclusion of bottom navigation. Parent fresh
focused M2 re-review resolved the fixture and viewport-edge defects; this is
not an independent Phase full review or physical-device posture acceptance.

The selectable-policy successor passed focused framework tests (42) and the
actual-app adaptive suite (9), followed by full final Flutter suites: Core 25,
TFAF 59, and Editing Studio 34. The final app run includes explicit 640-pixel
span checks for minimum pane widths and navigation exclusion. Core/TFAF analysis
is clean; the app retains only the same two existing nonfatal Book Capture
infos. Fresh parent review covered the public model/configuration, capability
and menu contracts, geometry/composition, lifecycle/query ownership, and app
integration specifications. No repair batch, commit, Phase closure, or new
device installation is implied by these results.

### Region geometry and bounded extension

Core's `SeparatedDisplayRegions` exposes left/right or upper/lower rectangles
and their separator in full Flutter-view coordinates. TFAF measures the actual
SafeArea body after AppBar, ancestor offsets, and bottom-navigation constraints,
then clips Core geometry to that viewport. It does not treat a screen-space
hinge Y coordinate as a body-local offset. Content painting is held while a
changed viewport is unmeasured, avoiding an initial or resize frame with an
incorrect unapproved composition. Measurement callbacks are post-frame and do
not query Resource Views. Avoid excludes the recognized separator; span
deliberately crosses it without changing measurement ownership.

The `split` preference/presentation covers both side-by-side and stacked
composition; rotation does not create a second semantic selection or preference.
The original `SideBySideDisplayRegions` API remains vertical-only for backward
compatibility, while TFAF consumes the generalized companion API.

This slice handles the first relevant full-span fold/hinge separator, in ordinary
axis-aligned, translation-only widget placement. General multiple/partial-feature
partitioning and externally scaled/rotated subtrees are deferred. The content
viewport is partitioned; AppBar/navigation chrome is not relocated around an
unusual separator crossing that chrome. Applications must not supply private
hinge-offset workarounds. Focused extension verification is recorded separately
from physical-device posture acceptance.

## References

- [Architecture notes](architecture.md)
- [TFAF Phase 1](../phase/phase-1.md)
- [Initial architecture journal](../journal/2026/09/2026-09-27-configuration-driven-ui-framework.md)
