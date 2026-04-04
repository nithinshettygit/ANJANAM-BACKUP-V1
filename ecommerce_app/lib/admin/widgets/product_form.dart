
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import 'package:ecommerce_app/core/constants/app_currency.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/images/product_image_compress.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/user_facing_error_message.dart';
import 'package:ecommerce_app/presentation/widgets/product_image_carousel.dart';
import 'package:ecommerce_app/presentation/widgets/product_image_fullscreen_gallery.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import 'admin_cached_image.dart';
import 'admin_new_category_dialog.dart';

/// Max images stored on [products.image_urls] (first = primary / storefront thumbnail).
const int kMaxProductImagesPerProduct = 8;

/// Reject originals larger than this before decode (memory safety).
const int kMaxImagePickBytes = 12 * 1024 * 1024;

/// Target max size after compression before upload.
const int kMaxImageUploadBytes = 2 * 1024 * 1024;
const int kRecommendedProductImageSize = 1080;
const int kMinimumProductImageSize = 800;

class ProductForm extends ConsumerStatefulWidget {
  final AdminProduct? initialProduct;
  /// Folder id for storage paths `products/{id}/…` — existing product id or pre-assigned UUID for new products.
  final String storageProductId;
  final Future<void> Function(ProductUpsertInput input) onSubmit;

  const ProductForm({
    super.key,
    this.initialProduct,
    required this.storageProductId,
    required this.onSubmit,
  });

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  static const _kCustomCategory = '__custom_category__';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _dimensionsCtrl;
  late final TextEditingController _inventoryCtrl;
  late final TextEditingController _discountPercentCtrl;

  final List<String> _imageUrls = [];
  bool _saving = false;
  late int _discountPercent;
  late bool _isPopular;
  late bool _isRecommended;
  late bool _isFestivalSpecial;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    _titleCtrl = TextEditingController(text: p?.title ?? '');
    _descriptionCtrl = TextEditingController(text: p?.description ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    _priceCtrl = TextEditingController(text: p?.price.toString() ?? '');
    _weightCtrl = TextEditingController(
      text: p != null && p.weight > 0 ? p.weight.toStringAsFixed(3) : '',
    );
    _dimensionsCtrl = TextEditingController(text: p?.dimensions ?? '');
    _inventoryCtrl = TextEditingController(text: (p?.inventoryCount ?? 0).toString());
    _imageUrls.addAll(p?.imageUrls ?? const []);
    _discountPercent = (p?.displayDiscountPercent ?? 0).clamp(0, 99);
    _discountPercentCtrl = TextEditingController(text: _discountPercent.toString());
    _isPopular = p?.isPopular ?? false;
    _isRecommended = p?.isRecommended ?? false;
    _isFestivalSpecial = p?.isFestivalSpecial ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _categoryCtrl.dispose();
    _skuCtrl.dispose();
    _brandCtrl.dispose();
    _tagsCtrl.dispose();
    _priceCtrl.dispose();
    _weightCtrl.dispose();
    _dimensionsCtrl.dispose();
    _inventoryCtrl.dispose();
    _discountPercentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 650,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 10),
              _buildCategoryField(),
              const SizedBox(height: 10),
              TextFormField(
                controller: _skuCtrl,
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _brandCtrl,
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Sale price (INR)',
                  helperText: 'Amount the customer pays. Card promo % derives MRP on product cards.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null || value <= 0) return 'Price must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Storefront card promo (0 = no "% OFF" badge)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: TextFormField(
                      controller: _discountPercentCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: '%',
                        counterText: '',
                        isDense: true,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n == null) return;
                        setState(() => _discountPercent = n.clamp(0, 99));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: _discountPercent.toDouble(),
                      min: 0,
                      max: 99,
                      divisions: 99,
                      label: '$_discountPercent%',
                      onChanged: (v) {
                        final next = v.round().clamp(0, 99);
                        setState(() {
                          _discountPercent = next;
                          _discountPercentCtrl.text = next.toString();
                          _discountPercentCtrl.selection = TextSelection.collapsed(
                            offset: _discountPercentCtrl.text.length,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}$')),
                      ],
                      decoration: const InputDecoration(labelText: 'Weight (kg)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _dimensionsCtrl,
                      decoration: const InputDecoration(labelText: 'Dimensions (LxWxH)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _inventoryCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Inventory Count'),
                validator: (v) {
                  final value = int.tryParse((v ?? '').trim());
                  if (value == null || value < 0) return 'Invalid count';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Text(
                'Homepage',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Popular products rail'),
                value: _isPopular,
                onChanged: (v) => setState(() => _isPopular = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recommended for you rail'),
                value: _isRecommended,
                onChanged: (v) => setState(() => _isRecommended = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Festival specials rail'),
                value: _isFestivalSpecial,
                onChanged: (v) => setState(() => _isFestivalSpecial = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Product images (first = primary)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Up to $kMaxProductImagesPerProduct images · JPG, PNG, WebP · max ${(kMaxImageUploadBytes / (1024 * 1024)).round()} MB each after compression',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Use square photos (1:1). Recommended: ${kRecommendedProductImageSize}×${kRecommendedProductImageSize}px · Minimum: ${kMinimumProductImageSize}×${kMinimumProductImageSize}px.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              ReorderableGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.92,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _imageUrls.removeAt(oldIndex);
                    _imageUrls.insert(newIndex, item);
                  });
                },
                footer: [
                  if (_imageUrls.length < kMaxProductImagesPerProduct)
                    _AddImageTile(
                      key: const ValueKey('add-image-cell'),
                      enabled: !_saving,
                      onTap: _pickAndUploadImages,
                    ),
                ],
                children: List.generate(_imageUrls.length, (i) {
                  final url = _imageUrls[i];
                  return _AdminProductImageTile(
                    key: ValueKey(url),
                    imageUrl: url,
                    index: i,
                    onRemove: () => setState(() => _imageUrls.remove(url)),
                    onPreview: () {
                      final start = _imageUrls.indexOf(url);
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (_) => ProductImageFullscreenGallery(
                            imageUrls: List<String>.from(_imageUrls),
                            initialIndex: start < 0 ? 0 : start,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _pickAndUploadImages,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Add photos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _showPreview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview Product Page'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Saving...' : 'Save Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryField() {
    final optionsAsync = ref.watch(adminCatalogCategoryOptionsProvider);
    return optionsAsync.when(
      loading: () => TextFormField(
        controller: _categoryCtrl,
        decoration: const InputDecoration(
          labelText: 'Category',
          helperText: 'Loading catalog categories…',
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Enter category' : null,
      ),
      error: (_, __) => TextFormField(
        controller: _categoryCtrl,
        decoration: const InputDecoration(labelText: 'Category'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Enter category' : null,
      ),
      data: _buildCategoryFieldWithOptions,
    );
  }

  Widget _buildCategoryFieldWithOptions(List<AdminCategoryOption> options) {
    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: 'Category',
              helperText: 'No catalog categories yet. Type a value or create one below.',
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter category' : null,
          ),
          TextButton.icon(
            onPressed: _saving ? null : _onCreateCategoryFromForm,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('Create new category'),
          ),
        ],
      );
    }

    final dropdownValue = _resolveCategoryDropdownValue(options);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          decoration: const InputDecoration(
            labelText: 'Category',
            helperText: 'Pick from catalog (slug is stored on the product).',
          ),
          isExpanded: true,
          initialValue: dropdownValue,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Select category'),
            ),
            ...options.map(
              (o) => DropdownMenuItem<String?>(
                value: o.slug,
                child: Text(
                  '${o.label} (${o.slug})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const DropdownMenuItem<String?>(
              value: _kCustomCategory,
              child: Text('Custom category…'),
            ),
          ],
          onChanged: _saving
              ? null
              : (v) {
                  setState(() {
                    if (v == null) {
                      _categoryCtrl.clear();
                    } else if (v == _kCustomCategory) {
                      // Keep existing text so admins can edit a legacy value.
                    } else {
                      _categoryCtrl.text = v;
                    }
                  });
                },
          validator: (_) {
            if (_categoryCtrl.text.trim().isEmpty) {
              return 'Choose or enter a category';
            }
            return null;
          },
        ),
        if (dropdownValue == _kCustomCategory) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _categoryCtrl,
            decoration: const InputDecoration(
              labelText: 'Custom category value',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        TextButton.icon(
          onPressed: _saving ? null : _onCreateCategoryFromForm,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('Create new category'),
        ),
      ],
    );
  }

  String? _resolveCategoryDropdownValue(List<AdminCategoryOption> options) {
    final t = _categoryCtrl.text.trim().toLowerCase();
    if (t.isEmpty) return null;
    if (options.any((o) => o.slug == t)) return t;
    return _kCustomCategory;
  }

  Future<void> _onCreateCategoryFromForm() async {
    final slug = await showAdminNewCategoryDialog(context: context, ref: ref);
    if (!mounted || slug == null) return;
    ref.invalidate(adminCatalogCategoryOptionsProvider);
    setState(() => _categoryCtrl.text = slug);
  }

  bool _allowedProductImageFile(PlatformFile file) {
    final n = file.name.toLowerCase();
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUploadImages() async {
    final slots = kMaxProductImagesPerProduct - _imageUrls.length;
    if (slots <= 0) {
      _snack('Maximum of $kMaxProductImagesPerProduct photos per product.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final id = widget.storageProductId.trim();
    if (id.isEmpty) {
      _snack('Missing storage id for uploads.');
      return;
    }

    final files = result.files.take(slots).toList();
    setState(() => _saving = true);
    try {
      final service = ref.read(adminServiceProvider);
      var uploaded = 0;
      for (final file in files) {
        if (_imageUrls.length >= kMaxProductImagesPerProduct) break;
        if (!_allowedProductImageFile(file)) {
          _snack('Skipped ${file.name} — use JPG, PNG, or WebP.');
          continue;
        }
        final raw = file.bytes;
        if (raw == null || raw.isEmpty) {
          _snack('Could not read ${file.name}.');
          continue;
        }
        if (raw.length > kMaxImagePickBytes) {
          _snack(
            '${file.name} is too large before processing '
            '(max ${kMaxImagePickBytes ~/ (1024 * 1024)} MB).',
          );
          continue;
        }
        final compressed = compressProductImageForUpload(Uint8List.fromList(raw));
        if (compressed == null) {
          _snack('Could not decode ${file.name}.');
          continue;
        }
        if (compressed.length > kMaxImageUploadBytes) {
          _snack('${file.name} is still over 2 MB after compression.');
          continue;
        }
        final url = await service.uploadProductImage(
          productId: id,
          bytes: compressed,
          fileName: file.name,
        );
        _imageUrls.add(url);
        uploaded++;
      }
      if (uploaded > 0) setState(() {});
    } catch (e) {
      if (!mounted) return;
      _snack('Upload failed: ${userFacingErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final rawDiscount = _discountPercentCtrl.text.trim();
    final discountPercent = rawDiscount.isEmpty
        ? 0
        : (int.tryParse(rawDiscount) ?? _discountPercent).clamp(0, 99);
    final input = ProductUpsertInput(
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      sku: _skuCtrl.text.trim(),
      brand: _brandCtrl.text.trim(),
      tags: _tagsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      price: double.parse(_priceCtrl.text.trim()),
      currency: kAppCurrencyCode,
      weight: double.tryParse(_weightCtrl.text.trim()) ?? 0,
      dimensions: _dimensionsCtrl.text.trim(),
      inventoryCount: int.parse(_inventoryCtrl.text.trim()),
      imageUrls: _imageUrls,
      displayDiscountPercent: discountPercent,
      isPopular: _isPopular,
      isRecommended: _isRecommended,
      isFestivalSpecial: _isFestivalSpecial,
    );
    setState(() => _saving = true);
    try {
      await widget.onSubmit(input);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showPreview() {
    final title = _titleCtrl.text.trim().isEmpty ? 'Product title' : _titleCtrl.text.trim();
    final description = _descriptionCtrl.text.trim().isEmpty
        ? 'Product description'
        : _descriptionCtrl.text.trim();
    final category = _categoryCtrl.text.trim().isEmpty ? '-' : _categoryCtrl.text.trim();
    final sku = _skuCtrl.text.trim().isEmpty ? '-' : _skuCtrl.text.trim();
    final brand = _brandCtrl.text.trim().isEmpty ? '-' : _brandCtrl.text.trim();
    final tags = _tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final dimensions = _dimensionsCtrl.text.trim().isEmpty ? '-' : _dimensionsCtrl.text.trim();

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_imageUrls.isNotEmpty)
                ProductImageCarousel(
                  imageUrls: _imageUrls,
                  height: 200,
                  borderRadius: BorderRadius.circular(10),
                ),
              const SizedBox(height: 10),
              Text(description),
              const SizedBox(height: 8),
              Text('Category: $category'),
              Text('SKU: $sku'),
              Text('Brand: $brand'),
              Text('Tags: ${tags.isEmpty ? '-' : tags.join(', ')}'),
              Text('Sale price: ${formatInrAmount(price)}'),
              Text('Card promo: $_discountPercent%'),
              Text('Weight: ${weight <= 0 ? '-' : '${weight.toStringAsFixed(3)} kg'}'),
              Text('Dimensions: $dimensions'),
              Text('Stock: ${_inventoryCtrl.text.trim().isEmpty ? '-' : _inventoryCtrl.text.trim()}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AdminProductImageTile extends StatelessWidget {
  final String imageUrl;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onPreview;

  const _AdminProductImageTile({
    super.key,
    required this.imageUrl,
    required this.index,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                return AdminCachedImage(
                  imageUrl: imageUrl,
                  width: c.maxWidth,
                  height: c.maxHeight,
                );
              },
            ),
            if (index == 0)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.marigoldOrange.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Primary',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoalBlack,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(30, 30),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.close, size: 16),
                onPressed: onRemove,
              ),
            ),
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: Colors.white.withOpacity(0.9),
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _AddImageTile({
    super.key,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withOpacity(0.45),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: enabled ? scheme.primary : scheme.onSurfaceVariant.withOpacity(0.38),
          ),
        ),
      ),
    );
  }
}
