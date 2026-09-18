import 'package:ecommerce_app/presentation/routing/route_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads and decodes a route query parameter', () {
    expect(
      routeQueryParameter('/search?q=red%20shoes', 'q'),
      'red shoes',
    );
  });

  test('returns null when the route has no requested parameter', () {
    expect(routeQueryParameter('/search', 'q'), isNull);
    expect(routeQueryParameter('/search?q=books', 'category'), isNull);
  });

  test('does not throw for malformed route input', () {
    expect(routeQueryParameter('/search?%', 'q'), isNull);
  });
}