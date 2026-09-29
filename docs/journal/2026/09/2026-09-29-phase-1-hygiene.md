# Phase 1 Hygiene ledger

Date: 2026-09-29

These three findings remain OPEN and nonblocking. Their exact accepted text
and original ownership are preserved from the independent acceptance audit.
This closure records the debt; it does not implement these maintenance changes.

HYG-TFAF-PHASE1-APP-CONFIG-001: OPEN Hygiene. config/README.md:3-4 still describes the Resource List/Detail configuration contract as future availability although both configuration assets and their executable decoder/runtime path exist. This pre-existing supporting-document debt does not block code acceptance or Phase 1 closure. Owner: nict-editing-studio-app. Maintenance boundary: update only config/README.md to describe the implemented JSON assets and link the Cozy handoff contract; do not change schemas, bindings, Phase scope, or runtime behavior.

HYG-TFAF-PHASE1-APP-SPEC-001: OPEN Hygiene. Unchanged test/editing_studio_view_space_test.dart:7 and test/tfaf_dependency_test.dart:6 lack adjacent semantic Given/When/Then clauses; the view-space scenario combines loading, adapter ownership, and Aggregate refresh assertions without explicit behavioral boundaries. Expectations provide behavioral evidence, and current changed/new scenarios satisfy the authoring gate. This pre-existing specification debt does not block code acceptance or Phase 1 closure. Owner: nict-editing-studio-app. Maintenance boundary: add adjacent semantic clauses and grouping where useful in these existing tests, preserving behavior and assertions without adding closure/source-shape tests.

HYG-TFAF-PHASE1-SPEC-001: OPEN Hygiene. Unchanged test/application_view_model_test.dart:18,41, test/crud_resource_adapter_test.dart:52, test/presentation_realization_test.dart:5, test/resource_list_detail_test.dart:60, and test/resource_list_detail_hinge_test.dart:15,40,73,118,206,245,270,338 lack adjacent semantic Given/When/Then clauses. Their behavioral assertions remain useful, and current changed/new action scenarios satisfy the authoring gate. This pre-existing specification debt does not block code acceptance or Phase 1 closure. Owner: textus-flutter-application-framework. Maintenance boundary: add adjacent semantic clauses and behavioral grouping where useful in these existing tests, preserving behavior and assertions without adding closure/source-shape tests.
