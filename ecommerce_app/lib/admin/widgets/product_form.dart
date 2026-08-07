
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

/// Mutable row for the admin variant editor.
class _VariantLineEdit {
  _VariantLineEdit.fromUpsert(AdminVariantUpsert v)
      : id = v.id,
        typeCtrl = TextEditingController(text: v.variantType),
        nameCtrl = TextEditingController(text: v.variantName),
        priceCtrl = TextEditingController(text: v.price.toStringAsFixed(2)),
        stockCtrl = TextEditingController(text: v.stockQuantity.toString()),
        weightCtrl = TextEditingController(
          text: v.weight != null && v.weight! > 0 ? v.weight!.toStringAsFixed(3) : '',
        ),
        dimensionsCtrl = TextEditingController(text: v.dimensions ?? ''),
        imageCtrl = TextEditingController(text: v.imageUrl),
        skuCtrl = TextEditingController(text: v.sku ?? ''),
        isDefault = v.isDefault;

  _VariantLineEdit.emptyWithType(String type)
      : id = null,
        typeCtrl = TextEditingController(text: type.trim().isEmpty ? 'size' : type.trim().toLowerCase()),
        nameCtrl = TextEditingController(),
        priceCtrl = TextEditingController(text: '0'),
        stockCtrl = TextEditingController(text: '0'),
        weightCtrl = TextEditingController(),
        dimensionsCtrl = TextEditingController(),
        imageCtrl = TextEditingController(),
        skuCtrl = TextEditingController(),
        isDefault = false;

  final String? id;
  final TextEditingController typeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController dimensionsCtrl;
  final TextEditingController imageCtrl;
  final TextEditingController skuCtrl;
  bool isDefault;

  void dispose() {
    typeCtrl.dispose();
    nameCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    weightCtrl.dispose();
    dimensionsCtrl.dispose();
    imageCtrl.dispose();
    skuCtrl.dispose();
  }

  AdminVariantUpsert toUpsert() {
    final normalizedType = typeCtrl.text.trim().toLowerCase();
    return AdminVariantUpsert(
      id: id,
      variantType: normalizedType,
      variantName: nameCtrl.text.trim(),
      price: double.tryParse(priceCtrl.text.trim()) ?? 0,
      stockQuantity: int.tryParse(stockCtrl.text.trim()) ?? 0,
      weight: () {
        final w = double.tryParse(weightCtrl.text.trim());
        return (w != null && w > 0) ? w : null;
      }(),
      dimensions: () {
        final d = dimensionsCtrl.text.trim();
        return d.isEmpty ? null : d;
      }(),
      imageUrl: imageCtrl.text.trim(),
      sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
      isDefault: isDefault,
    );
  }
}

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
  /// Existing SKU rows when editing; preserved on save unless the variants editor is implemented.
  final List<AdminVariantUpsert> initialVariants;
  /// Folder id for storage paths `products/{id}/…` — existing product id or pre-assigned UUID for new products.
  final String storageProductId;
  final Future<void> Function(ProductUpsertInput input) onSubmit;

  const ProductForm({
    super.key,
    this.initialProduct,
    this.initialVariants = const [],
    required this.storageProductId,
    required this.onSubmit,
  });

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  static const _kCustomCategory = '__custom_category__';
  static const List<String> _kVariantTypePresets = <String>[
    'size',
    'color',
    'flavor',
    'weight',
    'pack',
    'material',
  ];

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
  late String _paymentMode;
  late String _deliveryChargeMode;
  late final TextEditingController _deliveryChargeInrCtrl;

  late final TextEditingController _newVariantTypeCtrl;
  final List<_VariantLineEdit> _variantLines = [];

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
    _paymentMode = p?.paymentMode == 'online_only' ? 'online_only' : 'both';
    final dMode = (p?.deliveryChargeMode ?? 'default').trim().toLowerCase();
    _deliveryChargeMode =
        (dMode == 'free' || dMode == 'custom') ? dMode : 'default';
    final dFee = p?.deliveryChargeInr;
    _deliveryChargeInrCtrl = TextEditingController(
      text: dFee != null && dFee >= 0 ? dFee.toStringAsFixed(2) : '',
    );

    _newVariantTypeCtrl = TextEditingController(
      text: widget.initialVariants.isNotEmpty ? widget.initialVariants.first.variantType : 'size',
    );
    for (final v in widget.initialVariants) {
      _variantLines.add(_VariantLineEdit.fromUpsert(v));
    }
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
    _deliveryChargeInrCtrl.dispose();
    for (final l in _variantLines) {
      l.dispose();
    }
    _newVariantTypeCtrl.dispose();
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
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        helperText: 'Required for courier shipping',
                      ),
                      validator: (v) {
                        final value = double.tryParse((v ?? '').trim());
                        if (value == null || value <= 0) {
                          return 'Enter weight > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _dimensionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dimensions (LxWxH cm)',
                        helperText: 'Required, e.g. 20x15x10',
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Enter dimensions';
                        final hasShape = RegExp(r'^\d+(\.\d+)?\s*[xX×]\s*\d+(\.\d+)?\s*[xX×]\s*\d+(\.\d+)?$')
                            .hasMatch(t);
                        if (!hasShape) return 'Use format LxWxH (e.g. 20x15x10)';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _inventoryCtrl,
                readOnly: _variantLines.isNotEmpty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Inventory Count',
                  helperText: _variantLines.isNotEmpty
                      ? 'Locked when variants exist. Stock is managed per variant.'
                      : null,
                ),
                validator: (v) {
                  final value = int.tryParse((v ?? '').trim());
                  if (value == null || value < 0) return 'Invalid count';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment mode',
                  helperText: 'Controls COD vs online-only at checkout.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'both',
                    child: Text('COD + Online (default)'),
                  ),
                  DropdownMenuItem(
                    value: 'online_only',
                    child: Text('Only Online Payment'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _paymentMode = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _deliveryChargeMode,
                decoration: const InputDecoration(
                  labelText: 'Delivery charge',
                  helperText:
                      'Store default uses global delivery settings. Free or custom overrides that product’s share of order shipping (order fee = highest rule).',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'default',
                    child: Text('Store default'),
                  ),
                  DropdownMenuItem(
                    value: 'free',
                    child: Text('Free delivery (disabled)'),
                  ),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom charge (override)'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _deliveryChargeMode = v);
                },
              ),
              if (_deliveryChargeMode == 'custom') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _deliveryChargeInrCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Custom delivery charge (₹)',
                    helperText: 'Fixed delivery fee for this product’s rule (order uses the max across cart).',
                  ),
                  validator: (v) {
                    if (_deliveryChargeMode != 'custom') return null;
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Enter custom delivery amount';
                    final n = double.tryParse(t);
                    if (n == null || n < 0) return 'Invalid amount';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _variantLines.isNotEmpty,
                title: Text(
                  'Product variants (optional)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                subtitle: const Text(
                  'Each option has type + name (for example Size: M, Color: Red). '
                  'Newly added options appear at the top.',
                ),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kVariantTypePresets
                        .map(
                          (type) => ActionChip(
                            label: Text(type),
                            onPressed: () => setState(() => _newVariantTypeCtrl.text = type),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newVariantTypeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Type for next option',
                            hintText: 'size, color, flavor, material...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _variantLines.insert(
                              0,
                              _VariantLineEdit.emptyWithType(_newVariantTypeCtrl.text),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add option'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _variantLines.insert(
                            0,
                            _VariantLineEdit.emptyWithType(_newVariantTypeCtrl.text),
                          );
                        });
                      },
                      icon: const Icon(Icons.vertical_align_top),
                      label: const Text('Add option to top'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Quick guide: Add options -> mark one default -> optional image per option. '
                      'If option image is empty, product primary image is used.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._variantLines.asMap().entries.map((e) {
                    final i = e.key;
                    final line = e.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Option ${i + 1}',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () {
                                    setState(() {
                                      line.dispose();
                                      _variantLines.removeAt(i);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: TextFormField(
                                    controller: line.typeCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Type (e.g. size, color)',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 210,
                                  child: TextFormField(
                                    controller: line.nameCtrl,
                                    decoration:
                                        const InputDecoration(labelText: 'Name (e.g. M, 250ml)'),
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: TextFormField(
                                    controller: line.priceCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Price (INR)'),
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: TextFormField(
                                    controller: line.stockCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(labelText: 'Stock'),
                                  ),
                                ),
                                SizedBox(
                                  width: 170,
                                  child: TextFormField(
                                    controller: line.weightCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}$')),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Weight kg (optional)',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: TextFormField(
                                    controller: line.dimensionsCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Dimensions cm (optional)',
                                      hintText: 'LxWxH, e.g. 20x15x10',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: TextFormField(
                                    controller: line.skuCtrl,
                                    decoration: const InputDecoration(labelText: 'SKU (optional)'),
                                  ),
                                ),
                              ],
                            ),
                            TextFormField(
                              controller: line.imageCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Image URL or storage path',
                                helperText:
                                    'Optional. If empty, product primary image is used in storefront.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => _pickAndUploadVariantImage(line),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload variant image'),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(line.imageCtrl.clear),
                                  child: const Text('Use product image'),
                                ),
                              ],
                            ),
                            if (line.imageCtrl.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AdminCachedImage(
                                  imageUrl: line.imageCtrl.text.trim(),
                                  width: 72,
                                  height: 72,
                                ),
                              ),
                            ],
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Default option'),
                              value: line.isDefault,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    for (final o in _variantLines) {
                                      o.isDefault = false;
                                    }
                                    line.isDefault = true;
                                  } else {
                                    line.isDefault = false;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
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
                'Use square photos (1:1). Recommended: $kRecommendedProductImageSize×$kRecommendedProductImageSize px · Minimum: $kMinimumProductImageSize×$kMinimumProductImageSize px.',
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

  Future<void> _pickAndUploadVariantImage(_VariantLineEdit line) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final id = widget.storageProductId.trim();
    if (id.isEmpty) {
      _snack('Missing storage id for uploads.');
      return;
    }

    final file = result.files.first;
    if (!_allowedProductImageFile(file)) {
      _snack('Use JPG, PNG, or WebP image.');
      return;
    }
    final raw = file.bytes;
    if (raw == null || raw.isEmpty) {
      _snack('Could not read ${file.name}.');
      return;
    }
    if (raw.length > kMaxImagePickBytes) {
      _snack(
        '${file.name} is too large before processing '
        '(max ${kMaxImagePickBytes ~/ (1024 * 1024)} MB).',
      );
      return;
    }
    final compressed = compressProductImageForUpload(Uint8List.fromList(raw));
    if (compressed == null) {
      _snack('Could not decode ${file.name}.');
      return;
    }
    if (compressed.length > kMaxImageUploadBytes) {
      _snack('${file.name} is still over 2 MB after compression.');
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(adminServiceProvider);
      final url = await service.uploadProductImage(
        productId: id,
        bytes: compressed,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => line.imageCtrl.text = url);
      _snack('Variant image uploaded.');
    } catch (e) {
      if (!mounted) return;
      _snack('Upload failed: ${userFacingErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    List<AdminVariantUpsert> variants;
    if (_variantLines.isEmpty) {
      variants = const [];
    } else {
      final built = <AdminVariantUpsert>[];
      var defaults = 0;
      final seenNames = <String>{};
      for (final l in _variantLines) {
        final u = l.toUpsert();
        if (u.variantType.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Each option needs a variant type.')),
          );
          return;
        }
        if (u.variantName.trim().isEmpty) continue;
        final normalized = '${u.variantType.trim().toLowerCase()}::${u.variantName.trim().toLowerCase()}';
        if (!seenNames.add(normalized)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Duplicate option: ${u.variantType} - ${u.variantName}'),
            ),
          );
          return;
        }
        if (u.stockQuantity < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid stock for variant: ${u.variantName}')),
          );
          return;
        }
        if (u.weight != null && u.weight! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid weight for variant: ${u.variantName}')),
          );
          return;
        }
        final dims = u.dimensions?.trim() ?? '';
        if (dims.isNotEmpty) {
          final hasShape = RegExp(r'^\d+(\.\d+)?\s*[xX×]\s*\d+(\.\d+)?\s*[xX×]\s*\d+(\.\d+)?$')
              .hasMatch(dims);
          if (!hasShape) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Use LxWxH format for variant dimensions: ${u.variantName}'),
              ),
            );
            return;
          }
        }
        if (u.isDefault) defaults++;
        built.add(u);
      }
      if (built.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each variant needs a name.')),
        );
        return;
      }
      if (defaults != 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mark exactly one variant as default.')),
        );
        return;
      }
      variants = built;
    }

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
      paymentMode: _paymentMode,
      deliveryChargeMode: _deliveryChargeMode,
      deliveryChargeInr: _deliveryChargeMode == 'custom'
          ? double.tryParse(_deliveryChargeInrCtrl.text.trim())
          : null,
      variants: variants,
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
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: 'Sale price: '),
                    TextSpan(
                      text: formatInrAmount(price),
                      style: const TextStyle(
                        color: AppColors.priceText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
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
                    color: AppColors.marigoldOrange.withValues(alpha: 0.95),
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
                color: Colors.white.withValues(alpha: 0.9),
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
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: enabled ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}
