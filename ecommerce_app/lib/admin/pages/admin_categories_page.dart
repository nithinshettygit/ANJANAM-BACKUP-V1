import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';

import '../../features/catalog/state/shop_categories_provider.dart';
import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/homepage_image_upload.dart';
import '../widgets/admin_cached_image.dart';

class AdminCategoriesPage extends ConsumerWidget {
  const AdminCategoriesPage({super.key});

  static final _slugRe = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCatalogCategoriesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load categories: $e'),
        ),
      ),
      data: (rows) => _AdminCategoriesBody(initialRows: rows),
    );
  }
}

class _AdminCategoriesBody extends ConsumerStatefulWidget {
  final List<AdminCatalogCategoryRow> initialRows;

  const _AdminCategoriesBody({required this.initialRows});

  @override
  ConsumerState<_AdminCategoriesBody> createState() => _AdminCategoriesBodyState();
}

class _AdminCategoriesBodyState extends ConsumerState<_AdminCategoriesBody> {
  late List<AdminCatalogCategoryRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = [...widget.initialRows];
  }

  @override
  void didUpdateWidget(covariant _AdminCategoriesBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rows = [...widget.initialRows];
  }

  Future<void> _persistOrder() async {
    try {
      await ref.read(adminServiceProvider).reorderCatalogCategories(
            _rows.map((e) => e.id).toList(),
          );
      if (!mounted) return;
      ref.invalidate(adminCatalogCategoriesProvider);
      ref.invalidate(adminCatalogCategoryOptionsProvider);
      ref.invalidate(shopCategoriesStorefrontProvider);
      ref.invalidate(catalogFilterCategoriesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    }
  }

  Future<void> _openEditor(AdminCatalogCategoryRow? existing) async {
    var defaultOrder = 0;
    if (existing != null) {
      defaultOrder = existing.displayOrder;
    } else {
      try {
        final list = await ref.read(adminServiceProvider).fetchCatalogCategoriesAdmin();
        defaultOrder = list.length * 10;
      } catch (_) {}
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final slugCtrl = TextEditingController(text: existing?.slug ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final orderCtrl = TextEditingController(text: '$defaultOrder');
    var isActive = existing?.isActive ?? true;
    var showInShop = existing?.showInShop ?? true;
    var uploading = false;
    var uploadedUrl = '';
    var dialogOpen = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final imageUrl = uploadedUrl.trim().isNotEmpty ? uploadedUrl.trim() : imageCtrl.text.trim();

          return AlertDialog(
            title: Text(existing == null ? 'Create category' : 'Edit category'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      enabled: existing == null,
                      decoration: InputDecoration(
                        labelText: 'Slug *',
                        border: const OutlineInputBorder(),
                        helperText: existing == null
                            ? 'Lowercase, e.g. books, spiritual-items'
                            : 'Slug cannot be changed here (matches product category text).',
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
                      subtitle: const Text('Inactive categories are hidden from the storefront.'),
                      value: isActive,
                      onChanged: (v) => setLocal(() => isActive = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show in Shop'),
                      subtitle: const Text('When on, appears on the customer Shop category grid.'),
                      value: showInShop,
                      onChanged: (v) => setLocal(() => showInShop = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final slug = slugCtrl.text.trim().toLowerCase();
                  final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || slug.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Name and slug are required.')),
                    );
                    return;
                  }
                  if (!AdminCategoriesPage._slugRe.hasMatch(slug)) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Slug: lowercase letters, numbers, single hyphens only.'),
                      ),
                    );
                    return;
                  }
                  final img = imageUrl.trim().isEmpty ? null : imageUrl.trim();
                  try {
                    final service = ref.read(adminServiceProvider);
                    if (existing == null) {
                      await service.insertCatalogCategory(
                        name: name,
                        slug: slug,
                        imageUrl: img,
                        isActive: isActive,
                        showInShop: showInShop,
                        displayOrder: order,
                      );
                    } else {
                      await service.updateCatalogCategory(
                        id: existing.id,
                        name: name,
                        slug: existing.slug,
                        imageUrl: img,
                        isActive: isActive,
                        showInShop: showInShop,
                        displayOrder: order,
                      );
                    }
                    if (ctx.mounted) {
                      ref.invalidate(adminCatalogCategoriesProvider);
                      ref.invalidate(adminCatalogCategoryOptionsProvider);
                      ref.invalidate(shopCategoriesStorefrontProvider);
                      ref.invalidate(catalogFilterCategoriesProvider);
                      Navigator.pop(ctx);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(userFacingErrorMessage(e))),
                    );
                  }
                },
                child: Text(existing == null ? 'Create' : 'Save'),
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
  }

  Future<void> _confirmDelete(AdminCatalogCategoryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange.shade800),
        title: Text('Delete category: ${row.name}?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are about to remove this category from the catalog (slug: ${row.slug}).',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please note:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('• Existing products are not deleted; their category field is unchanged.'),
              const SizedBox(height: 6),
              const Text('• Update product categories in Inventory if you no longer want this slug.'),
              const SizedBox(height: 6),
              const Text('• This action cannot be undone from the app.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete category'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(adminServiceProvider).deleteCatalogCategory(row.id);
      ref.invalidate(adminCatalogCategoriesProvider);
      ref.invalidate(adminCatalogCategoryOptionsProvider);
      ref.invalidate(shopCategoriesStorefrontProvider);
      ref.invalidate(catalogFilterCategoriesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Categories',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () {
                ref.invalidate(adminCatalogCategoriesProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _openEditor(null),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create category'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Create, edit, or delete categories below. Drag rows to change order on the Shop page. '
          'Inactive categories are hidden from customers.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No categories yet.'),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _openEditor(null),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Create your first category'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    itemCount: _rows.length,
                    onReorder: (oldI, newI) {
                      setState(() {
                        if (newI > oldI) newI -= 1;
                        final item = _rows.removeAt(oldI);
                        _rows.insert(newI, item);
                      });
                      _persistOrder();
                    },
                    itemBuilder: (context, index) {
                      final r = _rows[index];
                      return Card(
                        key: ValueKey(r.id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              title: Text(
                                r.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Slug: ${r.slug} · Order: ${r.displayOrder}'
                                '${r.isActive ? '' : ' · Inactive'}'
                                '${r.showInShop ? '' : ' · Hidden from shop grid'}',
                              ),
                              trailing: (r.imageUrl ?? '').isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AdminCachedImage(
                                        imageUrl: r.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openEditor(r),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('Edit'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _confirmDelete(r),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                    label: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
