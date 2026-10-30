# Shared text revision review — 2026-10-30

PHASE-6.8 S1-B extends the existing generated-draft controller/panel with an
explicit optional operation at source selection. Omitted operations preserve
image-description/text-summary behavior. Core request validation admits each
selection before mutation. Operation-only changes retire the old generation
through existing cancellation and cleanup ownership; equivalent selections are
inert. Commands and retained attempts keep their original admitted operation.

Proofreading uses `原文の校正`; personal-annotation readability uses
`個人注釈の文章改善` and discloses that a rewrite is not a verbatim quotation.
Pending and adopted review preserve original/raw/selected text and use Core's
exact whole-text comparison, including an explicit `変更なし` result. Adoption
remains a whole-text human decision. Stale text is retained for inspection and
requires regeneration/review or manual reconciliation. Existing rendered-owner,
context, generation and dialog-route fences remain in force.

The caller owns semantic source eligibility, current-source/context guards,
persistence and application of selected text. In particular, readability must
be restricted to personal annotations by the App adapter. App text-revision
integration belongs to S2; the shared panel makes no Book target decisions.

Native Flutter executable specifications describe explicit operation forwarding,
selection retirement, invalid/no-op selection, exact comparison and whole-text
decisions, history labeling and stale action fencing. Validation, independent
review and acceptance remain parent-owned.

## Step acceptance

ESA68-S1 is accepted on 2026-10-30 after focused validation and independent
Step review/focused closure. The reviewed callback-selection guard now binds
source, operation and generation before callbacks and fences launch, readiness
and decision publication after reentrant changes. Valid past proposals remain
adoptable under fresh render authority. Book integration, actual Japanese
device qualification, comprehensive Phase review, full validation and final
Phase completion remain pending.
