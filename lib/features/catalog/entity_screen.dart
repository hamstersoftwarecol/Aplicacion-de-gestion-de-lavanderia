import 'package:flutter/material.dart';
import '../../core/money.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';
import '../orders/orders_screen.dart';

class EntityScreen extends StatefulWidget {
  final LaundryRepository repository;
  final String table;
  final bool isAdmin;
  const EntityScreen({
    super.key,
    required this.repository,
    required this.table,
    required this.isAdmin,
  });
  @override
  State<EntityScreen> createState() => _EntityState();
}

class _EntityState extends State<EntityScreen> {
  late Future<List<JsonRow>> _data;
  int _page = 0;
  String _query = '';
  bool get clients => widget.table == 'clients';
  bool get editable => clients || widget.isAdmin;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EntityScreen old) {
    super.didUpdateWidget(old);
    if (old.table != widget.table) {
      _page = 0;
      _query = '';
      _load();
    }
  }

  void _load() {
    _data = widget.repository.list(widget.table, query: _query, page: _page);
  }

  Future<void> _edit([JsonRow? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EntityDialog(
        repository: widget.repository,
        table: widget.table,
        row: row,
      ),
    );
    if (saved == true && mounted) setState(_load);
  }

  Future<void> _archive(JsonRow row) async {
    final active = row['active'] != true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(active ? 'Reactivar registro' : 'Archivar registro'),
        content: const Text('Se conservará todo el historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.repository.save(widget.table, {
        'active': active,
      }, id: row['id']);
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) reportProblem(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          clients ? 'Clientes' : 'Servicios',
          clients
              ? 'Contactos e historial de tu lavandería.'
              : 'Tu catálogo de servicios y precios.',
          action: editable
              ? FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.add),
                  label: Text(clients ? 'Nuevo cliente' : 'Nuevo servicio'),
                )
              : null,
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar por nombre',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (v) => setState(() {
            _query = v;
            _page = 0;
            _load();
          }),
        ),
        const SizedBox(height: 16),
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
                            child: Text('No hay registros para mostrar.'),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            child: Icon(
                                              clients
                                                  ? Icons.person_outline
                                                  : Icons
                                                        .local_laundry_service_outlined,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r['name'] as String,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  clients
                                                      ? r['phone'] as String
                                                      : '${money(r['price_minor'] as int)} / ${unitLabel(r['unit'] as String)}',
                                                ),
                                                if (r['active'] != true)
                                                  const Text(
                                                    'Archivado',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (editable)
                                            IconButton(
                                              tooltip: 'Editar',
                                              onPressed: () => _edit(r),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                            ),
                                          if (editable)
                                            IconButton(
                                              tooltip: r['active'] == true
                                                  ? 'Archivar'
                                                  : 'Reactivar',
                                              onPressed: () => _archive(r),
                                              icon: Icon(
                                                r['active'] == true
                                                    ? Icons.archive_outlined
                                                    : Icons.unarchive_outlined,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (clients)
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => Scaffold(
                                                appBar: AppBar(
                                                  title: Text(
                                                    'Historial · ${r['name']}',
                                                  ),
                                                ),
                                                body: OrdersScreen(
                                                  repository: widget.repository,
                                                  clientId: r['id'],
                                                ),
                                              ),
                                            ),
                                          ),
                                          child: const Text(
                                            'Ver historial de pedidos',
                                          ),
                                        ),
                                    ],
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

class _EntityDialog extends StatefulWidget {
  final LaundryRepository repository;
  final String table;
  final JsonRow? row;
  const _EntityDialog({
    required this.repository,
    required this.table,
    this.row,
  });
  @override
  State<_EntityDialog> createState() => _EntityDialogState();
}

class _EntityDialogState extends State<_EntityDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController name, phone, email, notes, price;
  String unit = 'piece';
  bool _busy = false;
  String? _error;
  bool get clients => widget.table == 'clients';
  @override
  void initState() {
    super.initState();
    final r = widget.row ?? {};
    name = TextEditingController(text: r['name']);
    phone = TextEditingController(text: r['phone']);
    email = TextEditingController(text: r['email']);
    notes = TextEditingController(text: r['notes']);
    price = TextEditingController(
      text: r['price_minor'] == null ? '' : moneyInput(r['price_minor']),
    );
    unit = r['unit'] ?? 'piece';
  }

  @override
  void dispose() {
    for (final c in [name, phone, email, notes, price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.save(widget.table, {
        'name': name.text.trim(),
        if (clients) ...{
          'phone': phone.text.trim(),
          'email': email.text.trim(),
          'notes': notes.text.trim(),
        } else ...{
          'unit': unit,
          'price_minor': parseMoney(price.text),
        },
      }, id: widget.row?['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
        if (isAccessError(e)) reportProblem(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'Campo obligatorio' : null;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        '${widget.row == null ? 'Nuevo' : 'Editar'} ${clients ? 'cliente' : 'servicio'}',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: requiredText,
                ),
                const SizedBox(height: 16),
                if (clients) ...[
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                    validator: requiredText,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Correo (opcional)',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v != null &&
                            v.isNotEmpty &&
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                        ? 'Correo inválido'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                    maxLines: 2,
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: const [
                      DropdownMenuItem(value: 'piece', child: Text('Pieza')),
                      DropdownMenuItem(
                        value: 'kilogram',
                        child: Text('Kilogramo'),
                      ),
                    ],
                    onChanged: (v) => unit = v!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: price,
                    decoration: const InputDecoration(
                      labelText: 'Precio (COP)',
                      helperText: 'Sin separadores de miles',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      try {
                        if (parseMoney(v ?? '') > 1000000000000) {
                          return 'Precio fuera de rango';
                        }
                        return null;
                      } on FormatException catch (e) {
                        return e.message;
                      }
                    },
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
