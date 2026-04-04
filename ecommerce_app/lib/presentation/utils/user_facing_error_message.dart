import 'package:ecommerce_app/core/errors/app_exception.dart';

/// Short copy for SnackBars and simple alerts (avoids raw repository dumps).
String userFacingErrorMessage(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
