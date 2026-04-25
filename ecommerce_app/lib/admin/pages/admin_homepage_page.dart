import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/homepage_image_upload.dart';
import '../widgets/admin_cached_image.dart';

const _kCollections = <Map<String, String>>[
  {'key': 'popular', 'label': 'Popular Products'},
  {'key': 'recommended', 'label': 'Recommended For You'},
  {'key': 'festival', 'label': 'Festival Specials'},
  {'key': 'new_arrivals', 'label': 'New Arrivals'},
];

class AdminHomepagePage extends ConsumerStatefulWidget {
  const AdminHomepagePage({super.key});

  @override
  ConsumerState<AdminHomepagePage> createState() => _AdminHomepagePageState();
}

class _AdminHomepagePageState extends ConsumerState<AdminHomepagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Hero banners'),
            Tab(text: 'Top categories'),
            Tab(text: 'Product sections'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _HeroBannersTab(),
              _TopCategoriesTab(),
              _ProductSectionsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroBannersTab extends ConsumerWidget {
  const _HeroBannersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminHomeHeroBannersProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drag banners to reorder. Active banners appear in homepage carousel.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showBannerEditor(context, ref, null),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add banner'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No banners. Add one to show the carousel.'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      onReorder: (oldIndex, newIndex) async {
                        final updated = [...rows];
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = updated.removeAt(oldIndex);
                        updated.insert(newIndex, item);
                        await ref.read(adminServiceProvider).reorderHomeHeroBanners(
                              updated.map((e) => e.id).toList(),
                            );
                        ref.invalidate(adminHomeHeroBannersProvider);
                      },
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return Card(
                          key: ValueKey(r.id),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AdminCachedImage(
                                imageUrl: r.imageUrl,
                                width: 86,
                                height: 46,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            title: Text('${r.redirectType} → ${r.redirectValue.isEmpty ? 'none' : r.redirectValue}'),
                            subtitle: Text(r.enabled ? 'Active' : 'Inactive'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.drag_indicator),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showBannerEditor(context, ref, r),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Delete banner?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!ok || !context.mounted) return;
                                    await ref.read(adminServiceProvider).deleteHomeHeroBanner(r.id);
                                    ref.invalidate(adminHomeHeroBannersProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showBannerEditor(
  BuildContext context,
  WidgetRef ref,
  AdminHomeHeroBannerRow? existing,
) async {
  final categoryOptions = await ref.read(adminCatalogCategoryOptionsProvider.future);
  final products = await ref.read(adminProductsProvider.future);

  final imageUrlCtrl = TextEditingController(text: existing?.imageUrl ?? '');
  final manualOverrideCtrl = TextEditingController();

  var uploadedImageUrl = '';
  var redirectType = existing?.redirectType ?? 'category';
  var active = existing?.enabled ?? true;
  var uploading = false;
  String? selectedCategory = existing?.redirectType == 'category' ? existing?.redirectValue : null;
  String? selectedProduct = existing?.redirectType == 'product' ? existing?.redirectValue : null;
  String? selectedCollection = existing?.redirectType == 'collection' ? existing?.redirectValue : null;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final effectiveImage = uploadedImageUrl.trim().isNotEmpty
            ? uploadedImageUrl.trim()
            : imageUrlCtrl.text.trim();

        String selectedTarget() {
          switch (redirectType) {
            case 'category':
              return selectedCategory ?? '';
            case 'product':
              return selectedProduct ?? '';
            case 'collection':
              return selectedCollection ?? '';
            case 'external_link':
              return '';
            case 'no_redirect':
              return '';
            default:
              return '';
          }
        }

        final manualOverride = manualOverrideCtrl.text.trim();
        final finalRedirectValue = manualOverride.isNotEmpty ? manualOverride : selectedTarget();

        return AlertDialog(
          title: Text(existing == null ? 'Add hero banner' : 'Edit hero banner'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    ),
                    child: const Text(
                      'Required fields are marked with *.\n'
                      'Use selectors first; manual override is for advanced use only.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Banner image *',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () {
                            pickAndUploadHomepageImage(
                              context: ctx,
                              ref: ref,
                              storageFolder: 'banners',
                              setUploading: (v) {
                                if (ctx.mounted) setLocal(() => uploading = v);
                              },
                              onUploaded: (url) => setLocal(() => uploadedImageUrl = url),
                            );
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(uploading ? 'Uploading…' : 'Upload banner image (recommended)'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: imageUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Paste image URL (optional)',
                      helperText: 'Recommended size: 1200 x 500 (3:1). Uploaded image takes priority.',
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 10),
                  _BannerPreviewCard(imageUrl: effectiveImage),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: redirectType,
                    decoration: const InputDecoration(labelText: 'Redirect type *'),
                    items: const [
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'product', child: Text('Product')),
                      DropdownMenuItem(value: 'collection', child: Text('Collection')),
                      DropdownMenuItem(value: 'external_link', child: Text('External Link')),
                      DropdownMenuItem(value: 'no_redirect', child: Text('No Redirect')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() => redirectType = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (redirectType == 'category')
                    DropdownMenu<String>(
                      width: 480,
                      enableFilter: true,
                      initialSelection: selectedCategory,
                      label: const Text('Select category (recommended)'),
                      dropdownMenuEntries: categoryOptions
                          .map(
                            (e) => DropdownMenuEntry<String>(
                              value: e.slug,
                              label: '${e.label} (${e.slug})',
                            ),
                          )
                          .toList(),
                      onSelected: (v) => setLocal(() => selectedCategory = v),
                    ),
                  if (redirectType == 'product')
                    DropdownMenu<String>(
                      width: 480,
                      enableFilter: true,
                      initialSelection: selectedProduct,
                      label: const Text('Select product (recommended)'),
                      dropdownMenuEntries: products
                          .map(
                            (p) => DropdownMenuEntry<String>(
                              value: p.id,
                              label: '${p.title} (${p.id.substring(0, p.id.length > 8 ? 8 : p.id.length)})',
                            ),
                          )
                          .toList(),
                      onSelected: (v) => setLocal(() => selectedProduct = v),
                    ),
                  if (redirectType == 'collection')
                    DropdownButtonFormField<String>(
                      initialValue: selectedCollection,
                      decoration: const InputDecoration(
                        labelText: 'Select collection (recommended)',
                      ),
                      items: _kCollections
                          .map((e) => DropdownMenuItem(value: e['key'], child: Text(e['label']!)))
                          .toList(),
                      onChanged: (v) => setLocal(() => selectedCollection = v),
                    ),
                  if (redirectType == 'external_link')
                    TextField(
                      controller: manualOverrideCtrl,
                      decoration: const InputDecoration(
                        labelText: 'External link URL *',
                        helperText: 'Example: https://example.com/offer',
                      ),
                    )
                  else if (redirectType != 'no_redirect')
                    TextField(
                      controller: manualOverrideCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Manual slug / ID (optional override)',
                        helperText: 'If filled, this overrides selected target.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text('Active banners appear in the homepage carousel.'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                  if (finalRedirectValue.isNotEmpty && redirectType != 'no_redirect')
                    Text(
                      'Final redirect target: $finalRedirectValue',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final image = effectiveImage.trim();
                if (image.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Banner image is required.')),
                  );
                  return;
                }
                if (redirectType != 'no_redirect' && finalRedirectValue.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select a redirect target or add manual override.')),
                  );
                  return;
                }
                var redirectValue = finalRedirectValue.trim();
                if (redirectType == 'external_link') {
                  // Make admin input forgiving: "gmail.com" -> "https://gmail.com".
                  if (!redirectValue.startsWith('http://') &&
                      !redirectValue.startsWith('https://')) {
                    redirectValue = 'https://$redirectValue';
                  }
                  final uri = Uri.tryParse(redirectValue);
                  final valid = uri != null &&
                      (uri.scheme == 'http' || uri.scheme == 'https') &&
                      uri.host.trim().isNotEmpty;
                  if (!valid) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid external URL (example: https://gmail.com).'),
                      ),
                    );
                    return;
                  }
                }
                try {
                  final service = ref.read(adminServiceProvider);
                  if (existing == null) {
                    await service.insertHomeHeroBanner(
                      imageUrl: image,
                      redirectType: redirectType,
                      redirectValue: redirectValue,
                      enabled: active,
                    );
                  } else {
                    await service.updateHomeHeroBanner(
                      id: existing.id,
                      imageUrl: image,
                      redirectType: redirectType,
                      redirectValue: redirectValue,
                      sortOrder: existing.sortOrder,
                      enabled: active,
                    );
                  }
                  if (ctx.mounted) {
                    ref.invalidate(adminHomeHeroBannersProvider);
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(userFacingErrorMessage(e))),
                  );
                }
              },
              child: const Text('Save banner'),
            ),
          ],
        );
      },
    ),
  );
}

class _BannerPreviewCard extends StatelessWidget {
  const _BannerPreviewCard({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 1,
            child: imageUrl.isEmpty
                ? Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Text('Banner preview'),
                  )
                : AdminCachedImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 120,
                    borderRadius: BorderRadius.circular(12),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TopCategoriesTab extends ConsumerWidget {
  const _TopCategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminHomeTopCategoriesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drag categories to reorder. Visible categories appear on homepage.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showCategoryEditor(context, ref, null),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add category chip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No chips. Add categories for the home row.'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      onReorder: (oldIndex, newIndex) async {
                        final updated = [...rows];
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = updated.removeAt(oldIndex);
                        updated.insert(newIndex, item);
                        await ref.read(adminServiceProvider).reorderHomeTopCategories(
                              updated.map((e) => e.id).toList(),
                            );
                        ref.invalidate(adminHomeTopCategoriesProvider);
                      },
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return Card(
                          key: ValueKey(r.id),
                          child: ListTile(
                            leading: ClipOval(
                              child: AdminCachedImage(
                                imageUrl: r.iconUrl,
                                width: 44,
                                height: 44,
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            title: Text(r.label),
                            subtitle: Text('${r.categorySlug} · ${r.enabled ? 'Visible' : 'Hidden'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.drag_indicator),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showCategoryEditor(context, ref, r),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Delete category chip?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!ok || !context.mounted) return;
                                    await ref.read(adminServiceProvider).deleteHomeTopCategory(r.id);
                                    ref.invalidate(adminHomeTopCategoriesProvider);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showCategoryEditor(
  BuildContext context,
  WidgetRef ref,
  AdminHomeTopCategoryRow? existing,
) async {
  final options = await ref.read(adminCatalogCategoryOptionsProvider.future);

  final labelCtrl = TextEditingController(text: existing?.label ?? '');
  final manualSlugCtrl = TextEditingController();
  final iconUrlCtrl = TextEditingController(text: existing?.iconUrl ?? '');

  var selectedSlug = existing?.categorySlug;
  var selectedLabel = '';
  var visible = existing?.enabled ?? true;
  var uploading = false;
  var uploadedIconUrl = '';

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final imageUrl = uploadedIconUrl.trim().isNotEmpty
            ? uploadedIconUrl.trim()
            : iconUrlCtrl.text.trim();
        final manualSlug = manualSlugCtrl.text.trim().toLowerCase();
        final finalSlug = manualSlug.isNotEmpty ? manualSlug : (selectedSlug ?? '');

        return AlertDialog(
          title: Text(existing == null ? 'Add top category' : 'Edit top category'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    ),
                    child: const Text(
                      'Select existing category first, then edit label only if needed.\n'
                      'Manual slug is for advanced override only.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownMenu<String>(
                    width: 480,
                    enableFilter: true,
                    initialSelection: selectedSlug,
                    label: const Text('Category * (recommended)'),
                    dropdownMenuEntries: options
                        .map((e) => DropdownMenuEntry<String>(value: e.slug, label: '${e.label} (${e.slug})'))
                        .toList(),
                    onSelected: (v) {
                      if (v == null) return;
                      final matched = options.where((e) => e.slug == v).toList();
                      final lbl = matched.isEmpty ? v : matched.first.label;
                      setLocal(() {
                        selectedSlug = v;
                        selectedLabel = lbl;
                        if (labelCtrl.text.trim().isEmpty || labelCtrl.text.trim() == selectedLabel) {
                          labelCtrl.text = lbl;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: manualSlugCtrl,
                    onChanged: (raw) {
                      final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
                      if (cleaned == raw) {
                        setLocal(() {});
                        return;
                      }
                      manualSlugCtrl.value = TextEditingValue(
                        text: cleaned,
                        selection: TextSelection.collapsed(offset: cleaned.length),
                      );
                      setLocal(() {});
                    },
                    decoration: const InputDecoration(
                      labelText: 'Manual category slug (advanced)',
                      helperText: 'Optional override for custom slug',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Label *',
                      helperText: 'Auto-filled from selected category, editable',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Category icon *',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: uploading
                        ? null
                        : () {
                            pickAndUploadHomepageImage(
                              context: ctx,
                              ref: ref,
                              storageFolder: 'category-icons',
                              setUploading: (v) {
                                if (ctx.mounted) setLocal(() => uploading = v);
                              },
                              onUploaded: (url) => setLocal(() => uploadedIconUrl = url),
                            );
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(uploading ? 'Uploading…' : 'Upload icon (recommended)'),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: iconUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Paste icon image URL (optional)',
                      helperText: 'Recommended size: 512 x 512 square. Uploaded image takes priority.',
                    ),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 10),
                  _IconPreviewCard(imageUrl: imageUrl),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible'),
                    subtitle: const Text('Visible categories appear on the homepage.'),
                    value: visible,
                    onChanged: (v) => setLocal(() => visible = v),
                  ),
                  if (finalSlug.isNotEmpty)
                    Text('Final category slug: $finalSlug', style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final label = labelCtrl.text.trim();
                final iconUrl = imageUrl.trim();
                final slug = finalSlug.trim().toLowerCase();
                if (label.isEmpty || iconUrl.isEmpty || slug.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Category, label, and icon are required.')),
                  );
                  return;
                }
                if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(slug)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Slug can use only a-z, 0-9, - and _.')),
                  );
                  return;
                }
                try {
                  final service = ref.read(adminServiceProvider);
                  if (existing == null) {
                    await service.insertHomeTopCategory(
                      label: label,
                      iconUrl: iconUrl,
                      categorySlug: slug,
                      enabled: visible,
                    );
                  } else {
                    await service.updateHomeTopCategory(
                      id: existing.id,
                      label: label,
                      iconUrl: iconUrl,
                      categorySlug: slug,
                      sortOrder: existing.sortOrder,
                      enabled: visible,
                    );
                  }
                  if (ctx.mounted) {
                    ref.invalidate(adminHomeTopCategoriesProvider);
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(userFacingErrorMessage(e))),
                  );
                }
              },
              child: const Text('Save category'),
            ),
          ],
        );
      },
    ),
  );
}

class _IconPreviewCard extends StatelessWidget {
  const _IconPreviewCard({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl.isEmpty
              ? Container(
                  width: 72,
                  height: 72,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined),
                )
              : AdminCachedImage(
                  imageUrl: imageUrl,
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(10),
                ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('Preview (square icon)')),
      ],
    );
  }
}

class _ProductSectionsTab extends ConsumerStatefulWidget {
  const _ProductSectionsTab();

  @override
  ConsumerState<_ProductSectionsTab> createState() => _ProductSectionsTabState();
}

class _ProductSectionsTabState extends ConsumerState<_ProductSectionsTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, ({bool popular, bool recommended, bool festival})>
      _sectionOverrides = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ProductUpsertInput _copyAsInput(
    AdminProduct p, {
    bool? isPopular,
    bool? isRecommended,
    bool? isFestivalSpecial,
    List<AdminVariantUpsert> variants = const [],
  }) {
    return ProductUpsertInput(
      title: p.title,
      description: p.description,
      category: p.category ?? '',
      sku: p.sku,
      brand: p.brand,
      tags: p.tags,
      price: p.price,
      currency: p.currency,
      weight: p.weight,
      dimensions: p.dimensions,
      inventoryCount: p.inventoryCount,
      imageUrls: p.imageUrls,
      displayDiscountPercent: p.displayDiscountPercent,
      isPopular: isPopular ?? p.isPopular,
      isRecommended: isRecommended ?? p.isRecommended,
      isFestivalSpecial: isFestivalSpecial ?? p.isFestivalSpecial,
      variants: variants,
    );
  }

  Future<void> _setSectionFlag(
    AdminProduct p, {
    bool? isPopular,
    bool? isRecommended,
    bool? isFestivalSpecial,
  }) async {
    final current = _sectionOverrides[p.id];
    final previous = current ??
        (
          popular: p.isPopular,
          recommended: p.isRecommended,
          festival: p.isFestivalSpecial,
        );
    final next = (
      popular: isPopular ?? previous.popular,
      recommended: isRecommended ?? previous.recommended,
      festival: isFestivalSpecial ?? previous.festival,
    );

    setState(() => _sectionOverrides[p.id] = next);
    try {
      var initialVariants = const <AdminVariantUpsert>[];
      try {
        initialVariants = await ref.read(adminServiceProvider).fetchProductVariants(p.id);
      } catch (_) {}
      await ref.read(adminServiceProvider).updateProduct(
            p.id,
            _copyAsInput(
              p,
              isPopular: next.popular,
              isRecommended: next.recommended,
              isFestivalSpecial: next.festival,
              variants: initialVariants,
            ),
          );
      ref.invalidate(adminProductsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sectionOverrides[p.id] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(adminProductsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? products
            : products.where((p) {
                return p.title.toLowerCase().contains(query) ||
                    (p.category ?? '').toLowerCase().contains(query);
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: const Text(
                'Each product can appear in multiple home sections at once (Popular, Recommended, Festival).\n'
                'Toggles save to the catalog and stay highlighted after you leave this tab or refresh the list.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search product by title or category',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching products'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final override = _sectionOverrides[p.id];
                        final isPopular = override?.popular ?? p.isPopular;
                        final isRecommended = override?.recommended ?? p.isRecommended;
                        final isFestivalSpecial = override?.festival ?? p.isFestivalSpecial;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (p.category ?? 'general').toUpperCase(),
                                  style: Theme.of(context).textTheme.labelMedium,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    _SectionToggle(
                                      label: 'Popular',
                                      value: isPopular,
                                      onChanged: (v) async {
                                        await _setSectionFlag(p, isPopular: v);
                                      },
                                    ),
                                    _SectionToggle(
                                      label: 'Recommended',
                                      value: isRecommended,
                                      onChanged: (v) async {
                                        await _setSectionFlag(p, isRecommended: v);
                                      },
                                    ),
                                    _SectionToggle(
                                      label: 'Festival special',
                                      value: isFestivalSpecial,
                                      onChanged: (v) async {
                                        await _setSectionFlag(p, isFestivalSpecial: v);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color selectedTone() {
      final k = label.toLowerCase();
      if (k.contains('popular')) return const Color(0xFFFFE082); // amber
      if (k.contains('festival')) return const Color(0xFFFFCCBC); // deep orange
      if (k.contains('recommended')) return const Color(0xFFC8E6C9); // green
      return scheme.primaryContainer;
    }

    final selectedBg = selectedTone();
    final fg = value ? AppColors.charcoalBlack : scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: value ? selectedBg : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value
                  ? AppColors.charcoalBlack.withValues(alpha: 0.72)
                  : scheme.outlineVariant.withValues(alpha: 0.75),
              width: value ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value) ...[
                Icon(Icons.check_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
