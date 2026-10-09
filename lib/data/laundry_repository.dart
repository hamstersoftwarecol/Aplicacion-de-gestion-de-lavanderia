import 'package:supabase_flutter/supabase_flutter.dart';

typedef JsonRow = Map<String, dynamic>;

class AccessDenied implements Exception {
  const AccessDenied();
}

class StaffSession {
  final String id, name, role;
  const StaffSession(this.id, this.name, this.role);
  bool get isAdmin => role == 'admin';
}

abstract class LaundryRepository {
  bool get hasSession;
  Stream<bool> get sessions;
  Future<StaffSession> profile();
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<List<JsonRow>> list(
    String table, {
    String query = '',
    int page = 0,
    String? status,
    String? clientId,
  });
  Future<void> save(String table, JsonRow values, {String? id});
  Future<JsonRow> dashboard();
  Future<String> createOrder({
    required String clientId,
    required DateTime dueAt,
    required String notes,
    required List<JsonRow> items,
  });
  Future<JsonRow> orderDetail(String id);
  Future<void> pay(
    String id, {
    required int amountMinor,
    required String method,
    String? reference,
    required String key,
  });
  Future<void> transition(String id, String expected, String next);
  Future<void> setProfileAccess(String id, String role, bool active);
}

class SupabaseLaundryRepository extends LaundryRepository {
  final SupabaseClient client;
  SupabaseLaundryRepository(this.client);
  @override
  bool get hasSession => client.auth.currentSession != null;
  @override
  Stream<bool> get sessions =>
      client.auth.onAuthStateChange.map((e) => e.session != null);
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<StaffSession> profile() async {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AccessDenied();
    final row = await client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null || row['active'] != true) throw const AccessDenied();
    return StaffSession(id, row['name'] as String, row['role'] as String);
  }

  @override
  Future<List<JsonRow>> list(
    String table, {
    String query = '',
    int page = 0,
    String? status,
    String? clientId,
  }) async {
    await profile();
    if (!{'clients', 'services', 'profiles', 'orders'}.contains(table)) {
      throw ArgumentError('Tabla no admitida');
    }
    final select = table == 'orders' ? '*,clients!inner(name,phone)' : '*';
    var request = client.from(table).select(select);
    if (query.trim().isNotEmpty) {
      final literal = query
          .trim()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final number = int.tryParse(query.trim());
      if (table == 'orders' && number != null) {
        request = request.eq('number', number);
      } else {
        request = request.ilike(
          table == 'orders' ? 'clients.name' : 'name',
          '%$literal%',
        );
      }
    }
    if (status != null) request = request.eq('status', status);
    if (clientId != null) request = request.eq('client_id', clientId);
    return await request
        .order(
          table == 'orders' ? 'received_at' : 'name',
          ascending: table != 'orders',
        )
        .order('id')
        .range(page * 25, page * 25 + 24);
  }

  @override
  Future<void> save(String table, JsonRow values, {String? id}) async {
    await profile();
    if (!{'clients', 'services'}.contains(table)) {
      throw ArgumentError('Tabla no editable');
    }
    if (id == null) {
      await client.from(table).insert(values).select('id').single();
    } else {
      await client
          .from(table)
          .update(values)
          .eq('id', id)
          .select('id')
          .single();
    }
  }

  @override
  Future<JsonRow> dashboard() async {
    await profile();
    return Map<String, dynamic>.from(await client.rpc('dashboard_summary'));
  }

  @override
  Future<String> createOrder({
    required String clientId,
    required DateTime dueAt,
    required String notes,
    required List<JsonRow> items,
  }) async {
    await profile();
    return await client.rpc(
          'create_order',
          params: {
            'p_client_id': clientId,
            'p_due_at': dueAt.toUtc().toIso8601String(),
            'p_notes': notes,
            'p_items': items,
          },
        )
        as String;
  }

  @override
  Future<JsonRow> orderDetail(String id) async {
    await profile();
    return await client
        .from('orders')
        .select(
          '*,clients(name,phone),order_items(*),payments(*),order_events(*)',
        )
        .eq('id', id)
        .single();
  }

  @override
  Future<void> pay(
    String id, {
    required int amountMinor,
    required String method,
    String? reference,
    required String key,
  }) async {
    await profile();
    await client.rpc(
      'record_payment',
      params: {
        'p_order_id': id,
        'p_amount_minor': amountMinor,
        'p_method': method,
        'p_reference': reference,
        'p_idempotency_key': key,
      },
    );
  }

  @override
  Future<void> transition(String id, String expected, String next) async {
    await profile();
    await client.rpc(
      'change_order_status',
      params: {
        'p_order_id': id,
        'p_expected_status': expected,
        'p_next_status': next,
      },
    );
  }

  @override
  Future<void> setProfileAccess(String id, String role, bool active) async {
    await profile();
    await client.rpc(
      'set_profile_access',
      params: {'p_profile_id': id, 'p_role': role, 'p_active': active},
    );
  }
}
