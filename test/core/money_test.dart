import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/core/money.dart';

void main() {
  test('kilograms accept decimal comma, pieces require integers', () {
    expect(parseQuantity('1,250', ServiceUnit.kilogram), 1250);
    expect(parseQuantity('2', ServiceUnit.piece), 2);
    for (final text in ['1,5', '0', '-1', 'abc']) {
      expect(
        () => parseQuantity(text, ServiceUnit.piece),
        throwsFormatException,
      );
    }
    expect(
      () => parseQuantity('1,2500', ServiceUnit.kilogram),
      throwsFormatException,
    );
  });
  test('subtotal rounds half up using integer minor units', () {
    expect(
      lineSubtotal(
        priceMinor: 1001,
        quantity: 1500,
        unit: ServiceUnit.kilogram,
      ),
      1502,
    );
    expect(
      lineSubtotal(priceMinor: 1001, quantity: 2, unit: ServiceUnit.piece),
      2002,
    );
  });
  test('money rejects negative, ambiguous and excessive precision', () {
    expect(parseMoney('12500,50'), 1250050);
    for (final text in ['-1', '0', '1.000,50', '1,001']) {
      expect(() => parseMoney(text), throwsFormatException);
    }
  });
}
