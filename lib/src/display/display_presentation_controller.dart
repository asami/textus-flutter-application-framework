import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import '../view/resource_list_detail_display_model.dart';
import 'display_definition_registry.dart';

/// Immutable semantic inputs copied from accepted writable bindings.
final class DisplayDraft {
  DisplayDraft._({
    required this.generation,
    required this.resourceId,
    required this.definition,
    required this.definitionKey,
    required this.observedRevision,
    required Iterable<DisplayEditBinding> bindings,
    required Map<DisplayFieldLocator, DisplayValue?> initialValues,
    required Map<DisplayFieldLocator, DisplayValue?> values,
    this.needsReconciliation = false,
  }) : bindings = List.unmodifiable(bindings),
       initialValues = Map.unmodifiable(initialValues),
       values = Map.unmodifiable(values);
  final int generation;
  final String resourceId;
  final DisplayUiDefinition definition;
  final DisplayDefinitionKey? definitionKey;
  final int observedRevision;
  final List<DisplayEditBinding> bindings;
  final Map<DisplayFieldLocator, DisplayValue?> initialValues;
  final Map<DisplayFieldLocator, DisplayValue?> values;
  final bool needsReconciliation;
  bool get hasUnsavedChanges =>
      values.entries.any((entry) => initialValues[entry.key] != entry.value);

  DisplayDraft replace({
    Map<DisplayFieldLocator, DisplayValue?>? values,
    bool? needsReconciliation,
  }) => DisplayDraft._(
    generation: generation,
    resourceId: resourceId,
    definition: definition,
    definitionKey: definitionKey,
    observedRevision: observedRevision,
    bindings: bindings,
    initialValues: initialValues,
    values: values ?? this.values,
    needsReconciliation: needsReconciliation ?? this.needsReconciliation,
  );
}

/// Presentation snapshot retaining Core's independently observable history.
final class DisplayPresentationState {
  DisplayPresentationState._({
    required this.session,
    required this.resolution,
    required this.displayedDefinition,
    required this.draft,
    required Iterable<DisplayFieldError> fieldErrors,
    required this.busy,
  }) : fieldErrors = List.unmodifiable(fieldErrors);
  final DisplaySessionState session;
  final DisplayDefinitionResolution resolution;
  final DisplayUiDefinition? displayedDefinition;
  final DisplayDraft? draft;
  final List<DisplayFieldError> fieldErrors;
  final bool busy;
  bool get canEdit => !busy && resolution.isAvailable && session.canMutate;
  bool get canSave =>
      canEdit &&
      draft != null &&
      !draft!.needsReconciliation &&
      draft!.resourceId == session.selectedResourceId &&
      draft!.definition == resolution.definition;
  bool get canOperate => canEdit && draft == null;
}

/// Outcome of an explicit selection, without implicit draft loss.
enum DisplayNavigationOutcome { selected, discardRequired, failed }

/// Owns one Core session and one adaptive model; no transport metadata is copied.
final class DisplayPresentationController extends ChangeNotifier {
  DisplayPresentationController({
    required this._session,
    required this._registry,
  }) {
    if (_session.isDisposed) {
      throw ArgumentError('Cannot own a disposed session');
    }
    _emit = () {
      super.notifyListeners();
    };
    resolveDefinition();
    _state = snapshot();
    _session.addListener(sessionChanged);
    displayModel.addListener(modelChanged);
  }
  late final VoidCallback _emit;
  DisplaySession _session;
  DisplayDefinitionRegistry _registry;

  /// Owned presentation preferences, available to a borrowed Settings binding.
  final ResourceListDetailDisplayModel displayModel =
      ResourceListDetailDisplayModel();
  DisplaySession get session => _session;
  DisplayDefinitionRegistry get registry => _registry;
  bool get isDisposed => _disposed;
  DisplayPresentationState get state => _state;
  late DisplayPresentationState _state;
  late DisplayDefinitionResolution _resolution;
  DisplayUiDefinition? _displayed;
  DisplayDraft? _draft;
  List<DisplayFieldError> _errors = [];
  int _generation = 0;
  int? _submittedGeneration;
  int? _expectedSequence;
  int _notificationDepth = 0;
  bool _acting = false;
  bool _disposed = false;

  /// Explicit initial query with no eager Detail.
  Future<void> load() => act((session) => session.query());

  /// Explicit safe collection retry.
  Future<void> retryList() => act((session) => session.retryList());

  /// Explicit safe retry of accepted Detail.
  Future<void> retryDetail() => act((session) => session.retryDetail());

  /// Explicit safe read/query reconciliation without command replay.
  Future<void> reload() => act((session) => session.reload());

  /// Selects only after a successful read; a draft requires explicit discard.
  Future<DisplayNavigationOutcome> select(
    String resourceId, {
    bool discardDraft = false,
  }) {
    available();
    identifier(resourceId);
    final core = _session.state;
    if (resourceId == core.selectedResourceId && core.detail.data != null) {
      displayModel.openDetail();
      return Future.value(DisplayNavigationOutcome.selected);
    }
    if (core.projectionPending ||
        core.commandUncertain ||
        core.contextFailure != null) {
      throw StateError('Current flow cannot switch resource');
    }
    if (_draft != null && !discardDraft) {
      return Future.value(DisplayNavigationOutcome.discardRequired);
    }
    final captured = _session;
    final previous = core.detail.data;
    _acting = true;
    if (discardDraft) {
      _draft = null;
      _errors = [];
      resolveDefinition();
    }
    publish();
    if (!active(captured)) {
      return Future.value(DisplayNavigationOutcome.failed);
    }
    return selectReserved(captured, resourceId, previous);
  }

  /// Navigates without changing semantic selection or drafts.
  void showList() {
    available(semantic: false);
    displayModel.showList();
  }

  /// Prefers focused Detail in an expanded layout.
  void focusDetail() {
    available(semantic: false);
    displayModel.focusDetail();
  }

  /// Restores an expanded split presentation.
  void restoreSplit() {
    available(semantic: false);
    displayModel.restoreSplit();
  }

  /// Copies writable input metadata from the accepted Detail exactly once.
  void beginEdit() {
    available();
    if (!state.canEdit) {
      throw StateError('Detail is not editable');
    }
    if (_draft != null) {
      return;
    }
    final data = _session.state.detail.data!;
    final bindings = data.bindings
        .where((binding) => binding.writable)
        .toList();
    final values = {
      for (final binding in bindings) binding.locator: binding.inputValue,
    };
    _draft = DisplayDraft._(
      generation: ++_generation,
      resourceId: data.resourceId,
      definition: _resolution.definition!,
      definitionKey: _resolution.key,
      observedRevision: data.sourceRevision,
      bindings: bindings,
      initialValues: values,
      values: values,
    );
    _errors = [];
    publish();
  }

  /// Changes one scoped input without formatting or trimming it.
  void setValue(DisplayFieldLocator locator, DisplayValue? value) {
    available();
    final draft = _draft;
    if (draft == null || !draft.values.containsKey(locator)) {
      throw ArgumentError('Unknown or read-only input locator');
    }
    if (!state.canSave) {
      throw StateError('Draft is not editable');
    }
    _draft = draft.replace(values: {...draft.values, locator: value});
    _errors = _errors.where((error) => error.locator != locator).toList();
    publish();
  }

  /// Explicitly discards even an incompatible or uncertain retained draft.
  void discardDraft() {
    available();
    _draft = null;
    _errors = [];
    resolveDefinition();
    publish();
  }

  /// Reopens current accepted input after explicit reconciliation.
  void discardAndEdit() {
    available();
    if (!state.canEdit) {
      throw StateError('Current Detail is not editable');
    }
    _draft = null;
    _errors = [];
    resolveDefinition();
    beginEdit();
  }

  /// Validates Text inputs and submits ordered fields at the retained revision.
  Future<void> save() {
    available();
    if (!state.canSave) {
      throw StateError('Draft cannot be submitted');
    }
    final draft = _draft!;
    final errors = <DisplayFieldError>[];
    for (final binding in draft.bindings) {
      final value = draft.values[binding.locator];
      String? code;
      if (value is! TextDisplayValue) {
        code = 'invalid-type';
      } else if (binding.requiredNonBlank &&
          value.value.replaceAll('\u0085', ' ').trim().isEmpty) {
        code = 'required-nonblank';
      }
      if (code != null) {
        errors.add(
          DisplayFieldError(
            locator: binding.locator,
            code: code,
            message: code,
          ),
        );
      }
    }
    if (errors.isNotEmpty) {
      _errors = errors;
      publish();
      return Future.value();
    }
    _submittedGeneration = draft.generation;
    _expectedSequence = _session.state.command.sequence + 1;
    return act(
      (session) => session.update(
        observedRevision: draft.observedRevision,
        fields: [
          for (final binding in draft.bindings)
            DisplayFieldInput(
              locator: binding.locator,
              value: draft.values[binding.locator]!,
            ),
        ],
      ),
    );
  }

  /// Executes one admitted descriptor, with zero implicit Display calls.
  Future<void> executeOperation(String operationId) {
    available();
    identifier(operationId);
    if (!state.canOperate) {
      throw StateError('Operation is not eligible');
    }
    final detail = _session.state.detail.data!;
    if (!detail.model.actions.any(
      (action) => action.id == operationId && action.enabled,
    )) {
      throw ArgumentError('Unknown or disabled Operation');
    }
    return act(
      (session) => session.executeOperation(
        operationId: operationId,
        observedRevision: detail.sourceRevision,
      ),
    );
  }

  /// Dispatches the bounded unsupported create capability explicitly.
  Future<void> createUnsupported() {
    available();
    if (!_resolution.isAvailable ||
        !_session.state.canCreate ||
        _draft != null) {
      throw StateError('Create is not eligible');
    }
    return act((session) => session.create(fields: const []));
  }

  /// Dispatches the bounded unsupported delete capability explicitly.
  Future<void> deleteUnsupported() {
    available();
    if (!state.canOperate) {
      throw StateError('Delete is not eligible');
    }
    final revision = _session.state.detail.data!.sourceRevision;
    return act((session) => session.delete(observedRevision: revision));
  }

  /// Replaces registration data while pinning an incompatible retained draft.
  void updateRegistry(DisplayDefinitionRegistry registry) {
    available();
    _registry = registry;
    resolveDefinition();
    publish();
  }

  /// Transfers ownership only of a pristine distinct fixed-flow session.
  void reset({
    required DisplaySession nextSession,
    required DisplayDefinitionRegistry nextRegistry,
    bool discardDraft = false,
  }) {
    available();
    final next = nextSession.state;
    if (identical(nextSession, _session) ||
        nextSession.isDisposed ||
        next.busy ||
        next.list.phase != DisplaySessionReadPhase.idle ||
        next.detail.phase != DisplaySessionReadPhase.idle ||
        next.selectedResourceId != null ||
        next.command.sequence != 0 ||
        next.command.phase != DisplaySessionCommandPhase.idle ||
        next.projectionPending ||
        next.commandUncertain ||
        next.contextFailure != null ||
        (_draft != null && !discardDraft)) {
      throw StateError(
        'Reset requires an explicitly discarded draft and pristine new session',
      );
    }
    _acting = true;
    _session.removeListener(sessionChanged);
    _session.dispose();
    _session = nextSession;
    _registry = nextRegistry;
    _draft = null;
    _errors = [];
    _displayed = null;
    _expectedSequence = null;
    _submittedGeneration = null;
    _session.addListener(sessionChanged);
    resolveDefinition();
    displayModel.showList();
    if (!active(nextSession)) {
      return;
    }
    _acting = false;
    publish();
  }

  /// Stops owned Core immediately; releases notifiers after notification stacks.
  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _session.removeListener(sessionChanged);
    displayModel.removeListener(modelChanged);
    _session.dispose();
    scheduleMicrotask(() {
      displayModel.dispose();
      super.dispose();
    });
  }
}

extension on DisplayPresentationController {
  DisplayPresentationState snapshot() => DisplayPresentationState._(
    session: _session.state,
    resolution: _resolution,
    displayedDefinition: _displayed,
    draft: _draft,
    fieldErrors: _errors,
    busy: _acting || _session.state.busy || _disposed,
  );
  void resolveDefinition() {
    final next = _registry.resolve(
      context: _session.state.context,
      resourceType: _session.resourceType,
      listScreenId: _session.listScreenId,
      detailScreenId: _session.detailScreenId,
    );
    if (next.isAvailable &&
        _draft != null &&
        next.definition != _draft!.definition) {
      _resolution = DisplayDefinitionResolution.failed(
        const DisplayDefinitionFailure(
          kind: DisplayDefinitionFailureKind.definitionChangeRequiresDiscard,
          message: 'Discard the draft before adopting the changed definition',
        ),
        key: next.key,
      );
    } else {
      _resolution = next;
      if (next.isAvailable) {
        _displayed = next.definition;
      }
    }
  }

  void publish() {
    if (_disposed) {
      return;
    }
    _state = snapshot();
    _notificationDepth++;
    try {
      _emit();
    } finally {
      _notificationDepth--;
    }
  }

  void sessionChanged() {
    if (_disposed) {
      return;
    }
    final command = _session.state.command;
    if (_expectedSequence == command.sequence &&
        command.kind == DisplaySessionCommandKind.update &&
        _submittedGeneration == _draft?.generation) {
      final receipt = command.mutation;
      if (command.phase == DisplaySessionCommandPhase.settled &&
          receipt != null) {
        // Consume before notifying or continuing into Core's pending refresh.
        _expectedSequence = null;
        _submittedGeneration = null;
        _errors = List.of(receipt.fieldErrors);
        if (receipt.outcome == DisplayCommandOutcome.changed ||
            receipt.outcome == DisplayCommandOutcome.noOp) {
          _draft = null;
        } else if (receipt.outcome == DisplayCommandOutcome.conflict) {
          _draft = _draft!.replace(needsReconciliation: true);
        }
      } else if (command.phase == DisplaySessionCommandPhase.failed) {
        _expectedSequence = null;
        _submittedGeneration = null;
        if (_session.state.commandUncertain) {
          _draft = _draft!.replace(needsReconciliation: true);
        }
      }
    }
    resolveDefinition();
    publish();
  }

  void modelChanged() {
    if (!_disposed) {
      publish();
    }
  }

  void available({bool semantic = true}) {
    if (_disposed) {
      throw StateError('DisplayPresentationController is disposed');
    }
    if (semantic &&
        (_acting || _session.state.busy || _notificationDepth > 0)) {
      throw StateError('A presentation activity or notification is active');
    }
  }

  bool active(DisplaySession captured) =>
      !_disposed && identical(_session, captured);
  Future<void> act(Future<void> Function(DisplaySession) action) {
    available();
    final captured = _session;
    _acting = true;
    publish();
    if (!active(captured)) {
      return Future.value();
    }
    return finishActivity(captured, action);
  }

  Future<void> finishActivity(
    DisplaySession captured,
    Future<void> Function(DisplaySession) action,
  ) async {
    try {
      if (active(captured)) {
        await action(captured);
      }
    } finally {
      if (active(captured)) {
        _acting = false;
        resolveDefinition();
        publish();
      }
    }
  }

  Future<DisplayNavigationOutcome> selectReserved(
    DisplaySession captured,
    String id,
    DisplayDetailData? previous,
  ) async {
    var result = DisplayNavigationOutcome.failed;
    try {
      await captured.read(id);
      if (!active(captured)) {
        return result;
      }
      final core = captured.state;
      if (core.detail.phase == DisplaySessionReadPhase.ready &&
          core.selectedResourceId == id &&
          !identical(core.detail.data, previous)) {
        displayModel.openDetail();
        if (!active(captured)) {
          return result;
        }
        result = DisplayNavigationOutcome.selected;
      }
    } finally {
      if (active(captured)) {
        _acting = false;
        publish();
      }
    }
    return result;
  }
}
