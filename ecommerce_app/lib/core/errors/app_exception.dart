abstract class AppException implements Exception {
  final String message;

  const AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Classifies authentication failures for user-facing copy and actions.
enum AuthFailureKind {
  invalidCredentials,
  accountExists,
  accountSuspended,
  emailNotConfirmed,
  weakPassword,
  network,
  sessionExpired,
  rateLimited,
  unknown,
}

class AuthException extends AppException {
  final AuthFailureKind kind;

  const AuthException(super.message, {this.kind = AuthFailureKind.unknown});
}

class RepositoryException extends AppException {
  const RepositoryException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

