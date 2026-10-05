# Persistent Dashboard Presentation Modes

Date: 2026-10-05
Status: framework direction
Driver: Textus Control Center Flutter client

TFAF should support reusable application-level presentation policy for applications that can alternate between ordinary mobile use and persistent dashboard use.

The initial conceptual modes are Mobile, Dashboard, Stand and Ambient. These are presentation modes, not device classes and not domain states.

Resolution consumes environment facts from textus-flutter-core together with user/application policy. Relevant inputs can include usable display regions, size, orientation, power/charging state, inactivity and capabilities. Charging is an input only; it must not mean "dashboard" unconditionally.

TFAF owns the reusable policy/resolver and presentation-session transition semantics. A consumer application supplies defaults and allowed modes. Application View/domain state must survive mode transitions.

Ambient mode is a presentation behavior for unattended persistent display. Reusable support may include reduced information density, dark presentation, bounded position shifting, inactivity transition and interaction-to-resume. Platform wake-lock APIs and raw power-state observation remain below TFAF in Core/platform services.

This follows the existing rule that presentation derives from capabilities, geometry and declared policy rather than Android/iOS or product names.

CNCF Display Model remains target-neutral. TFAF may use semantic priority/role information from a Display Model to decide which information survives into constrained Dashboard/Stand/Ambient realizations, but local charging, inactivity and burn-in mitigation state must not be written back into the semantic Display Model.
