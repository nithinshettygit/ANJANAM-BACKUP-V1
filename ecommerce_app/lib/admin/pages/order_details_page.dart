import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/errors/app_exception.dart';
import 'package:ecommerce_app/core/formatting/estimated_delivery_format.dart';
import 'package:ecommerce_app/core/invoice/invoice_generator.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_data.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_preview.dart';
import 'package:ecommerce_app/core/shipping_label/shipping_label_service.dart';
import 'package:ecommerce_app/core/supabase/supabase_client_provider.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_item.dart';
import 'package:ecommerce_app/features/order_history/domain/entities/order_shipping_info.dart';
import 'package:ecommerce_app/core/formatting/inr_format.dart';
import 'package:ecommerce_app/core/theme/app_colors.dart';
import 'package:ecommerce_app/presentation/utils/order_details_format.dart'
    show formatOrderDetailsDateTime, formatOrderIdDisplay;

import '../providers/admin_providers.dart';
import '../services/admin_service.dart';
import '../utils/admin_order_status_push.dart';
import '../utils/admin_return_status_push.dart';
import '../utils/admin_order_status_workflow.dart';
import '../../features/notifications/data/services/fcm_edge_function_notification_sender.dart';
import '../widgets/admin_cached_image.dart';
import '../widgets/admin_detail_back_leading.dart';
import '../widgets/admin_guard.dart';
import '../widgets/admin_state_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show RealtimeChannel, PostgresChangeEvent, SupabaseClient;

class AdminOrderDetailsPage extends ConsumerStatefulWidget {
  final String orderId;
  final bool focusShipmentDetails;

  const AdminOrderDetailsPage({
    super.key,
    required this.orderId,
    this.focusShipmentDetails = false,
  });

  @override
  ConsumerState<AdminOrderDetailsPage> createState() =>
      _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends ConsumerState<AdminOrderDetailsPage> {
  final GlobalKey _shipmentSectionKey = GlobalKey();
  final _trackCtrl = TextEditingController();
  final _courierCtrl = TextEditingController();
  final _pkgWeightCtrl = TextEditingController();
  final _pkgDimCtrl = TextEditingController();
  DateTime? _estDelivery;
  bool _shipmentDirty = false;
  String? _syncedShipmentOrderId;
  String? _syncedShipmentSignature;
  bool _statusBusy = false;
  bool _shipmentSaving = false;
  bool _didAutoFocusShipment = false;
  bool _manualDeliveryBusy = false;
  bool _shiprocketBusy = false;
  RealtimeChannel? _orderRealtimeChannel;
  SupabaseClient? _orderRealtimeClient;
  String? _manualPkgDefaultsOrderId;
  String? _manualPkgDefaultsKey;
  double? _manualAutoWeightKg;
  String? _manualAutoDimensionsCm;
  bool _manualPkgDefaultsLoading = false;

  @override
  void initState() {
    super.initState();
    _subscribeOrderRealtime();
  }

  bool _refundBusy = false;
  bool _labelDownloadBusy = false;

  @override
  void dispose() {
    if (_orderRealtimeChannel != null && _orderRealtimeClient != null) {
      _orderRealtimeClient!.removeChannel(_orderRealtimeChannel!);
      _orderRealtimeChannel = null;
      _orderRealtimeClient = null;
    }
    _trackCtrl.dispose();
    _courierCtrl.dispose();
    _pkgWeightCtrl.dispose();
    _pkgDimCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdminOrderDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      if (_orderRealtimeChannel != null && _orderRealtimeClient != null) {
        _orderRealtimeClient!.removeChannel(_orderRealtimeChannel!);
        _orderRealtimeChannel = null;
        _orderRealtimeClient = null;
      }
      _subscribeOrderRealtime();
      _syncedShipmentOrderId = null;
      _syncedShipmentSignature = null;
      _shipmentDirty = false;
    }
  }

  void _subscribeOrderRealtime() {
    final client = ref.read(supabaseClientProvider);
    _orderRealtimeClient = client;
    final channel = client.channel('admin-order-${widget.orderId}');
    // No server-side filter: filtered postgres_changes can miss updates on some clients;
    // we only invalidate when the changed row id matches this order.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'orders',
      callback: (payload) {
        if (!mounted) return;
        try {
          final nr = (payload as dynamic).newRecord;
          if (nr is Map && nr['id']?.toString() == widget.orderId) {
            ref.invalidate(adminOrderDetailsProvider(widget.orderId));
            _syncAdminOrdersListCache();
          }
        } catch (_) {}
      },
    );
    channel.subscribe();
    _orderRealtimeChannel = channel;
  }

  /// Ensures the admin orders list refetches so table chips match this page after updates.
  Future<void> _syncAdminOrdersListCache() async {
    ref.invalidate(adminOrdersProvider);
    try {
      await ref.read(adminOrdersProvider.future);
    } catch (_) {}
  }

  bool _shipmentEditableForStatus(String rawStatus) {
    final c = canonicalAdminOrderStatus(rawStatus);
    return c != 'delivered' && c != 'cancelled' && c != 'cancel_requested';
  }

  /// Store order was marked [cancelled] (e.g. old webhook) while Shiprocket fulfilment never completed — allow admin to recover.
  bool _fulfillmentRecoveryMode(AdminOrderDetails details) {
    final st = canonicalAdminOrderStatus(details.order.status);
    if (st != 'cancelled') return false;
    if ((details.deliveryMethod ?? '').toLowerCase().trim() !=
        'shiprocket_delivery') {
      return false;
    }
    final ds = (details.deliveryStatus ?? '').toLowerCase().trim();
    if (ds == 'delivered') return false;
    return true;
  }

  bool _shipmentFormDiffersFrom(AdminOrderDetails details) {
    final t = _trackCtrl.text.trim();
    final c = _courierCtrl.text.trim();
    final w = _pkgWeightCtrl.text.trim();
    final d = _pkgDimCtrl.text.trim();
    final serverT = (details.trackingNumber ?? '').trim();
    final serverC = (details.courierName ?? '').trim();
    final serverW = details.packageWeightKg == null
        ? ''
        : details.packageWeightKg!.toString();
    final serverD = (details.packageDimensionsCm ?? '').trim();
    if (t != serverT || c != serverC || w != serverW || d != serverD)
      return true;
    final pick = _estDelivery;
    final srv = details.estimatedDeliveryDate;
    if (pick == null && srv == null) return false;
    if (pick == null || srv == null) return true;
    return pick.year != srv.year ||
        pick.month != srv.month ||
        pick.day != srv.day;
  }

  void _syncShipmentFieldsFromDetails(
      AdminOrderDetails details, String orderId) {
    if (_shipmentDirty) return;
    final nextSignature = _shipmentSignatureFrom(details);
    if (_syncedShipmentOrderId == orderId &&
        _syncedShipmentSignature == nextSignature) {
      return;
    }
    _trackCtrl.text = details.trackingNumber ?? '';
    _courierCtrl.text = details.courierName ?? '';
    _pkgWeightCtrl.text = details.packageWeightKg == null
        ? ''
        : details.packageWeightKg!.toString();
    _pkgDimCtrl.text = details.packageDimensionsCm ?? '';
    setState(() {
      _estDelivery = details.estimatedDeliveryDate;
      _syncedShipmentOrderId = orderId;
      _syncedShipmentSignature = nextSignature;
    });
  }

  String _shipmentSignatureFrom(AdminOrderDetails details) {
    final tracking = (details.trackingNumber ?? '').trim();
    final courier = (details.courierName ?? '').trim();
    final weight = details.packageWeightKg?.toString() ?? '';
    final dimensions = (details.packageDimensionsCm ?? '').trim();
    final date = details.estimatedDeliveryDate == null
        ? ''
        : '${details.estimatedDeliveryDate!.year.toString().padLeft(4, '0')}-'
            '${details.estimatedDeliveryDate!.month.toString().padLeft(2, '0')}-'
            '${details.estimatedDeliveryDate!.day.toString().padLeft(2, '0')}';
    return '$tracking|$courier|$weight|$dimensions|$date';
  }

  String _manualPkgDefaultsSignature(AdminOrderDetails details) {
    final parts = <String>[];
    for (final item in details.items) {
      parts.add('${item.productId}:${item.quantity}');
    }
    parts.sort();
    return parts.join('|');
  }

  String _formatWeightKg(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  List<double>? _parseDims3(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final m = RegExp(
      r'^([0-9]+(?:\.[0-9]+)?)\s*[xX×]\s*([0-9]+(?:\.[0-9]+)?)\s*[xX×]\s*([0-9]+(?:\.[0-9]+)?)$',
    ).firstMatch(s);
    if (m == null) return null;
    final a = double.tryParse(m.group(1)!);
    final b = double.tryParse(m.group(2)!);
    final c = double.tryParse(m.group(3)!);
    if (a == null || b == null || c == null) return null;
    return <double>[a, b, c];
  }

  String _formatDims3(List<double> dims) {
    String f(double v) {
      final s = v.toStringAsFixed(2);
      return s
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }

    return '${f(dims[0])}x${f(dims[1])}x${f(dims[2])}';
  }

  void _applyManualPkgDefaultsToForm(AdminOrderDetails details) {
    final isManual = (details.deliveryMethod ?? '').toLowerCase().trim() ==
        'manual_delivery';
    if (!isManual || _shipmentDirty) return;
    var changed = false;
    if (_manualAutoWeightKg != null) {
      final next = _formatWeightKg(_manualAutoWeightKg!);
      if (_pkgWeightCtrl.text.trim() != next) {
        _pkgWeightCtrl.text = next;
        changed = true;
      }
    }
    if (_manualAutoDimensionsCm != null &&
        _manualAutoDimensionsCm!.trim().isNotEmpty) {
      final next = _manualAutoDimensionsCm!.trim();
      if (_pkgDimCtrl.text.trim() != next) {
        _pkgDimCtrl.text = next;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _ensureManualPkgDefaults(AdminOrderDetails details) async {
    final isManual = (details.deliveryMethod ?? '').toLowerCase().trim() ==
        'manual_delivery';
    if (!isManual) return;
    final key = _manualPkgDefaultsSignature(details);
    if (_manualPkgDefaultsOrderId == details.order.id &&
        _manualPkgDefaultsKey == key) {
      _applyManualPkgDefaultsToForm(details);
      return;
    }

    setState(() => _manualPkgDefaultsLoading = true);
    try {
      final ids = details.items
          .map((e) => e.productId.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      final variantIds = details.items
          .map((e) => (e.variantId ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _manualPkgDefaultsOrderId = details.order.id;
          _manualPkgDefaultsKey = key;
          _manualAutoWeightKg = null;
          _manualAutoDimensionsCm = null;
        });
        return;
      }

      final rows = await ref
          .read(supabaseClientProvider)
          .from('products')
          .select('id, weight, dimensions')
          .inFilter('id', ids);
      final byId = <String, Map<String, dynamic>>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final id = row['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        byId[id] = row;
      }
      final variantById = <String, Map<String, dynamic>>{};
      if (variantIds.isNotEmpty) {
        final variantRows = await ref
            .read(supabaseClientProvider)
            .from('product_variants')
            .select('id, weight, dimensions')
            .inFilter('id', variantIds);
        for (final row in (variantRows as List).cast<Map<String, dynamic>>()) {
          final id = row['id']?.toString().trim();
          if (id == null || id.isEmpty) continue;
          variantById[id] = row;
        }
      }

      var totalWeight = 0.0;
      var hasAnyWeight = false;
      final dimVectors = <List<double>>[];
      final dimTexts = <String>[];

      for (final item in details.items) {
        final variant = variantById[(item.variantId ?? '').trim()];
        final p = byId[item.productId.trim()];
        final w = ((variant?['weight'] ?? p?['weight']) as num?)?.toDouble();
        if (w != null && w > 0) {
          totalWeight += (w * item.quantity);
          hasAnyWeight = true;
        }
        final d =
            (variant?['dimensions'] ?? p?['dimensions'])?.toString().trim();
        if (d != null && d.isNotEmpty) {
          dimTexts.add(d);
          final parsed = _parseDims3(d);
          if (parsed != null) {
            dimVectors.add(parsed);
            for (var i = 1; i < item.quantity; i++) {
              dimVectors.add(parsed);
            }
          }
        }
      }

      String? derivedDims;
      if (dimVectors.isNotEmpty) {
        var maxL = 0.0;
        var maxW = 0.0;
        var totalH = 0.0;
        for (final v in dimVectors) {
          if (v[0] > maxL) maxL = v[0];
          if (v[1] > maxW) maxW = v[1];
          totalH += v[2];
        }
        derivedDims = _formatDims3(<double>[maxL, maxW, totalH]);
      } else if (dimTexts.isNotEmpty) {
        derivedDims = dimTexts.first;
      }

      if (!mounted) return;
      setState(() {
        _manualPkgDefaultsOrderId = details.order.id;
        _manualPkgDefaultsKey = key;
        _manualAutoWeightKg =
            hasAnyWeight && totalWeight > 0 ? totalWeight : null;
        _manualAutoDimensionsCm = derivedDims;
      });
      _applyManualPkgDefaultsToForm(details);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _manualPkgDefaultsOrderId = details.order.id;
        _manualPkgDefaultsKey = key;
      });
    } finally {
      if (mounted) setState(() => _manualPkgDefaultsLoading = false);
    }
  }

  void _focusShipmentSectionIfRequested() {
    if (!widget.focusShipmentDetails || _didAutoFocusShipment) return;
    final ctx = _shipmentSectionKey.currentContext;
    if (ctx == null) return;
    _didAutoFocusShipment = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _shipmentSectionKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please fill shipment details here before marking as shipped.'),
        ),
      );
    });
  }

  String _humanManualDeliveryStatus(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'packed':
        return 'Packed';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      default:
        return (raw == null || raw.trim().isEmpty) ? '—' : raw.trim();
    }
  }

  String _humanShiprocketStatus(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'created':
        return 'Created';
      case 'shipped':
        return 'Shipped';
      case 'in_transit':
        return 'In transit';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'shipment_created':
        return 'Shipment created';
      case 'rto_initiated':
        return 'RTO initiated';
      case 'rto_completed':
        return 'RTO';
      default:
        return (raw == null || raw.trim().isEmpty) ? '—' : raw.trim();
    }
  }

  String _relativeTime(DateTime? at) {
    if (at == null) return '—';
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  bool _manualTransitionAllowed(String currentStatus, String target) {
    final c = canonicalAdminOrderStatus(currentStatus);
    switch (target) {
      case 'packed':
        return c == 'processing' || c == 'packed';
      case 'shipped':
        return c == 'packed' || c == 'shipped';
      case 'out_for_delivery':
        return c == 'packed' || c == 'shipped' || c == 'out_for_delivery';
      case 'delivered':
        return c == 'out_for_delivery' || c == 'delivered';
      default:
        return false;
    }
  }

  int _manualStageIndex(String statusRaw) {
    switch (canonicalAdminOrderStatus(statusRaw)) {
      case 'packed':
        return 1;
      case 'shipped':
        return 2;
      case 'out_for_delivery':
        return 3;
      case 'delivered':
        return 4;
      default:
        return 0;
    }
  }

  bool _shipmentCoreReady(AdminOrderDetails details) {
    final tracking = (details.trackingNumber ?? '').trim();
    final courier = (details.courierName ?? '').trim();
    final weightOk = (details.packageWeightKg ?? 0) > 0;
    final dims = (details.packageDimensionsCm ?? '').trim();
    return tracking.isNotEmpty &&
        courier.isNotEmpty &&
        weightOk &&
        dims.isNotEmpty;
  }

  Color _stageButtonColor(
    BuildContext context, {
    required int stageIndex,
    required int currentIndex,
  }) {
    if (currentIndex > stageIndex) return Colors.yellow.shade700; // completed
    if (currentIndex == stageIndex) return Colors.orange.shade800; // current
    return Colors.yellow.shade600; // pending
  }

  bool _hasShiprocketShipment(AdminOrderDetails d) {
    final sid = (d.shipmentId ?? '').trim();
    return sid.isNotEmpty;
  }

  /// After Shiprocket cancels a shipment, IDs are cleared — admin must be able to book again.
  /// Also treat stale rows where `delivery_status` is cancelled but `delivery_method` was not cleared.
  bool _shiprocketShipmentCancelledAwaitingChoice(AdminOrderDetails d) {
    final ds = (d.deliveryStatus ?? '').toLowerCase().trim();
    if (ds != 'cancelled') return false;
    final dm = (d.deliveryMethod ?? '').trim().toLowerCase();
    return dm.isEmpty || dm == 'shiprocket_delivery';
  }

  bool _blocksNewShiprocketShipment(AdminOrderDetails d) {
    final ds = (d.deliveryStatus ?? '').toLowerCase().trim();
    if (ds == 'cancelled') return false;
    return _hasShiprocketShipment(d);
  }

  bool _blocksManualWhileShiprocketSelected(AdminOrderDetails d) {
    final dm = (d.deliveryMethod ?? '').toLowerCase().trim();
    if (dm != 'shiprocket_delivery') return false;
    final ds = (d.deliveryStatus ?? '').toLowerCase().trim();
    if (ds == 'cancelled') return false;
    return true;
  }

  Future<void> _openManualDeliveryDialog(
    BuildContext context,
    String orderId,
    AdminOrderDetails details,
  ) async {
    final nameCtrl =
        TextEditingController(text: details.deliveryPartnerName ?? '');
    final phoneCtrl =
        TextEditingController(text: details.deliveryPartnerPhone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual delivery'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Delivery partner name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Partner phone (10 digits)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    final partnerName = nameCtrl.text;
    final partnerPhone = phoneCtrl.text;
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (ok != true || !context.mounted) return;
    setState(() => _manualDeliveryBusy = true);
    try {
      await ref.read(adminServiceProvider).setManualDelivery(
            orderId: orderId,
            partnerName: partnerName,
            partnerPhone: partnerPhone,
          );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      await _syncAdminOrdersListCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manual delivery saved')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _manualDeliveryBusy = false);
    }
  }

  Future<void> _setManualDeliveryStatus(
    BuildContext context,
    String orderId,
    String status,
    AdminOrderDetails details,
  ) async {
    if (status == 'out_for_delivery') {
      final isManual = (details.deliveryMethod ?? '').toLowerCase().trim() ==
          'manual_delivery';
      final effectiveWeightText = isManual && _manualAutoWeightKg != null
          ? _formatWeightKg(_manualAutoWeightKg!)
          : _pkgWeightCtrl.text.trim();
      final effectiveDimsText = isManual &&
              _manualAutoDimensionsCm != null &&
              _manualAutoDimensionsCm!.trim().isNotEmpty
          ? _manualAutoDimensionsCm!.trim()
          : _pkgDimCtrl.text.trim();
      final hasShipmentFields = (_trackCtrl.text.trim().isNotEmpty) &&
          (_courierCtrl.text.trim().isNotEmpty) &&
          (effectiveWeightText.isNotEmpty) &&
          (effectiveDimsText.isNotEmpty);
      if (!hasShipmentFields) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Set Shipment (customer-visible) fields first: tracking, courier, weight, dimensions.'),
          ),
        );
        return;
      }
      try {
        await ref.read(adminServiceProvider).updateOrderShipmentInfo(
              orderId: orderId,
              trackingNumber: _trackCtrl.text,
              courierName: _courierCtrl.text,
              estimatedDeliveryDate: _estDelivery,
              packageWeightKg: double.tryParse(effectiveWeightText),
              packageDimensionsCm: effectiveDimsText,
            );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shipment save failed: $e')),
          );
        }
        return;
      }
    }
    setState(() => _manualDeliveryBusy = true);
    try {
      await ref.read(adminServiceProvider).updateManualDeliveryStatus(
            orderId: orderId,
            deliveryStatus: status,
          );
      await trySendOrderStatusFcmForTarget(
        ref.read(fcmNotificationSenderProvider),
        userId: details.order.userId,
        orderId: orderId,
        targetStatusTitleCase: _statusDisplayLabel(status),
      );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      await _syncAdminOrdersListCache();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Delivery status: ${_humanManualDeliveryStatus(status)}')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _manualDeliveryBusy = false);
    }
  }

  Future<void> _openShiprocketDialog(
    BuildContext context,
    String orderId,
    AdminOrderDetails details,
  ) async {
    final pickupCtrl = TextEditingController();
    final stateCtrl = TextEditingController(text: details.shippingState ?? '');
    final weightCtrl = TextEditingController(
      text: details.packageWeightKg == null
          ? '0.5'
          : details.packageWeightKg!.toString(),
    );
    final dimCtrl = TextEditingController(
      text: (details.packageDimensionsCm ?? '').trim().isEmpty
          ? '20x15x10'
          : details.packageDimensionsCm!.trim(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shiprocket shipment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pickup location must match a warehouse name in your Shiprocket account.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pickupCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pickup location name',
                  hintText: 'Exact Shiprocket warehouse name (e.g. warehouse)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Package weight (kg)',
                  hintText: 'e.g. 0.5',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dimCtrl,
                decoration: const InputDecoration(
                  labelText: 'Package dimensions (cm)',
                  hintText: 'e.g. 20x15x10',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shipping state (optional)',
                  hintText: 'e.g. Kerala',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create shipment')),
        ],
      ),
    );
    final pickup = pickupCtrl.text.trim();
    final weightRaw = weightCtrl.text.trim();
    final dims = dimCtrl.text.trim();
    final stateOverride = stateCtrl.text.trim();
    pickupCtrl.dispose();
    weightCtrl.dispose();
    dimCtrl.dispose();
    stateCtrl.dispose();
    if (ok != true || !context.mounted) return;
    final weight = double.tryParse(weightRaw);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid package weight greater than 0.')),
      );
      return;
    }
    setState(() => _shiprocketBusy = true);
    try {
      // Keep shipment metadata synced before creating courier shipment.
      await ref.read(adminServiceProvider).updateOrderShipmentInfo(
            orderId: orderId,
            trackingNumber: details.trackingNumber ?? '',
            courierName: details.courierName ?? '',
            estimatedDeliveryDate: details.estimatedDeliveryDate,
            packageWeightKg: weight,
            packageDimensionsCm: dims,
          );
      await ref.read(adminServiceProvider).createShiprocketShipment(
            orderId: orderId,
            pickupLocation: pickup,
            shippingState: stateOverride.length >= 2 ? stateOverride : null,
          );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      await _syncAdminOrdersListCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shiprocket shipment created')),
      );
    } on RepositoryException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shiprocket failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _shiprocketBusy = false);
    }
  }

  String _statusDisplayLabel(String raw) {
    final c = canonicalAdminOrderStatus(raw);
    switch (c) {
      case 'pending_payment':
        return 'Pending payment';
      case 'payment_failed':
        return 'Payment failed';
      case 'processing':
        return 'Processing';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancel_requested':
        return 'Cancel pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return raw;
    }
  }

  String _refundStatusLabel(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'none':
        return 'None';
      case 'requested':
        return 'Requested';
      case 'approved':
        return 'Approved';
      case 'processing':
        return 'Processing';
      case 'refunded':
        return 'Refunded';
      case 'rejected':
        return 'Rejected';
      default:
        return raw;
    }
  }

  Future<void> _runApproveRefund(
    BuildContext context, {
    required AdminOrderDetails details,
  }) async {
    final refundPaise =
        details.refundAmountPaise ?? (details.order.totalAmount * 100).round();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Confirmation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ID: ${details.order.id}'),
              Text('Customer Name: ${details.order.customerName}'),
              Text('Payment Method: ${details.paymentMethod.toUpperCase()}'),
              Text(
                  'Total Paid Amount: ${formatInrAmount(details.order.totalAmount)}'),
              Text('Refund Amount: ${formatInrAmount(refundPaise / 100)}'),
              const SizedBox(height: 10),
              const Text(
                'This action will send money back to the customer. Refunds cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (refundPaise > 500000) ...[
                const SizedBox(height: 8),
                Text(
                  '\u26A0 High value refund. Please verify before confirming.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _refundBusy = true);
    try {
      await ref
          .read(adminServiceProvider)
          .approveRefundForOrder(orderId: details.order.id);
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(details.order.id));
      await _syncAdminOrdersListCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Refund approved and submitted to Razorpay.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refund failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _refundBusy = false);
    }
  }

  Future<void> _runApproveCancellation(
      BuildContext context, String orderId, String userId) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: const AdminOrderNextAction(
        buttonLabel: 'Approve cancellation',
        targetStatusTitleCase: 'Cancelled',
        confirmationTitle: 'Approve cancellation',
        confirmationBody:
            'The order will be cancelled, inventory will be restored, and a refund row will be created automatically for paid Razorpay orders.',
        destructive: true,
      ),
    );
    if (!context.mounted || noteOutcome == null) return;

    setState(() => _statusBusy = true);
    try {
      await ref.read(adminServiceProvider).approveOrderCancellation(
            orderId: orderId,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );
      await trySendOrderStatusFcmCustom(
        ref.read(fcmNotificationSenderProvider),
        userId: userId,
        orderId: orderId,
        title: 'Order cancelled',
        message:
            'Your cancellation was approved. If you paid online, a refund has been initiated.',
      );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      await _syncAdminOrdersListCache();
      ref.invalidate(adminDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cancellation approved. Order is cancelled.')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _runRejectCancellation(
      BuildContext context, String orderId, String userId) async {
    final noteOutcome = await showAdminOrderStatusConfirmDialog(
      context,
      action: const AdminOrderNextAction(
        buttonLabel: 'Reject cancellation',
        targetStatusTitleCase: 'Processing',
        confirmationTitle: 'Reject cancellation',
        confirmationBody:
            'The order will return to its previous fulfilment status and the customer will be notified.',
      ),
    );
    if (!context.mounted || noteOutcome == null) return;

    setState(() => _statusBusy = true);
    try {
      await ref.read(adminServiceProvider).rejectOrderCancellation(
            orderId: orderId,
            notes: noteOutcome.isEmpty ? null : noteOutcome,
          );
      await trySendOrderStatusFcmCustom(
        ref.read(fcmNotificationSenderProvider),
        userId: userId,
        orderId: orderId,
        title: 'Cancellation request declined',
        message:
            'Your order will continue processing. Open the order for details.',
      );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      await _syncAdminOrdersListCache();
      ref.invalidate(adminDashboardProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation request rejected.')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _runReturnStatusAction(
    BuildContext context, {
    required String orderId,
    required String userId,
    required String returnId,
    required String newStatus,
    String? successMessage,
  }) async {
    setState(() => _statusBusy = true);
    try {
      await ref.read(adminServiceProvider).updateReturnStatus(
            returnId: returnId,
            newStatus: newStatus,
          );
      await trySendReplacementStatusFcm(
        ref.read(fcmNotificationSenderProvider),
        userId: userId,
        orderId: orderId,
        status: newStatus,
      );
      if (!context.mounted) return;
      ref.invalidate(adminOrderDetailsProvider(orderId));
      ref.invalidate(adminReturnsProvider('all'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage ?? 'Return updated.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Return update failed: $e')));
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Order _orderEntityForInvoice(AdminOrderDetails d) {
    final o = d.order;
    final items = d.items
        .map(
          (i) => OrderItem(
            variantId: i.variantId,
            productId: i.productId,
            title: i.title,
            imageUrls: i.imageUrls,
            unitPrice: i.unitPrice,
            currency: i.currency,
            quantity: i.quantity,
            hsnCode: i.hsnCode,
            taxStatus: i.taxStatus,
            taxableValue: i.taxableValue,
            gstRate: i.gstRate,
            cgstAmount: i.cgstAmount,
            sgstAmount: i.sgstAmount,
            igstAmount: i.igstAmount,
            priceIncludesGst: i.priceIncludesGst,
          ),
        )
        .toList();
    return Order(
      id: o.id,
      userId: o.userId,
      status: OrderStatusX.fromDbValue(o.status),
      items: items,
      currency: o.currency,
      createdAt: o.createdAt,
      deliveryFee: o.deliveryFee,
      trackingNumber: d.trackingNumber,
      courierName: d.courierName,
      estimatedDeliveryDate: d.estimatedDeliveryDate,
      paymentMethod: orderPaymentMethodFromDb(d.paymentMethod),
      paymentStatus: orderPaymentStatusFromDb(d.paymentStatus),
      razorpayPaymentId: d.razorpayPaymentId ?? o.razorpayPaymentId,
      returnDeadline: null,
    );
  }

  OrderShippingInfo _shippingForInvoice(AdminOrderDetails d) {
    final structured = _hasStructuredShipping(d);
    final String? addressLine;
    if (structured) {
      addressLine = d.shippingAddressLine != null &&
              d.shippingAddressLine!.trim().isNotEmpty
          ? d.shippingAddressLine!.trim()
          : null;
    } else {
      final line = d.shippingAddress.trim();
      addressLine = line.isEmpty ? null : line;
    }
    final name =
        d.shippingFullName != null && d.shippingFullName!.trim().isNotEmpty
            ? d.shippingFullName!.trim()
            : (d.order.customerName.trim().isEmpty
                ? null
                : d.order.customerName.trim());
    return OrderShippingInfo(
      fullName: name,
      phone: d.shippingPhone,
      addressLine: addressLine,
      city: d.shippingCity,
      state: d.shippingState,
      postalCode: d.shippingPostalCode,
      invoiceName: d.invoiceName,
      invoiceAddressLine: d.invoiceAddressLine,
      invoiceCity: d.invoiceCity,
      invoiceState: d.invoiceState,
    );
  }

  Future<void> _onDownloadShippingLabel(
    BuildContext context,
    AdminOrderDetails details,
  ) async {
    if (_labelDownloadBusy) return;
    final previewHandle = await prepareShippingLabelPreview(
      name: 'label_${formatOrderIdDisplay(details.order.id)}',
    );

    setState(() => _labelDownloadBusy = true);
    try {
      final service = ShippingLabelService();
      final bytes = await service.generatePdfForAdminOrder(details);
      if (!context.mounted) return;
      await finalizeShippingLabelPreview(
        previewHandle,
        bytes,
        name: 'label_${formatOrderIdDisplay(details.order.id)}',
      );
    } on ShippingLabelException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e, st) {
      debugPrint('Admin shipping label: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Shipping label could not be generated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _labelDownloadBusy = false);
    }
  }

  Future<void> _onDownloadAdminInvoice(
    BuildContext context,
    AdminOrderDetails details,
  ) async {
    if (details.items.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice cannot be generated.')),
      );
      return;
    }
    final previewHandle = await prepareInvoicePreview(
      name: 'ANJANAM-INV-${formatOrderIdDisplay(details.order.id)}',
    );
    try {
      final order = _orderEntityForInvoice(details);
      final gen = InvoiceGenerator();
      final bytes = await gen.generateInvoicePdf(
        order,
        order.items,
        shipping: _shippingForInvoice(details),
      );
      if (!context.mounted) return;
      await finalizeInvoicePreview(
        previewHandle,
        bytes,
        name: 'ANJANAM-INV-${formatOrderIdDisplay(order.id)}',
      );
    } catch (e, st) {
      debugPrint('Admin invoice: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cannot be generated.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;

    ref.listen(adminOrderDetailsProvider(orderId), (_, next) {
      next.whenData((details) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _syncShipmentFieldsFromDetails(details, details.order.id);
          _applyManualPkgDefaultsToForm(details);
          _ensureManualPkgDefaults(details);
        });
      });
    });
    final detailsAsync = ref.watch(adminOrderDetailsProvider(orderId));
    final returnsAsync = ref.watch(adminReturnsProvider('all'));

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          automaticallyImplyLeading: false,
          leading:
              adminDetailBackLeading(context, fallbackRoute: '/admin/orders'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AdminStateView(
            isLoading: detailsAsync.isLoading,
            error: detailsAsync.asError?.error,
            isEmpty: false,
            emptyMessage: 'No order details available',
            child: detailsAsync.when(
              data: (details) {
                _focusShipmentSectionIfRequested();
                final order = details.order;
                final manualDeliverySelected =
                    (details.deliveryMethod ?? '').toLowerCase().trim() ==
                        'manual_delivery';
                final effectiveWeightText =
                    manualDeliverySelected && _manualAutoWeightKg != null
                        ? _formatWeightKg(_manualAutoWeightKg!)
                        : _pkgWeightCtrl.text.trim();
                final effectiveDimsText = manualDeliverySelected &&
                        _manualAutoDimensionsCm != null &&
                        _manualAutoDimensionsCm!.trim().isNotEmpty
                    ? _manualAutoDimensionsCm!.trim()
                    : _pkgDimCtrl.text.trim();
                final shipmentEditable =
                    _shipmentEditableForStatus(order.status) ||
                        _fulfillmentRecoveryMode(details);
                final orderReturns = returnsAsync.asData?.value
                        .where((r) => r.orderId == order.id)
                        .toList() ??
                    const <AdminReturnRow>[];
                return SelectionArea(
                  child: ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer name: ${order.customerName}'),
                              Text('Customer email: ${order.customerEmail}'),
                              const SizedBox(height: 8),
                              Text('Order ID: ${order.id}'),
                              Text('Date: ${order.createdAt.toLocal()}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Details',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              _AdminPaymentDetailLine(
                                label: 'Payment Method',
                                value: _adminPaymentMethodLabel(
                                    details.paymentMethod),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Payment Status',
                                value: _adminPaymentStatusLabel(
                                    details.paymentStatus),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Razorpay Payment ID',
                                value: _dashIfEmpty(details.razorpayPaymentId),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Razorpay Order ID',
                                value: _dashIfEmpty(details.razorpayOrderId),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Order Amount',
                                value: formatInrAmount(order.totalAmount),
                                valueColor: AppColors.priceText,
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Transaction Date',
                                value: () {
                                  final txAt = details.paidAt ??
                                      details.paymentVerifiedAt;
                                  if (txAt == null) return '—';
                                  return formatOrderDetailsDateTime(
                                      txAt.toLocal());
                                }(),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Refund Status',
                                value: _refundStatusLabel(details.refundStatus),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Refund Amount',
                                value: details.refundAmountPaise == null
                                    ? '—'
                                    : formatInrAmount(
                                        details.refundAmountPaise! / 100.0),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Refund ID',
                                value: _dashIfEmpty(details.refundId),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Refund Requested At',
                                value: details.refundRequestedAt == null
                                    ? '—'
                                    : formatOrderDetailsDateTime(
                                        details.refundRequestedAt!.toLocal(),
                                      ),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Refund Processed At',
                                value: details.refundProcessedAt == null
                                    ? '—'
                                    : formatOrderDetailsDateTime(
                                        details.refundProcessedAt!.toLocal(),
                                      ),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Refund Initiated By',
                                value: _dashIfEmpty(details.refundInitiatedBy),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: details.paymentMethod
                                            .toLowerCase()
                                            .trim() ==
                                        'cod'
                                    ? const SizedBox(
                                        width: 240,
                                        child: Text(
                                          'No refund required (Cash on Delivery)',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              TextStyle(color: Colors.black54),
                                        ),
                                      )
                                    : FilledButton(
                                        onPressed: _refundBusy ||
                                                details.paymentMethod
                                                        .toLowerCase()
                                                        .trim() !=
                                                    'razorpay' ||
                                                details.paymentStatus
                                                        .toLowerCase()
                                                        .trim() !=
                                                    'paid' ||
                                                details.razorpayPaymentId ==
                                                    null ||
                                                details.razorpayPaymentId!
                                                    .trim()
                                                    .isEmpty ||
                                                details.refundStatus ==
                                                    'processing' ||
                                                details.refundStatus ==
                                                    'refunded'
                                            ? null
                                            : () => _runApproveRefund(
                                                  context,
                                                  details: details,
                                                ),
                                        child: Text(
                                          _refundBusy
                                              ? 'Processing Refund...'
                                              : 'Initiate Refund',
                                        ),
                                      ),
                              ),
                              _AdminPaymentDetailLine(
                                label: 'Created At',
                                value: formatOrderDetailsDateTime(
                                    order.createdAt.toLocal()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shipping address',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (_hasStructuredShipping(details)) ...[
                                if (details.shippingFullName != null &&
                                    details.shippingFullName!.isNotEmpty)
                                  Text(details.shippingFullName!),
                                if (details.shippingPhone != null &&
                                    details.shippingPhone!.isNotEmpty)
                                  Text('Phone: ${details.shippingPhone}'),
                                if (details.shippingAddressLine != null &&
                                    details.shippingAddressLine!.isNotEmpty)
                                  Text(details.shippingAddressLine!),
                                Builder(
                                  builder: (_) {
                                    final cityLine = [
                                      if (details.shippingCity != null &&
                                          details.shippingCity!.isNotEmpty)
                                        details.shippingCity!,
                                      if (details.shippingPostalCode != null &&
                                          details
                                              .shippingPostalCode!.isNotEmpty)
                                        details.shippingPostalCode!,
                                    ].join(', ');
                                    if (cityLine.isEmpty)
                                      return const SizedBox.shrink();
                                    return Text(cityLine);
                                  },
                                ),
                              ] else
                                Text(
                                  details.shippingAddress,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (canonicalAdminOrderStatus(order.status) ==
                          'cancel_requested') ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cancellation review',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Approve to cancel the order (inventory restored; paid Razorpay orders get an automatic refund record). '
                                  'Reject to resume fulfilment at the previous status.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton(
                                      onPressed: _statusBusy
                                          ? null
                                          : () => _runApproveCancellation(
                                                context,
                                                order.id,
                                                order.userId,
                                              ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onError,
                                      ),
                                      child:
                                          const Text('Approve Cancel Request'),
                                    ),
                                    OutlinedButton(
                                      onPressed: _statusBusy
                                          ? null
                                          : () => _runRejectCancellation(
                                                context,
                                                order.id,
                                                order.userId,
                                              ),
                                      child:
                                          const Text('Reject Cancel Request'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Timeline',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              ...details.timeline.map((event) {
                                final sub = StringBuffer(
                                  event.timestamp
                                      .toLocal()
                                      .toString()
                                      .split('.')
                                      .first,
                                );
                                if (event.notes != null &&
                                    event.notes!.isNotEmpty) {
                                  sub.writeln();
                                  sub.write(event.notes);
                                }
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.timeline, size: 18),
                                  title: Text(event.label),
                                  subtitle: Text(sub.toString()),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery management',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Choose manual fulfilment or Shiprocket. Courier APIs run only on the server.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _AdminShipmentReadOnlyLine(
                                label: 'Current method',
                                value: () {
                                  if (_shiprocketShipmentCancelledAwaitingChoice(
                                      details)) {
                                    return 'Not set (Shiprocket shipment cancelled — choose again)';
                                  }
                                  final m = (details.deliveryMethod ?? '')
                                      .toLowerCase()
                                      .trim();
                                  if (m == 'manual_delivery')
                                    return 'Manual delivery';
                                  if (m == 'shiprocket_delivery')
                                    return 'Shiprocket';
                                  return 'Not set';
                                }(),
                              ),
                              if (_shiprocketShipmentCancelledAwaitingChoice(
                                  details)) ...[
                                const SizedBox(height: 8),
                                Material(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Shiprocket reported this shipment as cancelled. '
                                            'Delivery method was reset — choose Manual delivery or create a new Shiprocket shipment.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onErrorContainer,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              if ((details.deliveryMethod ?? '')
                                      .toLowerCase() ==
                                  'manual_delivery') ...[
                                _AdminShipmentReadOnlyLine(
                                  label: 'Delivery partner',
                                  value: details.deliveryPartnerName,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Partner phone',
                                  value: details.deliveryPartnerPhone,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Delivery status',
                                  value: _humanManualDeliveryStatus(
                                      details.deliveryStatus),
                                ),
                              ],
                              if ((details.deliveryMethod ?? '')
                                      .toLowerCase() ==
                                  'shiprocket_delivery') ...[
                                _AdminShipmentReadOnlyLine(
                                  label: 'Shipping provider',
                                  value:
                                      details.shippingProvider ?? 'Shiprocket',
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Shipment ID',
                                  value: details.shipmentId,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'AWB',
                                  value: details.awbCode,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Courier',
                                  value: details.courierName,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Shipment status',
                                  value: _humanShiprocketStatus(
                                    details.deliveryStatus ??
                                        details.shipmentStatus,
                                  ),
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Tracking URL',
                                  value: details.trackingUrl,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Last updated',
                                  value:
                                      _relativeTime(details.lastTrackingUpdate),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _shiprocketBusy
                                            ? null
                                            : () async {
                                                setState(() =>
                                                    _shiprocketBusy = true);
                                                try {
                                                  final out = await ref
                                                      .read(
                                                          adminServiceProvider)
                                                      .syncShiprocketShipmentStatus(
                                                        orderId: order.id,
                                                      );
                                                  if (!context.mounted) return;
                                                  ref.invalidate(
                                                      adminOrderDetailsProvider(
                                                          orderId));
                                                  await _syncAdminOrdersListCache();
                                                  final synced =
                                                      out['synced'] == true;
                                                  final detail =
                                                      out['detail']?.toString();
                                                  if (synced) {
                                                    final deliveryStatus =
                                                        out['delivery_status']
                                                            ?.toString()
                                                            .trim();
                                                    final shipmentStatus =
                                                        out['shipment_status']
                                                            ?.toString()
                                                            .trim();
                                                    String?
                                                        targetStatusTitleCase;
                                                    if (deliveryStatus ==
                                                        'delivered') {
                                                      targetStatusTitleCase =
                                                          'Delivered';
                                                    } else if (deliveryStatus ==
                                                        'out_for_delivery') {
                                                      targetStatusTitleCase =
                                                          'Out for delivery';
                                                    } else if (shipmentStatus ==
                                                        'in_transit') {
                                                      targetStatusTitleCase =
                                                          'Shipped';
                                                    }
                                                    if (targetStatusTitleCase !=
                                                        null) {
                                                      await trySendOrderStatusFcmForTarget(
                                                        ref.read(
                                                            fcmNotificationSenderProvider),
                                                        userId: order.userId,
                                                        orderId: order.id,
                                                        targetStatusTitleCase:
                                                            targetStatusTitleCase,
                                                      );
                                                    }
                                                  }
                                                  final dsOut =
                                                      out['delivery_status']
                                                          ?.toString()
                                                          .trim();
                                                  final clearedBooking =
                                                      out['force_cleared'] ==
                                                              true ||
                                                          dsOut == 'cancelled';
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        clearedBooking
                                                            ? 'Shiprocket booking cleared. Choose Manual delivery or create a new shipment.'
                                                            : synced
                                                                ? 'Shiprocket status synced'
                                                                : (detail !=
                                                                            null &&
                                                                        detail
                                                                            .isNotEmpty
                                                                    ? detail
                                                                    : 'No new status yet'),
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              'Sync failed: $e')),
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted)
                                                    setState(() =>
                                                        _shiprocketBusy =
                                                            false);
                                                }
                                              },
                                        icon: const Icon(Icons.sync, size: 18),
                                        label: const Text(
                                            'Sync Shiprocket status'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _shiprocketBusy
                                            ? null
                                            : () async {
                                                final confirmed =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                        'Clear Shiprocket booking?'),
                                                    content: const Text(
                                                      'Use this only if you already cancelled the shipment '
                                                      'in Shiprocket (or it was removed) and Anjanam still '
                                                      'shows Shiprocket as the method.\n\n'
                                                      'This clears shipment IDs and lets you choose Manual '
                                                      'delivery or create a new Shiprocket shipment.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, false),
                                                        child:
                                                            const Text('Back'),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, true),
                                                        child: const Text(
                                                            'Clear booking'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirmed != true ||
                                                    !context.mounted) return;
                                                setState(() =>
                                                    _shiprocketBusy = true);
                                                try {
                                                  final out = await ref
                                                      .read(
                                                          adminServiceProvider)
                                                      .syncShiprocketShipmentStatus(
                                                        orderId: order.id,
                                                        forceClearShiprocketBooking:
                                                            true,
                                                      );
                                                  if (!context.mounted) return;
                                                  ref.invalidate(
                                                      adminOrderDetailsProvider(
                                                          orderId));
                                                  await _syncAdminOrdersListCache();
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        out['synced'] == true
                                                            ? 'Shiprocket booking cleared.'
                                                            : 'Request completed.',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              'Clear failed: $e')),
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted)
                                                    setState(() =>
                                                        _shiprocketBusy =
                                                            false);
                                                }
                                              },
                                        icon: const Icon(
                                            Icons.link_off_outlined,
                                            size: 18),
                                        label: const Text('Clear SR booking'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                'Current order status: ${_statusDisplayLabel(order.status)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: (!shipmentEditable ||
                                            _manualDeliveryBusy ||
                                            _shiprocketBusy ||
                                            _blocksManualWhileShiprocketSelected(
                                                details) ||
                                            canonicalAdminOrderStatus(
                                                    order.status) ==
                                                'pending_payment' ||
                                            canonicalAdminOrderStatus(
                                                    order.status) ==
                                                'payment_failed')
                                        ? null
                                        : () => _openManualDeliveryDialog(
                                              context,
                                              order.id,
                                              details,
                                            ),
                                    child: const Text('Manual delivery'),
                                  ),
                                  FilledButton(
                                    onPressed: (!shipmentEditable ||
                                            _manualDeliveryBusy ||
                                            _shiprocketBusy ||
                                            _blocksNewShiprocketShipment(
                                                details) ||
                                            canonicalAdminOrderStatus(
                                                    order.status) ==
                                                'payment_failed')
                                        ? null
                                        : () => _openShiprocketDialog(
                                              context,
                                              order.id,
                                              details,
                                            ),
                                    child: const Text('Shiprocket shipment'),
                                  ),
                                ],
                              ),
                              if ((details.deliveryMethod ?? '')
                                          .toLowerCase() ==
                                      'shiprocket_delivery' &&
                                  !_fulfillmentRecoveryMode(details) &&
                                  (details.deliveryStatus ?? '')
                                          .toLowerCase()
                                          .trim() !=
                                      'cancelled') ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Manual status buttons are hidden while Shiprocket delivery is selected.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        key: _shipmentSectionKey,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shipment (customer-visible)',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (!shipmentEditable) ...[
                                Text(
                                  _fulfillmentRecoveryMode(details)
                                      ? 'Order is marked cancelled but Shiprocket fulfilment was not completed. '
                                          'Choose Manual delivery or Shiprocket below to resume, or leave as cancelled.'
                                      : canonicalAdminOrderStatus(
                                                  order.status) ==
                                              'cancelled'
                                          ? 'Shipment details cannot be edited for a cancelled order.'
                                          : canonicalAdminOrderStatus(
                                                      order.status) ==
                                                  'cancel_requested'
                                              ? 'Shipment is read-only while a cancellation request is open.'
                                              : 'This order is delivered. Tracking and estimated delivery are read-only.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Tracking number',
                                  value: details.trackingNumber,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Courier name',
                                  value: details.courierName,
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Estimated delivery date',
                                  value: details.estimatedDeliveryDate == null
                                      ? null
                                      : formatEstimatedDeliveryDate(
                                          details.estimatedDeliveryDate!),
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Package weight (kg)',
                                  value: details.packageWeightKg?.toString(),
                                ),
                                _AdminShipmentReadOnlyLine(
                                  label: 'Package dimensions (cm)',
                                  value: details.packageDimensionsCm,
                                ),
                              ] else ...[
                                TextField(
                                  controller: _trackCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Tracking number',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _shipmentDirty = true),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _courierCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Courier name',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _shipmentDirty = true),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _pkgWeightCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Package weight (kg)',
                                    border: OutlineInputBorder(),
                                    hintText:
                                        'Auto from product weight for manual delivery',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  readOnly: manualDeliverySelected,
                                  enabled: !manualDeliverySelected,
                                  onChanged: (_) =>
                                      setState(() => _shipmentDirty = true),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _pkgDimCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Package dimensions (cm)',
                                    border: OutlineInputBorder(),
                                    hintText:
                                        'Auto from product dimensions for manual delivery',
                                  ),
                                  readOnly: manualDeliverySelected,
                                  enabled: !manualDeliverySelected,
                                  onChanged: (_) =>
                                      setState(() => _shipmentDirty = true),
                                ),
                                if (manualDeliverySelected) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _manualPkgDefaultsLoading
                                        ? 'Loading package specs from product details...'
                                        : 'Package weight and dimensions are auto-filled from product details for manual delivery.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Estimated delivery date'),
                                  subtitle: Text(
                                    _estDelivery == null
                                        ? 'Not set'
                                        : formatEstimatedDeliveryDate(
                                            _estDelivery!),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_estDelivery != null)
                                        IconButton(
                                          tooltip: 'Clear date',
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => setState(() {
                                            _estDelivery = null;
                                            _shipmentDirty = true;
                                          }),
                                        ),
                                      IconButton(
                                        tooltip: 'Pick date',
                                        icon: const Icon(
                                            Icons.calendar_today_outlined),
                                        onPressed: () async {
                                          final initial = _estDelivery == null
                                              ? DateTime.now()
                                              : DateTime(
                                                  _estDelivery!.year,
                                                  _estDelivery!.month,
                                                  _estDelivery!.day,
                                                );
                                          final picked = await showDatePicker(
                                            context: context,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now().add(
                                                const Duration(days: 365 * 2)),
                                            initialDate: initial,
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              _estDelivery = picked;
                                              _shipmentDirty = true;
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                if (_shipmentSaving)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child:
                                        LinearProgressIndicator(minHeight: 3),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: (_shipmentSaving ||
                                            _syncedShipmentOrderId !=
                                                order.id ||
                                            !_shipmentFormDiffersFrom(details))
                                        ? null
                                        : () async {
                                            setState(
                                                () => _shipmentSaving = true);
                                            try {
                                              await ref
                                                  .read(adminServiceProvider)
                                                  .updateOrderShipmentInfo(
                                                    orderId: order.id,
                                                    trackingNumber:
                                                        _trackCtrl.text,
                                                    courierName:
                                                        _courierCtrl.text,
                                                    estimatedDeliveryDate:
                                                        _estDelivery,
                                                    packageWeightKg:
                                                        double.tryParse(
                                                            effectiveWeightText),
                                                    packageDimensionsCm:
                                                        effectiveDimsText,
                                                  );
                                              if (!context.mounted) return;
                                              setState(() {
                                                _shipmentDirty = false;
                                                _syncedShipmentOrderId = null;
                                              });
                                              ref.invalidate(
                                                  adminOrderDetailsProvider(
                                                      orderId));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Shipment details saved')),
                                              );
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Save failed: $e')),
                                                );
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() =>
                                                    _shipmentSaving = false);
                                              }
                                            }
                                          },
                                    child: const Text('Save shipment'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if ((details.deliveryMethod ?? '').toLowerCase() ==
                          'manual_delivery') ...[
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Manual fulfilment sequence',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Follow in order: Packed -> Save shipment -> Mark as shipped -> Out for delivery -> Delivered',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (ctx) {
                                    final current =
                                        _manualStageIndex(order.status);
                                    final canPacked = _manualTransitionAllowed(
                                        order.status, 'packed');
                                    final canShipped = _manualTransitionAllowed(
                                        order.status, 'shipped');
                                    final canOut = _manualTransitionAllowed(
                                        order.status, 'out_for_delivery');
                                    final canDelivered =
                                        _manualTransitionAllowed(
                                            order.status, 'delivered');
                                    final isPackedCurrent = current == 1;
                                    final isShippedCurrent = current == 2;
                                    final isOutCurrent = current == 3;
                                    final isDeliveredCurrent = current == 4;
                                    final shipmentSaved =
                                        _shipmentCoreReady(details) &&
                                            !_shipmentFormDiffersFrom(details);

                                    return Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _stageButtonColor(
                                              ctx,
                                              stageIndex: 1,
                                              currentIndex: current,
                                            ),
                                            foregroundColor: Colors.black87,
                                          ),
                                          onPressed: (_manualDeliveryBusy ||
                                                  !canPacked ||
                                                  isPackedCurrent)
                                              ? null
                                              : () => _setManualDeliveryStatus(
                                                    context,
                                                    order.id,
                                                    'packed',
                                                    details,
                                                  ),
                                          child: const Text('Packed'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _stageButtonColor(
                                              ctx,
                                              stageIndex: 2,
                                              currentIndex: current,
                                            ),
                                            foregroundColor: Colors.black87,
                                          ),
                                          onPressed: (_manualDeliveryBusy ||
                                                  !canShipped ||
                                                  isShippedCurrent)
                                              ? null
                                              : () async {
                                                  if (!shipmentSaved) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Save shipment details first (tracking, courier, weight, dimensions).'),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  await _setManualDeliveryStatus(
                                                    context,
                                                    order.id,
                                                    'shipped',
                                                    details,
                                                  );
                                                },
                                          child: const Text('Mark as shipped'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _stageButtonColor(
                                              ctx,
                                              stageIndex: 3,
                                              currentIndex: current,
                                            ),
                                            foregroundColor: Colors.black87,
                                          ),
                                          onPressed: (_manualDeliveryBusy ||
                                                  !canOut ||
                                                  isOutCurrent)
                                              ? null
                                              : () => _setManualDeliveryStatus(
                                                    context,
                                                    order.id,
                                                    'out_for_delivery',
                                                    details,
                                                  ),
                                          child: const Text('Out for delivery'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _stageButtonColor(
                                              ctx,
                                              stageIndex: 4,
                                              currentIndex: current,
                                            ),
                                            foregroundColor: Colors.black87,
                                          ),
                                          onPressed: (_manualDeliveryBusy ||
                                                  !canDelivered ||
                                                  isDeliveredCurrent)
                                              ? null
                                              : () => _setManualDeliveryStatus(
                                                    context,
                                                    order.id,
                                                    'delivered',
                                                    details,
                                                  ),
                                          child: const Text('Delivered'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Return Actions',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (canonicalAdminOrderStatus(order.status) !=
                                      'delivered' &&
                                  orderReturns.isEmpty)
                                Text(
                                  'Return workflow unlocks after delivery.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                )
                              else if (orderReturns.isEmpty)
                                const Text('No return requests for this order.')
                              else
                                ...orderReturns.map((r) {
                                  final st =
                                      r.returnStatus.trim().toLowerCase();
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        '${r.lineTitle}  (${r.returnReason})'),
                                    subtitle: Text('Status: ${r.returnStatus}'),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        if (st == 'requested') ...[
                                          OutlinedButton(
                                            onPressed: _statusBusy
                                                ? null
                                                : () => _runReturnStatusAction(
                                                      context,
                                                      orderId: order.id,
                                                      userId: r.userId,
                                                      returnId: r.id,
                                                      newStatus: 'approved',
                                                      successMessage:
                                                          'Return approved.',
                                                    ),
                                            child: const Text('Approve'),
                                          ),
                                          OutlinedButton(
                                            onPressed: _statusBusy
                                                ? null
                                                : () => _runReturnStatusAction(
                                                      context,
                                                      orderId: order.id,
                                                      userId: r.userId,
                                                      returnId: r.id,
                                                      newStatus: 'rejected',
                                                      successMessage:
                                                          'Return rejected.',
                                                    ),
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                        if (st == 'approved')
                                          OutlinedButton(
                                            onPressed: _statusBusy
                                                ? null
                                                : () => _runReturnStatusAction(
                                                      context,
                                                      orderId: order.id,
                                                      userId: r.userId,
                                                      returnId: r.id,
                                                      newStatus: 'picked_up',
                                                      successMessage:
                                                          'Pickup marked completed.',
                                                    ),
                                            child:
                                                const Text('Mark Pickup Done'),
                                          ),
                                        if (st == 'picked_up')
                                          OutlinedButton(
                                            onPressed: _statusBusy
                                                ? null
                                                : () => _runReturnStatusAction(
                                                      context,
                                                      orderId: order.id,
                                                      userId: r.userId,
                                                      returnId: r.id,
                                                      newStatus: 'returned',
                                                      successMessage:
                                                          'Marked as returned.',
                                                    ),
                                            child: const Text('Mark Returned'),
                                          ),
                                        if (st == 'returned')
                                          FilledButton.tonal(
                                            onPressed: _statusBusy
                                                ? null
                                                : () => _runReturnStatusAction(
                                                      context,
                                                      orderId: order.id,
                                                      userId: r.userId,
                                                      returnId: r.id,
                                                      newStatus:
                                                          'refund_completed',
                                                      successMessage:
                                                          'Refund completed.',
                                                    ),
                                            child: const Text('Process Refund'),
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Items',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              ...details.items.map((item) {
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: item.imageUrls.isNotEmpty
                                      ? AdminCachedImage(
                                          imageUrl: item.imageUrls.first,
                                          width: 44,
                                          height: 44,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        )
                                      : const Icon(
                                          Icons.image_not_supported_outlined),
                                  title: Text(item.title),
                                  subtitle: Text('Quantity: ${item.quantity}'),
                                  trailing: Text(
                                    formatInrAmount(
                                        item.unitPrice * item.quantity),
                                    style: const TextStyle(
                                      color: AppColors.priceText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order summary',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              _summaryRow('Items subtotal',
                                  formatInrAmount(order.itemsSubtotal)),
                              _summaryRow(
                                'Delivery',
                                order.deliveryFee <= 0
                                    ? 'FREE'
                                    : formatInrAmount(order.deliveryFee),
                              ),
                              const Divider(height: 20),
                              _summaryRow(
                                'Total payable',
                                formatInrAmount(order.totalAmount),
                                emphasize: true,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _labelDownloadBusy
                                      ? null
                                      : () => _onDownloadShippingLabel(
                                          context, details),
                                  icon: _labelDownloadBusy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(
                                          Icons.local_shipping_outlined,
                                          size: 20),
                                  label: Text(
                                    _labelDownloadBusy
                                        ? 'Generating label…'
                                        : 'Download Label',
                                  ),
                                ),
                              ),
                              if (details.items.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _onDownloadAdminInvoice(
                                        context, details),
                                    icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 20),
                                    label: const Text('Download Invoice'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasStructuredShipping(AdminOrderDetails d) {
    return (d.shippingFullName != null && d.shippingFullName!.isNotEmpty) ||
        (d.shippingPhone != null && d.shippingPhone!.isNotEmpty) ||
        (d.shippingAddressLine != null && d.shippingAddressLine!.isNotEmpty) ||
        (d.shippingCity != null && d.shippingCity!.isNotEmpty) ||
        (d.shippingPostalCode != null && d.shippingPostalCode!.isNotEmpty);
  }

  static Widget _summaryRow(String label, String value,
      {bool emphasize = false}) {
    final isFree = value.trim().toUpperCase() == 'FREE';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: emphasize ? 16 : 14,
                color: isFree ? null : AppColors.priceText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _adminPaymentStatusLabel(String raw) {
  switch (raw.toLowerCase().trim()) {
    case 'paid':
    case 'captured':
    case 'success':
    case 'completed':
      return 'Paid';
    case 'authorized':
    case 'created':
      return 'Pending';
    case 'failed':
    case 'error':
      return 'Failed';
    case 'refunded':
      return 'Refunded';
    default:
      return 'Pending';
  }
}

String _adminPaymentMethodLabel(String raw) {
  final v = raw.toLowerCase().trim();
  if (v == 'razorpay' || v == 'online') return 'Razorpay (Online)';
  if (v == 'cod') return 'Cash on Delivery';
  return raw.trim().isEmpty ? '—' : raw;
}

String _dashIfEmpty(String? v) {
  final t = v?.trim() ?? '';
  return t.isEmpty ? '—' : t;
}

class _AdminShipmentReadOnlyLine extends StatelessWidget {
  final String label;
  final String? value;

  const _AdminShipmentReadOnlyLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display =
        (value == null || value!.trim().isEmpty) ? '—' : value!.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            display,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _AdminPaymentDetailLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _AdminPaymentDetailLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
