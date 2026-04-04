/// Parse `estimated_delivery_date` from Supabase/Postgres (timestamptz, ISO string, or JSON).
DateTime? parseEstimatedDeliveryFromDb(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final normalized = s.contains('T') ? s : s.replaceFirst(RegExp(r'\s+'), 'T');
  final parsed = DateTime.tryParse(normalized);
  return parsed?.toUtc();
}

/// Store the admin-picked **calendar** date as UTC noon on that Y-M-D so the intended day
/// stays stable across timezones (avoids local-midnight → UTC day-shift bugs).
String estimatedDeliveryToDbIso(DateTime datePickerResult) {
  final y = datePickerResult.year;
  final m = datePickerResult.month;
  final d = datePickerResult.day;
  return DateTime.utc(y, m, d, 12).toIso8601String();
}

/// Display the stored estimated delivery as a single calendar date (no clock time).
String formatEstimatedDeliveryDate(DateTime stored) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final u = stored.toUtc();
  final mon = months[u.month - 1];
  return '${u.day} $mon ${u.year}';
}
