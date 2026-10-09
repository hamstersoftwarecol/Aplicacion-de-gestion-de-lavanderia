import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/business_time.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';
import '../payments/payment_dialog.dart';
import 'order_rules.dart';

class OrderDetailScreen extends StatefulWidget {
  final LaundryRepository repository;
  final String id;
  const OrderDetailScreen({
    super.key,
    required this.repository,
    required this.id,
  });
  @override
  State<OrderDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<OrderDetailScreen> {
  late Future<JsonRow> _data;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.repository.orderDetail(widget.id);
  }

  Future<void> _transition(String expected, String next) async {
    if (_busy) return;
    if (next == 'cancelled') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cancelar pedido'),
          content: const Text(
            'Esta acción es definitiva. Se conservará el historial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar cancelación'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.transition(widget.id, expected, next);
    } catch (e) {
      if (mounted) reportProblem(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _load();
        });
      }
    }
  }

  Future<void> _payment(int balance) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(
        repository: widget.repository,
        orderId: widget.id,
        balance: balance,
      ),
    );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle del pedido'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _busy ? null : () => setState(_load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<JsonRow>(
      future: _data,
      builder: (context, s) {
        if (s.hasError) return LoadError(retry: () => setState(_load));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final r = s.data!,
            items = List<JsonRow>.from(r['order_items']),
            payments = List<JsonRow>.from(r['payments']);
        final events = List<JsonRow>.from(r['order_events'])
          ..sort(
            (a, b) => (a['created_at'] as String).compareTo(
              b['created_at'] as String,
            ),
          );
        final paid = payments.fold<int>(
              0,
              (sum, p) => sum + (p['amount_minor'] as int),
            ),
            balance = (r['total_minor'] as int) - paid;
        final status = OrderStatus.values.byName(r['status']);
        const actions = {
          'processing': 'Iniciar proceso',
          'ready': 'Marcar listo',
          'delivered': 'Entregar',
          'cancelled': 'Cancelar pedido',
        };
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SectionHeading(
                  'Pedido #${r['number']}',
                  '${r['clients']['name']} · ${r['clients']['phone']}',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(statusLabels[r['status']]!),
                    avatar: const Icon(Icons.local_laundry_service_outlined),
                  ),
                ),
                Text('Entrega prevista: ${businessDateLabel(r['due_at'])}'),
                if ((r['notes'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(r['notes']),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        for (final item in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['service_name']),
                            subtitle: Text(
                              '${item['unit'] == 'kilogram' ? (item['quantity'] as int) / 1000 : item['quantity']} ${unitLabel(item['unit'])}',
                            ),
                            trailing: Text(money(item['subtotal_minor'])),
                          ),
                        const Divider(),
                        _amount('Total', r['total_minor']),
                        _amount('Pagado', paid),
                        _amount('Saldo pendiente', balance),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (balance > 0 &&
                        status != OrderStatus.cancelled &&
                        status != OrderStatus.delivered)
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _payment(balance),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Registrar pago'),
                      ),
                    for (final a in actions.entries)
                      if (canTransition(
                        status,
                        OrderStatus.values.byName(a.key),
                        balanceMinor: balance,
                        hasPayments: payments.isNotEmpty,
                      ))
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _transition(r['status'], a.key),
                          child: Text(a.value),
                        ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Pagos registrados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aún no hay pagos.'),
                  ),
                for (final p in payments)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(money(p['amount_minor'])),
                    subtitle: Text(
                      '${{'cash': 'Efectivo', 'transfer': 'Transferencia', 'card': 'Tarjeta'}[p['method']]}${p['reference'] == null ? '' : ' · ${p['reference']}'}${p['created_at'] == null ? '' : ' · ${businessDateLabel(p['created_at'])}'}',
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Historial de estados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final e in events)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(statusLabels[e['to_status']] ?? e['to_status']),
                    subtitle: Text(businessDateLabel(e['created_at'])),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
  Widget _amount(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(money(value), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
