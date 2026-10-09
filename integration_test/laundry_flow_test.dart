// Run ONLY against a dedicated development project. Creates durable test orders.
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lavanderia/data/laundry_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_SUPABASE_INTEGRATION');
  testWidgets(
    'two authenticated sessions share order, payments and delivery',
    (tester) async {
      const url = String.fromEnvironment('SUPABASE_URL');
      const publicKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      const adminEmail = String.fromEnvironment('TEST_ADMIN_EMAIL');
      const adminPassword = String.fromEnvironment('TEST_ADMIN_PASSWORD');
      const employeeEmail = String.fromEnvironment('TEST_EMPLOYEE_EMAIL');
      const employeePassword = String.fromEnvironment('TEST_EMPLOYEE_PASSWORD');
      expect(
        [
          url,
          publicKey,
          adminEmail,
          adminPassword,
          employeeEmail,
          employeePassword,
        ].every((s) => s.isNotEmpty),
        isTrue,
        reason: 'Dedicated Supabase project and two test accounts required',
      );
      final a = SupabaseClient(url, publicKey);
      final b = SupabaseClient(url, publicKey);
      final anon = SupabaseClient(url, publicKey);
      addTearDown(() async {
        await a.dispose();
        await b.dispose();
        await anon.dispose();
      });
      final admin = SupabaseLaundryRepository(a),
          employee = SupabaseLaundryRepository(b);
      await admin.signIn(adminEmail, adminPassword);
      await employee.signIn(employeeEmail, employeePassword);
      expect((await admin.profile()).isAdmin, isTrue);
      expect((await employee.profile()).isAdmin, isFalse);
      final marker = 'Prueba ${DateTime.now().microsecondsSinceEpoch}';
      await admin.save('services', {
        'name': marker,
        'unit': 'piece',
        'price_minor': 100000,
      });
      await employee.save('clients', {'name': marker, 'phone': '0000000000'});
      final service = (await admin.list('services', query: marker)).single;
      final customer = (await employee.list('clients', query: marker)).single;
      await expectLater(
        employee.save('services', {'price_minor': 1}, id: service['id']),
        throwsA(isA<PostgrestException>()),
      );
      final id = await employee.createOrder(
        clientId: customer['id'],
        dueAt: DateTime.now().add(const Duration(days: 1)),
        notes: 'Prueba automatizada de desarrollo',
        items: [
          {'service_id': service['id'], 'quantity': 2},
        ],
      );
      await employee.pay(
        id,
        amountMinor: 50000,
        method: 'cash',
        key: const Uuid().v4(),
      );
      final seen = await admin.orderDetail(id);
      expect(seen['total_minor'], 200000);
      expect((seen['payments'] as List).single['amount_minor'], 50000);
      await admin.pay(
        id,
        amountMinor: 150000,
        method: 'transfer',
        reference: marker,
        key: const Uuid().v4(),
      );
      await employee.transition(id, 'received', 'processing');
      await employee.transition(id, 'processing', 'ready');
      await admin.transition(id, 'ready', 'delivered');
      expect((await employee.orderDetail(id))['status'], 'delivered');
      expect(await anon.from('clients').select('id'), isEmpty);
      await admin.save('clients', {'active': false}, id: customer['id']);
      await admin.save('services', {'active': false}, id: service['id']);
    },
    skip: !enabled,
  );
}
