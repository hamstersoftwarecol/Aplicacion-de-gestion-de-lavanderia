import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../core/business_time.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';

class OrderForm extends StatefulWidget {
  final LaundryRepository repository;
  final String? clientId;
  const OrderForm({super.key, required this.repository, this.clientId});
  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _notes = TextEditingController();
  final _lines = <JsonRow>[];
  String? _clientId;
  JsonRow? _client;
  DateTime _date = businessDate(DateTime.now().add(const Duration(days: 1)));
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _clientId = widget.clientId;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  int get total =>
      _lines.fold(0, (sum, r) => sum + (r['subtotal_minor'] as int));
  Future<void> _selectClient() async {
    final r = await showDialog<JsonRow>(
      context: context,
      builder: (_) =>
          _RecordPicker(repository: widget.repository, table: 'clients'),
    );
    if (r != null && mounted) {
      setState(() {
        _client = r;
        _clientId = r['id'];
      });
    }
  }

  Future<void> _addLine() async {
    if (_lines.length >= 100) {
      reportProblem(context, const FormatException('Máximo 100 servicios'));
      return;
    }
    final service = await showDialog<JsonRow>(
      context: context,
      builder: (_) =>
          _RecordPicker(repository: widget.repository, table: 'services'),
    );
    if (service == null || !mounted) return;
    final line = await showDialog<JsonRow>(
      context: context,
      builder: (_) => _QuantityDialog(service: service),
    );
    if (line != null && mounted) setState(() => _lines.add(line));
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_clientId == null || _lines.isEmpty) {
      reportProblem(
        context,
        const FormatException(
          'Selecciona un cliente y agrega al menos un servicio',
        ),
      );
      return;
    }
    if (total > maxExactMinor) {
      reportProblem(context, const FormatException('Total fuera de rango'));
      return;
    }
    final due = deliveryInstant(_date);
    if (due.isBefore(DateTime.now())) {
      reportProblem(
        context,
        const FormatException('La entrega debe ser posterior a la recepción'),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar pedido'),
        content: Text(
          '${_lines.length} servicios · Total ${money(total)}\nEntrega: ${businessDateLabel(due.toIso8601String())}\nEl detalle no podrá editarse después de confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Crear pedido'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await widget.repository.createOrder(
        clientId: _clientId!,
        dueAt: due,
        notes: _notes.text.trim(),
        items: [
          for (final l in _lines)
            {
              'service_id': l['service_id'],
              'quantity': l['quantity'],
              'expected_unit': l['unit'],
              'expected_price_minor': l['price_minor'],
            },
        ],
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) reportProblem(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Nuevo pedido')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SectionHeading(
                'Recibir un pedido',
                'Selecciona los servicios y revisa el total antes de guardar.',
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    _client?['name'] ??
                        (_clientId != null
                            ? 'Cliente del historial'
                            : 'Seleccionar cliente'),
                  ),
                  subtitle: _client == null ? null : Text(_client!['phone']),
                  trailing: const Icon(Icons.search),
                  onTap: _busy ? null : _selectClient,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                            _date.year,
                            _date.month,
                            _date.day,
                          ),
                          firstDate: businessDate(DateTime.now()),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null && mounted) {
                          setState(() => _date = date);
                        }
                      },
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  'Entrega: ${_date.day}/${_date.month}/${_date.year} · 18:00 Bogotá',
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < _lines.length; i++)
                Card(
                  child: ListTile(
                    title: Text(_lines[i]['service_name']),
                    subtitle: Text(
                      '${_lines[i]['display_quantity']} ${unitLabel(_lines[i]['unit'])} · ${money(_lines[i]['subtotal_minor'])}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Quitar servicio',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _lines.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Agregar servicio'),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notas del pedido (opcional)',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total: ${money(total)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Guardando…' : 'Revisar pedido'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RecordPicker extends StatefulWidget {
  final LaundryRepository repository;
  final String table;
  const _RecordPicker({required this.repository, required this.table});
  @override
  State<_RecordPicker> createState() => _RecordPickerState();
}

class _RecordPickerState extends State<_RecordPicker> {
  late Future<List<JsonRow>> _data;
  int _page = 0;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.repository.list(widget.table, query: _query, page: _page);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.table == 'clients'
          ? 'Seleccionar cliente'
          : 'Seleccionar servicio',
    ),
    content: SizedBox(
      width: 480,
      height: 400,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Buscar por nombre'),
            onSubmitted: (v) => setState(() {
              _query = v;
              _page = 0;
              _load();
            }),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<JsonRow>>(
              future: _data,
              builder: (c, s) {
                if (s.hasError) return LoadError(retry: () => setState(_load));
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  children: [
                    Expanded(
                      child: s.data!.isEmpty
                          ? const Center(
                              child: Text(
                                'Sin registros. Créalo primero en su sección.',
                              ),
                            )
                          : ListView(
                              children: [
                                for (final r in s.data!)
                                  ListTile(
                                    enabled: r['active'] == true,
                                    title: Text(r['name']),
                                    subtitle: Text(
                                      r['active'] != true
                                          ? 'Archivado'
                                          : widget.table == 'clients'
                                          ? r['phone']
                                          : '${money(r['price_minor'])} / ${unitLabel(r['unit'])}',
                                    ),
                                    onTap: r['active'] == true
                                        ? () => Navigator.pop(context, r)
                                        : null,
                                  ),
                              ],
                            ),
                    ),
                    Pager(
                      page: _page,
                      count: s.data!.length,
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
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
    ],
  );
}

class _QuantityDialog extends StatefulWidget {
  final JsonRow service;
  const _QuantityDialog({required this.service});
  @override
  State<_QuantityDialog> createState() => _QuantityState();
}

class _QuantityState extends State<_QuantityDialog> {
  final _form = GlobalKey<FormState>(),
      _quantity = TextEditingController(text: '1');
  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.service['name']),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _quantity,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Cantidad (${unitLabel(widget.service['unit'])})',
          helperText: 'Sin separadores de miles',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          try {
            lineSubtotal(
              priceMinor: widget.service['price_minor'],
              quantity: parseQuantity(
                v ?? '',
                ServiceUnit.values.byName(widget.service['unit']),
              ),
              unit: ServiceUnit.values.byName(widget.service['unit']),
            );
            return null;
          } on FormatException catch (e) {
            return e.message;
          }
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final unit = ServiceUnit.values.byName(widget.service['unit']);
          final qty = parseQuantity(_quantity.text, unit);
          Navigator.pop(context, <String, dynamic>{
            'service_id': widget.service['id'],
            'service_name': widget.service['name'],
            'unit': widget.service['unit'],
            'quantity': qty,
            'price_minor': widget.service['price_minor'],
            'display_quantity': _quantity.text,
            'subtotal_minor': lineSubtotal(
              priceMinor: widget.service['price_minor'],
              quantity: qty,
              unit: unit,
            ),
          });
        },
        child: const Text('Agregar'),
      ),
    ],
  );
}
