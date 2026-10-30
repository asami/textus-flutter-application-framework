# Structured candidate review host increment

Editing Studio App Phase 6.6 consumes the common source-linked proposal review
from the dedicated `codex/esa66-structured-candidates` branch, based on accepted
Phase 6.5 commit `baccbaf`.

Implemented current/proposed value comparison, explicit conflicts, source-span
disclosure and accept/edit/discard. Exact empty edits are clears. Actions check
the live admission policy; a dialog from a replaced owner cannot publish into
the replacement. Book labels and persistence stay in the App. See the
[contract](../../../notes/structured-candidate-review.md).

Actual host validation: `flutter analyze --no-pub` passed; the complete
`flutter test --no-pub --reporter expanded` run passed 888 tests, including
4 new common review widget scenarios. Raw output remains only at the App
task's `target/phase-6.6-host-20261030/tfaf-full.log`.

This record establishes host implementation evidence, not independent review,
native-device acceptance, a Phase release or publication.

Final UI follow-up: a parent rebuild may decode a semantically identical
workspace into new Dart instances (including keyboard/viewport changes).
Pending-proposal checks now compare exact product values rather than object
identity. Edit completion also compares its original source snapshot, so a
changed source or owner still cannot accept the old draft. Two additional
widget cases cover equivalent reconstruction and changed-source rejection.
Clean analysis and the complete host suite passed again: 890 tests, including
6 new widget cases. The final log is `tfaf-full-final.log` in the same local
directory; initial evidence remains retained.

## Ordinary implementation acceptance

Independent integrated review found that retained immediate accept/discard
callbacks could act on a replacement owner with equivalent proposal data
(CPB-ESA66-001). All three rendered actions now retain their generation,
exact source snapshot and original consumer callback. Edit also repeats the
guard after dialog completion. Five additional regressions exercise stale
accept/discard across owner/source replacement and stale Edit entry.

Final analysis is clean, the 11 common review cases pass and the complete
suite passes 895 tests. The fresh focused re-review closed the UI finding and
accepted the native Flutter naming and executable specification conventions.
The App's final integrated full suite and retained-data Fold scenario also
passed with this UI. Original results stay private under the owning App's
target directory. The App task owns the local commit result; this record does
not assert a separate TFAF Phase release or publication.
