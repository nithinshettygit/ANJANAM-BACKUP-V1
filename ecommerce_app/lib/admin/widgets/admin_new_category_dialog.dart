import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';

import '../providers/admin_providers.dart';
import '../utils/homepage_image_upload.dart';
import 'admin_cached_image.dart';

final _slugRe = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Admin-only dialog to insert a row into [categories]. Returns new slug on success.
Future<String?> showAdminNewCategoryDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  var defaultOrder = 0;
  try {
    final list = await ref.read(adminServiceProvider).fetchCatalogCategoriesAdmin();
    defaultOrder = list.length * 10;
  } catch (_) {}

  final nameCtrl = TextEditingController();
  final slugCtrl = TextEditingController();
  final imageCtrl = TextEditingController();
  final orderCtrl = TextEditingController(text: '$defaultOrder');
  var isActive = true;
  var showInShop = true;
  var uploading = false;
  var uploadedUrl = '';
  var dialogOpen = true;

  final slug = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final imageUrl =
            uploadedUrl.trim().isNotEmpty ? uploadedUrl.trim() : imageCtrl.text.trim();

        return AlertDialog(
          title: const Text('New category'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Creates a catalog category. Use the same slug you want on products '
                    '(lowercase, e.g. photo, tea-gifts).',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: slugCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Slug *',
                      border: OutlineInputBorder(),
                      helperText: 'Lowercase, e.g. books, spiritual-items',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display order',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () {
                            pickAndUploadHomepageImage(
                              context: ctx,
                              ref: ref,
                              storageFolder: 'category-icons',
                              setUploading: (v) {
                                if (dialogOpen && ctx.mounted) {
                                  setLocal(() => uploading = v);
                                }
                              },
                              onUploaded: (url) {
                                if (dialogOpen && ctx.mounted) {
                                  setLocal(() => uploadedUrl = url);
                                }
                              },
                            );
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(uploading ? 'Uploading…' : 'Upload image'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AdminCachedImage(
                        imageUrl: imageUrl,
                        width: 480,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setLocal(() => isActive = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show in Shop'),
                    value: showInShop,
                    onChanged: (v) => setLocal(() => showInShop = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final slugValue = slugCtrl.text.trim().toLowerCase();
                final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
                if (name.isEmpty || slugValue.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name and slug are required.')),
                  );
                  return;
                }
                if (!_slugRe.hasMatch(slugValue)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Slug: lowercase letters, numbers, single hyphens only.'),
                    ),
                  );
                  return;
                }
                final img = imageUrl.trim().isEmpty ? null : imageUrl.trim();
                try {
                  await ref.read(adminServiceProvider).insertCatalogCategory(
                        name: name,
                        slug: slugValue,
                        imageUrl: img,
                        isActive: isActive,
                        showInShop: showInShop,
                        displayOrder: order,
                      );
                  if (ctx.mounted) {
                    ref.invalidate(adminCatalogCategoriesProvider);
                    ref.invalidate(adminCatalogCategoryOptionsProvider);
                    Navigator.pop(ctx, slugValue);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(userFacingErrorMessage(e))),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    ),
  );
  dialogOpen = false;

  nameCtrl.dispose();
  slugCtrl.dispose();
  imageCtrl.dispose();
  orderCtrl.dispose();

  return slug;
}
