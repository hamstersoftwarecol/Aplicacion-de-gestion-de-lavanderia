import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lavanderia/app.dart';
import 'package:lavanderia/data/laundry_repository.dart';
import '../../support/fake_repository.dart';

class RevocationRepository extends FakeRepository {
  bool activeSession = true;
  final changes = StreamController<bool>.broadcast();
  bool rejectSave = false;
  @override
  bool get hasSession => activeSession;
  @override
  Stream<bool> get sessions => changes.stream;
  @override
  Future<void> save(String table, JsonRow values, {String? id}) async {
    if (rejectSave) {
      throw const PostgrestException(message: 'JWT expired', code: 'PGRST301');
    }
    await super.save(table, values, id: id);
  }
}

void main() {
  testWidgets('session end removes an open protected dialog', (tester) async {
    final repo = RevocationRepository();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(LaundryApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Pérez'), findsWidgets);
    repo.activeSession = false;
    repo.changes.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Editar cliente'), findsNothing);
    expect(find.text('Ana Pérez'), findsNothing);
  });
  testWidgets('JWT rejection while saving removes protected editor', (
    tester,
  ) async {
    final repo = RevocationRepository()..rejectSave = true;
    addTearDown(repo.changes.close);
    await tester.pumpWidget(LaundryApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar cliente'), findsNothing);
    expect(find.text('Ana Pérez'), findsNothing);
  });
}
