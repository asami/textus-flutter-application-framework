# Online Experiment Display Variant

TFAF consumes CNCF Display Model presentation variants for online A/B experiments.

CNCF owns subject assignment and stable Experiment/Run/Arm correlation. The Display Model carries only the client-safe assigned Arm/variant plus a Display Instance/correlation reference required by the protocol. TFAF must not randomize, rebalance, or otherwise choose an Arm.

TFAF may use the assigned variant to select different Flutter presentation realizations when the difference cannot be represented solely by target-neutral Display Model fields.

Display interactions and standard mutations preserve the Display Instance/correlation reference. The server restores the authoritative Experiment assignment and records mutation/business outcomes. TFAF does not need to attach trusted Experiment semantics to every Business Operation.

This supports end-to-end evidence such as: UI variant A shown -> edit/save behavior -> Business Operation -> AI-backed calculation -> final outcome, all correlated to one Experiment Arm.

## Multi-arm semantics

TFAF treats the Display Model variant as an opaque assigned Arm/variant from an N-arm Experiment. It must not assume only A/B. Fixed, weighted or adaptive allocation (including future Thompson Sampling/UCB policies) is invisible to TFAF; the client renders the assigned variant and preserves the Display correlation reference.
