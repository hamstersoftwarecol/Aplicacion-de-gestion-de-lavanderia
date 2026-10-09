import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavanderia/features/catalog/entity_screen.dart';
import '../../support/fake_repository.dart';

void main() {
  testWidgets('employee sees catalog but cannot edit prices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EntityScreen(
            repository: FakeRepository(),
            table: 'services',
            isAdmin: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lavado'), findsOneWidget);
    expect(find.text('Nuevo servicio'), findsNothing);
    expect(find.byTooltip('Editar'), findsNothing);
  });
}
