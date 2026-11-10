import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:textus_flutter_core/textus_flutter_core.dart';

typedef VoiceTextSessionFactory = VoiceTextInputSession Function();

/// Application-wide opt-out and fresh, dialog-owned Core session factory.
class VoiceTextInputScope extends InheritedWidget {
  const VoiceTextInputScope({
    required super.child,
    this.enabled = true,
    this.createSession = VoiceTextInputSession.platform,
    super.key,
  });
  final bool enabled;
  final VoiceTextSessionFactory createSession;
  static VoiceTextInputScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceTextInputScope>();
  @override
  bool updateShouldNotify(VoiceTextInputScope oldWidget) =>
      enabled != oldWidget.enabled || createSession != oldWidget.createSession;
}

/// Standard editable text with default voice action and ordinary onChanged.
/// Applies only to this component, never arbitrary third-party text widgets.
class VoiceTextField extends StatefulWidget {
  const VoiceTextField({
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.voiceInput = true,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.textFieldKey,
    this.onVoiceInputChanged,
    this.owner,
    super.key,
  });
  final TextEditingController controller;

  /// Optional focus for the actual TextField; the caller owns and disposes it.
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final InputDecoration decoration;
  final bool enabled, readOnly, obscureText, voiceInput;
  final int? maxLines, minLines;
  final List<TextInputFormatter>? inputFormatters;

  /// Preserve a caller's existing key on the actual editable TextField.
  final Key? textFieldKey;

  /// Dialog lifetime only; recording/conversion never signal a domain edit.
  final ValueChanged<bool>? onVoiceInputChanged;

  /// Include account/document identity when the controller outlives its owner.
  final Object? owner;
  @override
  State<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends State<VoiceTextField> {
  int _generation = 0;
  bool _open = false;
  DialogRoute<String>? _route;
  VoiceTextInputSession? _session;
  bool get _eligible =>
      widget.enabled &&
      !widget.readOnly &&
      !widget.obscureText &&
      widget.voiceInput;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open && !(VoiceTextInputScope.maybeOf(context)?.enabled ?? true)) {
      _retire();
    }
  }

  @override
  void didUpdateWidget(VoiceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.owner != widget.owner ||
        !_eligible) {
      _retire();
    }
  }

  void _retire() {
    ++_generation;
    final session = _session;
    final route = _route;
    _session = null;
    _route = null;
    if (session != null) unawaited(_release(session));
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  Future<void> _release(VoiceTextInputSession session) async {
    try {
      await session.close();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'textus voice input cleanup',
        ),
      );
    }
  }

  @override
  void dispose() {
    _retire();
    super.dispose();
  }

  Future<void> _voice(VoiceTextSessionFactory factory) async {
    if (!mounted) return;
    final scope = VoiceTextInputScope.maybeOf(context);
    final currentFactory =
        scope?.createSession ?? VoiceTextInputSession.platform;
    if (_open ||
        !_eligible ||
        !(scope?.enabled ?? true) ||
        factory != currentFactory ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final token = ++_generation;
    final controller = widget.controller;
    var original = controller.value;
    var changed = false;
    final targetValid = ValueNotifier(true);
    void observe() {
      if (controller.text != original.text) changed = true;
      targetValid.value = !changed;
    }

    controller.addListener(observe);
    final session = factory();
    _session = session;
    setState(() => _open = true);
    widget.onVoiceInputChanged?.call(true);
    final route = DialogRoute<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoiceTextInputDialog(
        session: session,
        targetValid: targetValid,
        onReselectTarget: () {
          if (!mounted ||
              token != _generation ||
              !_eligible ||
              widget.controller != controller) {
            return;
          }
          original = controller.value;
          changed = false;
          targetValid.value = true;
        },
      ),
    );
    _route = route;
    try {
      final value = await Navigator.of(context).push(route);
      if (!mounted ||
          token != _generation ||
          !_eligible ||
          changed ||
          value == null) {
        return;
      }
      final selection = original.selection.isValid
          ? original.selection
          : TextSelection.collapsed(offset: original.text.length);
      final proposed = TextEditingValue(
        text: original.text.replaceRange(selection.start, selection.end, value),
        selection: TextSelection.collapsed(
          offset: selection.start + value.length,
        ),
      );
      var formatted = proposed;
      for (final formatter in <TextInputFormatter>[
        ...?widget.inputFormatters,
        if (widget.maxLines == 1)
          FilteringTextInputFormatter.singleLineFormatter,
      ]) {
        formatted = formatter.formatEditUpdate(original, formatted);
      }
      controller.value = formatted;
      widget.onChanged?.call(formatted.text);
    } finally {
      controller.removeListener(observe);
      targetValid.dispose();
      await _release(session);
      if (identical(_session, session)) {
        _session = null;
        _route = null;
      }
      if (mounted) {
        setState(() => _open = false);
        widget.onVoiceInputChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = VoiceTextInputScope.maybeOf(context);
    final voice =
        widget.voiceInput && !widget.obscureText && (scope?.enabled ?? true);
    return TextField(
      key: widget.textFieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      decoration: widget.decoration.copyWith(
        suffixIcon: voice
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.decoration.suffixIcon,
                  IconButton(
                    tooltip: _voiceLabel(context, 'Voice input', '音声入力'),
                    onPressed: _eligible && !_open
                        ? () => _voice(
                            scope?.createSession ??
                                VoiceTextInputSession.platform,
                          )
                        : null,
                    icon: const Icon(Icons.mic_outlined),
                  ),
                ],
              )
            : widget.decoration.suffixIcon,
      ),
    );
  }
}

/// One explicit recording -> transcript -> optional cleanup -> Apply interaction.
class VoiceTextInputDialog extends StatefulWidget {
  const VoiceTextInputDialog({
    required this.session,
    required this.targetValid,
    this.onReselectTarget,
    super.key,
  });
  final VoiceTextInputSession session;
  final ValueListenable<bool> targetValid;
  final VoidCallback? onReselectTarget;
  @override
  State<VoiceTextInputDialog> createState() => _VoiceTextInputDialogState();
}

class _VoiceTextInputDialogState extends State<VoiceTextInputDialog> {
  final _transcript = TextEditingController();
  final _result = TextEditingController();
  AudioProviderAvailability? _speech;
  VoiceTextCleanupAvailability? _cleanup;
  bool _busy = true, _recording = false, _closing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_inspect());
  }

  Future<void> _inspect() => _run(() async {
    final speech = await widget.session.speechAvailability();
    if (mounted) _speech = speech;
    final cleanup = await widget.session.cleanupAvailability();
    if (mounted) {
      _cleanup = cleanup;
    }
  }, requireCurrentRoute: false);
  Future<void> _run(
    Future<void> Function() action, {
    bool requireCurrentRoute = true,
  }) async {
    if (!mounted ||
        _closing ||
        (requireCurrentRoute && ModalRoute.of(context)?.isCurrent == false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted && !_closing) _error = '$error';
    } finally {
      if (mounted && !_closing) setState(() => _busy = false);
    }
  }

  Future<void> _finish(String? text) async {
    final route = ModalRoute.of(context);
    if (_closing || route == null || !route.isCurrent) return;
    setState(() => _closing = true);
    try {
      await widget.session.close();
      _dismissOwn(route, text);
    } catch (error) {
      if (mounted) {
        if (text == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                _voiceLabel(
                  context,
                  'Voice input cleanup failed. Your field was not changed.',
                  '音声入力の終了処理に失敗しました。入力欄は変更していません。',
                ),
              ),
            ),
          );
          _dismissOwn(route, null);
          return;
        }
        setState(() {
          _error = '$error';
          _closing = false;
        });
      }
    }
  }

  void _dismissOwn(ModalRoute<dynamic> route, String? text) {
    if (!mounted || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop(text);
    } else {
      route.navigator?.removeRoute(route, text);
    }
  }

  @override
  void dispose() {
    _transcript.dispose();
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String label(String en, String ja) => _voiceLabel(context, en, ja);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) unawaited(_finish(null));
      },
      child: AlertDialog(
        title: Text(label('Voice input', '音声入力')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_busy || _closing) const LinearProgressIndicator(),
                if (_busy &&
                    widget.session.state == VoiceTextInputState.transcribing)
                  OutlinedButton.icon(
                    onPressed: _closing ? null : () => _finish(null),
                    icon: const Icon(Icons.stop),
                    label: Text(
                      label('Stop transcription and close', '文字起こしを中止して閉じる'),
                    ),
                  ),
                Text(
                  label(
                    'Speak for up to 120 seconds. Audio is not saved as an attachment.',
                    '録音は最大120秒です。音声資料としては保存しません。',
                  ),
                ),
                if (_error != null)
                  Text(_error!, key: const Key('voice-error')),
                if (_speech?.reason case final reason?) Text(reason),
                if (!_recording &&
                    _speech?.state != AudioProviderState.available)
                  TextButton(
                    onPressed: _busy || _closing
                        ? null
                        : () => _run(() async {
                            final value = await widget.session.prepareSpeech();
                            if (mounted) _speech = value;
                          }),
                    child: Text(label('Prepare speech', '音声認識を準備')),
                  ),
                FilledButton(
                  onPressed:
                      _busy ||
                          _closing ||
                          (!_recording &&
                              _speech?.state != AudioProviderState.available)
                      ? null
                      : () => _run(() async {
                          if (_recording) {
                            _recording = false;
                            final value = await widget.session
                                .stopAndTranscribe();
                            if (mounted) {
                              _transcript.text = value.text;
                              _result.clear();
                            }
                          } else {
                            await widget.session.startRecording();
                            if (mounted) _recording = true;
                          }
                        }),
                  child: Text(
                    _busy &&
                            widget.session.state ==
                                VoiceTextInputState.transcribing
                        ? label('Transcribing…', '文字起こし中…')
                        : _recording
                        ? label('Stop and transcribe', '停止して文字起こし')
                        : label('Start speaking', '録音を開始'),
                  ),
                ),
                TextField(
                  key: const Key('voice-transcript'),
                  controller: _transcript,
                  minLines: 3,
                  maxLines: 8,
                  enabled: !_busy && !_closing && !_recording,
                  decoration: InputDecoration(
                    labelText: label('Transcript', '文字起こし'),
                  ),
                  onChanged: (_) => setState(_result.clear),
                ),
                if (_cleanup?.reason case final reason?) Text(reason),
                if (_cleanup?.state == VoiceTextCleanupState.available)
                  Text(
                    label(
                      'On-device cleanup: ${_cleanup!.modelName}',
                      '端末内で整形：${_cleanup!.modelName}',
                    ),
                  ),
                if (_cleanup?.state == VoiceTextCleanupState.downloadable)
                  TextButton(
                    onPressed: _busy || _closing || _recording
                        ? null
                        : () => _run(() async {
                            await widget.session.prepareCleanup();
                            final value = await widget.session
                                .cleanupAvailability();
                            if (mounted) _cleanup = value;
                          }),
                    child: Text(label('Prepare local model', '端末内モデルを準備')),
                  ),
                TextButton(
                  onPressed:
                      _busy ||
                          _closing ||
                          _recording ||
                          _transcript.text.trim().isEmpty ||
                          _cleanup?.state != VoiceTextCleanupState.available
                      ? null
                      : () => _run(() async {
                          _result.clear();
                          final value = await widget.session.cleanup(
                            _transcript.text,
                          );
                          if (mounted) _result.text = value.text;
                        }),
                  child: Text(label('Convert', '変換する')),
                ),
                TextField(
                  key: const Key('voice-cleaned-text'),
                  controller: _result,
                  minLines: 3,
                  maxLines: 8,
                  enabled: !_busy && !_closing && !_recording,
                  decoration: InputDecoration(
                    labelText: label('Editable suggestion', '整形案（編集可）'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Text(
                  label(
                    'Applying edits this field only. Save separately.',
                    '反映は入力欄だけを変更します。保存は別操作です。',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _closing ? null : () => _finish(null),
            child: Text(label('Cancel', 'キャンセル')),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.targetValid,
            builder: (context, valid, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!valid)
                  Text(
                    label(
                      'The field changed. Reselect its current insertion target before applying.',
                      '入力欄が変更されました。現在の入力欄の反映先を選び直してください。',
                    ),
                  ),
                if (!valid && widget.onReselectTarget != null)
                  TextButton(
                    onPressed: _busy || _closing
                        ? null
                        : widget.onReselectTarget,
                    child: Text(
                      label('Use current field selection', '反映先を選び直す'),
                    ),
                  ),
                TextButton(
                  onPressed:
                      !valid ||
                          _busy ||
                          _closing ||
                          _recording ||
                          _transcript.text.trim().isEmpty
                      ? null
                      : () => _finish(_transcript.text),
                  child: Text(label('Apply transcript', '文字起こしをそのまま反映')),
                ),
                FilledButton(
                  onPressed:
                      !valid ||
                          _busy ||
                          _closing ||
                          _recording ||
                          _result.text.trim().isEmpty
                      ? null
                      : () => _finish(_result.text),
                  child: Text(label('Apply to field', '入力欄に反映')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _voiceLabel(BuildContext context, String english, String japanese) =>
    Localizations.localeOf(context).languageCode == 'ja' ? japanese : english;
