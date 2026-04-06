import 'dart:typed_data';

import 'package:ecommerce_app/features/returns/domain/return_enums.dart';
import 'package:ecommerce_app/features/returns/state/returns_providers.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:ecommerce_app/presentation/widgets/app_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class RequestReturnPageArgs {
  final String orderId;
  final String orderItemId;
  final String productTitle;
  final String? productImageUrl;

  const RequestReturnPageArgs({
    required this.orderId,
    required this.orderItemId,
    required this.productTitle,
    this.productImageUrl,
  });
}

class RequestReturnPage extends ConsumerStatefulWidget {
  final RequestReturnPageArgs args;

  const RequestReturnPage({super.key, required this.args});

  @override
  ConsumerState<RequestReturnPage> createState() => _RequestReturnPageState();
}

class _RequestReturnPageState extends ConsumerState<RequestReturnPage> {
  ReturnReason _reason = ReturnReason.damagedItem;
  final _noteCtrl = TextEditingController();
  final List<_LocalPickedImage> _images = [];
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _images.add(_LocalPickedImage(name: file.name, bytes: bytes));
    });
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _images.add(_LocalPickedImage(name: file.name, bytes: bytes));
    });
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    if (!mounted) return;
    setState(() {
      for (final f in res.files) {
        final b = f.bytes;
        if (b != null && b.isNotEmpty) {
          _images.add(_LocalPickedImage(name: f.name, bytes: b));
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one clear photo of the sealed pack / unboxing as proof.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final svc = ref.read(returnsServiceProvider);
    try {
      final urls = <String>[];
      for (final img in _images) {
        final url = await svc.uploadEvidencePhoto(bytes: img.bytes);
        urls.add(url);
      }
      await svc.createReturn(
        orderItemId: widget.args.orderItemId,
        reason: _reason,
        returnType: ReturnType.replacement,
        imageUrls: urls,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      ref.invalidate(orderReturnsProvider(widget.args.orderId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Replacement request submitted.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = widget.args;

    return Scaffold(
      appBar: AppBar(title: const Text('Request Replacement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNetworkImage(
                    imageUrl: a.productImageUrl,
                    width: 64,
                    height: 64,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.productTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Order #${a.orderId.length > 8 ? a.orderId.substring(0, 8) : a.orderId}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 4),
          Text(
            'Reason',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...ReturnReason.values.map(
            (r) => RadioListTile<ReturnReason>(
              title: Text(r.displayLabel),
              value: r,
              groupValue: _reason,
              onChanged: (v) {
                if (v != null) setState(() => _reason = v);
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Photo proof (required)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please take a clear photo while opening the package. '
            'A short unboxing video is recommended for your records; this app only uploads photos.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _submitting ? null : _pickCamera,
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Camera'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Gallery'),
              ),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickFiles,
                icon: const Icon(Icons.folder_open_outlined, size: 20),
                label: const Text('Files'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_images.isEmpty)
            Text(
              'No photos added yet.',
              style: TextStyle(color: scheme.outline),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _images[i].bytes,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _images.removeAt(i)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Return note (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            maxLength: 800,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit request'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LocalPickedImage {
  final String name;
  final Uint8List bytes;

  _LocalPickedImage({required this.name, required this.bytes});
}
