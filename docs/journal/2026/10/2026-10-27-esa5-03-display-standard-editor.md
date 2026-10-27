# ESA5-03 common formal Display Editor — implementation record

Authority: frozen `ESA5-03-TFAF-EDITOR-001`, PHASE-5, initial implementation.
One bounded Core-to-common-editor ownership edge. The parent selected the
actual Core public API and modal/receipt semantics. This record claims authored
implementation and specifications only. No validation, formatting, runtime,
review, acceptance, version update or commit was performed by this editor.

## Requirement mapping

| Manifest obligation | Authored implementation |
| --- | --- |
| Public common controller and view | New controller/widget and package barrel exports |
| Idle, same source, borrowed ownership | Constructor identity check; no eager I/O; controller generation retirement only |
| Formal observation and descriptor admission | Capture ready exact Detail; recheck source/selection after descriptor; match section/field identities |
| Text inputs and metadata | Capability plus availability; bound writable accepted Text; ordered labels, readonly values and hints |
| Exact drafts and ordered changes | Immutable copy-on-write scoped maps; exact code units; changed fields in descriptor order; equal values sent once |
| Busy and receipt/read separation | Single activity/reentrancy guard; receipt notification before safe Detail/List reads |
| Coherence and floor | New formal observations plus View flags, selected ID, exact matching revisions and receipt/original floor |
| Pending, unknown, conflict and rejection | Retained receipt; safe Reload only; taxonomy classification; pinned retired drafts; approved scoped code |
| Discard and fresh Edit | Dirty decision; discard preserves outstanding obligation and receipt; fresh Edit blocked until reconciliation |
| Existing common presentation | Existing ResourceListDetail retained behind modal; framework supplement plus recovery toolbar |
| Modal lifecycle | First-frame descriptor start; route-owned Text controllers; PopScope busy gate; opener/session checks and borrowed listener detach |
| Portable controlled evidence | Three exact producer goldens, origin README, shared real-Core MockClient fixture |
| Documentation | Common contract spec and this implementation record; no native/acceptance claim |

## Authored executable scenarios

The names below identify behavior specifications, not execution results. Each
test includes adjacent Given/When/Then clauses. Generated cases use the same
clauses for every listed parameter.

### Controller specifications

| Scenario / parameters | Given | When | Then |
| --- | --- | --- | --- |
| Idle / scoped admission | Real Core client and copied producer baseline, no selection | Construct, select, hold and release descriptor | No eager command, ready exact observation retained, ordered title/stage/description metadata, only scoped title/description editable, immutable maps and borrowed-source check |
| Receipt before held read | Revision1, reversed local edits and exact whitespace/Japanese/emoji | Save once, hold first read, attempt reentrant/concurrent actions, release | Receipt2 observed before GET, one PUT with revision1 and descriptor order, immutable draft, coherent Detail/List2 and editor closes |
| Equal draft | Unchanged observed Detail | Explicit Save | All writable fields sent once; producer unchanged receipt1 retained |
| Exact UTF16 | Draft containing whitespace, Japanese and isolated surrogate | Explicit Save receives domain rejection | Draft code units and escaped request survive unchanged; one PUT |
| Approved scoped rejection | Invalid title and private Conclusion prose | Save, correct field, explicitly Save again | Fixed approved diagnostic only, draft editable/retained, matching error clears, second PUT only on next explicit Save |
| Retired outcome: conflict / unknown / malformed / timeout / wrong-scope | One changed draft and selected controlled failure; conflict uses HTTP400 | Save, failed Reload, coherent Reload, attempt Save/Edit, discard and fresh Edit | Taxonomy/reconciliation respected, one PUT, no retry, draft pinned until discard, new Edit starts from fresh formal values |
| Receipt survival: ready / pending × read failure / query failure / stale floor | Committed receipt2 with failed or revision1 reads | Save, Reload where required, discard, coherent Reload2 | Pending starts no eager reads, receipt survives failure/discard, new Edit blocked while unresolved, one PUT and safe resolution |
| Pending resolution | Controlled committed-pending receipt | Save then explicit coherent Reload | Known commit retained, Save disabled, safe reads close accepted editor, one PUT |
| Different read revisions | Receipt2, Detail2 and List3 | Ready Save then coherent explicit Reload2 | Successful transports cannot bypass coherence; receipt remains and one PUT |
| Restricted input: unsupported / hidden / system / readonly / multiple / missing / number-kind | Controlled descriptor state or missing Text value | Begin Edit and attempt setText | No coerced/unauthorized title input or command |
| Scoped mismatch | Descriptor title in a different section | Match against formal Detail sections | No flat-key fallback, descriptor fails safely, no command |
| Disposal: descriptor / update / read | Finite held operation | Dispose controller then release | No late notification or next read/query; in-flight command uncertainty retained; borrowed View Model/client still usable |
| Availability and source identity | Supported but disabled update, then held descriptor | Admit disabled state; replace formal Detail before completion | No writable fallback or obsolete editable capture |

### Actual common Widget specifications

| Scenario / parameters | Given | When | Then |
| --- | --- | --- | --- |
| Common roundtrip: compact400 / expanded1000 | Actual ResourceListDetail, borrowed layout, Japanese producer row | Select, immediately push Edit, hold descriptor, edit exact Text, hold receipt read, attempt Back, release | Ordered labels/readonly stage and required hint, no nested AppBar, receipt before reads, one PUT, same underlying List/Detail State/layout/selection and coherent revision2; owners survive unmount |
| Dirty Cancel/Back: compact400 / expanded1000 | Current dirty modal | Cancel and keep editing; Back and explicit discard | One decision each, exact draft retained on decline, only current route closes on discard, no command |
| Editable rejection | Approved title diagnostic with private prose | Common Save, correction and explicit next Save | Scoped safe diagnostic, no private prose or automatic command, corrected Save returns to Detail |
| Producer hints | Required, placeholder, help and inert pattern | Open common Editor and Save nonmatching text | Metadata survives, server remains validator, no pattern authorization/coercion |
| Pending known commit | Pending receipt2 | Save, failed query Reload, coherent Reload | Known commit/pending shown, Save disabled, receipt/draft survive, one PUT and actual Detail return |
| Retired modal: conflict / unknown / malformed | Controlled uncertain or structured failure | Save and coherent safe Reload, then explicit discard and fresh Edit | Old draft remains pinned/disabled, no raw prose/replay, fresh values only after discard |
| Closed pending failed Detail | Known pending receipt and future read failure | Explicit discard closes Editor; common toolbar Reload fails then succeeds | Existing failed Detail diagnostic retains visible receipt and safe recovery; Edit stays blocked while unresolved; one PUT |
| Busy command | One held dispatched update | Repeat Save, Cancel and system Back | Busy route protected, no discard dialog/retry/cancellation claim; one PUT |
| Replaced opener: descriptor / update / read × Cancel / Back | Modal with finite held operation | Replace binding, observe retired presentation before completion, push unrelated route, release old future, Back to Editor, explicitly dismiss | Old future cannot pop unrelated route; loading ticker suppressed and stale Save/Reload/inputs disabled; retired Editor closes without discard/extra PUT/reads or replacement-controller activity; receipt/draft unchanged by dismissal and borrowed client remains usable |
| Removed opener: update × Cancel / Back | Modal with held dispatched update | Remove opener, observe retired presentation, push unrelated route, release update, Back to Editor, explicitly dismiss | One original PUT; unrelated route survives completion; current retired Editor dismisses without controller mutation or borrowed-owner disposal |
| Controller disposed during descriptor | Modal with finite held descriptor | Dispose controller, release, then explicit system Back with retained busy state | No late descriptor publication/navigation; current Editor closes without discard or extra transport; borrowed source/client survive |

## CPB-ESA5-03-001 repair mapping

Frozen authority: `ESA5-03-RETIRED-EDITOR-FIX-001`, PHASE-5 / ESA5-03.
The sealed review identified that opener retirement also blocked every dismissal
path, leaving a stale Editor on the Navigator stack after unrelated-route return.
The bounded repair retains a private route reference, detaches it on opener
replacement/removal, and requests one active-route presentation rebuild after the
frame. Ordinary completion clears only its identical route reference.

Current-route dismissal is separate from business-session authority. Explicit
retired Back/Cancel closes only that current route regardless of stale busy
state, without calling discard, Save, Reload or setText on borrowed controllers.
Active busy and dirty guards remain; stale business callbacks and inputs remain
guarded. No automatic unrelated-route pop, transport cancellation/replay or public
API change is introduced. The parameterized Widget scenarios above now actually
return from the unrelated route and dismiss the retired Editor; the disposed
descriptor scenario explicitly dismisses with retained busy state. All retain
their actual transport, visible-route and borrowed-ownership assertions with
adjacent Given/When/Then boundaries and bounded frames during held loading.

This entry records authored repair and regression evidence, not test execution,
PASS, review closure or acceptance. The repair is M2, `RE_REVIEW_REQUIRED=yes`.
The parent owns focused Widget validation first, the selected analyzer/format and
accumulator checks, and independent focused closure review. Only the two owned
Dart programs may be formatter-edited by this repair worker. The authorized SDK
`dart format` edit completed with exit 0 for those two paths (two processed, one
changed). No tests, analyzer, format check or self-review ran in this repair pass.

## Remaining ownership

Parent owns diff verification, analyzer/format checks, focused controller/widget and
existing common presentation validation, independent protected review and Step
transition. No extra path or upstream API was needed during authoring. No
separate follow-up debt was introduced. Same-file target behavior, lifecycle and
executable specification obligations were authored within the exact owned paths.

## Parent Step acceptance — 2026-10-27

ESA5-03 is accepted through the integrated independent protected Step review
and focused closure of CPB-ESA5-03-001 in the common Widget. Core401, TFAF84
and App52 focused tests passed;14 affected App consumer tests passed after
the private retired-route repair. Analysis, formatting and integrity checks
passed. Earlier authored-only descriptions and failed validation attempts are
retained as history. The accepted route is controlled common Edit/Save with
retained receipt and explicit safe Reload, without App-owned CRUD. Native
mutation, supplied-context and Business/E2E proof remain later Phase5 work;
this Step does not close the Phase or change producer capabilities.
