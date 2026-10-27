# Formal CNCF supplied presentation registry

Status: accepted for App ESA5-07 by independent protected Step review on 2026-10-28.
App Phase full review/release remain required.
Controlled local specifications do not establish a live producer Session, native
acceptance, or completion of Step 7 or Phase 5.

## Public contract

`CncfDisplayPresentationRegistry` is a pure configuration resolver for formal
`cncf.display-model.v1` reads. Its constructor requires an independently trusted
`CncfDisplayReadProfile`, a `ResourceListDetailConfiguration`
`neutralConfiguration`, and a `Map<String, ResourceListDetailConfiguration>`
`variants`. These three values are exposed read-only. The profile is already
immutable in Core. Each configuration is copied once through its existing
`toJson`/`fromJson` codec; configuration field/action lists and the stored variant
map are unmodifiable. Repeated resolutions return the same stored configuration
object for the same entry.

Declared variant keys must be nonblank and at most 128 Dart string characters
(UTF-16 code units). They retain their exact spelling, including case, Unicode,
and any surrounding spaces in the declaration. The registry neither trims keys
nor imposes an ASCII or experiment-allocation naming policy. Invalid keys or
configuration declarations throw `ArgumentError` locally. Formal Core admission
still applies its own wire string and context limits before a supplied value can
reach resolution; declaring a key does not weaken those limits.

`resolve(CncfDisplayRead? observation)` returns an immutable
`CncfDisplayPresentationResolution` with read-only `configuration`, `variant`,
`failure` and `isAvailable`. `CncfDisplayPresentationFailure` has exactly
`incompatibleDisplay` and `unknownVariant`.

| Observation | Configuration | Variant | Failure |
| --- | --- | --- | --- |
| No Display yet | Stored neutral | null | null |
| Compatible Display without supported `cncf.presentation/1` | Stored neutral | null | null |
| Compatible exact registered supplied variant | Stored registered entry | Exact supplied string | null |
| Compatible unregistered supplied variant | null | Exact supplied string | `unknownVariant` |
| Display incompatible with the independent profile | null | null | `incompatibleDisplay` |

Availability requires a non-null configuration and no failure. A known supplied
variant with no installed configuration is explicitly unavailable; it does not
silently select the neutral configuration or another variant.

## Formal admission and context responsibility

For every non-null observation the registry re-admits the **complete**
`observation.wire` with `CncfDisplayRead.decode` and its own trusted profile.
Detail admission uses `model.type == detail` and the formal resource's entity ID
as `expectedResourceId`. Only `CncfDisplayReadException` becomes the redacted
`incompatibleDisplay` result. Exception prose and raw wire are never UI messages.

The independent profile pins component ID, resource type, List and Detail screen
IDs, definition revision, semantic contract and provenance. It does not derive
trust from the flattened `ResourceRecord.revision`. Formal string revisions,
context, definitions, resource identity and snapshot information remain on
`CncfDisplayRead` and the existing command contracts.

After admission the resolver inspects only the supported
`cncf.presentation/1.data.variant`. Core admits and carries the generic families
`cncf.locale/1`, `cncf.presentation/1`, and `cncf.display-flow/1`. Locale and flow
are not alternate variant selectors. Unknown optional families and unsupported
optional versions retain Core's inert filtering policy. Core remains responsible
for strict structural decoding, authenticated transport and automatic
`X-CNCF-Presentation-Context` carriage on query, read, mutation descriptor,
Text update, ordinary Business and subsequent safe reads. TFAF and application
widgets do not copy headers or reinterpret flow expiry as a new session policy.

This contract is distinct from the Phase 4 development prototype
`textus.display.prototype.v1`, the prototype `PresentationContext` API and
`textus.presentation.arm`. There is no prototype wire alias, payload conversion,
nominal A/B arm assignment, allocation, random choice, clock, remote lookup, or
experiment policy. The application declares configurations and domain bindings;
an external trusted producer supplies the formal variant.

## Latest successfully projected Display

`CncfDisplayResourceDataSource.lastDisplay` is read-only and starts null.
`listResources` sets it alongside `lastQuery` only after projecting the entire
accepted collection. `getResource` sets it alongside `lastDetail` only after
projecting the entire accepted Detail. Successful accepted completion order
determines the latest Display. Core may retire an older GET when a new read
starts; a superseded read is not accepted or projected and cannot replace
`lastDisplay`. A new explicit query may become the latest Display after successful
acceptance and complete projection. Transport, admission and projection failures
preserve the prior value. Mutation
descriptors and command ACKs never set it. Existing `lastQuery`/`lastDetail`
semantics and flat resource adapters remain unchanged.

## Existing common UI realization

`CncfDisplayResourceView` accepts optional
`CncfDisplayPresentationRegistry? presentationRegistry`. A null registry keeps
the existing caller configuration and behavior. With a registry, the view
resolves `mutationController.source.lastDisplay`, including on notifications
from its borrowed `ResourceViewModel`. Before data it uses the registry's frozen
neutral configuration. A registered variant selects the configuration used by
the existing `ResourceListDetail`, including visual titles, field labels and
the presentation allowlist/labels for trusted ordinary Business actions.

The outer view subscribes to both borrowed controller and VM. Replacement
transfers exactly those listeners, and disposal removes them without disposing
the borrowed VM, layout model, controller, data source, or client. Configuration,
registry, controller or VM replacement resets the retained configuration cache.
Known configuration changes retain the same common child at the same position,
preserving its State, borrowed layout preference and resource selection. Resolving
a presentation never schedules an eager GET or replaces the semantic model.

## Explicit unavailable behavior and commands

An unknown or incompatible presentation keeps the common child mounted using
only its last available configuration internally (or the current registry's
neutral entry after cache reset). A full opaque `Theme.surface` overlay hides
that child. `ExcludeSemantics`, `ExcludeFocus` and `AbsorbPointer` prevent
underlying accessibility exposure, keyboard focus and pointer interaction.
The overlay exposes only:

- `This screen configuration is unavailable.`
- `Reload`, keyed `cncf-display-presentation-reload`.

No variant string, context, credential, raw metadata or server diagnostic is
rendered. Private pre-dispatch guards re-resolve current availability for new
Edit and Business intents, including previously captured callbacks. Business
also respects the current installed presentation allowlist. Existing controller
owner/session, disposed, busy, selection and reconciliation guards still apply.

Explicit presentation Reload validates the current mounted controller/VM owner
and session. It is disabled while busy, disposed, or a VM read is loading.
When reconciliation is required it calls only the existing controller `reload`;
otherwise it calls the current VM `load`. Both are safe GET paths. Recovery never
replays PUT or POST and never adds Navigator ownership or future-driven popping.
An already committed Business still performs its existing post-ACK safe
read/query even if a newer presentation is unavailable. Known receipts survive
reconciliation and do not authorize retrying the command.

An already opened Editor retains its captured formal observation, descriptor,
profile and semantic field/edit bindings until the user completes or cancels it.
A presentation-only change neither discards its draft nor pops its route. Its
existing Save, Cancel and Back rules remain in force. Unavailable presentation
blocks **new** Edit/Business intents; it does not rewrite an existing Editor's
wire definition or block safe post-commit reconciliation.

## Authored executable scenarios and remaining evidence

`cncf_display_presentation_registry_test.dart` covers neutral and exact variant
resolution, List/Detail re-admission, independent source/definition/semantic/
provenance mismatches, unknown policy, defensive configuration/map freezing,
invalid local declarations, superseded older queries preserving newer Detail
and fresh accepted queries becoming latest, projection failures,
failed reads, descriptors and ACKs.

`cncf_display_presentation_resource_view_test.dart` exercises actual common UI
with the existing controlled Core HTTP fixture. It covers first-query visual
selection, compact/expanded common Editor revision 1→2 and ordinary Business
2→3, receipt and fresh stage display, automatic generic family headers, neutral
and legacy paths, installed configuration changes without extra reads, retained
State/layout/selection, opaque unknown behavior, keyboard/semantics and captured
callback blocking, GET recovery, wrong profile, opened Editor ownership,
post-ACK reconciliation, exclusive reconciliation retry, and borrowed listener
replacement/unmount. Optional fixture `presentationContext` decoration defaults
to null and leaves the original local read baselines and old scenarios intact.

At authoring on 2026-10-27 these specifications were not yet validated. The parent owned new
focused specs, analysis/format checks, the existing formal/common mutation and
Business regression suite, downstream declarative App integration, fresh trusted
server Session and native evidence, full Step 7 gates and independent review.
The controlled dates above are structural test data, not live flow authority.
No test execution, server/native run, acceptance, commit, publication or
deployment is established by this document.

## Current validation — 2026-10-28

Parent-owned focused presentation/context specs passed 31 and repository-full
TFAF validation passed 816. Parent-owned analysis/format and affected App checks
are complete (App affected 21 PASS). App-owned `esa5-07-native-002` passed actual
Android integration, readiness and owned cleanup with fresh server Session/
resolver, private bearer, bounded flow and actual-start clock. Common Edit
revision 1→2, ordinary Business 2→3 and automatic read/query realized the supplied
Japanese variant while Core carried actual families. This is App-owned native
integration evidence, not a TFAF-owned server or dependency Phase closure.

Original native001 remains FAIL/exit 1 for a wrong seed-trace oracle despite
limited UI/context/cleanup PASS; only the harness oracle was corrected before
native002. Actual operational trace/correlation identities are distinct from
presentation-flow UUIDs. Controlled spec values remain test data, not live
authority. Private raw evidence stays ignored locally. Independent protected
Step 7 review, acceptance commits, the sole comprehensive App Phase full review
and distinct local release remain pending; no Step or Phase acceptance follows
from these validation results.


## ESA5-07 Step acceptance — 2026-10-28

Independent protected Step conformance passed without blockers, Hygiene or
Development Candidate additions across the complete 25-path/18-program
boundary. The preceding validation-time pending review statements are
superseded by this acceptance record. Actual native002, host 33 and the owning
Core 1331 / TFAF 816 / App 1210 PASS with 3 optional skips / server 774 results
remain the validation basis; native001 remains failed with its stated limits.

ESA5-07 is accepted; its exact local Step commits are the next management
action. All seven Steps are accepted, while the sole comprehensive Phase
review and distinct local Phase release remain required. Phase 5 is still
in progress. No dependency Phase is closed by this App Step acceptance.
