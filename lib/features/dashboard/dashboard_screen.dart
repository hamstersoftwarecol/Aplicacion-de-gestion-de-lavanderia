import 'package:flutter/material.dart';
import '../../data/laundry_repository.dart';
import '../../core/money.dart';
import '../../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  final LaundryRepository repository;
  final ValueChanged<int> navigate;
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.navigate,
  });
  @override
  State<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends State<DashboardScreen> {
  late Future<JsonRow> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.repository.dashboard();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<JsonRow>(
    future: _data,
    builder: (context, s) {
      if (s.hasError) return LoadError(retry: () => setState(_load));
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final d = s.data!;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SectionHeading(
            'Resumen del día',
            'Todo lo que necesita tu lavandería, en un solo lugar.',
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _metric(
                'Pedidos activos',
                '${d['active_orders']}',
                Icons.local_laundry_service_outlined,
              ),
              _metric(
                'Entregas para hoy',
                '${d['due_today']}',
                Icons.event_available_outlined,
              ),
              _metric(
                'Saldo pendiente',
                money((d['outstanding_minor'] as num).toInt()),
                Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Una operación más sencilla',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Registra pedidos, consulta su avance y mantén cada pago al día.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => widget.navigate(1),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Ver pedidos'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.navigate(2),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Ver clientes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Las entregas de hoy se calculan con la hora de Bogotá. Los pagos se registran manualmente.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ),
        ],
      );
    },
  );
  Widget _metric(String label, String value, IconData icon) => SizedBox(
    width: 290,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xff146b64), size: 30),
            const SizedBox(height: 18),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
