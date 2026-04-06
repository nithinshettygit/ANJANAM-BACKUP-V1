/// Client-side validation aligned with common ecommerce auth expectations.
/// Server/Supabase may enforce stricter rules; these avoid obviously weak input.

final RegExp _emailLoose = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmailFormat(String email) {
  final t = email.trim();
  if (t.length < 5 || t.length > 254) return false;
  return _emailLoose.hasMatch(t);
}

/// True if [password] meets app rules: length ≥8 and at least one digit or special char.
bool meetsPasswordStrengthRules(String password) {
  if (password.length < 8) return false;
  final hasDigit = RegExp(r'\d').hasMatch(password);
  final hasSpecial = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/;~`']''').hasMatch(password);
  return hasDigit || hasSpecial;
}

String? validateEmailField(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Email is required';
  if (!isValidEmailFormat(t)) return 'Enter a valid email address';
  return null;
}

String? validatePasswordField(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  if (v.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!meetsPasswordStrengthRules(v)) {
    return 'Include at least one number or one special character';
  }
  return null;
}
