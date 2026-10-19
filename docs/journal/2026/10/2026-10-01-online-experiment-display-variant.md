# UI A/B Experiment integration direction

Date: 2026-10-01

Decision: CNCF performs online Experiment assignment; TFAF only renders the server-assigned Display Model variant. Display Model carries a client-safe Arm/variant and Display Instance/correlation reference.

Mutation and subsequent backend evaluation remain CNCF responsibilities. TFAF preserves the correlation reference so CNCF can associate Display Mutation, Business Operation and optional AI Audit evidence with the UI variant actually shown.

The UI client does not perform random A/B assignment.
