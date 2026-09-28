# Display Model Visual Realization Direction

Date: 2026-09-29
Status: architectural direction

TFAF remains the visual application framework above textus-flutter-core. The server-driven path is refined as follows:

CNCF View -> Display Projection -> Display Model Protocol -> textus-flutter-core runtime -> TFAF visual realization -> application.

TFAF must not require semantic domain properties such as product_name or server-native JSON to render standard UI. It consumes presentation roles such as title, fields, sections and actions, with displayable values already prepared by the Display Model boundary.

The existing Phase 1 Resource List/Detail fake-data proof remains valid. Its future server replacement should use the Core Display Model source/runtime rather than bind Widgets directly to CNCF Operations or REST/JSON. Standard List/Detail visual code and application visual design should remain unchanged when the source changes.

TFAF owns how abstract List/Detail/etc. are visually realized, including adaptive/foldable composition. It does not own CNCF semantic View models, server Display Projection, or the wire protocol.
