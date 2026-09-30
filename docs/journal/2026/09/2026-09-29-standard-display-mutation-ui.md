# Standard Display Mutation UI

Date: 2026-09-29
Status: architectural direction

CNCF DisplayService will pair Display Objects with standard create/update/delete mutation semantics. TFAF should use that contract to execute common UI interaction patterns from configuration rather than requiring application-owned Editor screens and action handlers.

The intended framework path covers List -> Create Editor -> Detail, Detail -> Edit -> Save -> Detail, and Detail -> Delete confirmation -> List. Display metadata supplies editable fields, datatypes, constraints, identity/revision and mutation capability; TFAF supplies the platform visual realization, local draft state, validation presentation and navigation.

Business Operations remain separate. TFAF/application action bindings call the normal CNCF REST Operation interface directly. After a successful Business Operation, the initial client behavior is to reload the affected Display Object. Reactive invalidation/push can be added later.

This extends the configuration-first rule: standard mutation is not only a standardized network call; the screen and interaction from action trigger through mutation completion are framework behavior.
