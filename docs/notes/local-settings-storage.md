# Installation-local Settings storage

S06 supplies `createLocalSettingsStorage(namespace: ...)` through the public
framework package. Application composition injects the returned `SettingsStorage`
into the accepted `SettingsController`; neither Settings Widgets nor Resource
Views access storage. Construction validates a nonempty ASCII identifier
starting with a letter/digit and containing only letters, digits, `_`, `-`, `.`.
It performs no I/O. Use one controller as the writer for each namespace.

```dart
final settings = SettingsView.owned(
  service: SettingsController(
    storage: createLocalSettingsStorage(namespace: 'my-application'),
  ),
);
// Application composition owns load and disposal.
await settings.load();
```

## Native installation

The adapter uses `path_provider`'s application-support directory and stores one
opaque record at `textus-settings/<namespace>.json`. Missing files return null;
other directory/read failures propagate. A save creates the parent directory,
writes a uniquely owned temporary beside the destination with `flush: true`,
then renames it over the destination. Success is acknowledged only after this
replacement completes. Failed replacement propagates its original error and
cleans only that operation's temporary; a leftover temporary is never restored.
Separate namespaces cannot replace one another's record.

This is acknowledged application-restart persistence, not a guarantee against
sudden power loss or filesystem failure. The adapter does not coordinate
multiple controllers/processes writing the same namespace. The accepted
controller owns ordered/coalesced revisions and recovery; the adapter does not
parse, normalize or upgrade the Settings schema.

## Browser origin

Web uses the standard browser `localStorage` record
`textus.settings.<namespace>` within the current origin. `getItem` returns null
for absence. `setItem` replaces the whole string synchronously before the write
Future completes. Quota/access failures propagate to the controller's existing
unsaved/error/retry flow. Origin changes and browser data deletion are separate
storage domains. No server profile or cross-tab writer coordination is added.
Unsupported runtimes reject construction through the conditional stub.

## Evidence

`test/local_settings_storage_test.dart` covers absence/no read-caused writes,
opaque replacement/new-instance restoration, namespace isolation, failed
replacement/owned-temp cleanup, read/directory failure and namespace validation.
The Editing Studio consumer spec and native/browser smoke records are linked
from the [Phase 2.1 execution record](../journal/2026/10/2026-10-01-phase-2.1-completion.md).
