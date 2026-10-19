import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../widgets/application_text_scaling.dart';
import '../widgets/application_text_toolbar.dart';
import 'submission_settings_controller.dart';

/// Separate submission configuration route borrowing an explicitly loaded owner.
class SubmissionSettingsPage extends StatefulWidget {
  const SubmissionSettingsPage({
    required this.controller,
    this.title = 'Submission settings',
    super.key,
  });

  final SubmissionSettingsController controller;
  final String title;

  @override
  State<SubmissionSettingsPage> createState() => _SubmissionSettingsPageState();
}

class _SubmissionSettingsPageState extends State<SubmissionSettingsPage> {
  TextEditingController _driveId = TextEditingController();
  TextEditingController _account = TextEditingController();
  TextEditingController _folder = TextEditingController();
  TextEditingController _httpId = TextEditingController();
  TextEditingController _endpoint = TextEditingController();
  bool _requiresBearer = true;
  String? _formFailure;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(SubmissionSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      for (final field in [_driveId, _account, _folder, _httpId, _endpoint]) {
        field.clear();
        field.dispose();
      }
      _driveId = TextEditingController();
      _account = TextEditingController();
      _folder = TextEditingController();
      _httpId = TextEditingController();
      _endpoint = TextEditingController();
      _requiresBearer = true;
      _formFailure = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    for (final field in [_driveId, _account, _folder, _httpId, _endpoint]) {
      field.clear();
      field.dispose();
    }
    super.dispose();
  }

  void _changed() {
    // Given borrowed state, When notified while mounted, Then show current values.
    if (mounted) setState(() {});
  }

  // Given a captured control owner, When a callback runs,
  // Then allow commands only for the mounted current idle attachment.
  bool _current(SubmissionSettingsController controller) =>
      mounted &&
      identical(controller, widget.controller) &&
      !controller.busy &&
      !controller.isDetached;

  void _addDrive(SubmissionSettingsController controller) {
    // Given explicit new-target input, When Add is tapped while current,
    // Then construct only that immutable definition or show a fixed safe error.
    if (!_current(controller)) return;
    try {
      final connection = DriveSubmissionConnection(
        id: _driveId.text,
        accountId: _account.text,
        folderId: _folder.text,
      );
      setState(() => _formFailure = null);
      if (_current(controller)) controller.putDrive(connection);
    } on ArgumentError {
      setState(() => _formFailure = 'Submission configuration is invalid.');
    }
  }

  void _addHttp(SubmissionSettingsController controller) {
    // Given explicit endpoint input, When Add is tapped while current,
    // Then Core validates HTTPS without acquisition, authorization or selection.
    if (!_current(controller)) return;
    try {
      final connection = HttpSubmissionConnection(
        id: _httpId.text,
        endpoint: Uri.parse(_endpoint.text),
        requiresBearerToken: _requiresBearer,
      );
      setState(() => _formFailure = null);
      if (_current(controller)) controller.putHttp(connection);
    } on ArgumentError {
      setState(() => _formFailure = 'Submission configuration is invalid.');
    } on FormatException {
      setState(() => _formFailure = 'Submission configuration is invalid.');
    }
  }

  // Given local form ownership, When rendering an input,
  // Then bind only this local buffer without commands or persistence.
  Widget _field(TextEditingController field, String label, bool enabled) =>
      TextField(
        controller: field,
        enabled: enabled,
        decoration: InputDecoration(labelText: label),
      );

  Widget _defaults(
    SubmissionSettingsController controller,
    SubmissionConfigurationSnapshot snapshot,
    bool enabled,
  ) {
    // Given current defaults, When one explicit selector changes,
    // Then pass both desired IDs so null clears without selecting another target.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selections apply to new submissions'),
        const Text('Default storage'),
        DropdownButton<String>(
          isExpanded: true,
          value: snapshot.selectedStorageConnectionId,
          hint: const Text('None'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('None')),
            for (final drive in snapshot.driveConnections)
              DropdownMenuItem(value: drive.id, child: Text(drive.id)),
          ],
          // Given a rendered snapshot, When changed, Then recheck its current owner.
          onChanged: enabled
              ? (id) {
                  if (_current(controller)) {
                    controller.select(
                      storageConnectionId: id,
                      transportConnectionId:
                          snapshot.selectedTransportConnectionId,
                    );
                  }
                }
              : null,
        ),
        const Text('Default transport'),
        DropdownButton<String>(
          isExpanded: true,
          value: snapshot.selectedTransportConnectionId,
          hint: const Text('None'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('None')),
            for (final http in snapshot.httpConnections)
              DropdownMenuItem(value: http.id, child: Text(http.id)),
          ],
          // Given both defaults, When transport changes, Then retain desired storage.
          onChanged: enabled
              ? (id) {
                  if (_current(controller)) {
                    controller.select(
                      storageConnectionId: snapshot.selectedStorageConnectionId,
                      transportConnectionId: id,
                    );
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _drive(
    SubmissionSettingsController controller,
    DriveSubmissionConnection drive,
    bool enabled,
  ) {
    // Given immutable Drive identity, When rendered, Then expose safe definitions
    // and literal authorization observations without claiming remote connectivity.
    final authorization = controller.authorizationStates[drive.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Drive ID: ${drive.id}'),
        Text('Account: ${drive.accountId}'),
        Text('Folder: ${drive.folderId}'),
        Text('Authorization: ${authorization?.name ?? 'Not checked'}'),
        if (controller.hasDriveAuthorization)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                // Given this Drive ID, When tapped while current, Then refresh it only.
                onPressed: enabled
                    ? () {
                        if (_current(controller)) {
                          controller.refreshAuthorization(drive.id);
                        }
                      }
                    : null,
                child: const Text('Refresh authorization'),
              ),
              TextButton(
                // Given this Drive ID, When explicitly tapped, Then authorize it only.
                onPressed: enabled
                    ? () {
                        if (_current(controller)) {
                          controller.authorizeDrive(drive.id);
                        }
                      }
                    : null,
                child: const Text('Authorize'),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    final enabled = !controller.busy && !controller.isDetached;
    final scaler = ApplicationTextScaling.maybeTextScalerOf(context);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: scaler == null
          ? AppBar(title: Text(widget.title))
          : applicationTextAppBar(context, title: widget.title, width: width),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot != null) _defaults(controller, snapshot, enabled),
              Wrap(
                children: [
                  TextButton(
                    // Given explicit retry intent, When current, Then read configuration.
                    onPressed: enabled
                        ? () {
                            if (_current(controller)) controller.load();
                          }
                        : null,
                    child: const Text('Reload'),
                  ),
                ],
              ),
              if (controller.loading)
                const Text('Loading submission settings…')
              else if (controller.failed)
                Text(controller.failureMessage!)
              else if (snapshot == null)
                const Text('Submission settings not loaded.')
              else if (snapshot.driveConnections.isEmpty &&
                  snapshot.httpConnections.isEmpty)
                const Text('No submission connections configured.'),
              if (_formFailure != null) Text(_formFailure!),
              if (snapshot != null) ...[
                for (final drive in snapshot.driveConnections)
                  _drive(controller, drive, enabled),
                for (final http in snapshot.httpConnections)
                  _HttpSettingsEditor(
                    key: ValueKey((controller, http.id)),
                    controller: controller,
                    connection: http,
                    snapshot: snapshot,
                  ),
                const Divider(),
                const Text('Add Drive'),
                _field(_driveId, 'Drive ID', enabled),
                _field(_account, 'Account ID', enabled),
                _field(_folder, 'Folder ID', enabled),
                TextButton(
                  // Given form input, When explicitly tapped, Then add one safe definition.
                  onPressed: enabled ? () => _addDrive(controller) : null,
                  child: const Text('Add Drive'),
                ),
                const Text('Add HTTP'),
                _field(_httpId, 'HTTP ID', enabled),
                _field(_endpoint, 'HTTPS endpoint', enabled),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requires bearer token'),
                  value: _requiresBearer,
                  // Given this new definition, When toggled, Then change only form intent.
                  onChanged: enabled
                      ? (value) {
                          if (_current(controller)) {
                            setState(() => _requiresBearer = value ?? true);
                          }
                        }
                      : null,
                ),
                TextButton(
                  // Given form input, When explicitly tapped, Then add one HTTPS definition.
                  onPressed: enabled ? () => _addHttp(controller) : null,
                  child: const Text('Add HTTP'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HttpSettingsEditor extends StatefulWidget {
  const _HttpSettingsEditor({
    required this.controller,
    required this.connection,
    required this.snapshot,
    super.key,
  });

  final SubmissionSettingsController controller;
  final HttpSubmissionConnection connection;
  final SubmissionConfigurationSnapshot snapshot;

  @override
  State<_HttpSettingsEditor> createState() => _HttpSettingsEditorState();
}

class _HttpSettingsEditorState extends State<_HttpSettingsEditor> {
  final TextEditingController _token = TextEditingController();
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _restoreDeclaration();
  }

  void _restoreDeclaration() {
    // Given the exact HTTP declaration, When restoring its form,
    // Then missing and empty remain distinct in displayed committed state.
    _selected =
        (widget.snapshot.referenceAccessBindings[widget.connection.id] ??
                const <String>[])
            .toSet();
  }

  @override
  void didUpdateWidget(_HttpSettingsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.connection.id != widget.connection.id) {
      _token.clear();
      _restoreDeclaration();
    } else if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _restoreDeclaration();
    }
  }

  @override
  void dispose() {
    _token.clear();
    _token.dispose();
    super.dispose();
  }

  // Given a captured credential/declaration target, When its callback executes,
  // Then require the exact current mounted owner and connection ID.
  bool _current(SubmissionSettingsController controller, String id) =>
      mounted &&
      identical(controller, widget.controller) &&
      id == widget.connection.id &&
      !controller.busy &&
      !controller.isDetached;

  void _credential(
    SubmissionSettingsController controller,
    String id, {
    required bool clear,
  }) {
    // Given ephemeral input for an exact current HTTP target, When submitted,
    // Then read once and clear immediately before any external credential dispatch.
    if (!_current(controller, id)) return;
    final token = clear ? null : _token.text;
    _token.clear();
    if (_current(controller, id)) controller.setHttpBearerToken(id, token);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final id = widget.connection.id;
    final enabled = !controller.busy && !controller.isDetached;
    final declaration = widget.snapshot.referenceAccessBindings[id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text('HTTP ID: $id'),
        Text('HTTPS endpoint: ${widget.connection.endpoint}'),
        Text('Requires bearer token: ${widget.connection.requiresBearerToken}'),
        Text(
          'Reference access: ${declaration == null
              ? 'Unknown'
              : declaration.isEmpty
              ? 'No access'
              : declaration.join(', ')}',
        ),
        const Text('Does not grant or verify remote permissions'),
        for (final drive in widget.snapshot.driveConnections)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Reference access to ${drive.id}'),
            value: _selected.contains(drive.id),
            // Given this exact declaration draft, When toggled, Then change only local intent.
            onChanged: enabled
                ? (value) {
                    if (_current(controller, id)) {
                      setState(() {
                        if (value == true) {
                          _selected.add(drive.id);
                        } else {
                          _selected.remove(drive.id);
                        }
                      });
                    }
                  }
                : null,
          ),
        TextButton(
          // Given explicit operator intent, When saved, Then write only this HTTP declaration.
          onPressed: enabled
              ? () {
                  if (_current(controller, id)) {
                    controller.setReferenceAccess(
                      transportConnectionId: id,
                      storageConnectionIds: [
                        for (final drive in widget.snapshot.driveConnections)
                          if (_selected.contains(drive.id)) drive.id,
                      ],
                    );
                  }
                }
              : null,
          child: const Text('Save reference access declaration'),
        ),
        if (controller.hasHttpCredentialWriter) ...[
          TextField(
            controller: _token,
            enabled: enabled,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: 'Bearer token for $id'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                // Given ephemeral current input, When Set is tapped, Then clear before write.
                onPressed: enabled
                    ? () => _credential(controller, id, clear: false)
                    : null,
                child: const Text('Set credential'),
              ),
              TextButton(
                // Given explicit revocation, When Clear is tapped, Then send null for this ID.
                onPressed: enabled
                    ? () => _credential(controller, id, clear: true)
                    : null,
                child: const Text('Clear credential'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
