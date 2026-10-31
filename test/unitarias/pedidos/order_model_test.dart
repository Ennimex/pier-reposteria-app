// test/unitarias/pedidos/order_model_test.dart — las reglas del pedido que la
// app copia del backend (#63): cuándo el cliente todavía puede cancelarlo
// (#40, PUT /pedidos/:id/cancelar) y cuándo pasa al historial (#39), con los
// estados tal como los manda GET /pedidos/mis-pedidos.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';

/// Un pedido del backend con el estado dado.
Order _pedido(String estado) => Order.fromJson({
      'id': 1,
      'numero': 'PIER-261031-0001',
      'total': '150.00',
      'estado': estado,
      'created_at': '2026-10-31T12:00:00.000Z',
      'items': <Map<String, dynamic>>[],
    });

void main() {
  group('esCancelablePorCliente (#40)', () {
    // El backend solo deja que el cliente cancele un pedido «pendiente» o
    // «listo»: en cuanto lo toma el repartidor («asignado») ya no.
    for (final estado in ['pendiente', 'listo']) {
      test('«$estado» se puede cancelar', () {
        expect(_pedido(estado).esCancelablePorCliente, isTrue);
      });
    }
    for (final estado in [
      'en_preparacion',
      'completado',
      'cancelado',
      'asignado',
      'en_camino',
      'entregado',
      'entrega_fallida',
    ]) {
      test('«$estado» ya no se puede cancelar', () {
        expect(_pedido(estado).esCancelablePorCliente, isFalse);
      });
    }
  });

  group('esFinalizado (#39)', () {
    test('completado, cancelado, entregado y entrega fallida van al historial',
        () {
      for (final estado in [
        'completado',
        'cancelado',
        'entregado',
        'entrega_fallida',
      ]) {
        expect(_pedido(estado).esFinalizado, isTrue, reason: estado);
      }
    });

    test('los demás siguen en «Activos»', () {
      for (final estado in [
        'pendiente',
        'en_preparacion',
        'listo',
        'asignado',
        'en_camino',
      ]) {
        expect(_pedido(estado).esFinalizado, isFalse, reason: estado);
      }
    });
  });
}
