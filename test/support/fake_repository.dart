import 'package:lavanderia/data/laundry_repository.dart';

class FakeRepository extends LaundryRepository {
  bool failSave = false;
  int paymentsMade = 0;
  String? lastPaymentKey;
  final rows = <String, List<JsonRow>>{
    'clients': [
      {'id': 'c1', 'name': 'Ana Pérez', 'phone': '3001234567', 'active': true},
    ],
    'services': [
      {
        'id': 's1',
        'name': 'Lavado',
        'unit': 'piece',
        'price_minor': 100000,
        'active': true,
      },
    ],
    'profiles': [],
    'orders': [],
  };
  @override
  Future<StaffSession> profile() async =>
      const StaffSession('u1', 'Operador', 'admin');
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  bool get hasSession => true;
  @override
  Stream<bool> get sessions => const Stream.empty();
  @override
  Future<List<JsonRow>> list(
    String table, {
    String query = '',
    int page = 0,
    String? status,
    String? clientId,
  }) async => rows[table] ?? [];
  @override
  Future<void> save(String table, JsonRow values, {String? id}) async {
    if (failSave) throw Exception('Sin conexión');
    if (id == null) {
      rows[table]!.add({'id': 'new', ...values});
    } else {
      rows[table]!.firstWhere((r) => r['id'] == id).addAll(values);
    }
  }

  @override
  Future<JsonRow> dashboard() async => {
    'active_orders': 0,
    'due_today': 0,
    'outstanding_minor': 0,
  };
  @override
  Future<String> createOrder({
    required String clientId,
    required DateTime dueAt,
    required String notes,
    required List<JsonRow> items,
  }) async {
    rows['orders']!.add({
      'id': 'o1',
      'number': 1,
      'client_id': clientId,
      'clients': {'name': 'Ana Pérez'},
      'status': 'received',
      'total_minor': 100000,
      'received_at': DateTime.now().toIso8601String(),
      'due_at': dueAt.toIso8601String(),
    });
    return 'o1';
  }

  @override
  Future<JsonRow> orderDetail(String id) async => {
    ...rows['orders']!.firstWhere((r) => r['id'] == id),
    'order_items': [
      {
        'service_name': 'Lavado',
        'unit': 'piece',
        'quantity': 1,
        'subtotal_minor': 100000,
      },
    ],
    'payments': paymentsMade == 0
        ? <JsonRow>[]
        : [
            {'amount_minor': 100000, 'method': 'cash'},
          ],
    'order_events': <JsonRow>[],
  };
  @override
  Future<void> pay(
    String id, {
    required int amountMinor,
    required String method,
    String? reference,
    required String key,
  }) async {
    paymentsMade++;
    lastPaymentKey = key;
  }

  @override
  Future<void> transition(String id, String expected, String next) async {
    rows['orders']!.firstWhere((r) => r['id'] == id)['status'] = next;
  }

  @override
  Future<void> setProfileAccess(String id, String role, bool active) async {}
}
