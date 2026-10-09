# Capture image preview

Current status: authored; selected software and native validation pending.

Owner: TFAF, coordinated by PHASE-6/ESA6-02.

Update rule: change this contract through the parent plan; append actual validation
receipts separately. Authoring does not accept the Step or upstream Phase.

`CaptureImagePreview` is exported from the public
`textus_flutter_application_framework.dart` import. Its constructor accepts:

| Parameter | Contract |
| --- | --- |
| `materialId` | Required `String` immutable-original token, compared by value. |
| `sourceIdentity` | Required borrowed opaque `Object` owner, compared with `identical`. |
| `readBytes` | Required `Uint8List? Function()` synchronous validated-byte loader. |
| `imageKey` | Optional `Key?` forwarded to the actual `Image`. |
| `errorBuilder` | Optional `ImageErrorWidgetBuilder?` for real decode failures. |
| `semanticLabel` | Optional `String?` forwarded to the actual `Image`. |
| `maxDecodeDimension` | Positive `int`, default `2048`; bounds both decoded axes. |
| `key` | Optional outer widget key, distinct from `imageKey`. |

The loader runs in `initState` and, where needed, `didUpdateWidget`. A null result
renders `SizedBox.shrink` and retries on the next widget update. The first available
buffer is copied into one private, detached, unmodifiable `Uint8List` snapshot.
The snapshot and provider survive ordinary parent updates, layout changes, text
scaling, history edits and fresh callback closures. Callback equality is not an
identity. Synchronous loader failures propagate through Flutter's error boundary.
Callers must supply validated bytes for an immutable original token; an owner or
material replacement releases the old preview and reads the new one.

The actual `Image` uses `BoxFit.contain` and
`ResizeImage(MemoryImage(snapshot), width: maxDecodeDimension,
height: maxDecodeDimension, policy: ResizeImagePolicy.fit,
allowUpscaling: false)`. Decoding preserves aspect ratio, bounds both width and
height, and never upscales small originals. Changing only the bound reuses the
encoded snapshot while replacing the resize provider. Default 2048 is a
presentation decode bound, not a device memory acceptance threshold or persisted
setting. Encoded originals and full-resolution recognition inputs remain intact.

On bound change, identity replacement and widget disposal, the widget invokes
`evict` on only its privately owned `ResizeImage` provider. Its detached buffer
makes that cache identity private to the preview. It releases its local provider
and snapshot references on identity replacement or disposal. Flutter manages
active codecs and frames. The widget never clears the global image cache, changes
cache limits, maintains a process-global byte cache, attaches source listeners,
disposes borrowed owners, or performs acquisition, storage IO or inference.
There is no new dependency, book policy, global configuration or device preset.

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:textus_flutter_application_framework/textus_flutter_application_framework.dart';

Widget originalPreview(Object owner, String id, Uint8List? Function() read) =>
    CaptureImagePreview(
      key: ValueKey('preview:$id'),
      materialId: id,
      sourceIdentity: owner,
      readBytes: read,
      imageKey: ValueKey('original:$id'),
      semanticLabel: 'Original image',
      errorBuilder: (_, _, _) => const Text('Original could not be decoded'),
    );
```

The [preview specifications](../../test/capture_image_preview_test.dart) author
PV1–PV8 against real PNG decoding, painted `RenderImage`, cache outcomes, snapshot
immutability and owner replacement. Selected validation is pending in the parent.
Source improvements do not establish the cause of the unexplained Sony SIGKILL
or complete physical memory/Save/P8 acceptance.

## Parent original-image preview software receipts — 2026-10-08

Current status: selected software validation passed; updated native acceptance
and independent Step/Phase acceptance remain pending.

Owner: PHASE-6/ESA6-02 coordination; each repository retains its recorded
production responsibility and independent upstream Phase history.

Update rule: append actual native and review results separately. Preserve prior
authoring, failed checks, histories and user edits; no completion checkbox is
changed by these software receipts.

Parent-run normal platform review validation observed:

- TFAF real decoder/render/cache PV1–PV8: 8 passed.
- App selected editor/navigation suites, including APV1/APV2: 44 passed.
- Existing Material editor/local-list consumer suites: 37 passed.
- App's same 17 affected Phase 6 suites: 205 passed.
- TFAF preview plus four affected common consumers: 66 passed.
- App `flutter analyze lib test integration_test test_driver`: no issues.
- TFAF `flutter analyze lib test`: no issues.
- App, TFAF and Core `git diff --check`: exit 0.

Initial failures remain recorded: 42 passed/2 failed for invalid new fixture
choice 1.2; then 43 passed/1 failed for a Save-read expectation; and the first
17-suite run had 203 passed/2 failed for old direct MemoryImage casts. Frozen
repairs 41–43 use valid existing multiplier 1.3, assert zero added original IO
through typing/scaling while preserving both existing Save integrity reads per
original, and unwrap ResizeImage in four existing consumer byte assertions.
All exact encoded-original, provider stability, history and capture/inference
assertions remain. Each repair converged; earlier repair/review history remains.

These are affected software checks, not whole-App aggregate validation, native
memory evidence or release acceptance. Core production, stored originals and
full-resolution recognition inputs remain unchanged. The Sony SIGKILL cause is
still unknown. This slice installed no new APK and performed no updated native
Save/COLD test. Sony's last observed state was secure lock with screen off; the
existing unlock request is pending. Updated native proof, standard configuration
restoration, remaining negative cases including camera denial, independent
acceptance, release validation and separate commits remain due. Phase 6.1 has
not started; the original Goal, authority, bases, epoch and counters are retained.

## Parent original-image preview Sony native receipts — 2026-10-08

Current status: the updated common preview passed the observed Sony original-image,
fresh Save acknowledgement and same-install COLD restoration route. Complete
ESA6-02 physical/independent acceptance and Phase release remain pending.

Owner: PHASE-6/ESA6-02 coordination. Core retains full-resolution original and
recognition ownership; TFAF owns display preview; App owns book mapping/review.
Each upstream repository retains its own Phase history.

Update rule: append actual scoped results, preserving earlier pending statements,
failed attempts and user edits. These receipts change no acceptance checkbox.

Sony SO-52D on Android15/API35 was unlocked and the desired recognition setting
was restored through common Settings to androidStandard, with painted Changes
saved and persisted setting evidence. One preserving install-r of the normal
lib/main.dart debug APK returned Success; no uninstall or data clear occurred.
Both earlier saved Drafts remained visible. The second Draft ID was
`0f256e428b60ee674cde2546e82a4714`, retaining original
`e981a7909eb5b18e2b5c8ba8094e7b7745ce318a489c38143be2c09dbc71668a`
(JPEG2790558bytes) and comparison `9d0aa6e9dcce1ab1d6ea7fc9096ace16`.

Actual editor typing temporarily changed section7 to70 and restored it to7;
70 was never recorded or saved. The device relocked before restoration could
initially be visually confirmed; after human unlock the painted field was7.
The selected-original and evidence-original previews painted the retained cover.
Saving once then scrolling directly to the status, without leaving/reloading the
route, painted Draft saved. The same live process was10835. The saved schema2
Draft updated at2026-10-08T03:10:04.953638Z with title `窯変源氏物語`, section7,
empty ISBN, one original and one image element. Existing title history remained1;
flushing the temporary section edit appended a second manual section7 entry with
empty material links. Both entries are retained; unchanged history counts are not
claimed. Raw recognition review and original provenance remain separate.

A deliberate own-App force-stop followed by COLD launch of the same installation
returned Status ok (TotalTime3319ms, WaitTime3323ms), changing process10835 to12801.
There was no APK installation between Save and restart. Actual Home, Material
List, Material Detail and Edit Material restored the same second Draft ID, title,
section7, saved timestamp, both section histories, original metadata/image and
review lineage. Editor retained the historical desired pixelEnhanced comparison,
actual androidStandard/ML Kit1778ms and explicit Nano providerUnavailable reason
AICore reports the feature unavailable; Nano was not executed. Current common
Settings restored Standard Android, with no unsaved settings. The App remained
process12801 during this bounded restore route; no unexpected exit was observed.

During pre-Save original painting, own-process debug meminfo observed PSS332083kB,
RSS422036kB, graphicsPSS83224kB, GLmtrack13500kB and nativeheapPSS29987kB. The earlier
pre-preview debug observation was PSS432934kB/RSS517668kB and graphicsPSS179688kB.
These are different debug snapshots with different lifecycle histories, not a
controlled benchmark, a numerical pass threshold or proof of the earlier SIGKILL
cause. Core production, original files and full-resolution OCR/Nano inputs remain
unchanged. The earlier unexplained exit and absent initial P8 Save acknowledgement
are retained; this new Save/COLD proof does not retrospectively establish them.

The updated Sony route and final standard configuration restoration are now
observed. Camera denial and identical duplicate-proposal selection remain
physically unobserved. Full P1-P8/Step02/Phase acceptance, independent review,
separate commits and upstream release validation are not claimed by this append.
Phase6.1 has not started. Original Goal, authority, bases, ledger14, epoch1 and
repair counts remain: prereview43, Step02/Phase0, Step03 consumed1, Step05 0,
nonconverging0. This factual M0 projection consumes no logic repair or review.
