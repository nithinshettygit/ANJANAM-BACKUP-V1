import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ecommerce_app/core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(adminInventoryProvider);
    return AdminStateView(
      isLoading: productsAsync.isLoading,
      error: productsAsync.asError?.error,
      isEmpty: (productsAsync.asData?.value ?? const []).isEmpty,
      emptyMessage: 'No inventory items found',
      child: productsAsync.when(
      data: (products) {
        final filtered = products.where((p) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return p.title.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q) ||
              (p.category ?? '').toLowerCase().contains(q);
        }).toList();
        final lowStock = filtered.where((p) => p.inventoryCount > 0 && p.inventoryCount < 10).length;
        final outOfStock = filtered.where((p) => p.inventoryCount <= 0).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Inventory',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                const AdminDeliverySettingsButton(),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ref.invalidate(adminInventoryProvider);
                    ref.invalidate(adminDashboardProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final slug = await showAdminNewCategoryDialog(
                      context: context,
                      ref: ref,
                    );
                    if (!mounted) return;
                    if (slug != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Category “$slug” created. You can assign it when adding items.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('New category'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openProductForm(context: context, product: null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Inventory Item'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InventoryAlertCard(
                  title: 'Low Stock Alert',
                  value: lowStock.toString(),
                  color: AppColors.warningAmber,
                ),
                _InventoryAlertCard(
                  title: 'Out of Stock Alert',
                  value: outOfStock.toString(),
                  color: AppColors.errorRed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          labelText: 'Search inventory',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_selectedIds.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _bulkUpdateStock(filtered),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text('Bulk stock update (${_selectedIds.length})'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AdminDataTable<AdminProduct>(
                rows: filtered,
                initialRowsPerPage: 5,
                emptyMessage: 'No inventory items found',
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
                          width: 44,
                          height: 44,
                          borderRadius: BorderRadius.circular(8),
                          errorWidget: _noPhotoBadge(),
                        );
                      }
                      return _noPhotoBadge();
                    },
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Product',
                    sortValue: (p) => p.title,
                    cellBuilder: (p) => Text(p.title),
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Category',
                    sortValue: (p) => p.category ?? '',
                    cellBuilder: (p) => Text(p.category ?? '-'),
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Stock Count',
                    sortValue: (p) => p.inventoryCount,
                    cellBuilder: (p) => Text(p.inventoryCount.toString()),
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Card % off',
                    sortValue: (p) => p.displayDiscountPercent,
                    cellBuilder: (p) => Text(
                      p.displayDiscountPercent <= 0 ? '—' : '${p.displayDiscountPercent}%',
                    ),
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Alert',
                    sortValue: (p) => p.inventoryCount,
                    cellBuilder: (p) {
                      if (p.inventoryCount <= 0) {
                        return const Chip(
                          label: Text('Out of stock'),
                          backgroundColor: Color(0x22F44336),
                        );
                      }
                      if (p.inventoryCount < 10) {
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
                  AdminTableColumn<AdminProduct>(
                    label: 'Update',
                    cellBuilder: (p) => OutlinedButton(
                      onPressed: () => _updateStock(
                        context,
                        ref,
                        p.id,
                        p.inventoryCount,
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Edit',
                    cellBuilder: (p) => IconButton(
                      tooltip: 'Edit inventory item',
                      onPressed: () => _openProductForm(context: context, product: p),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  AdminTableColumn<AdminProduct>(
                    label: 'Delete',
                    cellBuilder: (p) => IconButton(
                      tooltip: 'Delete inventory item',
                      onPressed: () => _deleteItem(context, p),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
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

  Future<void> _updateStock(
    BuildContext context,
    WidgetRef ref,
    String productId,
    int currentCount,
  ) async {
    final controller = TextEditingController(text: currentCount.toString());
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
    try {
      await ref.read(adminServiceProvider).updateInventory(
            productId: productId,
            inventoryCount: result,
          );
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

  Future<void> _bulkUpdateStock(List<AdminProduct> products) async {
    final ctrl = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bulk Stock Update'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Set stock count for selected products'),
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
    try {
      final service = ref.read(adminServiceProvider);
      for (final p in products.where((p) => _selectedIds.contains(p.id))) {
        await service.updateInventory(productId: p.id, inventoryCount: value);
      }
      setState(() => _selectedIds.clear());
      ref.invalidate(adminInventoryProvider);
      ref.invalidate(adminDashboardProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk stock update completed')),
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
    required AdminProduct? product,
  }) async {
    final service = ref.read(adminServiceProvider);
    final storageId = product?.id ?? const Uuid().v4();
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ProductForm(
            storageProductId: storageId,
            initialProduct: product,
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

  const _InventoryAlertCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(Icons.warning_amber_rounded, color: color),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
