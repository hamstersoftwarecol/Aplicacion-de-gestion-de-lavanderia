import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'data/laundry_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL'),
      key = String.fromEnvironment('SUPABASE_ANON_KEY');
  LaundryRepository? repository;
  if (url.isNotEmpty && key.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      await Supabase.initialize(url: url, publishableKey: key);
      repository = SupabaseLaundryRepository(Supabase.instance.client);
    }
  }
  runApp(LaundryApp(repository: repository));
}
