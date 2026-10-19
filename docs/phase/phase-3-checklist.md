# Phase 3 Checklist - Background Transfer Status UI

status=planned
Owner: textus-flutter-application-framework Phase 3.
Plan: [Phase 3](phase-3.md).
All items are pending; documentation creation establishes no execution evidence.

## Entry

- [ ] Confirm actual predecessor/API handoff and previously implemented connected
      work; identify remaining delta without replaying accepted work.
- [ ] Freeze exact worktree, scope, public contract, dependency order and realistic
      execution estimate before implementation.

## TFAF3-01: Core handoff and view contract

- [ ] Consume accepted Core APIs and freeze configuration/state/action mapping.
- [ ] Record focused behavioral evidence, independent acceptance and the owning Step commit.

## TFAF3-02: Common screen and composition

- [ ] Implement list/detail, supported actions, summary and navigation hooks.
- [ ] Record focused behavioral evidence, independent acceptance and the owning Step commit.

## TFAF3-03: Consumer acceptance

- [ ] Verify fixtures and app composition, including failure/restart presentation.
- [ ] Record focused behavioral evidence, independent acceptance and the owning Step commit.

## Behavioral acceptance

- [ ] Consume the reviewed Core two-operation state/action contract; identify
      required public APIs before writing the view, with no private imports.
- [ ] Implement configurable list/detail and supported action presentation.
- [ ] Integrate summary/entry/navigation hooks without owning execution state.
- [ ] Validate view behavior using independently controllable Core fixtures.
- [ ] Hand off the public component/configuration to the app and verify its
      two destination labels, Home entry and return-to-Material integration.

- [ ] Cover both success paths, offline waiting, upload failure/dependent wait,
      upload success/submission failure and targeted retry, partial upload,
      queued/running restart, no-upload content and indeterminate progress.
- [ ] Prove that UI rebuild/navigation and submission retry do not repeat an
      already successful upload for the same committed content.
- [ ] Keep fake acceptance distinct from actual remote upload/submission; retain
      local originals and do not claim Candidate formation from either result.
- [ ] Run proportionate package analysis/tests and affected-consumer checks;
      coordinate release validation with Phase 6.1 without declaring upstream
      obligations satisfied by app-only tests.

## Phase closure

- [ ] All owned Steps and required consumer/adapter evidence accepted.
- [ ] Complete package analysis and tests pass; app-only tests are insufficient.
- [ ] One comprehensive Phase review closes all current blockers.
- [ ] Publish the public API/UI handoff and separate actual from fake results.
- [ ] Record closure in Phase, checklist, journal and index; create the distinct
      Phase release commit through the normal execution workflow.
