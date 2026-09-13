import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ecommerce_app/core/constants/stock_constants.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';

import '../utils/admin_android_ui.dart';
import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../widgets/admin_cached_image.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_state_view.dart';
import '../widgets/admin_delivery_settings_card.dart';
import '../widgets/product_form.dart';

enum _StockFilter { all, inStock, lowStock, outOfStock }

class AdminProductsPage extends ConsumerStatefulWidget {
  const AdminProductsPage({super.key});

  @override
  ConsumerState<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends ConsumerState<AdminProductsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'All';
  _StockFilter _stockFilter = _StockFilter.all;
  String _sortBy = 'Date (Newest)';
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(adminProductsProvider);
    return AdminStateView(
      isLoading: productsAsync.isLoading,
      error: productsAsync.asError?.error,
      isEmpty: (productsAsync.asData?.value ?? const []).isEmpty,
      emptyMessage: 'No products found',
      child: productsAsync.when(
        data: (products) {
          final categories = <String>{'All'};
          for (final p in products) {
            final c = (p.category ?? '').trim();
            if (c.isNotEmpty) categories.add(c);
          }

          final filtered = [...products].where((p) {
            final q = _query.trim().toLowerCase();
            final matchesSearch = q.isEmpty ||
                p.title.toLowerCase().contains(q) ||
                (p.category ?? '').toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q);
            final matchesCategory =
                _category == 'All' || (p.category ?? '') == _category;
            final matchesStock = switch (_stockFilter) {
              _StockFilter.all => true,
              _StockFilter.inStock => p.sellableStock >= kHealthyStockMin,
              _StockFilter.lowStock => sellableStockIsLow(p.sellableStock),
              _StockFilter.outOfStock => p.sellableStock <= 0,
            };
            return matchesSearch && matchesCategory && matchesStock;
          }).toList();

          filtered.sort((a, b) {
            switch (_sortBy) {
              case 'Price (Low to High)':
                return a.price.compareTo(b.price);
              case 'Price (High to Low)':
                return b.price.compareTo(a.price);
              case 'Date (Oldest)':
                return (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                        b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
              case 'Date (Newest)':
              default:
                return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                        a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
            }
          });

          final screenWidth = MediaQuery.sizeOf(context).width;
          final compact = kAdminAndroidCompactChrome || screenWidth < 960;
          final denseWeb = !compact;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedIds.isNotEmpty) ...[
                        adminAndroidToolbarIconButton(
                          icon: Icons.category_outlined,
                          tooltip: 'Update category (${_selectedIds.length})',
                          onPressed: () =>
                              _bulkUpdateCategory(context, products),
                        ),
                        adminAndroidToolbarIconButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete ${_selectedIds.length} selected',
                          color: Colors.red,
                          onPressed: () => _bulkDelete(context, products),
                        ),
                      ],
                      const AdminDeliverySettingsButton(compact: true),
                      adminAndroidToolbarIconButton(
                        icon: Icons.refresh,
                        tooltip: 'Refresh',
                        onPressed: () {
                          ref.invalidate(adminProductsProvider);
                          ref.invalidate(adminDashboardProvider);
                        },
                      ),
                      adminAndroidToolbarIconButton(
                        icon: Icons.add,
                        tooltip: 'Add product',
                        onPressed: () =>
                            _openProductForm(context: context, product: null),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 2),
              Card(
                margin: compact ? EdgeInsets.zero : null,
                child: Padding(
                  padding: denseWeb
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                      : adminFilterCardPadding,
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() {
                                _query = v;
                              }),
                              decoration: const InputDecoration(
                                labelText: 'Search products',
                                prefixIcon: Icon(Icons.search),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  DropdownButton<String>(
                                    isDense: true,
                                    value: _category,
                                    items: categories
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text('Cat: $c'),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _category = v;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  DropdownButton<_StockFilter>(
                                    isDense: true,
                                    value: _stockFilter,
                                    items: const [
                                      DropdownMenuItem(
                                        value: _StockFilter.all,
                                        child: Text('Stock: All'),
                                      ),
                                      DropdownMenuItem(
                                        value: _StockFilter.inStock,
                                        child: Text('Stock: In'),
                                      ),
                                      DropdownMenuItem(
                                        value: _StockFilter.lowStock,
                                        child: Text('Stock: Low'),
                                      ),
                                      DropdownMenuItem(
                                        value: _StockFilter.outOfStock,
                                        child: Text('Stock: Out'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _stockFilter = v;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  DropdownButton<String>(
                                    isDense: true,
                                    value: _sortBy,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Date (Newest)',
                                        child: Text('Sort: Newest'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Date (Oldest)',
                                        child: Text('Sort: Oldest'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Price (Low to High)',
                                        child: Text('Sort: \$↑'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Price (High to Low)',
                                        child: Text('Sort: \$↓'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      setState(() {
                                        _sortBy = v;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 40,
                                      maxHeight: 44,
                                    ),
                                    child: TextField(
                                      controller: _searchCtrl,
                                      onChanged: (v) => setState(() {
                                        _query = v;
                                      }),
                                      decoration: const InputDecoration(
                                        labelText: 'Search products',
                                        prefixIcon: Icon(Icons.search),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    DropdownButton<String>(
                                      isDense: true,
                                      value: _category,
                                      items: categories
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text('Category: $c'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _category = v;
                                        });
                                      },
                                    ),
                                    DropdownButton<_StockFilter>(
                                      isDense: true,
                                      value: _stockFilter,
                                      items: const [
                                        DropdownMenuItem(
                                          value: _StockFilter.all,
                                          child: Text('Stock: All'),
                                        ),
                                        DropdownMenuItem(
                                          value: _StockFilter.inStock,
                                          child: Text('Stock: In Stock'),
                                        ),
                                        DropdownMenuItem(
                                          value: _StockFilter.lowStock,
                                          child: Text('Stock: Low'),
                                        ),
                                        DropdownMenuItem(
                                          value: _StockFilter.outOfStock,
                                          child: Text('Stock: Out of Stock'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _stockFilter = v;
                                        });
                                      },
                                    ),
                                    DropdownButton<String>(
                                      isDense: true,
                                      value: _sortBy,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Date (Newest)',
                                          child: Text('Sort: Date (Newest)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Date (Oldest)',
                                          child: Text('Sort: Date (Oldest)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Price (Low to High)',
                                          child:
                                              Text('Sort: Price (Low to High)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Price (High to Low)',
                                          child:
                                              Text('Sort: Price (High to Low)'),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() {
                                          _sortBy = v;
                                        });
                                      },
                                    ),
                                    const AdminDeliverySettingsButton(),
                                    FilledButton.tonalIcon(
                                      onPressed: () {
                                        ref.invalidate(adminProductsProvider);
                                        ref.invalidate(adminDashboardProvider);
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: () => _openProductForm(
                                          context: context, product: null),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Product'),
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_selectedIds.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _bulkUpdateCategory(
                                          context, products),
                                      icon: const Icon(Icons.category_outlined),
                                      label: Text(
                                          'Update Category (${_selectedIds.length})'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _bulkDelete(context, products),
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      label: Text(
                                          'Delete Selected (${_selectedIds.length})'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AdminDataTable<AdminProduct>(
                  rows: filtered,
                  emptyMessage: 'No products found',
                  columns: [
                    AdminTableColumn<AdminProduct>(
                      label: 'Select',
                      cellBuilder: (p) => Checkbox(
                        value: _selectedIds.contains(p.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedIds.add(p.id);
                            } else {
                              _selectedIds.remove(p.id);
                            }
                          });
                        },
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Image',
                      cellBuilder: (p) {
                        if (p.imageUrls.isNotEmpty) {
                          return AdminCachedImage(
                            imageUrl: p.imageUrls.first,
                            width: 48,
                            height: 48,
                            borderRadius: BorderRadius.circular(8),
                            errorWidget: _noPhotoBadge(),
                          );
                        }
                        return _noPhotoBadge();
                      },
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Title',
                      sortValue: (p) => p.title,
                      cellBuilder: (p) => Text(p.title),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Category',
                      sortValue: (p) => p.category ?? '',
                      cellBuilder: (p) => Text(p.category ?? ''),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Price',
                      sortValue: (p) => p.price,
                      cellBuilder: (p) => Text(
                        formatInrAmount(p.price),
                        style: const TextStyle(
                          color: AppColors.priceText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'HSN Code',
                      sortValue: (p) => p.hsnCode ?? '',
                      cellBuilder: (p) => Text(
                        p.hsnCode?.trim().isNotEmpty == true ? p.hsnCode! : '—',
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'GST %',
                      sortValue: (p) => p.gstRate ?? 0,
                      cellBuilder: (p) {
                        if (p.taxStatus == 'exempt') return const Text('Exempt');
                        if (p.taxStatus == 'zero_rated') return const Text('0% (Zero)');
                        if (p.gstRate != null) return Text('${p.gstRate}%');
                        return const Text('—');
                      },
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Card % off',
                      sortValue: (p) => p.displayDiscountPercent,
                      cellBuilder: (p) => Text(
                        p.displayDiscountPercent <= 0
                            ? '—'
                            : '${p.displayDiscountPercent}%',
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Sellable',
                      sortValue: (p) => p.sellableStock,
                      cellBuilder: (p) => Text(p.sellableStock.toString()),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Reserved',
                      sortValue: (p) => p.reservedQuantity,
                      cellBuilder: (p) => Text(p.reservedQuantity.toString()),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Status',
                      sortValue: (p) => p.isActive ? 1 : 0,
                      cellBuilder: (p) => Chip(
                        label: Text(p.isActive ? 'Active' : 'Inactive'),
                        backgroundColor: p.isActive
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Quick Actions',
                      cellBuilder: (p) => Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message:
                                  p.isActive ? 'Set inactive' : 'Set active',
                              child: Switch.adaptive(
                                value: p.isActive,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (_) => _toggleActive(p),
                              ),
                            ),
                            const SizedBox(width: 4),
                            _quickActionIconButton(
                              tooltip: 'Duplicate',
                              icon: Icons.copy_outlined,
                              onPressed: () => _duplicateProduct(p),
                            ),
                            _quickActionIconButton(
                              tooltip: 'Preview',
                              icon: Icons.visibility_outlined,
                              onPressed: () => _previewProduct(context, p),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Edit',
                      cellBuilder: (p) => IconButton(
                        onPressed: () =>
                            _openProductForm(context: context, product: p),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                    AdminTableColumn<AdminProduct>(
                      label: 'Delete',
                      cellBuilder: (p) => IconButton(
                        onPressed: () => _deleteProduct(context, p),
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _openProductForm({
    required BuildContext context,
    required AdminProduct? product,
  }) async {
    final service = ref.read(adminServiceProvider);
    final storageId = product?.id ?? const Uuid().v4();
    var initialVariants = const <AdminVariantUpsert>[];
    if (product != null) {
      try {
        initialVariants = await service.fetchProductVariants(product.id);
      } catch (_) {}
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ProductForm(
            storageProductId: storageId,
            initialProduct: product,
            initialVariants: initialVariants,
            onSubmit: (input) async {
              if (product == null) {
                await service.createProduct(input, explicitId: storageId);
              } else {
                await service.updateProduct(product.id, input);
              }
              ref.invalidate(adminProductsProvider);
              ref.invalidate(adminDashboardProvider);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(
      BuildContext context, AdminProduct product) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete product?'),
            content:
                Text('Are you sure you want to delete "${product.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    try {
      await ref.read(adminServiceProvider).deleteProduct(product.id);
      _selectedIds.remove(product.id);
      ref.invalidate(adminProductsProvider);
      ref.invalidate(adminDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.title}" removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete "${product.title}": $e')),
      );
    }
  }

  Future<void> _toggleActive(AdminProduct product) async {
    final ok = await ref.read(adminServiceProvider).updateProductActive(
          productId: product.id,
          isActive: !product.isActive,
        );
    if (ok) {
      ref.invalidate(adminProductsProvider);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Active/inactive toggle is not available in this schema')),
      );
    }
  }

  Future<void> _duplicateProduct(AdminProduct product) async {
    final service = ref.read(adminServiceProvider);
    List<AdminVariantUpsert> variantCopy = const [];
    try {
      final existing = await service.fetchProductVariants(product.id);
      variantCopy = existing
          .map(
            (v) => AdminVariantUpsert(
              variantType: v.variantType,
              variantName: v.variantName,
              price: v.price,
              stockQuantity: v.stockQuantity,
              imageUrl: v.imageUrl,
              sku: v.sku,
              isDefault: v.isDefault,
            ),
          )
          .toList();
    } catch (_) {}
    final input = ProductUpsertInput(
      title: '${product.title} (Copy)',
      description: product.description,
      category: product.category ?? '',
      sku: product.sku,
      brand: product.brand,
      tags: product.tags,
      price: product.price,
      currency: product.currency,
      weight: product.weight,
      dimensions: product.dimensions,
      inventoryCount: product.inventoryCount,
      imageUrls: product.imageUrls,
      displayDiscountPercent: product.displayDiscountPercent,
      isPopular: product.isPopular,
      isRecommended: product.isRecommended,
      isFestivalSpecial: product.isFestivalSpecial,
      paymentMode: product.paymentMode,
      deliveryChargeMode: product.deliveryChargeMode,
      deliveryChargeInr: product.deliveryChargeInr,
      hsnCode: product.hsnCode,
      gstRate: product.gstRate,
      taxStatus: product.taxStatus,
      priceIncludesGst: product.priceIncludesGst,
      variants: variantCopy,
    );
    await service.createProduct(input);
    ref.invalidate(adminProductsProvider);
    ref.invalidate(adminDashboardProvider);
  }

  void _previewProduct(BuildContext context, AdminProduct product) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(product.title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrls.isNotEmpty)
                AdminCachedImage(
                  imageUrl: product.imageUrls.first,
                  height: 180,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(10),
                ),
              const SizedBox(height: 10),
              Text(product.description),
              const SizedBox(height: 8),
              Text('Category: ${product.category ?? '-'}'),
              Text('SKU: ${product.sku.isEmpty ? '-' : product.sku}'),
              Text('Brand: ${product.brand.isEmpty ? '-' : product.brand}'),
              Text('HSN Code: ${product.hsnCode?.isNotEmpty == true ? product.hsnCode : '-'}'),
              Text('Tax Status: ${product.taxStatus}'),
              Text('GST Rate: ${product.gstRate != null ? '${product.gstRate}%' : '-'} (${product.priceIncludesGst ? 'Inclusive' : 'Exclusive'})'),
              Text(
                  'Tags: ${product.tags.isEmpty ? '-' : product.tags.join(', ')}'),
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    const TextSpan(text: 'Sale price: '),
                    TextSpan(
                      text: formatInrAmount(product.price),
                      style: const TextStyle(
                        color: AppColors.priceText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                  'Weight: ${product.weight <= 0 ? '-' : product.weight.toStringAsFixed(3)} kg'),
              Text(
                  'Dimensions: ${product.dimensions.isEmpty ? '-' : product.dimensions}'),
              Text(
                'Stock: ${product.sellableStock} sellable '
                '(reserved: ${product.reservedQuantity}, total: ${product.inventoryCount})',
              ),
              Text(
                product.displayDiscountPercent <= 0
                    ? 'Card promo: off'
                    : 'Card promo: ${product.displayDiscountPercent}%',
              ),
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

  Future<void> _bulkDelete(
      BuildContext context, List<AdminProduct> allProducts) async {
    if (_selectedIds.isEmpty) return;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete selected products?'),
            content: Text('Delete ${_selectedIds.length} selected products?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    final service = ref.read(adminServiceProvider);
    try {
      for (final id in _selectedIds.toList()) {
        await service.deleteProduct(id);
      }
      setState(() => _selectedIds.clear());
      ref.invalidate(adminProductsProvider);
      ref.invalidate(adminDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected products removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk delete failed: $e')),
      );
    }
  }

  Future<void> _bulkUpdateCategory(
      BuildContext context, List<AdminProduct> allProducts) async {
    if (_selectedIds.isEmpty) return;
    final ctrl = TextEditingController();
    final category = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update category'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'New category'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('Update')),
        ],
      ),
    );
    if (category == null || category.isEmpty) return;

    final service = ref.read(adminServiceProvider);
    for (final p in allProducts.where((e) => _selectedIds.contains(e.id))) {
      var initialVariants = const <AdminVariantUpsert>[];
      try {
        initialVariants = await service.fetchProductVariants(p.id);
      } catch (_) {}
      await service.updateProduct(
        p.id,
        ProductUpsertInput(
          title: p.title,
          description: p.description,
          category: category,
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
          isPopular: p.isPopular,
          isRecommended: p.isRecommended,
          isFestivalSpecial: p.isFestivalSpecial,
          paymentMode: p.paymentMode,
          deliveryChargeMode: p.deliveryChargeMode,
          deliveryChargeInr: p.deliveryChargeInr,
          hsnCode: p.hsnCode,
          gstRate: p.gstRate,
          taxStatus: p.taxStatus,
          priceIncludesGst: p.priceIncludesGst,
          variants: initialVariants,
        ),
      );
    }
    setState(() => _selectedIds.clear());
    ref.invalidate(adminProductsProvider);
  }
}

/// Compact icon control for table cells so [DataTable] column width does not collapse icons on top of each other.
Widget _quickActionIconButton({
  required String tooltip,
  required IconData icon,
  required VoidCallback onPressed,
}) {
  return IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 22),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

Widget _noPhotoBadge() {
  return Container(
    width: 64,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'No photo',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}
