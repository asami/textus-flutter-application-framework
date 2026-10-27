# ESA5-01 — formal Display read presentation binding

The common `CncfDisplayResourceDataSource` consumes Core's authenticated formal
CNCF query/read client and feeds the existing Resource List/Detail Widget.
The App supplies its trusted reference profile and declarative field selection;
it does not implement a second list/detail UI, decode the wire or propagate
presentation context manually.

The first route is read-only. Server actions do not create handlers or authority.
The original observations retain definition/provenance, exact string revision,
optional query snapshot and supplied context through `lastQuery`/`lastDetail`.
The legacy ResourceRecord integer revision is not a mutation observation.
Ambiguous same-ID fields in different sections reject rather than overwrite
inside the legacy flat presentation adapter. Rich section and lossless non-Text
rendering remain later consumers of Core's formal model.

This integration uses existing common loading/error/navigation behavior.
Producer-wire widget checks do not establish native server deployment or Android
E2E. App ESA5-01 remains in progress until actual server reads are verified.

## Native read acceptance

The subsequent App-owned real Android proof passed the authenticated server
query/read through this adapter and the existing common Japanese List/Detail
Widget. The source observations retained exact identities/revisions and absent
context, with no native writes and complete owned cleanup. Independent ESA5-01
Step conformance passed. Standard-route replacement, mutation, supplied-context
realization, Business/reload and final Phase acceptance remain separate work.
