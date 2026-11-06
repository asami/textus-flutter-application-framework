import 'package:flutter/material.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../widgets/application_text_scaling.dart';
import '../widgets/application_text_toolbar.dart';
import 'submission_settings_controller.dart';

/// Separate submission configuration route borrowing an explicitly loaded owner.
class SubmissionSettingsPage extends StatefulWidget {
  const SubmissionSettingsPage({
    required this.controller,
    this.title = '送信設定',
    this.tklDeliveryOnly = false,
    this.participantAuthenticationRequired = false,
    this.onOpenAccount,
    super.key,
  });

  final SubmissionSettingsController controller;
  final String title;

  /// This route bootstraps TKL; physical Google storage is server-owned.
  final bool tklDeliveryOnly;

  /// Read-only presentation policy; Core retains all permission authority.
  final bool participantAuthenticationRequired;
  final VoidCallback? onOpenAccount;

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

  bool get _participantMode => widget.participantAuthenticationRequired ||
      widget.controller.snapshot?.participantAuthentication != null;

  // Given a retained technical control, recheck current presentation policy too.
  bool _technicalCurrent(SubmissionSettingsController controller) =>
      _current(controller) && !_participantMode;

  void _addDrive(SubmissionSettingsController controller) {
    // Given explicit new-target input, When Add is tapped while current,
    // Then construct only that immutable definition or show a fixed safe error.
    if (!_technicalCurrent(controller)) return;
    try {
      final connection = DriveSubmissionConnection(
        id: _driveId.text,
        accountId: _account.text,
        folderId: _folder.text,
      );
      setState(() => _formFailure = null);
      if (_technicalCurrent(controller)) controller.putDrive(connection);
    } on ArgumentError {
      setState(() => _formFailure = '送信設定を確認してください。');
    }
  }

  void _addHttp(SubmissionSettingsController controller) {
    // Given explicit endpoint input, When Add is tapped while current,
    // Then Core validates HTTPS without acquisition, authorization or selection.
    if (!_technicalCurrent(controller)) return;
    try {
      final connection = HttpSubmissionConnection(
        id: _httpId.text,
        endpoint: Uri.parse(_endpoint.text),
        requiresBearerToken: widget.tklDeliveryOnly || _requiresBearer,
      );
      if (widget.tklDeliveryOnly && !connection.endpoint.path.endsWith('/')) {
        throw ArgumentError('TKL requires an HTTPS service root.');
      }
      setState(() => _formFailure = null);
      if (_technicalCurrent(controller)) controller.putHttp(connection);
    } on ArgumentError {
      setState(() => _formFailure = '送信設定を確認してください。');
    } on FormatException {
      setState(() => _formFailure = '送信設定を確認してください。');
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
        const Text('設定はこれから登録する送信内容に適用されます'),
        if (!widget.tklDeliveryOnly) ...[
          const Text('原本の保存先'),
          DropdownButton<String>(
            isExpanded: true,
            value: snapshot.selectedStorageConnectionId,
            hint: const Text('未選択'),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('未選択')),
              for (final drive in snapshot.driveConnections)
                DropdownMenuItem(value: drive.id, child: Text(drive.id)),
            ],
            // Given a rendered snapshot, When changed, Then recheck its current owner.
            onChanged: enabled
                ? (id) {
                    if (_technicalCurrent(controller)) {
                      controller.select(
                        storageConnectionId: id,
                        transportConnectionId:
                            snapshot.selectedTransportConnectionId,
                      );
                    }
                  }
                : null,
          ),
        ],
        Text(
          widget.tklDeliveryOnly
              ? 'TKL接続'
              : '送信先',
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: snapshot.selectedTransportConnectionId,
          hint: const Text('未選択'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('未選択')),
            for (final http in snapshot.httpConnections)
              DropdownMenuItem(value: http.id, child: Text(http.id)),
          ],
          // Given both defaults, When transport changes, Then retain desired storage.
          onChanged: enabled
              ? (id) {
                  if (_technicalCurrent(controller)) {
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
        Text('Drive接続ID: ${drive.id}'),
        Text('Googleアカウント: ${drive.accountId}'),
        Text('フォルダー: ${drive.folderId}'),
        Text('利用許可: ${_authorizationLabel(authorization)}'),
        if (controller.hasDriveAuthorization)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                // Given this Drive接続ID, When tapped while current, Then refresh it only.
                onPressed: enabled
                    ? () {
                        if (_technicalCurrent(controller)) {
                          controller.refreshAuthorization(drive.id);
                        }
                      }
                    : null,
                child: const Text('許可状態を確認'),
              ),
              TextButton(
                // Given this Drive接続ID, When explicitly tapped, Then authorize it only.
                onPressed: enabled
                    ? () {
                        if (_technicalCurrent(controller)) {
                          controller.authorizeDrive(drive.id);
                        }
                      }
                    : null,
                child: const Text('利用を許可'),
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
    final participant = _participantMode;
    final accountOpener = widget.onOpenAccount;
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
              if (participant)
                const Text('アカウントでログインして送信します。送信先は担当者が管理します。'),
              if (participant && accountOpener != null)
                TextButton(
                  onPressed: enabled
                      ? () {
                          if (_current(controller) &&
                              identical(accountOpener, widget.onOpenAccount)) {
                            accountOpener();
                          }
                        }
                      : null,
                  child: const Text('アカウントを開く'),
                ),
              if (!participant && widget.tklDeliveryOnly)
                const Text(
                  '保存先と転送方法はTKLが指定します。Google側の保存先はサーバーで設定します。',
                ),
              if (!participant && snapshot != null)
                _defaults(controller, snapshot, enabled),
              Wrap(
                children: [
                  TextButton(
                    // Given explicit retry intent, When current, Then read configuration.
                    onPressed: enabled
                        ? () {
                            if (_current(controller)) controller.load();
                          }
                        : null,
                    child: const Text('再読み込み'),
                  ),
                ],
              ),
              if (controller.loading)
                const Text('送信設定を読み込んでいます…')
              else if (controller.failed)
                Text(_configurationFailureLabel(controller.failureCode))
              else if (snapshot == null)
                const Text('送信設定はまだ読み込まれていません。')
              else if (participant &&
                  (snapshot.participantAuthentication == null ||
                      snapshot.selectedTransportConnectionId == null))
                const Text('送信先を準備中です。担当者に確認してください。')
              else if (!participant && snapshot.driveConnections.isEmpty &&
                  snapshot.httpConnections.isEmpty)
                const Text('送信先が設定されていません。'),
              if (!participant && _formFailure != null) Text(_formFailure!),
              if (!participant && snapshot != null) ...[
                if (!widget.tklDeliveryOnly)
                  for (final drive in snapshot.driveConnections)
                    _drive(controller, drive, enabled),
                for (final http in snapshot.httpConnections)
                  _HttpSettingsEditor(
                    key: ValueKey((controller, http.id)),
                    controller: controller,
                    connection: http,
                    snapshot: snapshot,
                    tklDeliveryOnly: widget.tklDeliveryOnly,
                    technicalCurrent: () => _technicalCurrent(controller),
                  ),
                const Divider(),
                if (!widget.tklDeliveryOnly) ...[
                  const Text('Drive接続を追加'),
                  _field(_driveId, 'Drive接続ID', enabled),
                  _field(_account, 'Googleアカウント', enabled),
                  _field(_folder, 'フォルダーID', enabled),
                  TextButton(
                    // Given form input, When explicitly tapped, Then add one safe definition.
                    onPressed: enabled ? () => _addDrive(controller) : null,
                    child: const Text('Drive接続を追加'),
                  ),
                ],
                Text(
                  widget.tklDeliveryOnly
                      ? 'TKL接続を追加（検証・初期設定用）'
                      : 'HTTP接続を追加',
                ),
                _field(_httpId, '接続ID', enabled),
                _field(
                  _endpoint,
                  widget.tklDeliveryOnly
                      ? 'TKLのHTTPS接続先（末尾は /）'
                      : 'HTTPS接続先',
                  enabled,
                ),
                if (!widget.tklDeliveryOnly)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('認証が必要'),
                    value: _requiresBearer,
                    // Given this new definition, When toggled, Then change only form intent.
                    onChanged: enabled
                        ? (value) {
                            if (_technicalCurrent(controller)) {
                              setState(() => _requiresBearer = value ?? true);
                            }
                          }
                        : null,
                  ),
                TextButton(
                  // Given form input, When explicitly tapped, Then add one HTTPS definition.
                  onPressed: enabled ? () => _addHttp(controller) : null,
                  child: const Text('HTTP接続を追加'),
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
    required this.technicalCurrent,
    this.tklDeliveryOnly = false,
    super.key,
  });

  final SubmissionSettingsController controller;
  final HttpSubmissionConnection connection;
  final SubmissionConfigurationSnapshot snapshot;
  final bool Function() technicalCurrent;
  final bool tklDeliveryOnly;

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
      widget.technicalCurrent() &&
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
        Text('接続ID: $id'),
        Text('HTTPS接続先: ${widget.connection.endpoint}'),
        Text('認証が必要: ${widget.connection.requiresBearerToken ? '必要' : '不要'}'),
        if (!widget.tklDeliveryOnly) ...[
          Text(
            '原本の参照設定: ${declaration == null
                ? '未確認'
                : declaration.isEmpty
                ? '参照先なし'
                : declaration.join(', ')}',
          ),
          const Text('この設定だけではリモート側の許可は付与・確認されません'),
          for (final drive in widget.snapshot.driveConnections)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${drive.id}の原本を参照'),
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
            child: const Text('原本の参照設定を保存'),
          ),
        ],
        if (controller.hasHttpCredentialWriter) ...[
          TextField(
            controller: _token,
            enabled: enabled,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: '$idの認可情報（検証・初期設定用）'),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                // Given ephemeral current input, When Set is tapped, Then clear before write.
                onPressed: enabled
                    ? () => _credential(controller, id, clear: false)
                    : null,
                child: const Text('認可情報を設定'),
              ),
              TextButton(
                // Given explicit revocation, When Clear is tapped, Then send null for this ID.
                onPressed: enabled
                    ? () => _credential(controller, id, clear: true)
                    : null,
                child: const Text('認可情報を解除'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String _authorizationLabel(SubmissionAuthorizationState? state) => switch (state) {
  SubmissionAuthorizationState.available => '利用可能',
  SubmissionAuthorizationState.authorizationRequired => '認証が必要',
  SubmissionAuthorizationState.unavailable => '利用不可',
  null => '未確認',
};

String _configurationFailureLabel(String? code) => switch (code) {
  'configurationInvalid' => '送信設定を確認してください。',
  'connectionConflict' => '同じ接続IDに別の設定が登録されています。',
  'connectionMissing' => '接続先が設定されていません。',
  'configurationClosed' => 'この送信設定は閉じられました。',
  'authorizationRequired' => '認証が必要です。',
  'authorizationCancelled' => '認証を取り消しました。',
  'authorizationBusy' => '認証の処理中です。',
  'foregroundRequired' => 'アプリを開いて認証してください。',
  'credentialUnavailable' => '認可情報を利用できません。',
  _ => '送信設定を読み込めませんでした。',
};
