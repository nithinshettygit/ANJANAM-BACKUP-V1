import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentSettings {
  final String sellerLegalName;
  final String sellerAddress;
  final String sellerPhone;
  final String sellerEmail;
  final String? sellerGstin;
  final bool showTaxBreakup;
  final String? placeOfSupply;
  final List<String> labelFromAddressLines;
  final String? labelCarrierName;

  const DocumentSettings({
    required this.sellerLegalName,
    required this.sellerAddress,
    required this.sellerPhone,
    required this.sellerEmail,
    this.sellerGstin,
    this.showTaxBreakup = false,
    this.placeOfSupply,
    required this.labelFromAddressLines,
    this.labelCarrierName,
  });

  factory DocumentSettings.fromJson(Map<String, dynamic> json) {
    final address =
        (json['label_from_address'] ?? '').toString().replaceAll(r'\n', '\n');
    return DocumentSettings(
      sellerLegalName: _text(json['seller_legal_name'], 'Anjanam'),
      sellerAddress: _text(json['seller_address'], ''),
      sellerPhone: _text(json['seller_phone'], ''),
      sellerEmail: _text(json['seller_email'], ''),
      sellerGstin: _optional(json['seller_gstin']),
      showTaxBreakup: json['show_tax_breakup'] == true,
      placeOfSupply: _optional(json['place_of_supply']),
      labelFromAddressLines: address
          .split(RegExp(r'[\r\n]+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      labelCarrierName: _optional(json['label_carrier_name']),
    );
  }

  static DocumentSettings defaults() => const DocumentSettings(
        sellerLegalName: 'Anjanam',
        sellerAddress: 'MUGU, Kasaragod, Kerala, India, 671321',
        sellerPhone: '+91 81291 07108',
        sellerEmail: 'support.anjanam@gmail.com',
        labelFromAddressLines: [
          'Anjanam',
          'Anjanam Warehouse',
          'MUGU, Kasaragod',
          'Kerala, India 671321',
          '+91 81291 07108',
        ],
      );

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _optional(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class DocumentSettingsService {
  final SupabaseClient client;

  const DocumentSettingsService(this.client);

  Future<DocumentSettings> fetch() async {
    try {
      final row = await client
          .from('document_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row == null) return DocumentSettings.defaults();
      return DocumentSettings.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return DocumentSettings.defaults();
    }
  }
}
