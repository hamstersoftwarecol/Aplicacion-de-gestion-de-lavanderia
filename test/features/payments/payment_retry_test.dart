import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/features/payments/payment_dialog.dart';
import '../../support/fake_repository.dart';

class LostResponseRepository extends FakeRepository {
  final keys = <String>[];
  @override
  Future<void> pay(
    String id, {
    required int amountMinor,
    required String method,
    String? reference,
    required String key,
  }) async {
    keys.add(key);
    if (keys.length == 1) throw Exception('Connection closed after commit');
  }
}

void main() {
  testWidgets(
    'retry keeps payment identifier and prevents editing original amount',
    (tester) async {
      final repo = LostResponseRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => showDialog<void>(
                  context: c,
                  builder: (_) => PaymentDialog(
                    repository: repo,
                    orderId: 'o',
                    balance: 100000,
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe (COP)'),
        '500',
      );
      await tester.tap(find.text('Revisar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pago'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.widgetWithText(TextFormField, 'Importe (COP)'),
                matching: find.byType(EditableText),
              ),
            )
            .readOnly,
        isTrue,
      );
      await tester.tap(find.text('Reintentar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pago'));
      await tester.pumpAndSettle();
      expect(repo.keys.length, 2);
      expect(repo.keys[0], repo.keys[1]);
    },
  );
}
