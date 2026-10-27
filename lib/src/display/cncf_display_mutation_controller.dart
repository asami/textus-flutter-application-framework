import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../resource/cncf_display_resource_data_source.dart';
import '../resource/resource_view_model.dart';

/// One descriptor-driven Text editing session, borrowing all read/transport owners.
/// Disposal retires continuations; it cannot roll back a dispatched command.
final class CncfDisplayMutationController extends ChangeNotifier {
  CncfDisplayMutationController({
    required this.source,
    required this.viewModel,
  }) {
    if (!identical(viewModel.dataSource, source)) {
      throw ArgumentError('The View Model must borrow the selected source');
    }
  }

  final CncfDisplayResourceDataSource source;
  final ResourceViewModel viewModel;
  bool _busy = false;
  bool _editorOpen = false;
  bool _needsReconciliation = false;
  bool _isDisposed = false;
  bool _publishing = false;
  bool _retiredDraft = false;
  bool _accepted = false;
  bool _commandStarted = false;
  int _generation = 0;
  CncfDisplayMutationDescriptor? _descriptor;
  CncfDisplayRead? _observation;
  CncfDisplayMutationResult? _receipt;
  CncfDisplayReadException? _failure;
  Map<CncfDisplayFieldLocator, String> _initial = const {};
  Map<CncfDisplayFieldLocator, String> _draft = const {};
  Map<CncfDisplayFieldLocator, String> _errors = const {};

  bool get busy => _busy;
  bool get editorOpen => _editorOpen;
  bool get needsReconciliation => _needsReconciliation;
  bool get isDisposed => _isDisposed;
  CncfDisplayMutationDescriptor? get descriptor => _descriptor;
  CncfDisplayRead? get observation => _observation;
  CncfDisplayMutationResult? get receipt => _receipt;
  CncfDisplayReadException? get failure => _failure;
  Map<CncfDisplayFieldLocator, String> get draftValues => _draft;
  Map<CncfDisplayFieldLocator, String> get initialValues => _initial;
  Map<CncfDisplayFieldLocator, String> get fieldErrors => _errors;
  bool get canSave =>
      !_isDisposed &&
      !_busy &&
      _editorOpen &&
      !_needsReconciliation &&
      !_retiredDraft &&
      !_accepted &&
      _descriptor != null &&
      _draft.isNotEmpty &&
      _selectionMatches();

  bool get _idle => !_isDisposed && !_busy && !_publishing;
  bool _current(int generation) => !_isDisposed && generation == _generation;

  bool _selectionMatches() {
    final observed = _observation;
    return observed != null &&
        observed.resources.length == 1 &&
        identical(source.lastDetail, observed) &&
        !viewModel.detailFailed &&
        !viewModel.detailLoading &&
        viewModel.selectedId == observed.resources.single.entityId &&
        viewModel.selectedResource?.id == observed.resources.single.entityId;
  }

  Future<void> beginEdit() async {
    if (!_idle || _editorOpen || _needsReconciliation) {
      return;
    }
    final observed = source.lastDetail;
    if (observed == null ||
        observed.resources.length != 1 ||
        viewModel.detailLoading ||
        viewModel.detailFailed ||
        viewModel.selectedId != observed.resources.single.entityId ||
        viewModel.selectedResource?.id != observed.resources.single.entityId) {
      return;
    }
    final generation = ++_generation;
    _observation = observed;
    _descriptor = null;
    _initial = const {};
    _draft = const {};
    _errors = const {};
    _failure = null;
    _retiredDraft = false;
    _accepted = false;
    _editorOpen = true;
    _busy = true;
    _publish();
    try {
      final descriptor = await source.client.describeMutation();
      if (!_current(generation)) {
        return;
      }
      if (!_selectionMatches()) {
        throw const CncfDisplayReadException('selectionChanged');
      }
      final fields = <CncfDisplayFieldLocator, Map<String, Object?>>{};
      for (final section in observed.model['sections']! as List) {
        final map = section as Map<String, Object?>;
        for (final item in map['fields']! as List) {
          final field = item as Map<String, Object?>;
          fields[CncfDisplayFieldLocator(
                map['id']! as String,
                field['id']! as String,
              )] =
              field;
        }
      }
      final values = <CncfDisplayFieldLocator, String>{};
      for (final field in descriptor.fields) {
        final read = fields[field.locator];
        if (read == null) {
          throw const CncfDisplayReadException('descriptorFieldMismatch');
        }
        final value = read['value']! as Map<String, Object?>;
        if (descriptor.supports('update') &&
            descriptor.isAvailable('update') &&
            field.isEditableText &&
            value['type'] == 'text') {
          values[field.locator] = value['text']! as String;
        }
      }
      _descriptor = descriptor;
      _initial = Map.unmodifiable(values);
      _draft = Map.unmodifiable(values);
    } catch (error) {
      if (!_current(generation)) {
        return;
      }
      _failure = _redacted(error);
    } finally {
      if (_current(generation)) {
        _busy = false;
        _publish();
      }
    }
  }

  void setText(CncfDisplayFieldLocator locator, String text) {
    if (!_idle || !canSave || !_draft.containsKey(locator)) {
      return;
    }
    if (_draft[locator] == text && !_errors.containsKey(locator)) {
      return;
    }
    _draft = Map.unmodifiable({..._draft, locator: text});
    _errors = Map.unmodifiable({..._errors}..remove(locator));
    _failure = null;
    _publish();
  }

  Future<bool> save() async {
    if (!_idle || !canSave) {
      return false;
    }
    final generation = _generation;
    final changes = [
      for (final field in _descriptor!.fields)
        if (_draft.containsKey(field.locator) &&
            _draft[field.locator] != _initial[field.locator])
          CncfDisplayTextChange(field.locator, _draft[field.locator]!),
    ];
    if (changes.isEmpty) {
      changes.addAll([
        for (final field in _descriptor!.fields)
          if (_draft.containsKey(field.locator))
            CncfDisplayTextChange(field.locator, _draft[field.locator]!),
      ]);
    }
    _busy = true;
    _commandStarted = true;
    _failure = null;
    _errors = const {};
    _publish();
    try {
      final receipt = await source.client.update(
        descriptor: _descriptor!,
        observation: _observation!,
        changes: changes,
      );
      if (!_current(generation)) {
        return false;
      }
      _commandStarted = false;
      // Publish authoritative command evidence before even starting a safe GET.
      _receipt = receipt;
      _accepted = true;
      _needsReconciliation = true;
      _publish();
      if (!_current(generation) || receipt.reloadRequired) {
        return false;
      }
      return await _refresh(generation);
    } catch (error) {
      if (!_current(generation)) {
        return false;
      }
      _failure = _redacted(error);
      final structured = _failure!.failure;
      if (structured != null &&
          structured.isEditableRejection &&
          _draft.containsKey(structured.fieldLocator)) {
        _errors = Map.unmodifiable({
          structured.fieldLocator!:
              'Invalid value (${structured.diagnosticCode})',
        });
      } else {
        _needsReconciliation = true;
        _retiredDraft = true;
      }
      return false;
    } finally {
      if (_current(generation)) {
        _commandStarted = false;
        _busy = false;
        _publish();
      }
    }
  }

  /// Reconciliation only: never dispatches or retries a command.
  Future<bool> reload() async {
    if (!_idle || !_needsReconciliation || _observation == null) {
      return false;
    }
    final generation = _generation;
    _busy = true;
    _publish();
    try {
      return await _refresh(generation);
    } catch (error) {
      if (_current(generation)) {
        _failure = _redacted(error);
      }
      return false;
    } finally {
      if (_current(generation)) {
        _busy = false;
        _publish();
      }
    }
  }

  Future<bool> _refresh(int generation) async {
    final id = _observation!.resources.single.entityId;
    if (viewModel.selectedId != id) {
      return false;
    }
    final oldDetail = source.lastDetail;
    await viewModel.detailView.refresh();
    if (!_current(generation)) {
      return false;
    }
    final oldQuery = source.lastQuery;
    await viewModel.collectionView.load();
    if (!_current(generation)) {
      return false;
    }
    final detail = source.lastDetail;
    final query = source.lastQuery;
    final floor = BigInt.parse(
      _accepted ? _receipt!.revision : _observation!.resources.single.revision,
    );
    final rows = query?.resources.where((row) => row.entityId == id).toList();
    final coherent =
        !viewModel.detailFailed &&
        !viewModel.detailLoading &&
        !viewModel.listFailed &&
        !viewModel.listLoading &&
        viewModel.selectedId == id &&
        viewModel.selectedResource?.id == id &&
        detail != null &&
        !identical(detail, oldDetail) &&
        query != null &&
        !identical(query, oldQuery) &&
        detail.resources.length == 1 &&
        detail.resources.single.entityId == id &&
        rows != null &&
        rows.length == 1 &&
        detail.resources.single.revision == rows.single.revision &&
        BigInt.parse(detail.resources.single.revision) >= floor;
    if (!coherent) {
      _failure = const CncfDisplayReadException('reconciliationRequired');
      return false;
    }
    _needsReconciliation = false;
    _failure = null;
    if (_accepted) {
      _clearEditor();
      return true;
    }
    // A rejected/unknown draft remains retired until the user discards it.
    return false;
  }

  void discard() {
    if (!_idle) {
      return;
    }
    ++_generation;
    _clearEditor();
    _publish();
  }

  void _clearEditor() {
    _editorOpen = false;
    _descriptor = null;
    _draft = const {};
    _initial = const {};
    _errors = const {};
    if (!_needsReconciliation) {
      _observation = null;
      _retiredDraft = false;
      _accepted = false;
    }
  }

  CncfDisplayReadException _redacted(Object error) =>
      error is CncfDisplayReadException
      ? error
      : const CncfDisplayReadException(
          'unclassifiedFailure',
          outcomeUnknown: true,
        );

  void _publish() {
    if (_isDisposed) {
      return;
    }
    _publishing = true;
    try {
      notifyListeners();
    } finally {
      _publishing = false;
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    if (_commandStarted) {
      _needsReconciliation = true;
      _retiredDraft = true;
    }
    _isDisposed = true;
    ++_generation;
    super.dispose();
  }
}
