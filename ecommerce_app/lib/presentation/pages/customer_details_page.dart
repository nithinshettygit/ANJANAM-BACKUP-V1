import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/formatting/inr_format.dart';
import '../providers/customer_details_provider.dart';

class CustomerDetailsPage extends ConsumerWidget {
  const CustomerDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(customerDetailsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Details')),
      body: detailsAsync.when(
        data: (details) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text('Customer Name: ${details.customerName}'),
                      Text('Email: ${details.email}'),
                      Text('Phone: ${details.phone.trim().isEmpty ? '-' : details.phone}'),
                      Text('Address: ${details.address.trim().isEmpty ? '-' : details.address}'),
                      const SizedBox(height: 8),
                      Text('Total Orders: ${details.totalOrders}'),
                      Text('Total Revenue: ${formatInrAmount(details.totalRevenue)}'),
                      Text('Last Order Date: ${_formatDateTime(details.lastOrderDate)}'),
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
                        'Customer Insights',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text('First Order Date: ${_formatDateTime(details.firstOrderDate)}'),
                      Text('Average Order Value: ${formatInrAmount(details.averageOrderValue)}'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Failed to load customer details: $error'),
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  return dateTime.toLocal().toString().split('.').first;
}
