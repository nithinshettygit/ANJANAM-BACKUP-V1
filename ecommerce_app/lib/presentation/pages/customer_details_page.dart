import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                      Text(
                        'Your details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text('Name: ${details.customerName}'),
                      Text('Email: ${details.email}'),
                      Text('Phone: ${details.phone.trim().isEmpty ? '-' : details.phone}'),
                      Text('Address: ${details.address.trim().isEmpty ? '-' : details.address}'),
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
