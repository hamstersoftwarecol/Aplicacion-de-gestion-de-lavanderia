import 'package:flutter/material.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  final LaundryRepository repository;
  final VoidCallback onSignedIn;
  const LoginScreen({
    super.key,
    required this.repository,
    required this.onSignedIn,
  });
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.signIn(_email.text, _password.text);
      if (mounted) widget.onSignedIn();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.local_laundry_service_outlined,
                      size: 56,
                      color: Color(0xff146b64),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tu lavandería, en orden',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Inicia sesión para gestionar el día a día.'),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      validator: (s) => s == null || !s.contains('@')
                          ? 'Introduce un correo válido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _login(),
                      validator: (s) =>
                          s == null || s.isEmpty ? 'Campo obligatorio' : null,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: Text(_busy ? 'Ingresando…' : 'Iniciar sesión'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '¿Necesitas acceso? Solicita una cuenta al administrador.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
