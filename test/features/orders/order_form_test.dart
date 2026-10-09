import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/features/orders/order_form.dart';
import '../../support/fake_repository.dart';

void main() {
  testWidgets(
    'create order selects client and service and confirms before save',
    (tester) async {
      final repo = FakeRepository();
      await tester.pumpWidget(MaterialApp(home: OrderForm(repository: repo)));
      await tester.tap(find.text('Seleccionar cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Pérez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar servicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lavado'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2.000'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Revisar pedido'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Revisar pedido'));
      await tester.pumpAndSettle();
      expect(repo.rows['orders'], isEmpty);
      expect(find.textContaining('no podrá editarse'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Crear pedido'));
      await tester.pumpAndSettle();
      expect(repo.rows['orders']!.length, 1);
    },
  );
}
