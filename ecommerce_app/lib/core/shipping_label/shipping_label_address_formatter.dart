/// Builds ship-to address lines for labels (domestic and international).
class ShippingLabelAddressFormatter {
  static const String _missing = '—';

  /// Returns display lines for the TO block (name and phone are separate on the label).
  static List<String> formatShipToLines({
    String? fullName,
    String? phone,
    String? addressLine,
    String? city,
    String? state,
    String? postalCode,
    String legacyAddress = '',
    String fallbackCustomerName = '',
  }) {
    final lines = <String>[];

    final street = _trim(addressLine);
    if (street != null) {
      lines.addAll(_splitMultiline(street));
    } else {
      final legacy = legacyAddress.trim();
      if (legacy.isNotEmpty) {
        lines.addAll(_splitMultiline(legacy));
      }
    }

    final cityT = _trim(city);
    final stateT = _trim(state);
    final postalT = _trim(postalCode);

    if (cityT != null || stateT != null || postalT != null) {
      lines.add(_formatLocalityLine(city: cityT, state: stateT, postal: postalT));
    }

    if (lines.isEmpty) {
      final name = _trim(fullName) ?? _trim(fallbackCustomerName);
      if (name != null) {
        lines.add(name);
      }
    }

    if (lines.isEmpty) return const [_missing];
    return lines;
  }

  static String? formatPhone(String? phone) {
    final t = phone?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static String formatCustomerName({
    String? fullName,
    String fallbackCustomerName = '',
  }) {
    return _trim(fullName) ?? _trim(fallbackCustomerName) ?? _missing;
  }

  static String? _trim(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static List<String> _splitMultiline(String text) {
    return text
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Domestic (e.g. City, State PIN) vs international (City, Region, Postal).
  static String _formatLocalityLine({
    String? city,
    String? state,
    String? postal,
  }) {
    final parts = <String>[];
    if (city != null) parts.add(city);

    final statePostal = <String>[];
    if (state != null) statePostal.add(state);
    if (postal != null) statePostal.add(postal);

    if (statePostal.isNotEmpty) {
      parts.add(statePostal.join(' '));
    }

    return parts.join(', ');
  }
}
