import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'capture_image_preview.dart';

/// Borrowed presentation data for one attached original; owns no byte cache or IO.
final class PhotoRoleCaptureImage {
  /// Binds exact identity, synchronous cached bytes and independent status labels.
  const PhotoRoleCaptureImage({required this.materialId, required this.sourceIdentity,
    required this.readBytes, required this.selected, required this.readStatusLabel,
    required this.recognitionStatusLabel, this.errorDescription});

  /// App-supplied durable original token.
  final String materialId;
  /// Borrowed owner identity used by the bounded preview lifecycle.
  final Object sourceIdentity;
  /// Synchronous cached bytes only; never an acquisition or storage operation.
  final Uint8List? Function() readBytes;
  /// App-supplied use selection for subsequent recognition.
  final bool selected;
  /// Read status independent of attachment and recognition.
  final String readStatusLabel;
  /// Recognition status independent of attachment and reading.
  final String recognitionStatusLabel;
  /// Optional observed acquisition/read failure description.
  final String? errorDescription;
}

/// A generic App-defined role and an immutable snapshot of its attached photos.
final class PhotoRoleCaptureItem {
  /// Snapshots attached images without interpreting role IDs or labels.
  PhotoRoleCaptureItem({required this.id, required this.label, this.guidance,
    required Iterable<PhotoRoleCaptureImage> images, this.operationStatusLabel})
      : images = List.unmodifiable(images);

  /// Stable App-supplied role ID.
  final String id;
  /// Human-readable App-supplied role name.
  final String label;
  /// Optional App-specific acquisition guidance.
  final String? guidance;
  /// Attached originals only; empty means this role is not captured.
  final List<PhotoRoleCaptureImage> images;
  /// Optional transient acquisition/attachment outcome.
  final String? operationStatusLabel;
}

/// Generic role overview borrowing data and callbacks from its App owner.
/// Build and Inspect perform no storage, capture or recognition operations.
class PhotoRoleCapturePanel extends StatefulWidget {
  /// Shows primary roles always, with additional roles behind a local expansion.
  PhotoRoleCapturePanel({required List<PhotoRoleCaptureItem> roles,
    List<PhotoRoleCaptureItem> additionalRoles = const [],
    this.interactionEnabled = true, this.captureSupported = true,
    this.readOnly = false, this.onCapture, this.onRetake,
    this.onSelectionChanged, this.onRoleChanged, this.onRetryRead, super.key})
      : roles = List.unmodifiable(roles), additionalRoles = List.unmodifiable(additionalRoles) {
    final ids = [...this.roles, ...this.additionalRoles].map((role) => role.id).toList();
    if (ids.toSet().length != ids.length) throw ArgumentError('Photo role IDs must be unique');
  }

  /// Ordered role frames that are always visible.
  final List<PhotoRoleCaptureItem> roles;
  /// Optional roles available in Additional photos.
  final List<PhotoRoleCaptureItem> additionalRoles;
  /// Enables domain callbacks according to the owner's route and busy guards.
  final bool interactionEnabled;
  /// Whether the owner can acquire a fresh original.
  final bool captureSupported;
  /// Disables domain mutations while retaining inspection and explicit read retry.
  final bool readOnly;
  /// Capture and Add both request a fresh original for the clicked role.
  final ValueChanged<String>? onCapture;
  /// Retake requests another original, retaining the previous originals.
  final ValueChanged<String>? onRetake;
  /// Explicit selection command with exact original identity.
  final void Function(String materialId, bool selected)? onSelectionChanged;
  /// Explicit role-change request; the App confirms before recording it.
  final void Function(String materialId, String roleId)? onRoleChanged;
  /// Explicit exact-original read retry, including in read-only presentation.
  final ValueChanged<String>? onRetryRead;

  @override
  State<PhotoRoleCapturePanel> createState() => _PhotoRoleCapturePanelState();
}

class _PhotoRoleCapturePanelState extends State<PhotoRoleCapturePanel> {
  final _inspected = <String>{};
  bool _additional = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final role in widget.roles) _role(role),
      if (widget.additionalRoles.isNotEmpty) ...[
        TextButton(
          key: const ValueKey('photo-role-additional'),
          onPressed: () => setState(() => _additional = !_additional),
          child: Text(_additional ? 'Hide additional photos' : 'Additional photos'),
        ),
        if (_additional) for (final role in widget.additionalRoles) _role(role),
      ],
    ],
  );

  Widget _role(PhotoRoleCaptureItem role) {
    final mutate = widget.interactionEnabled && !widget.readOnly;
    final capture = mutate && widget.captureSupported;
    return Card(key: ValueKey('photo-role:${role.id}'), child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(role.label),
        Text(role.images.isEmpty ? 'Not captured' : 'Captured (${role.images.length} photos)'),
        Text('Selected (${role.images.where((image) => image.selected).length} photos)'),
        if (role.guidance != null) Text(role.guidance!),
        if (role.operationStatusLabel != null) Text(role.operationStatusLabel!),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final image in role.images)
            SizedBox(width: 112, height: 112, child: _RolePhotoPreview(
              key: ValueKey('photo-thumbnail:${image.materialId}'), image: image,
            )),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (role.images.isEmpty) ElevatedButton(
            key: ValueKey('photo-role-capture:${role.id}'),
            onPressed: capture && widget.onCapture != null ? () => widget.onCapture!(role.id) : null,
            child: const Text('Capture')),
          TextButton(key: ValueKey('photo-role-inspect:${role.id}'),
            onPressed: () => setState(() {
              if (!_inspected.add(role.id)) _inspected.remove(role.id);
            }), child: Text(_inspected.contains(role.id) ? 'Hide photos' : 'Inspect')),
          ElevatedButton(key: ValueKey('photo-role-add:${role.id}'),
            onPressed: capture && widget.onCapture != null ? () => widget.onCapture!(role.id) : null,
            child: const Text('Add')),
          ElevatedButton(key: ValueKey('photo-role-retake:${role.id}'),
            onPressed: capture && widget.onRetake != null ? () => widget.onRetake!(role.id) : null,
            child: const Text('Retake')),
        ]),
        if (_inspected.contains(role.id))
          for (final image in role.images) Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Original: ${image.materialId}'),
              CheckboxListTile(key: ValueKey('photo-selected:${image.materialId}'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Use for recognition'), value: image.selected,
                onChanged: mutate && widget.onSelectionChanged != null ?
                  (selected) { if (selected != null) widget.onSelectionChanged!(image.materialId, selected); } : null),
              Text('Read: ${image.readStatusLabel}'),
              if (image.errorDescription != null) Text('Read error: ${image.errorDescription}'),
              TextButton(key: ValueKey('photo-read-retry:${image.materialId}'),
                onPressed: widget.interactionEnabled && widget.onRetryRead != null ?
                  () => widget.onRetryRead!(image.materialId) : null,
                child: const Text('Retry read')),
              Text('Recognition: ${image.recognitionStatusLabel}'),
              DropdownButton<String>(key: ValueKey('photo-correct-role:${image.materialId}'),
                value: role.id, isExpanded: true, itemHeight: null,
                items: [for (final choice in [...widget.roles, ...widget.additionalRoles])
                  DropdownMenuItem(value: choice.id, child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8), child: Text(choice.label)))],
                onChanged: mutate && widget.onRoleChanged != null ? (id) {
                  if (id != null && id != role.id) widget.onRoleChanged!(image.materialId, id);
                } : null),
              SizedBox(height: 240, child: _RolePhotoPreview(
                key: ValueKey('photo-inspected:${image.materialId}'), image: image)),
            ]),
      ]),
    ));
  }
}

class _RolePhotoPreview extends StatefulWidget {
  const _RolePhotoPreview({required this.image, super.key});
  final PhotoRoleCaptureImage image;
  @override
  State<_RolePhotoPreview> createState() => _RolePhotoPreviewState();
}

class _RolePhotoPreviewState extends State<_RolePhotoPreview> {
  int _retry = 0;
  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    if (image.readStatusLabel != 'Loaded') {
      return Center(child: Text(image.readStatusLabel));
    }
    return CaptureImagePreview(
      key: ValueKey('photo-decoder:${image.materialId}:$_retry'),
      materialId: image.materialId, sourceIdentity: image.sourceIdentity,
      readBytes: image.readBytes, maxDecodeDimension: 512,
      imageKey: ValueKey('photo-render:${image.materialId}:$_retry'),
      semanticLabel: 'Attached original ${image.materialId}',
      errorBuilder: (context, error, stack) => SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('Image decode failed'),
          TextButton(onPressed: () => setState(() => _retry++), child: const Text('Retry preview')),
        ])),
    );
  }
}
