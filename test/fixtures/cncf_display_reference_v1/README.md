# Formal Display reference fixtures

These three JSON files are exact copies of the selected Editing Studio producer
goldens in `src/test/resources/display/protocol/v1/` from the selected
Editing Studio server repository for PHASE-5 ESA5-03.
They preserve the producer's provisional scenario contract and Japanese Text.

`test/support/cncf_display_mutation_fixture.dart` uses these portable local
baselines with the actual Core client and a controlled MockClient. Update
receipts, changed revisions, errors and read timing are controlled test evidence,
not native/server execution or producer validation. No runtime sibling path is
used by the tests.
