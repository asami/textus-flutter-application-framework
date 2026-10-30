# Common media actions for Web and tablet

Decision date: 2026-10-31
Status: accepted direction; implementation/acceptance pending

Web and large native tablet/Fold use the same screen/action composition. Render
media actions from the [Core media capability contract](../../../textus-flutter-core/docs/spec/media-input-capabilities.md),
not platform-name conditions in an application widget. Device availability can
vary without hiding or moving the basic actions.

| Action | Presentation |
| --- | --- |
| 画像を取り込む | Primary image-input action using the available file/photo picker; independent of camera/microphone state |
| 撮影する | Enabled when capture is usable; an explicit action may request permission when requestable; known unavailable capture is disabled with reason |
| 録音する | Uses microphone support/device/permission state in the same way, independently of camera state |
| 再生する | Enabled for playable content and supported playback; user initiated, never dependent on a microphone grant |

Known unsupported adapter, absent hardware, denied/policy-blocked or busy states
show an appropriate explanation. Keep disabled commands visible in the same
location; provide text/details accessible by touch and keyboard as well as
pointer, not only a tooltip on a disabled control. Offer applicable settings
guidance or retry without looping permission requests.

Unknown/requestable is not known unavailable. Provide a visible 「利用を確認」
or equivalent explicit action so the user can resolve availability/permission;
do not disable every route to permission and trap the user. A pending check may
temporarily disable capture while displaying progress. Preserve the distinction
between unknown, hardware absence and denied access in user-facing explanations.

Selecting an image opens the common preview/attachment flow; cancellation does
not discard the current work. Failed capture/permission does not disable import,
reference browsing or text editing. Layout/mode/posture changes never request
permissions or start recording/playback. Raw OS/browser APIs live in Core.
App supplies domain labels, association targets and submission intent, not a
second capability/permission implementation.

## Phase 8 full input

Add explicit image paste and drag/drop as additional entrances to the same
preview/attachment flow, plus multiple-image selection, upload progress and
targeted retry/status. Visible picker/paste actions remain available where
supported; dragging or keyboard shortcuts are not the only entrance. Consume
Core's actual input capabilities and outcomes; preserve existing work on cancel
or unsupported clipboard content. This is App Phase 8 ESA8-06, not a Phase 7 gate.

## Acceptance

- Web and tablet/Fold share action order and behavior; capability state changes
  enabledness/reason, not a separate page or `isWeb` capture prohibition.
- Image import remains usable with no camera, denied microphone or unsupported
  capture adapter. Preview/cancel/save behavior is understandable.
- Allowed/unknown/requestable/blocked/absent cases map to meaningful controls,
  with accessible reason and recovery access; no silent disabling on unknown.
- Selected native Fold and Web consumer scenarios preserve current work through
  mode/size changes without permission prompts or automatic media activity.

Delivery: [shared media UI plan](../phase/media-input-actions-plan.md).
