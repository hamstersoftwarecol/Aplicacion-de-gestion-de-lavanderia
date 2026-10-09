import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/money.dart';
import '../../data/laundry_repository.dart';
import '../../widgets/common.dart';

class PaymentDialog extends StatefulWidget {
  final LaundryRepository repository;
  final String orderId;
  final int balance;
  const PaymentDialog({
    super.key,
    required this.repository,
    required this.orderId,
    required this.balance,
  });
  @override
  State<PaymentDialog> createState() => _PaymentState();
}

class _PaymentState extends State<PaymentDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(), _reference = TextEditingController();
  final _key = const Uuid().v4();
  String _method = 'cash';
  bool _busy = false, _locked = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_busy || !_form.currentState!.validate()) return;
    final amount = parseMoney(_amount.text);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar pago'),
        content: Text(
          'Registrar ${money(amount)}. Este pago no podrá editarse ni eliminarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar pago'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _locked = true;
      _error = null;
    });
    try {
      await widget.repository.pay(
        widget.orderId,
        amountMinor: amount,
        method: _method,
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        key: _key,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${errorText(e)}\nEl reintento conserva el mismo pago. Si cierras esta ventana, revisa el historial antes de registrar otro.',
        );
        reportProblem(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Registrar pago'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo pendiente: ${money(widget.balance)}'),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amount,
                  readOnly: _locked,
                  decoration: const InputDecoration(
                    labelText: 'Importe (COP)',
                    helperText: 'Sin separadores de miles',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    try {
                      final amount = parseMoney(v ?? '');
                      return amount > widget.balance
                          ? 'Supera el saldo pendiente'
                          : null;
                    } on FormatException catch (e) {
                      return e.message;
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Método'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                  ],
                  onChanged: _locked
                      ? null
                      : (v) => setState(() => _method = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reference,
                  readOnly: _locked,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                  ),
                ),
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
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _pay,
          child: Text(
            _busy
                ? 'Registrando…'
                : _locked
                ? 'Reintentar pago'
                : 'Revisar pago',
          ),
        ),
      ],
    ),
  );
}
