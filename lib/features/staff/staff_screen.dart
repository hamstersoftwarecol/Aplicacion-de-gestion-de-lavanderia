import 'package:flutter/material.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';

class StaffScreen extends StatefulWidget {
  final LaundryRepository repository;
  const StaffScreen({super.key, required this.repository});
  @override
  State<StaffScreen> createState() => _StaffState();
}

class _StaffState extends State<StaffScreen> {
  late Future<List<JsonRow>> _data;
  int _page = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = widget.repository.list('profiles', page: _page);
  }

  Future<void> _change(JsonRow r, String role, bool active) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cambiar acceso'),
        content: Text(
          '${r['name']}: ${role == 'admin' ? 'administrador' : 'empleado'}, ${active ? 'activo' : 'desactivado'}.',
        ),
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
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.setProfileAccess(r['id'], role, active);
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) reportProblem(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          'Personal',
          'Gestiona roles y acceso de las cuentas existentes.',
        ),
        const Text(
          'Las nuevas cuentas se invitan desde la consola de Supabase.',
        ),
        const SizedBox(height: 16),
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
                    child: ListView(
                      children: [
                        for (final r in s.data!)
                          Card(
                            child: ListTile(
                              title: Text(r['name']),
                              subtitle: Text(
                                '${r['role'] == 'admin' ? 'Administrador' : 'Empleado'} · ${r['active'] == true ? 'Activo' : 'Desactivado'}',
                              ),
                              trailing: PopupMenuButton<String>(
                                enabled: !_busy,
                                onSelected: (v) => _change(
                                  r,
                                  v == 'role'
                                      ? (r['role'] == 'admin'
                                            ? 'employee'
                                            : 'admin')
                                      : r['role'],
                                  v == 'active'
                                      ? r['active'] != true
                                      : r['active'],
                                ),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'role',
                                    child: Text('Cambiar rol'),
                                  ),
                                  PopupMenuItem(
                                    value: 'active',
                                    child: Text(
                                      r['active'] == true
                                          ? 'Desactivar'
                                          : 'Activar',
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
  );
}
