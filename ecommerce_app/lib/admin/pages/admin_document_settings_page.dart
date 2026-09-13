import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ecommerce_app/core/document_settings/document_settings.dart';
import '../providers/admin_providers.dart';

class AdminDocumentSettingsPage extends ConsumerWidget {
  const AdminDocumentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDocumentSettingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not load document settings: $error')),
      data: (settings) => _DocumentSettingsForm(settings: settings),
    );
  }
}

class _DocumentSettingsForm extends ConsumerStatefulWidget {
  final DocumentSettings settings;

  const _DocumentSettingsForm({required this.settings});

  @override
  ConsumerState<_DocumentSettingsForm> createState() =>
      _DocumentSettingsFormState();
}

class _DocumentSettingsFormState extends ConsumerState<_DocumentSettingsForm> {
  late final TextEditingController _legalName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _gstin;
  late final TextEditingController _placeOfSupply;
  late final TextEditingController _fromAddress;
  late final TextEditingController _carrier;
  bool _showTaxBreakup = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _legalName = TextEditingController(text: s.sellerLegalName);
    _address = TextEditingController(text: s.sellerAddress);
    _phone = TextEditingController(text: s.sellerPhone);
    _email = TextEditingController(text: s.sellerEmail);
    _gstin = TextEditingController(text: s.sellerGstin ?? '');
    _placeOfSupply = TextEditingController(text: s.placeOfSupply ?? '');
    _fromAddress =
        TextEditingController(text: s.labelFromAddressLines.join('\n'));
    _carrier = TextEditingController(text: s.labelCarrierName ?? '');
    _showTaxBreakup = s.showTaxBreakup;
  }

  @override
  void dispose() {
    for (final controller in [
      _legalName,
      _address,
      _phone,
      _email,
      _gstin,
      _placeOfSupply,
      _fromAddress,
      _carrier,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = DocumentSettings(
        sellerLegalName: _legalName.text,
        sellerAddress: _address.text,
        sellerPhone: _phone.text,
        sellerEmail: _email.text,
        sellerGstin: _gstin.text,
        showTaxBreakup: _showTaxBreakup,
        placeOfSupply: _placeOfSupply.text,
        labelFromAddressLines: _fromAddress.text
            .split(RegExp(r'[\r\n]+'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(),
        labelCarrierName: _carrier.text,
      );
      await ref.read(adminServiceProvider).updateDocumentSettings(settings);
      ref.invalidate(adminDocumentSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document settings saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Invoice and Label Settings',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
            'These values are editable placeholders used by generated documents.'),
        const SizedBox(height: 20),
        _section('Seller details', [
          _field(_legalName, 'Legal seller name *'),
          _field(_address, 'Registered/business address *', maxLines: 3),
          _field(_phone, 'Seller phone'),
          _field(_email, 'Seller email'),
          _field(_gstin, 'GSTIN (optional)'),
        ]),
        _section('Invoice display', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show tax breakup on invoices'),
            subtitle: const Text(
                'Enable only after rates and GST details are verified.'),
            value: _showTaxBreakup,
            onChanged: (value) => setState(() => _showTaxBreakup = value),
          ),
          _field(_placeOfSupply, 'Place of supply'),
        ]),
        _section('Delivery label', [
          _field(_fromAddress, 'From / return address', maxLines: 5),
          _field(_carrier, 'Default carrier name (optional)'),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Save document settings'),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            ...children,
          ]),
        ),
      );

  Widget _field(TextEditingController controller, String label,
          {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
        ),
      );
}
