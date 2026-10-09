import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

import 'audio_capture_facade.dart';

/// One original's interaction lifetime, append-only review and exact dirty buffer.
/// Owners record corrections before domain Save and await [detach] for handoff.
final class AudioCaptureController implements Listenable {
  /// Borrows an inert facade and preserves a restored review exactly.
  AudioCaptureController({
    required this.facade,
    AudioTranscriptReview? initialReview,
    this.locale = 'ja-JP',
    AudioRecordingConfiguration? configuration,
    DateTime Function()? now,
  }) : configuration = configuration ?? AudioRecordingConfiguration(),
       _now = now ?? DateTime.now,
       _review = initialReview,
       _draftText = initialReview?.currentText ?? '' {
    if (!RegExp(r'^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$').hasMatch(locale)) {
      throw ArgumentError.value(locale, 'locale', 'invalid language tag');
    }
  }

  /// Caller-owned Core forwarding boundary.
  final AudioCaptureFacade facade;

  /// Exact recognition locale.
  final String locale;

  /// Explicit capture duration limit.
  final AudioRecordingConfiguration configuration;
  final DateTime Function() _now;
  final _AudioNotifier _notifier = _AudioNotifier();
  final List<_AudioListener> _listeners = [];
  final Set<Future<void>> _settling = {};
  AudioTranscriptReview? _review;
  String _draftText;
  bool _dirty = false;
  bool _detached = false;
  bool _disposed = false;
  bool _notifierDisposed = false;
  bool _recordingOwned = false;
  bool _recordingStarted = false;
  bool _interrupting = false;
  bool _interruptLaunched = false;
  AudioCaptureState? _operation;
  AudioCaptureState? _activeOperation;
  AudioProviderAvailability? _availability;
  Object? _error;
  Object? _cleanupError;
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _generation = 0;
  int _notificationDepth = 0;
  Future<void>? _detachment;

  /// Shared Core state; external work is never owned by this controller.
  AudioCaptureState get state => facade.state;

  /// Local active command or persistent owned recording.
  bool get busy => _settling.isNotEmpty || _recordingOwned;

  /// Whether the owned microphone start actually succeeded.
  bool get recordingStarted => _recordingStarted;

  /// UI seconds, clamped to the capture limit without automatic stop.
  int get elapsedSeconds => _elapsedSeconds;

  /// Last exact successful readiness snapshot.
  AudioProviderAvailability? get availability => _availability;

  /// Actual last command error, without transformation.
  Object? get error => _error;

  /// First actual detach cleanup failure, retained for owner inspection.
  Object? get cleanupError => _cleanupError;

  /// Exact immutable review, including a save completed after detach.
  AudioTranscriptReview? get review => _review;

  /// Exact editable text separate from recorded revisions and domain storage.
  String get draftText => _draftText;

  /// Explicit user intent awaiting a recorded revision, including empty clear.
  bool get hasUnsavedText => _dirty;

  /// Whether this interaction lifetime has terminally detached.
  bool get isDetached => _detached;

  /// Whether listener resources have been disposed.
  bool get isDisposed => _disposed;

  bool get _live => !_detached && !_disposed;
  bool get _idle => _live && !busy && state == AudioCaptureState.idle;
  bool get _ordinary => _idle && facade.pendingOriginal == null;

  /// Whether a first original may be recorded on the supported idle runtime.
  bool get canStartRecording =>
      _ordinary && _review == null && facade.isSupported;

  /// Whether successful owned recording can explicitly stop and save.
  bool get canStopRecording => canCancelRecording && _recordingStarted;

  /// Whether this controller can interrupt its own pending/active recording.
  bool get canCancelRecording =>
      _live &&
      !_interrupting &&
      _recordingOwned &&
      _operation == AudioCaptureState.recording &&
      state == AudioCaptureState.recording;

  /// Whether retained original import can be retried without capture.
  bool get canRetryPendingOriginal =>
      _idle && _review == null && facade.pendingOriginal != null;

  /// Whether exact original replay can start.
  bool get canPlayOriginal =>
      _ordinary && _review != null && facade.isSupported;

  /// Whether this controller can interrupt its own playback.
  bool get canStopPlayback =>
      _live &&
      !_interrupting &&
      _operation == AudioCaptureState.playing &&
      state == AudioCaptureState.playing;

  /// Whether saved-input recognition can recheck actual provider readiness.
  bool get canTranscribe => _ordinary && _review != null;

  /// Whether explicit preparation is offered for known downloadable readiness.
  bool get canPrepareTranscription =>
      _ordinary && _availability?.state == AudioProviderState.downloadable;

  /// Whether this controller owns interruptible readiness or recognition work.
  bool get canCancelTranscription =>
      _live &&
      !_interrupting &&
      (_operation == AudioCaptureState.preparing ||
          _operation == AudioCaptureState.transcribing) &&
      (state == AudioCaptureState.preparing ||
          state == AudioCaptureState.transcribing);

  /// Whether exact manual text may be edited, independent of runtime readiness.
  bool get canEditTranscript => _live && _review != null;

  /// Whether explicit dirty intent may be appended as a manual revision.
  bool get canRecordCorrection => canEditTranscript && _dirty;

  /// Explicitly checks exact-locale readiness.
  Future<AudioProviderAvailability> refreshAvailability() {
    _require(_ordinary);
    return _command(AudioCaptureState.preparing, () async {
      final value = await facade.availability(locale: locale);
      _availability = value;
      return value;
    });
  }

  /// Explicitly prepares the model; Core remains actual capability authority.
  Future<AudioProviderAvailability> prepareTranscription() {
    _require(_ordinary);
    return _command(AudioCaptureState.preparing, () async {
      final value = await facade.prepareTranscription(locale: locale);
      _availability = value;
      return value;
    });
  }

  /// Reserves microphone ownership before notification or provider work.
  Future<void> startRecording() {
    _require(canStartRecording);
    _recordingOwned = true;
    _elapsedSeconds = 0;
    return _command(AudioCaptureState.recording, () async {
      try {
        await facade.startRecording(configuration: configuration);
        if (_live && !_interrupting && state == AudioCaptureState.recording) {
          _recordingStarted = true;
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (!_live || !_recordingStarted) return;
            if (_elapsedSeconds < configuration.maxDurationSeconds) {
              _elapsedSeconds++;
            }
            _notify();
          });
        }
      } catch (_) {
        _stopTimer();
        if (state != AudioCaptureState.recording) _recordingOwned = false;
        rethrow;
      }
    });
  }

  /// Explicitly saves a successful recording and retains its durable original.
  Future<AudioTranscriptReview> stopRecording() {
    _require(canStopRecording);
    _stopTimer();
    return _command(AudioCaptureState.saving, () async {
      final Future<OriginalAudio> saving = facade.stopRecording();
      _recordingOwned = false;
      _activeOperation = AudioCaptureState.saving;
      return _acceptOriginal(await saving);
    });
  }

  /// Retries exact retained bytes and accepts only durable success.
  Future<AudioTranscriptReview> retryPendingOriginal() {
    _require(canRetryPendingOriginal);
    return _command(
      AudioCaptureState.saving,
      () async => _acceptOriginal(await facade.retryPendingOriginal()),
    );
  }

  AudioTranscriptReview _acceptOriginal(OriginalAudio original) {
    final value = AudioTranscriptReview(original: original);
    _review = value;
    _draftText = '';
    _dirty = false;
    return value;
  }

  /// Cancels only this controller's unsaved microphone work.
  Future<void> cancelRecording() {
    _require(canCancelRecording);
    _stopTimer();
    return _command(AudioCaptureState.recording, () async {
      try {
        await facade.cancelRecording();
      } finally {
        _recordingOwned = false;
      }
    }, interrupt: true);
  }

  /// Replays the unchanged original without any import.
  Future<void> playOriginal() {
    _require(canPlayOriginal);
    final original = _review!.original;
    return _command(
      AudioCaptureState.playing,
      () => facade.playOriginal(original),
    );
  }

  /// Interrupts only owned playback.
  Future<void> stopPlayback() {
    _require(canStopPlayback);
    return _command(
      AudioCaptureState.playing,
      facade.stopPlayback,
      interrupt: true,
    );
  }

  /// Appends Core's exact result to the latest concurrently edited review.
  Future<AudioTranscriptReview> transcribe() {
    _require(canTranscribe);
    final original = _review!.original;
    return _command(AudioCaptureState.transcribing, () async {
      final report = await facade.transcribe(original, locale: locale);
      final value = _review!.appendReport(report);
      _review = value;
      if (!_dirty) _draftText = value.currentText ?? '';
      return value;
    });
  }

  /// Interrupts only owned readiness, preparation or recognition.
  Future<void> cancelTranscription() {
    _require(canCancelTranscription);
    return _command(_operation!, facade.cancelTranscription, interrupt: true);
  }

  /// Marks exact user intent even when it equals canonical text or is empty.
  void setDraftText(String exactText) {
    _require(canEditTranscript);
    _draftText = exactText;
    _dirty = true;
    _notify();
  }

  /// Explicitly records a manual revision; domain persistence remains the owner.
  AudioTranscriptReview recordCorrection() {
    _require(canEditTranscript);
    if (!_dirty) return _review!;
    final value = _review!.correct(_draftText, recordedAt: _revisionTime());
    _review = value;
    _dirty = false;
    _notify();
    return value;
  }

  /// Explicitly selects a successful proposal, replacing even a dirty buffer.
  AudioTranscriptReview useReport(String id) {
    _require(canEditTranscript);
    final reports = _review!.reports.where((report) => report.id == id);
    final source = reports.isEmpty ? null : reports.single;
    final value = _review!.useReport(
      id,
      recordedAt: _revisionTime(source: source),
    );
    _review = value;
    _draftText = value.currentText!;
    _dirty = false;
    _notify();
    return value;
  }

  DateTime _revisionTime({AudioTranscriptReport? source}) {
    final current = _review!;
    var value = _now().toUtc();
    final selectedId = current.revisions.isEmpty
        ? null
        : current.revisions.last.reportId;
    final selected = current.reports.where((report) => report.id == selectedId);
    final floors = [
      current.original.material.capturedAt,
      if (current.revisions.isNotEmpty) current.revisions.last.recordedAt,
      if (source != null) source.completedAt,
      if (selected.isNotEmpty) selected.single.completedAt,
    ];
    for (final floor in floors) {
      if (value.isBefore(floor)) value = floor;
    }
    return value;
  }

  void _require(bool allowed) {
    if (!allowed) {
      throw StateError('Audio interaction is unavailable, busy or detached');
    }
  }

  Future<T> _command<T>(
    AudioCaptureState operation,
    Future<T> Function() action, {
    bool interrupt = false,
  }) {
    final token = ++_generation;
    final completion = Completer<T>();
    late final Future<void> settled;
    settled = completion.future.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _settling.add(settled);
    _operation = operation;
    if (interrupt) _interrupting = true;
    _error = null;
    _notify();
    Future<void> run() async {
      var launched = false;
      T? result;
      Object? failure;
      StackTrace? failureStack;
      try {
        if (!_live) {
          throw StateError('Audio interaction detached before launch');
        }
        launched = true;
        if (interrupt) {
          _interruptLaunched = true;
        } else if (operation != AudioCaptureState.saving || !_recordingOwned) {
          _activeOperation = operation;
        }
        result = await action();
        _error = null;
      } catch (error, stack) {
        _error = error;
        failure = error;
        failureStack = stack;
        if (!launched &&
            !interrupt &&
            operation == AudioCaptureState.recording) {
          _recordingOwned = false;
        }
      } finally {
        if (token == _generation) {
          _interrupting = false;
          _interruptLaunched = false;
          if (!_recordingOwned) {
            _operation = null;
            _activeOperation = null;
          }
        }
        // Release local reservation before returning completion to the caller.
        _settling.remove(settled);
        if (failure == null) {
          completion.complete(result as T);
        } else {
          completion.completeError(failure, failureStack!);
        }
        _notify();
      }
    }

    unawaited(run());
    return completion.future;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _recordingStarted = false;
  }

  /// Terminally detaches once, cancels only owned work and awaits all own commands.
  /// Saving is retained for owner handoff; the facade, service and store are borrowed.
  Future<void> detach() {
    if (_detachment != null) return _detachment!;
    final completion = Completer<void>();
    _detachment = completion.future;
    _detached = true;
    _stopTimer();
    final prior = List<Future<void>>.of(_settling);
    Future<void> cleanup() async {
      Object? failure;
      StackTrace? failureStack;
      try {
        if (_activeOperation != null && !_interruptLaunched) {
          if (_activeOperation == AudioCaptureState.recording &&
              state == AudioCaptureState.recording) {
            await facade.cancelRecording();
          } else if (_activeOperation == AudioCaptureState.playing &&
              state == AudioCaptureState.playing) {
            await facade.stopPlayback();
          } else if ((_activeOperation == AudioCaptureState.preparing ||
                  _activeOperation == AudioCaptureState.transcribing) &&
              state == _activeOperation) {
            await facade.cancelTranscription();
          }
        }
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
        _cleanupError ??= error;
      }
      await Future.wait(prior);
      _recordingOwned = false;
      if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
    }

    cleanup().then(
      completion.complete,
      onError: (Object error, StackTrace stack) =>
          completion.completeError(error, stack),
    );
    return completion.future;
  }

  @override
  void addListener(VoidCallback listener) {
    _require(_live);
    final entry = _AudioListener(listener, () {
      if (_live) listener();
    });
    _listeners.add(entry);
    _notifier.addListener(entry.guarded);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_notifierDisposed) return;
    final index = _listeners.indexWhere((entry) => entry.original == listener);
    if (index < 0) return;
    _notifier.removeListener(_listeners.removeAt(index).guarded);
  }

  void _notify() {
    if (!_live) return;
    _notificationDepth++;
    try {
      _notifier.emit();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) _disposeNotifier();
    }
  }

  /// Detaches with an observed failure handler and safely releases listener resources.
  void dispose() {
    if (_disposed) return;
    unawaited(
      detach().then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    _disposed = true;
    for (final entry in _listeners) {
      _notifier.removeListener(entry.guarded);
    }
    _listeners.clear();
    if (_notificationDepth == 0) _disposeNotifier();
  }

  void _disposeNotifier() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    _notifier.dispose();
  }
}

final class _AudioNotifier extends ChangeNotifier {
  void emit() {
    notifyListeners();
  }
}

final class _AudioListener {
  _AudioListener(this.original, this.guarded);
  final VoidCallback original;
  final VoidCallback guarded;
}
