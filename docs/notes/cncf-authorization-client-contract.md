# Flutter Application Framework CNCF Authorization Client Contract

Status: initial projection
Updated: 2026-10-16
Canonical reference: asami/goldenport-cncf Textus Security Architecture / Entity Authorization / APK Untrusted Client note

The Flutter Application Framework provides the common client contract for authentication/session propagation and invocation of CNCF-backed Operations. It does not reproduce CNCF ABAC/ReBAC or Entity authorization in the client.

Applications may use authorization-derived presentation hints for UX, but the server remains authoritative. Request construction must not allow local owner/tenant/role fields to become authority merely because they are sent by the client.

The framework should make the secure path ordinary: common authentication renewal/transport is centralized, while each application does not invent token handling or duplicate server authorization logic.
