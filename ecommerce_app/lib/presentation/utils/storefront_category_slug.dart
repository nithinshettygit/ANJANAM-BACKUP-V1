/// Normalizes category string from routes / filters for product queries (ilike).
/// Allows typical product [category] text (spaces, underscores, etc.).
/// Only `%` is blocked (ILIKE wildcard). `_` is allowed for real category names like `photo_frame`.
String? normalizeStorefrontCategorySlug(String? raw) {
  final t = raw?.trim().toLowerCase();
  if (t == null || t.isEmpty) return null;
  if (t.length > 120) return null;
  if (t.contains('%')) return null;
  return t;
}
