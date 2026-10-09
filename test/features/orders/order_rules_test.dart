import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/features/orders/order_rules.dart';

void main() {
  test('legal transitions require paid balance for delivery', () {
    expect(
      canTransition(
        OrderStatus.received,
        OrderStatus.processing,
        balanceMinor: 100,
        hasPayments: false,
      ),
      isTrue,
    );
    expect(
      canTransition(
        OrderStatus.received,
        OrderStatus.delivered,
        balanceMinor: 0,
        hasPayments: true,
      ),
      isFalse,
    );
    expect(
      canTransition(
        OrderStatus.ready,
        OrderStatus.delivered,
        balanceMinor: 1,
        hasPayments: true,
      ),
      isFalse,
    );
    expect(
      canTransition(
        OrderStatus.ready,
        OrderStatus.delivered,
        balanceMinor: 0,
        hasPayments: true,
      ),
      isTrue,
    );
    expect(
      canTransition(
        OrderStatus.processing,
        OrderStatus.cancelled,
        balanceMinor: 50,
        hasPayments: true,
      ),
      isFalse,
    );
    expect(
      canTransition(
        OrderStatus.received,
        OrderStatus.cancelled,
        balanceMinor: 50,
        hasPayments: false,
      ),
      isTrue,
    );
    expect(
      canTransition(
        OrderStatus.delivered,
        OrderStatus.processing,
        balanceMinor: 0,
        hasPayments: true,
      ),
      isFalse,
    );
  });
}
