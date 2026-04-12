import 'package:flutter/material.dart';

/// Back control for full-screen admin detail routes (order, user, …).
///
/// After a **web refresh**, the navigator stack is empty so [Navigator.pop] does nothing
/// unless we fall back to replacing with [fallbackRoute] (e.g. `/admin/orders`).
Widget adminDetailBackLeading(
  BuildContext context, {
  required String fallbackRoute,
}) {
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    tooltip: 'Back',
    onPressed: () {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        nav.pushReplacementNamed(fallbackRoute);
      }
    },
  );
}
