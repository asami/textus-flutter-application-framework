# Photo role Japanese presentation and explicit preview readiness

Recorded: 2026-11-05. Implementation scope:
ESA610-PHOTO-ROLE-JAPANESE-PREVIEW-001, consuming App PHASE-6.10.
Status: implementation authored only. Parent-selected tests, source analysis,
independent review, local Step acceptance and native acceptance remain pending.

The common `PhotoRoleCapturePanel` now uses the frozen Japanese participant
words and semantic label prefix. `PhotoRoleCaptureImage` adds optional nullable
`previewReady`: explicit true permits localized read labels, false suppresses
decoder construction and byte borrowing, and omission retains exact legacy
`readStatusLabel == 'Loaded'` readiness. Readiness adds no IO or eager byte read.
Existing original/source identity, 512 decode bound, local retry, private
snapshot/cache disposal and callback guards remain unchanged.

The consuming Book App passes its existing cached original-availability
predicate explicitly, supplies Japanese read labels, and uses the frozen
Japanese role-correction dialog and role/use history words. Supplied IDs,
timestamps, roles, callback authority and original provenance remain intact.

Two executable specifications were authored using the real PNG/paint helper:
localized ready originals paint both thumbnail and inspected RawImages without
domain callbacks; explicitly unready originals labeled `Loaded` build and
Inspect without a decoder or byte reads while exact-original read retry remains
reachable. Existing legacy decoder scenarios and App original-paint assertions
are retained, with participant display expectations updated.

The App's recognition values, integrated statuses, acquisition enum names and
raw error diagnostics remain existing open full-Phase Japanese coverage.
No completed Japanese coverage, test result, review result, native evidence or
Phase completion is claimed. Existing completed Framework Phase3 and planned
Phase4 identities are preserved. See the
[readiness contract](../../../notes/photo-role-preview-readiness.md).
