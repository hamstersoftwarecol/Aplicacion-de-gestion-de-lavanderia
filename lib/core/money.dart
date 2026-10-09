import 'package:intl/intl.dart';

enum ServiceUnit { piece, kilogram }

const maxExactMinor = 9000000000000000;
int _decimal(String text, int digits) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!RegExp('^[0-9]+(?:\\.[0-9]{1,$digits})?\$').hasMatch(normalized)) {
    throw const FormatException(
      'Usa un importe positivo, sin separadores de miles',
    );
  }
  final parts = normalized.split('.');
  final scale = digits == 2 ? 100 : 1000;
  final value = int.tryParse(parts[0]);
  if (value == null || value > maxExactMinor ~/ scale) {
    throw const FormatException('Importe fuera de rango');
  }
  final result =
      value * scale +
      int.parse(parts.length == 1 ? '0' : parts[1].padRight(digits, '0'));
  if (result <= 0 || result > maxExactMinor) {
    throw const FormatException('Debe ser mayor que cero');
  }
  return result;
}

int parseMoney(String text) => _decimal(text, 2);
int parseQuantity(String text, ServiceUnit unit) {
  final int quantity;
  if (unit == ServiceUnit.kilogram) {
    quantity = _decimal(text, 3);
  } else {
    if (!RegExp(r'^[0-9]+$').hasMatch(text.trim())) {
      throw const FormatException('Introduce piezas enteras');
    }
    quantity = int.tryParse(text.trim()) ?? 0;
  }
  if (quantity <= 0 || quantity > 1000000) {
    throw const FormatException('Cantidad fuera de rango');
  }
  return quantity;
}

int lineSubtotal({
  required int priceMinor,
  required int quantity,
  required ServiceUnit unit,
}) {
  if (priceMinor <= 0 ||
      priceMinor > 1000000000000 ||
      quantity <= 0 ||
      quantity > 1000000) {
    throw const FormatException('Precio o cantidad fuera de rango');
  }
  // BigInt avoids precision loss from JS multiplication before division.
  final product = BigInt.from(priceMinor) * BigInt.from(quantity);
  final result = unit == ServiceUnit.piece
      ? product
      : (product + BigInt.from(500)) ~/ BigInt.from(1000);
  if (result <= BigInt.zero || result > BigInt.from(maxExactMinor)) {
    throw const FormatException('Total fuera de rango');
  }
  return result.toInt();
}

String money(int minor) => NumberFormat.currency(
  locale: 'es_CO',
  symbol: r'$ ',
  decimalDigits: 2,
).format(minor / 100);
String moneyInput(int minor) =>
    '${minor ~/ 100},${(minor % 100).toString().padLeft(2, '0')}';
String unitLabel(String unit) => unit == 'kilogram' ? 'kg' : 'pieza';
