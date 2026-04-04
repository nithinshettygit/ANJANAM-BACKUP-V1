/// Short order id for display, e.g. `#BE8D4F4B` from UUID.
String formatOrderIdDisplay(String uuid) {
  final clean = uuid.replaceAll('-', '');
  final slice = clean.length >= 8 ? clean.substring(0, 8) : clean;
  return slice.toUpperCase();
}

/// E.g. `28 Mar 2026, 11:37 PM` (local, 12-hour).
String formatOrderDetailsDateTime(DateTime dateTime) {
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
  final l = dateTime.toLocal();
  final mon = months[l.month - 1];
  var h = l.hour % 12;
  if (h == 0) h = 12;
  final m = l.minute.toString().padLeft(2, '0');
  final ampm = l.hour < 12 ? 'AM' : 'PM';
  return '${l.day} $mon ${l.year}, $h:$m $ampm';
}
