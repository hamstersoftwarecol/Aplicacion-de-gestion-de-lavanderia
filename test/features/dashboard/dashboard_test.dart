import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/core/business_time.dart';

void main() {
  test('business day follows Bogota across UTC midnight', () {
    expect(
      businessDate(DateTime.parse('2026-10-09T02:00:00Z')),
      DateTime.utc(2026, 10, 8),
    );
    expect(
      businessDate(DateTime.parse('2026-10-09T04:59:00Z')),
      DateTime.utc(2026, 10, 8),
    );
    expect(
      businessDate(DateTime.parse('2026-10-09T05:00:00Z')),
      DateTime.utc(2026, 10, 9),
    );
  });
}
