# Generic photo role capture panel

Recorded: 2026-10-08. Scope: PHASE-6 / ESA6-02 / ESA6-02-PHOTO-A.
Current status: public UI and executable specifications authored; parent selected
validation and independent acceptance pending. Existing repository history remains.
Owner: TFAF common presentation; App supplies role meaning and commands.
Update rule: append actual validation and acceptance results, retaining the
authored contract and prior evidence.

`PhotoRoleCapturePanel`, exported by the public application-framework library,
borrows App-supplied role IDs, labels, guidance, attached image snapshots and
callbacks. Primary `roles` always appear; `additionalRoles` are available behind
Additional photos. Combined role IDs must be unique. `PhotoRoleCaptureItem`
snapshots its images. `PhotoRoleCaptureImage` carries an exact original token,
borrowed `sourceIdentity`, synchronous `readBytes`, use selection, independent
read/recognition labels and optional observed error description. It owns no IO,
byte cache, controller, provider, App vocabulary or storage authority.

Each role shows its label and Captured (N photos) or Not captured. Counts come
from attached image references regardless of read/decode/recognition success.
Thumbnails use the existing borrowed `CaptureImagePreview`, bounded to512 on
both decode dimensions without upscaling. Layout wraps thumbnails/actions and
supports narrow viewports and large text. Inspect is a local expansion only and
shows original token, selected checkbox, read/error/retry, recognition label and
an explicit role dropdown with the combined supplied choices.

Capture and Add call `onCapture(roleId)`; Retake calls `onRetake(roleId)`. The App
keeps old originals and chooses how to confirm a role request. Selection calls
`onSelectionChanged(materialId, selected)`, correction calls
`onRoleChanged(materialId, roleId)` and read retry calls
`onRetryRead(materialId)`. Missing callbacks disable their controls.
`interactionEnabled`, `captureSupported` and `readOnly` guard domain mutation.
Read-only retains Inspect and explicit read/local decode retry, while capture,
add, retake, role and use edits are disabled. Decode failure is a visible actual
decoder label; Retry preview recreates only that preview without clearing the
global ImageCache. Build/Inspect/scale/selection initiate no storage or inference.

Stable public keys are `photo-role:<roleId>`, `photo-role-capture:<roleId>`,
`photo-role-add:<roleId>`, `photo-role-retake:<roleId>`,
`photo-role-inspect:<roleId>`, `photo-selected:<materialId>`,
`photo-correct-role:<materialId>` and `photo-read-retry:<materialId>`.

The legacy `PhotoCapturePanel` captures `onComparison` at operation start. The
same mounted/generation/controller-identity checks still suppress detached or
replaced-owner completion. A same-controller rebuild with a new callback cannot
redirect the already started result. The App binds its operation role in that
callback and retains it beside pending adoption state for retry.

Executable specifications cover exact supplied IDs, counts despite read failure,
actual bounded decoder painting, narrow/large text, read-only controls, local
decode retry, immutable image snapshots, duplicate choices and held public
service callback replacement. Results are pending parent execution. Book field
priorities and role/target-aware recognition integration remain App and later
in-Phase Slice B contracts.
