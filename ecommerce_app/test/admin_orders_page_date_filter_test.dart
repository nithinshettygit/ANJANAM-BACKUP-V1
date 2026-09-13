import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecommerce_app/admin/pages/admin_orders_page.dart';

void main() {
  test('same-day range does not include orders from the previous day', () {
    final range = DateTimeRange(
      start: DateTime(2026, 10, 13),
      end: DateTime(2026, 10, 13),
    );

    expect(
      matchesAdminOrderDateRange(DateTime(2026, 10, 13, 12, 30), range),
      isTrue,
    );
    expect(
      matchesAdminOrderDateRange(DateTime(2026, 10, 12, 23, 59), range),
      isFalse,
    );
    expect(
      matchesAdminOrderDateRange(DateTime(2026, 10, 14, 0, 1), range),
      isFalse,
    );
  });
}
