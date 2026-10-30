# Shared media action UI integration

Status: PLANNED; execution not started
Decision date: 2026-10-31
Consumer: App Phase 7 ESA7-08

Implement [common media actions](../spec/media-input-actions.md) over the
[Core workstream](../../../textus-flutter-core/docs/phase/media-input-capabilities-plan.md).
Reuse existing capture and adaptive/Fold components. Preserve closed phases;
do not add Book-specific device logic or require all Sensitive Interaction work.

| ID | Delivery | Acceptance |
| --- | --- | --- |
| TFAF-MEDIA01 | Common action/status binding | Same import/capture/record/play controls for Web and native large screens, consuming Core states |
| TFAF-MEDIA02 | Import preview and availability/recovery UX | Import-first flow, visible disabled actions with accessible reasons; unknown/requestable states offer explicit confirmation, not a dead end |
| TFAF-MEDIA03 | Web/Fold consumer acceptance | Validate missing/blocked/usable adapters and actual Web import/native device use; layout changes preserve work without starting permission/capture |

- [ ] TFAF-MEDIA01 shared action composition wired to public Core capabilities.
- [ ] TFAF-MEDIA02 preview/cancel and state/recovery interaction accepted.
- [ ] TFAF-MEDIA03 selected Web/Fold cases accepted with ESA7-08 before ESA7-05 closure.

Inventory capability risks early, but implement this media-action extension
after the basic phone → Web → persisted Information route works (Nov 6 JST
target). App connects Fold editing first, then Web image import with Core and
Framework (Nov 7), followed by joined rehearsal/release Nov 8 and Nov 9 defect
buffer. Framework owns common controls/preview and App owns composition; reuse
the working editor and registration path. These are planning targets, not extra
review cycles; report gaps/forecast rather than waive acceptance. See the
[milestone schedule](../../../../Project2026/nict-editing-studio/docs/milestone/2026-11-10-nict-demo.md#intermediate-delivery-targets-jst).

Use controlled state scenarios for unavailable/unknown combinations plus real
selected-platform evidence; distinguish those evidence types. General tablet
device qualification is later; the layout and common behavior are shared now.

Phase 8 ESA8-06 adds explicit image paste, drag/drop, multiple-image preview and
common upload progress/retry presentation over Core's shared pipeline. This
extends the basic picker/submission route and does not expand Phase 7 closure.
