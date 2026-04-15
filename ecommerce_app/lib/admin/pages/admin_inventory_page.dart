import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';
import '../utils/admin_android_ui.dart';
import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../widgets/admin_cached_image.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_state_view.dart';
import '../widgets/admin_delivery_settings_card.dart';
import '../widgets/admin_new_category_dialog.dart';
import '../widgets/product_form.dart';

class AdminInventoryPage extends ConsumerStatefulWidget {
  const AdminInventoryPage({super.key});

  @override
  ConsumerState<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends ConsumerState<AdminInventoryPage> {
  String _query = '';
  final Set<String> _selectedIds = {};
  _InventoryStockFilter? _stockFilter = _InventoryStockFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(adminInventoryProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 640;
    final isNarrow = width < 1024;
    return AdminStateView(
      isLoading: productsAsync.isLoading,
      error: productsAsync.asError?.error,
      isEmpty: (productsAsync.asData?.value ?? const []).isEmpty,
      emptyMessage: 'No inventory items found',
      child: productsAsync.when(
      data: (products) {
        final activeFilter = _stockFilter ?? _InventoryStockFilter.all;
        final filtered = products.where((p) {
          final q = _query.trim().toLowerCase();
          final textMatches = q.isEmpty ||
              p.productTitle.toLowerCase().contains(q) ||
              p.productId.toLowerCase().contains(q) ||
              (p.variantName ?? '').toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              (p.category ?? '').toLowerCase().contains(q);
          if (!textMatches) return false;
          return switch (activeFilter) {
            _InventoryStockFilter.all => true,
            _InventoryStockFilter.outOfStock => p.outOfStock,
            _InventoryStockFilter.lowStock => p.lowStock,
            _InventoryStockFilter.healthy => !p.lowStock && !p.outOfStock,
          };
        }).toList();
        final lowStock = products.where((p) => p.lowStock).length;
        final outOfStock = products.where((p) => p.outOfStock).length;
        final totalRows = products.length;
        final variantRows = products.where((p) => p.hasVariant).length;
        final productOnlyRows = totalRows - variantRows;

        final theme = Theme.of(context);
        final compact = kAdminAndroidCompactChrome;
        final compactTop = compact || kIsWeb || isNarrow;
        final denseTop = compactTop;
        final cardWidth = isPhone ? 170.0 : (isNarrow ? 180.0 : 150.0);
        final useDesktopSplit = !isNarrow;

        final metricsStrip = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _InventoryAlertCard(
              title: 'Rows',
              value: totalRows.toString(),
              color: AppColors.deepGold,
              compact: true,
              width: cardWidth,
              ultraCompact: true,
            ),
            _InventoryAlertCard(
              title: 'Variant',
              value: variantRows.toString(),
              color: AppColors.forestGreen,
              compact: true,
              width: cardWidth,
              ultraCompact: true,
            ),
            _InventoryAlertCard(
              title: 'No Variant',
              value: productOnlyRows.toString(),
              color: AppColors.charcoalBlack,
              compact: true,
              width: cardWidth,
              ultraCompact: true,
            ),
            _InventoryAlertCard(
              title: 'Low Stock',
              value: lowStock.toString(),
              color: AppColors.warningAmber,
              compact: true,
              width: cardWidth,
              ultraCompact: true,
            ),
            _InventoryAlertCard(
              title: 'Out of Stock',
              value: outOfStock.toString(),
              color: AppColors.errorRed,
              compact: true,
              width: cardWidth,
              ultraCompact: true,
            ),
          ],
        );

        final searchFilterCard = Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: compactTop
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                : adminFilterCardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by product, variant, SKU, or category',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _query = '';
                            }),
                            icon: const Icon(Icons.clear),
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Showing ${filtered.length} of $totalRows rows',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(
                      label: 'All',
                      selected: activeFilter == _InventoryStockFilter.all,
                      onTap: () => setState(() => _stockFilter = _InventoryStockFilter.all),
                    ),
                    _filterChip(
                      label: 'Out of stock',
                      selected: activeFilter == _InventoryStockFilter.outOfStock,
                      onTap: () => setState(() => _stockFilter = _InventoryStockFilter.outOfStock),
                    ),
                    _filterChip(
                      label: 'Low stock',
                      selected: activeFilter == _InventoryStockFilter.lowStock,
                      onTap: () => setState(() => _stockFilter = _InventoryStockFilter.lowStock),
                    ),
                    _filterChip(
                      label: 'Healthy',
                      selected: activeFilter == _InventoryStockFilter.healthy,
                      onTap: () => setState(() => _stockFilter = _InventoryStockFilter.healthy),
                    ),
                  ],
                ),
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _bulkUpdateStock(filtered),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text('Bulk stock (${_selectedIds.length})'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(_selectedIds.clear),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear selection'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: denseTop ? 0 : 2),
                        if (compact)
                          Row(
                children: [
                  AdminDeliverySettingsButton(compact: true),
                  adminAndroidToolbarIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: () {
                      ref.invalidate(adminInventoryProvider);
                      ref.invalidate(adminDashboardProvider);
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onSelected: (v) async {
                      if (v == 'cat') {
                        final slug = await showAdminNewCategoryDialog(
                          context: context,
                          ref: ref,
                        );
                        if (!mounted) return;
                        if (slug != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Category “$slug” created. You can assign it when adding items.',
                              ),
                            ),
                          );
                        }
                      } else if (v == 'add') {
                        _openProductForm(context: context);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<String>(
                        value: 'cat',
                        child: Text('New category'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'add',
                        child: Text('Add inventory item'),
                      ),
                    ],
                  ),
                ],
              )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const AdminDeliverySettingsButton(compact: true),
                              FilledButton.tonalIcon(
                    onPressed: () {
                      ref.invalidate(adminInventoryProvider);
                      ref.invalidate(adminDashboardProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                              OutlinedButton.icon(
                    onPressed: () async {
                      final slug = await showAdminNewCategoryDialog(
                        context: context,
                        ref: ref,
                      );
                      if (!mounted) return;
                      if (slug != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Category “$slug” created. You can assign it when adding items.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('New category'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                              FilledButton.icon(
                    onPressed: () => _openProductForm(context: context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add inventory item'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        if (useDesktopSplit)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: searchFilterCard),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: Align(alignment: Alignment.topRight, child: metricsStrip)),
                            ],
                          )
                        else ...[
                          metricsStrip,
                          const SizedBox(height: 6),
                          searchFilterCard,
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  flex: 3,
                  child: AdminDataTable<AdminInventoryRow>(
                rows: filtered,
                initialRowsPerPage: isPhone ? 8 : (isNarrow ? 14 : 25),
                minTableWidth: isPhone ? 980 : (isNarrow ? 1120 : 1240),
                emptyMessage: 'No inventory items found',
                columns: [
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Select',
                    cellBuilder: (p) => Checkbox(
                      value: _selectedIds.contains(p.rowId),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedIds.add(p.rowId);
                          } else {
                            _selectedIds.remove(p.rowId);
                          }
                        });
                      },
                    ),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Product',
                    sortValue: (p) => p.productTitle,
                    cellBuilder: (p) => Text(
                      p.productTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Variant',
                    sortValue: (p) => p.variantName ?? '',
                    cellBuilder: (p) => Text(
                      p.variantName == null
                          ? 'Product-level stock'
                          : '${p.variantType?.trim().isNotEmpty == true ? '${p.variantType}: ' : ''}${p.variantName}',
                    ),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Image',
                    cellBuilder: (p) {
                      final usesProductImage = p.variantImageUrl == p.productImageUrl;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.variantImageUrl.trim().isNotEmpty)
                            AdminCachedImage(
                              imageUrl: p.variantImageUrl,
                              width: 36,
                              height: 36,
                              borderRadius: BorderRadius.circular(8),
                              errorWidget: _noPhotoBadge(),
                            )
                          else
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: _noPhotoBadge(),
                            ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: usesProductImage ? 'Using product image' : 'Using variant image',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: usesProductImage
                                    ? Colors.grey.withOpacity(0.14)
                                    : AppColors.forestGreen.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                usesProductImage ? 'P' : 'V',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'SKU',
                    sortValue: (p) => p.sku,
                    cellBuilder: (p) => Text(p.sku.trim().isEmpty ? '-' : p.sku),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Price',
                    sortValue: (p) => p.price,
                    cellBuilder: (p) => Text('₹${p.price.toStringAsFixed(2)}'),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Stock',
                    sortValue: (p) => p.stockQuantity,
                    cellBuilder: (p) => Text(p.stockQuantity.toString()),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Reserved',
                    sortValue: (p) => p.reservedQuantity, cellBuilder: (p) => Text(p.reservedQuantity.toString()),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Available',
                    sortValue: (p) => p.availableStock,
                    cellBuilder: (p) => Text(p.availableStock.toString()),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Alert',
                    sortValue: (p) => p.availableStock,
                    cellBuilder: (p) {
                      if (p.availableStock <= 0) {
                        return const Chip(
                          label: Text('Out of stock'),
                          backgroundColor: Color(0x22F44336),
                        );
                      }
                      if (p.availableStock < 10) {
                        return const Chip(
                          label: Text('Low stock (<10)'),
                          backgroundColor: Color(0x22FF9800),
                        );
                      }
                      return const Chip(
                        label: Text('Healthy'),
                        backgroundColor: Color(0x224CAF50),
                      );
                    },
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Update',
                    cellBuilder: (p) => OutlinedButton(
                      onPressed: () => _updateStock(context, ref, p),
                      child: const Text('Update'),
                    ),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Edit',
                    cellBuilder: (p) => IconButton(
                      tooltip: 'Edit inventory item',
                      onPressed: () => _openProductForm(
                        context: context,
                        productId: p.productId,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  AdminTableColumn<AdminInventoryRow>(
                    label: 'Delete',
                    cellBuilder: (p) => IconButton(
                      tooltip: 'Delete inventory item',
                      onPressed: () => _deleteItem(
                        context,
                        AdminProduct(
                          id: p.productId,
                          title: p.productTitle,
                          description: '',
                          category: p.category,
                          sku: p.sku,
                          brand: '',
                          tags: const [],
                          price: p.price,
                          currency: 'INR',
                          weight: 0,
                          dimensions: '',
                          inventoryCount: p.stockQuantity,
                          imageUrls: p.productImageUrl.trim().isEmpty
                              ? const []
                              : [p.productImageUrl],
                          createdAt: null,
                          isActive: true,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ),
                ],
              ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    ),
    );
  }

  Future<void> _updateStock(
    BuildContext context,
    WidgetRef ref,
    AdminInventoryRow row,
  ) async {
    final controller = TextEditingController(text: row.stockQuantity.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Inventory Count'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (result == null || result < 0) return;
    if (result < row.reservedQuantity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock cannot be less than reserved (${row.reservedQuantity}).'),
        ),
      );
      return;
    }
    try {
      final service = ref.read(adminServiceProvider);
      if (row.hasVariant) {
        await service.updateVariantInventory(
          variantId: row.variantId!,
          stockQuantity: result,
        );
      } else {
        await service.updateInventory(
          productId: row.productId,
          inventoryCount: result,
        );
      }
      ref.invalidate(adminInventoryProvider);
      ref.invalidate(adminDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update stock: $e')),
      );
    }
  }

  Future<void> _bulkUpdateStock(List<AdminInventoryRow> rows) async {
    final ctrl = TextEditingController();
    final mode = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bulk Stock Action'),
        content: const Text('Choose the bulk action to apply on selected rows.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('mark_oos'),
            child: const Text('Mark out of stock'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('increase'),
            child: const Text('Increase stock'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('set'),
            child: const Text('Set stock'),
          ),
        ],
      ),
    );
    if (mode == null) return;

    int deltaOrSetValue = 0;
    if (mode == 'set' || mode == 'increase') {
      final value = await showDialog<int>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(mode == 'set' ? 'Set stock value' : 'Increase stock by'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Enter value'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(int.tryParse(ctrl.text.trim())),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (value == null || value < 0) return;
      deltaOrSetValue = value;
    }

    try {
      final service = ref.read(adminServiceProvider);
      for (final row in rows.where((p) => _selectedIds.contains(p.rowId))) {
        final next = switch (mode) {
          'mark_oos' => row.reservedQuantity,
          'increase' => row.stockQuantity + deltaOrSetValue,
          _ => deltaOrSetValue,
        };
        if (row.hasVariant) {
          await service.updateVariantInventory(
            variantId: row.variantId!,
            stockQuantity: next < row.reservedQuantity ? row.reservedQuantity : next,
          );
        } else {
          await service.updateInventory(
            productId: row.productId,
            inventoryCount: next < row.reservedQuantity ? row.reservedQuantity : next,
          );
        }
      }
      setState(() => _selectedIds.clear());
      ref.invalidate(adminInventoryProvider);
      ref.invalidate(adminDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk stock action completed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk stock update failed: $e')),
      );
    }
  }

  Future<void> _openProductForm({
    required BuildContext context,
    String? productId,
  }) async {
    final service = ref.read(adminServiceProvider);
    AdminProduct? product;
    if (productId != null && productId.trim().isNotEmpty) {
      try {
        final products = await service.fetchProducts();
        for (final p in products) {
          if (p.id == productId) {
            product = p;
            break;
          }
        }
      } catch (_) {}
    }
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
              ref.invalidate(adminInventoryProvider);
              ref.invalidate(adminProductsProvider);
              ref.invalidate(adminDashboardProvider);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, AdminProduct product) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('Delete "${product.title}" from inventory?'),
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
      ref.invalidate(adminInventoryProvider);
      ref.invalidate(adminProductsProvider);
      ref.invalidate(adminDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${product.title}" removed from inventory.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete "${product.title}": $e')),
      );
    }
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.marigoldOrange.withOpacity(0.28),
    );
  }
}

enum _InventoryStockFilter {
  all,
  outOfStock,
  lowStock,
  healthy,
}

Widget _noPhotoBadge() {
  return Container(
    width: 64,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.16),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'No photo',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class _InventoryAlertCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool compact;
  final double? width;
  final bool ultraCompact;

  const _InventoryAlertCard({
    required this.title,
    required this.value,
    required this.color,
    this.compact = false,
    this.width,
    this.ultraCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pad = ultraCompact ? 6.0 : (compact ? 8.0 : 12.0);
    final avatarR = ultraCompact ? 12.0 : (compact ? 16.0 : 20.0);
    final iconS = ultraCompact ? 14.0 : (compact ? 18.0 : 24.0);
    final valueSize = ultraCompact ? 14.0 : (compact ? 15.0 : 18.0);
    final titleStyle = compact
        ? Theme.of(context).textTheme.labelSmall
        : Theme.of(context).textTheme.bodyMedium;

    final inner = Card(
      margin: compact ? EdgeInsets.zero : null,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: avatarR,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(Icons.warning_amber_rounded, color: color, size: iconS),
            ),
            SizedBox(width: ultraCompact ? 6 : (compact ? 8 : 10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: titleStyle),
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: valueSize),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final wrapped = SizedBox(width: width ?? (compact ? 210 : 240), child: inner);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: wrapped,
    );
  }
}
