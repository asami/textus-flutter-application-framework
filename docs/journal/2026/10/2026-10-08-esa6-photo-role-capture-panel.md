# ESA6 generic role photo UI authoring

Recorded: 2026-10-08.
Identity: PHASE-6 / ESA6-02 / ESA6-02-PHOTO-A.
Current status: bounded public UI/specification authoring; parent validation,
focused independent review and acceptance pending.
Owner: TFAF common interaction/presentation; App supplies book meaning/commands.
Update rule: append actual results later, retaining this repository's existing
Phase histories, previous receipts and architecture work.

The public exported PhotoRoleCapturePanel and immutable presentation values accept
App role IDs/labels/guidance and attached original snapshots. They display role
counts, bounded thumbnails, local Inspect, selection, role requests and separate
read/recognition labels. Capture/Add/Retake callbacks return the clicked generic
role ID. Read-only disables domain mutations while retaining inspection and
explicit read/local decode retry. The panel owns no service, storage/native IO,
App enum, book field priorities or new image cache.

Legacy PhotoCapturePanel captures its comparison callback at operation start,
retaining existing mounted/generation/controller checks. Same-owner rebuilds
cannot redirect completed acquisition; owner replacement/detachment still
suppresses callback delivery. Actual held public-service and widget decoder
specifications are authored. No validation command or native operation is
represented by this record.

The public contract is detailed in
[Photo role capture panel](../../../notes/photo-role-capture-panel.md).
App persistence, explicit confirmation and role/use events remain App authority.
Generic role/target operation context needed by integrated recognition is a later
ESA6-02-PHOTO-B requirement, frozen separately before editing. Complete ESA6-02
review/native acceptance and the Phase release remain due.

## Parent selected Slice A validation — 2026-10-08

PhotoRoleCapturePanel／PhotoCapturePanelの代表2スイート14件と、preview・controller・facade・ResourceListDetail lifecycleを含む影響範囲6スイート72件が成功した。TFAFのlib/test静的解析と差分チェックも成功した。Appの代表写真UI50件は成功したが、20スイートの影響検証には4件の互換性修正が残り、親が別の限定修正を確定した。TFAFのプログラム変更はその修正に含まれない。

Current status: software evidence recorded; App repair revalidation、Slice Bの汎用operation context、更新後実機確認、complete ESA6-02独立reviewとrepository受入れ／Phase releaseはpending。この記録はStep・Phase受入れや実機結果を付与しない。

## Slice A consumer repair closure evidence — 2026-10-08

Appの修正後代表4スイート78件と影響範囲20スイート225件がすべて成功し、前回の4件の失敗が解消した。App静的解析と3repositoryの差分チェックも成功した。TFAFプログラムにはこの修正で変更がなく、代表14件／影響範囲72件・lib/test静的解析の成功を保持する。

Current status: Slice Aの汎用写真管理UIはparent-selected software validation完了。Slice Bの汎用operation contextとApp候補統合、更新後実機確認、complete ESA6-02独立review、各repository受入れとPhase releaseはpending。Appの書籍意味・項目優先順位とCoreのprovider/storage責務を保持し、Step／Phase受入れや新たな実機結果は付与しない。
