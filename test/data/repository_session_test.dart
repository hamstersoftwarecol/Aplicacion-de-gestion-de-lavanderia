import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lavanderia/data/laundry_repository.dart';

void main() {
  test(
    'expired session rejects client mutation before reporting success',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'public-test-key',
        httpClient: MockClient(
          (r) async => Response(
            '[]',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = SupabaseLaundryRepository(client);
      await expectLater(
        repo.save('clients', {'name': 'Ana', 'phone': '123'}, id: 'missing'),
        throwsA(isA<AccessDenied>()),
      );
      await client.dispose();
    },
  );
}
