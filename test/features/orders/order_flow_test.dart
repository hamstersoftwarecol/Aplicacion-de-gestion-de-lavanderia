import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/features/orders/order_detail_screen.dart';
import '../../support/fake_repository.dart';

void main() {
  testWidgets('payment confirmation updates balance before delivery', (
    tester,
  ) async {
    final repo = FakeRepository();
    await repo.createOrder(
      clientId: 'c1',
      dueAt: DateTime.now().add(const Duration(days: 1)),
      notes: '',
      items: [],
    );
    repo.rows['orders']!.first['status'] = 'ready';
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailScreen(repository: repo, id: 'o1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Entregar'), findsNothing);
    await tester.tap(find.text('Registrar pago'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Importe (COP)'),
      '1000',
    );
    await tester.tap(find.text('Revisar pago'));
    await tester.pumpAndSettle();
    expect(repo.paymentsMade, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pago'));
    await tester.pumpAndSettle();
    expect(find.text('Entregar'), findsOneWidget);
    await tester.tap(find.text('Entregar'));
    await tester.pumpAndSettle();
    expect(find.text('Entregado'), findsOneWidget);
  });
}
