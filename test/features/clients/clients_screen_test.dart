import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/features/catalog/entity_screen.dart';
import '../../support/fake_repository.dart';

void main() {
  testWidgets('client form validates and preserves fields after failure', (
    tester,
  ) async {
    final repo = FakeRepository()..failSave = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityScreen(repository: repo, table: 'clients', isAdmin: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obligatorio'), findsNWidgets(2));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'María',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Teléfono'),
      '3101234567',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('María'), findsOneWidget);
    expect(find.textContaining('No se pudo guardar'), findsOneWidget);
    expect(repo.rows['clients']!.length, 1);
    repo.failSave = false;
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.rows['clients']!.length, 2);
  });
}
