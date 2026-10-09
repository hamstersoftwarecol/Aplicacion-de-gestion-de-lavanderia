enum OrderStatus { received, processing, ready, delivered, cancelled }

const statusLabels = {
  'received': 'Recibido',
  'processing': 'En proceso',
  'ready': 'Listo',
  'delivered': 'Entregado',
  'cancelled': 'Cancelado',
};
bool canTransition(
  OrderStatus from,
  OrderStatus to, {
  required int balanceMinor,
  required bool hasPayments,
}) =>
    (from == OrderStatus.received && to == OrderStatus.processing) ||
    (from == OrderStatus.processing && to == OrderStatus.ready) ||
    (from == OrderStatus.ready &&
        to == OrderStatus.delivered &&
        balanceMinor == 0) ||
    ((from == OrderStatus.received || from == OrderStatus.processing) &&
        to == OrderStatus.cancelled &&
        !hasPayments);
