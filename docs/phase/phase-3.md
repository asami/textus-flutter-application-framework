# Phase 3: Sensitive Interaction Application Framework

Status: PLANNED
Plan date: 2026-10-16
Depends on: textus-flutter-core Phase 2, CNCF Phase 111, Cozy Phase 85

## Goal

Make provider-delegated sensitive interaction the ordinary application-level
Flutter path.

## Planned work

- define application-facing SensitiveInteraction API;
- initial interaction families: payment, identity/authentication, signing and
  provider consent as justified by concrete use cases;
- expose domain-safe Reference/Assertion/Result values rather than provider
  secrets;
- integrate CML/Cozy-generated contracts where Phase 85 defines them;
- ensure UI/application state does not receive excluded sensitive values in the
  ordinary path;
- document fallback/exception behavior for providers without delegated UI.

## Initial direction

Application code requests an interaction and receives a typed result. Provider
selection, platform UI and credential handling belong below the application
framework boundary.

The API remains small until concrete Android/iOS integrations prove the common
abstraction.
