/// Sanitize user input for safe use inside PostgREST `ilike` patterns.
String sanitizeOrderSearchIlike(String raw) {
  return raw.replaceAll(RegExp(r'[%_\\\x00]'), '').trim();
}

bool orderIdMatchesSearch(String orderId, String queryLower, String queryNorm) {
  final id = orderId.toLowerCase();
  final idNorm = id.replaceAll('-', '');
  return id.contains(queryLower) || idNorm.contains(queryNorm);
}
