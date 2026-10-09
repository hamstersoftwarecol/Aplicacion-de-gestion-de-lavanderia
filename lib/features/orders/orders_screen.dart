import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/business_time.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';
import 'order_rules.dart';
import 'order_form.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  final LaundryRepository repository;
  final String? clientId;
  const OrdersScreen({super.key, required this.repository, this.clientId});
  @override
  State<OrdersScreen> createState() => _OrdersState();
}

class _OrdersState extends State<OrdersScreen> {
  late Future<List<JsonRow>> _data;
  int _page = 0;
  String _query = '';
  String? _status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.repository.list(
      'orders',
      page: _page,
      query: _query,
      status: _status,
      clientId: widget.clientId,
    );
  }

  Future<void> _open(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderDetailScreen(repository: widget.repository, id: id),
      ),
    );
    if (mounted) setState(_load);
  }

  Future<void> _new() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrderForm(repository: widget.repository, clientId: widget.clientId),
      ),
    );
    if (mounted && id != null) {
      setState(_load);
      await _open(id);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          'Pedidos',
          'Sigue cada pedido, desde la recepción hasta la entrega.',
          action: FilledButton.icon(
            onPressed: _new,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo pedido'),
          ),
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar por número o cliente',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (v) => setState(() {
            _query = v;
            _page = 0;
            _load();
          }),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: _status == null,
                  onSelected: (_) => setState(() {
                    _status = null;
                    _page = 0;
                    _load();
                  }),
                ),
              ),
              for (final e in statusLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) => setState(() {
                      _status = e.key;
                      _page = 0;
                      _load();
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<JsonRow>>(
            future: _data,
            builder: (context, s) {
              if (s.hasError) return LoadError(retry: () => setState(_load));
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = s.data!;
              return Column(
                children: [
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Text('No hay pedidos para mostrar.'),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (c, i) {
                              final r = rows[i];
                              return Card(
                                child: InkWell(
                                  onTap: () => _open(r['id']),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Pedido #${r['number']} · ${r['clients']['name']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 20,
                                          runSpacing: 6,
                                          children: [
                                            Text(
                                              statusLabels[r['status']] ??
                                                  r['status'],
                                              style: const TextStyle(
                                                color: Color(0xff146b64),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(money(r['total_minor'])),
                                            Text(
                                              'Entrega: ${businessDateLabel(r['due_at'])}',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Pager(
                    page: _page,
                    count: rows.length,
                    onPage: (p) => setState(() {
                      _page = p;
                      _load();
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
