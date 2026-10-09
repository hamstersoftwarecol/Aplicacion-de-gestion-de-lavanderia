import 'package:intl/intl.dart';

// Colombia has used UTC−5 without daylight saving since 1993.
DateTime bogotaTime(DateTime instant) =>
    instant.toUtc().subtract(const Duration(hours: 5));
DateTime businessDate(DateTime instant) {
  final d = bogotaTime(instant);
  return DateTime.utc(d.year, d.month, d.day);
}

String businessDateLabel(String value) =>
    DateFormat('dd/MM/yyyy HH:mm').format(bogotaTime(DateTime.parse(value)));
DateTime deliveryInstant(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day, 23); // 18:00 Bogotá
