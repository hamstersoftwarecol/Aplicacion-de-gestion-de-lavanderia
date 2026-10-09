import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/laundry_repository.dart';

class SessionScope extends InheritedWidget {
  final VoidCallback onDenied;
  const SessionScope({super.key, required this.onDenied, required super.child});
  @override
  bool updateShouldNotify(SessionScope oldWidget) => false;
}

String errorText(Object error) {
  if (error is FormatException) return error.message;
  if (error is PostgrestException && error.code == '23514') {
    return error.message;
  }
  if (error is AuthException) {
    return 'No se pudo iniciar sesión. Revisa tus datos y la conexión.';
  }
  return 'No se pudo guardar o cargar la información. Revisa la conexión e inténtalo de nuevo.';
}

bool isAccessError(Object error) =>
    error is AccessDenied ||
    error is AuthException ||
    (error is PostgrestException &&
        ['42501', 'PGRST301', 'PGRST302', 'PGRST303'].contains(error.code));
void reportProblem(BuildContext context, Object error) {
  if (isAccessError(error)) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    if (scope != null) {
      scope.onDenied();
      return;
    }
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(errorText(error))));
}

class LoadError extends StatelessWidget {
  final VoidCallback retry;
  const LoadError({super.key, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('No pudimos cargar los datos. Revisa tu conexión.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const SectionHeading(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class Pager extends StatelessWidget {
  final int page, count;
  final ValueChanged<int> onPage;
  const Pager({
    super.key,
    required this.page,
    required this.count,
    required this.onPage,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      IconButton(
        tooltip: 'Página anterior',
        onPressed: page > 0 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Página ${page + 1}'),
      IconButton(
        tooltip: 'Página siguiente',
        onPressed: count == 25 ? () => onPage(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
