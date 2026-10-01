# Application text presentation consumer contract

TFAF-S05 adds opt-in presentation over the accepted Settings catalog and borrowed
`SettingsView`. The finite common text choices remain Standard `1.0`, Larger
`1.15`, and Largest `1.30`. This contract changes presentation only; persistence,
intent, Resource Views and the S04 pane/hinge resolver retain their accepted
contracts. S05 is ACCEPTED at `13c5fcf3ae76ebb2da8a1f267b05a2b5b34c439a`. Parent focused validation passed 18 presentation
cases and 241 accumulated tests, with scoped analysis/formatting clean.
Independent S05 review found one missing semantic navigation activation; its
bounded repair and focused independent re-review resolved CB-TFAF-S05-01.
The exact Step acceptance commit above records the reviewed implementation.

## Public API and application placement

The public package exports `composeApplicationTextScaler` and
`ApplicationTextScaling(view: ..., child: ..., key: ...)`. S06 also exports
`applicationTextAppBar(context, title: ..., width: ..., leading: ..., actions: ...)`
so application-supplied toolbar titles can use the same wrapping/scrolling and
full OS-aware scaler. It requires the enclosing opt-in boundary and the actual
available toolbar width. Editing Studio uses it for Home and Book Capture.

```dart
MaterialApp(
  builder: (context, navigator) => ApplicationTextScaling(
    view: settings,
    child: navigator!,
  ),
  home: applicationHome,
);
```

The same builder placement applies to `CupertinoApp` and an app using Router:
wrap the provided Navigator/Router child below the ambient `MediaQuery`. The
boundary must be above app routes and their overlays so existing screens,
`showSettings`, native choice/reset modals and newly opened routes observe the
same effective text presentation. Placement in an individual page cannot provide
that app-wide guarantee. Existing applications opt in through composition;
constructors and behavior without an opted-in scope remain compatible.

For an original logical font size `s`, current OS function `S` and catalogued app
choice `m`, the only rendering equation is:

```text
effective.scale(s) = m * S(s)
```

The helper validates `m` through the actual common finite definition. It calls
the OS function with the original `s`, never `S(m * s)`, and never approximates
nonlinearity with a constant ratio. `m = 1.0` returns the original OS scaler.
For the nonlinear fixture `S(s) = s + 0.5 * min(s, 16)`, `S(16) = 24` and
Largest yields `31.2`. Its deprecated `textScaleFactor` is a compatibility
estimate only; presentation calls `scale` with each role's logical size.
Recomposing the helper's own wrapper replaces its former app choice rather than
multiplying it again. It neither clamps OS output nor caps accessibility size.

## One authoritative borrowed View and live environment

`ApplicationTextScaling` requires the actual registered common text definition,
reads the immutable current snapshot directly, and observes its borrowed View
with a stable child. A same-View nested boundary reuses the original OS and
effective scaler; its own ambient `MediaQuery` changes only the text scaler.
A different nested View throws `ArgumentError`, because an app presentation
scope has one authoritative Settings View. Missing or forged same-ID definitions
also reject. The helper's ordinary Dart equality is presentation value equality,
not a workflow control hash.

Root OS changes recompute against the current app preference. Replacing the root
View detaches the old observation and observes the new View. Unmounting detaches
observation. No constructor, rebuild, nested scope or OS-only update loads, edits,
resets, saves or disposes a View, service or storage. Composition owns explicit
restoration and disposal after every borrowed consumer detaches. No OS scaler is
cached globally and no Settings snapshot is copied into presentation ownership.

`ApplicationTextScaling.maybeTextScalerOf(context)` returns the scope's full
effective scaler, or null outside opt-in. TFAF text consumers use it where Flutter
native chrome introduces local clamping or preadjusted styles; logical font sizes
remain unchanged. Body text ordinarily inherits the root `MediaQuery` scaler.

## Framework chrome and native modal roles

Opted-in Resource and Material Settings toolbars retain native `AppBar` actions,
tooltips and back callbacks. Their title uses the unscaled theme title style and
full effective scaler, with wrapping measured after actual leading/action
reserves. The toolbar grows from 56 logical pixels. Its title viewport is bounded
by `max(56, 0.35 * usable viewport height)` and scrolls vertically when a complete
title requires more room. Text is never shrunk, fitted, capped or ellipsized.
The Resource body's existing viewport observer consumes the resulting chrome
geometry; its S04 resolver/session/hinge algorithms do not change.

Opted-in Cupertino Settings uses an opaque `ObstructingPreferredSizeWidget`,
native `CupertinoNavigationBarBackButton` on the nearest Navigator, and the
standard unscaled navigation-title style with full scaling. Its wrapping title
grows from 44 and follows the same 35 percent bound/scroll policy. SafeArea and
the actual preferred height inform `CupertinoPageScaffold`; the native
scaffold's text suppression does not flatten the explicitly supplied title
scaler. No new Navigator or service is introduced. `CupertinoApp` requires no
Material ancestor for the explicit Cupertino presentation.

Opted-in bottom navigation uses equal-width destination cells on a Material
SafeArea surface, preserving configured order, icons, selection callbacks,
Tooltip and selected/button semantics. Labels retain unscaled selected/unselected
`NavigationBarTheme` styles (falling back to `labelMedium`), wrap completely and
receive the full effective scaler. Icons stay 24 logical pixels; label separation
is 8 and vertical padding is 8. The surface grows with intrinsic label height
and scrolls the full destination row vertically beyond
`max(48, 0.35 * usable viewport height)`. It does not recreate visited pages or
change their IndexedStack keys and state. Outside the scope the existing native
`NavigationBar` branch remains the consumer.

Settings keeps its native controls, choice/reset surfaces and existing body
scrolling. Every opted-in modal text role resolves the live scope inside its
own Builder, preserving native styles, colors and weights while restoring the
original logical role size when Cupertino preadjusts it. Cupertino action-sheet
actions use 21, action-sheet title 13, reset title 17, reset content 13 and reset
actions 16.8 logical pixels. Material uses its actual unscaled native role style.
Inherited one-line styles are reset where required for full wrapping. Already
open modals recompute for both live OS and app changes. A captured scaler outside
the modal's observing Builder is not the contract.

The opted-in Material SimpleDialog keeps its native title style and options.
Its complete title scrolls within a viewport bounded to 35 percent of the
nonnegative available dialog height: screen height minus safe padding, keyboard
view insets and the default 48 logical pixels of vertical dialog inset. Native
options retain their independent scroll area. The opted-in Material reset
AlertDialog uses native scrollable title/content while its Cancel and Reset
actions remain reachable outside that area. Neither modal shrinks text or
changes logical role sizes; without the app text scope, legacy layout remains.

Native modals retain the nearest Navigator and captured View/definition guards:
Cancel/back/dismiss causes no intent; one confirmed reset creates one intent;
stale completions cannot edit a replacement View. Route completion is a pop,
not save acknowledgement. “Changes saved” still depends on the accepted
ready/idle/unsaved-state rules. Standard remains reachable through wrapping and
scrolling at Largest plus enlarged OS text.

## Nontext and resource ownership

Text-driven wrapping and chrome growth can change available body space. The app
multiplier never scales icons, images, padding/insets, Core display features,
physical hinge gaps, pane minimums or configured breakpoints. Nontext geometry
and all other `MediaQuery` fields remain unchanged at the common boundary.

Resource collection/detail View identities, selections and action authority
remain owned by the same application View space. Text changes cause no resource
load or domain command, clear neither pane nor hinge session override, and retain
compact intent and inactive-page state. Existing S04 eligibility and
excluded-gap rules use the measured safe body, including changed chrome height.
Settings storage/codec/controller implementation, finite schema, acknowledged
durability and reset/intent sequence are unchanged.

External custom Widgets inherit the scaler but remain responsible for their own
layout and any local text clamps or fitted text. Custom chrome can explicitly
read `maybeTextScalerOf` while preserving logical role sizes. Applications own
their builder opt-in and real adapter composition; they do not copy the common
Settings implementation.

## Authored assurance matrix and limits

| Scenarios | Authored behavior |
| --- | --- |
| TS01/TS02 | All choices with default, linear-two and nonlinear OS functions; original logical inputs; documented 31.2 result; invalid catalog/nonfinite rejection; replacement composition |
| TB01 | Same-View nesting, different-View rejection, unchanged physical MediaQuery fields and fixed icon/image sizes |
| TB02/TB03 | Actual rendered live OS/app changes, observation rebinding/unmount, borrowed lifetime, forged/missing catalog rejection and no presentation I/O |
| TB04 | Explicit controller load of invalid text wire data, Standard fallback, valid sibling/unknown retention and no read-caused default write |
| TP01/TP02 | Actual navigation, two Resource tabs and Settings routes; all choices/default/enlarged/nonlinear OS; compact/expanded/live changes with retained Views, sessions and query/action counts |
| TP03 | Long full Resource/destination/action labels at 320 x 568 and 640 x 360, measured bounded chrome, scroll fallbacks and reachable interactions at Largest plus OS two |
| TP04/TP05 | Material and standalone Cupertino Settings, Standard/extension/reset/Cancel, bounded full-size Material title with actual scroll to later words, native reset scrolling, reachable physical action taps, live open modals, numerical native role scales and nearest-Navigator authority |
| TP06 | Both hinge axes, unchanged physical gaps and safe body regions with retained selections/session choices |

Parent focused validation executed the representative presentation suite (18
passed) and the legacy-consumer/scaler/boundary accumulator (241 passed) on the
S05 candidate, with scoped analysis, formatting and diff integrity clean.
Independent S05 review and focused repair closure resolved CB-TFAF-S05-01;
the implementation is accepted at the Step commit above. S06 supplies separately
committed real local storage, application composition and Android/iOS/Web
restoration evidence; controllable storage alone proves no durability.
The one comprehensive Phase review and documentary closure check pass, and
the exact final framework driver passed clean analysis and all 276 tests.
See the [Phase completion record](../journal/2026/10/2026-10-01-phase-2.1-completion.md).
