import 'package:ecommerce_app/features/checkout/state/checkout_pricing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';

/// Compact control that opens a dialog to edit checkout delivery rules ([store_settings]).
///
/// Set [compact] to true on Android admin only — web keeps the default outlined button.
class AdminDeliverySettingsButton extends ConsumerWidget {
  const AdminDeliverySettingsButton({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return IconButton(
        tooltip: 'Delivery charge & free-delivery threshold',
        icon: const Icon(Icons.local_shipping_outlined, size: 22),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onPressed: () => _showDialog(context, ref),
      );
    }
    return Tooltip(
      message: 'Store-wide delivery charge and free-delivery threshold',
      child: OutlinedButton.icon(
        onPressed: () => _showDialog(context, ref),
        icon: const Icon(Icons.local_shipping_outlined, size: 20),
        label: const Text('Delivery'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  static Future<void> _showDialog(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Consumer(
          builder: (_, ref2, __) {
            final async = ref2.watch(adminStoreDeliverySettingsProvider);
            return async.when(
              loading: () => AlertDialog(
                title: _dialogTitle(context),
                content: const SizedBox(
                  width: 360,
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
              error: (e, _) => AlertDialog(
                title: _dialogTitle(context),
                content: SelectableText('$e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
              data: (settings) => _DeliverySettingsDialog(
                parentContext: context,
                dialogContext: dialogContext,
                settings: settings,
              ),
            );
          },
        );
      },
    );
  }

  static Widget _dialogTitle(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.local_shipping_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Checkout delivery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _DeliverySettingsDialog extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  final BuildContext dialogContext;
  final AdminStoreDeliverySettings settings;

  const _DeliverySettingsDialog({
    required this.parentContext,
    required this.dialogContext,
    required this.settings,
  });

  @override
  ConsumerState<_DeliverySettingsDialog> createState() => _DeliverySettingsDialogState();
}

class _DeliverySettingsDialogState extends ConsumerState<_DeliverySettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _feeCtrl;
  late final TextEditingController _freeAboveCtrl;
  bool _saving = false;

  static String _fmtAmount(double n) {
    if ((n - n.round()).abs() < 1e-6) return n.round().toString();
    return n.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _feeCtrl = TextEditingController(text: _fmtAmount(widget.settings.deliveryFeeInr));
    _freeAboveCtrl = TextEditingController(
      text: widget.settings.freeDeliveryAboveInr == null
          ? ''
          : _fmtAmount(widget.settings.freeDeliveryAboveInr!),
    );
  }

  @override
  void dispose() {
    _feeCtrl.dispose();
    _freeAboveCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final fee = double.tryParse(_feeCtrl.text.trim());
    if (fee == null || fee < 0) return;
    final rawFree = _freeAboveCtrl.text.trim();
    final freeAbove = rawFree.isEmpty ? null : double.tryParse(rawFree);
    if (rawFree.isNotEmpty && (freeAbove == null || freeAbove < 0)) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Free delivery threshold must be empty or ≥ 0')),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminServiceProvider).updateStoreDeliverySettings(
            deliveryFeeInr: fee,
            freeDeliveryAboveInr: freeAbove,
          );
      ref.invalidate(adminStoreDeliverySettingsProvider);
      ref.invalidate(checkoutPricingRulesProvider);
      if (widget.dialogContext.mounted) {
        Navigator.of(widget.dialogContext).pop();
      }
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Delivery settings saved')),
        );
      }
    } catch (e) {
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: AdminDeliverySettingsButton._dialogTitle(context),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These rules apply to every checkout (same as the customer cart).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _feeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Delivery charge (INR)',
                    helperText: '0 = no delivery fee unless waived by the rule below.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    final x = double.tryParse((v ?? '').trim());
                    if (x == null || x < 0) return 'Enter a valid amount ≥ 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _freeAboveCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Free delivery when order subtotal ≥ (INR)',
                    helperText: 'Leave empty to never waive delivery via this rule.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    final x = double.tryParse(t);
                    if (x == null || x < 0) return 'Enter ≥ 0 or leave empty';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(widget.dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveAndClose,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save & close'),
        ),
      ],
    );
  }
}
