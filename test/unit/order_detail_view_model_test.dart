// test/unit/order_detail_view_model_test.dart — detalle de un pedido (MVVM,
// Fase 5) sin red: arranca con el pedido de la lista, lo refresca, arma la
// línea de tiempo y cancela (incluido el backend que falla después de
// cancelar).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/order_model.dart';
import 'package:pier_pasteleria/ui/orders/view_model/order_detail_view_model.dart';

import '../fakes/fake_api_client.dart';

final String _detalle = ApiConstants.pedidoById('7');
final String _cancelar = ApiConstants.pedidoCancelar('7');

Order _pedido({
  OrderStatus estado = OrderStatus.ready,
  String? tipoEntrega,
  bool porConfirmar = false,
}) =>
    Order(
      id: '7',
      numero: 'PIER-261010-0007',
      items: const [],
      total: 300,
      tipoEntrega: tipoEntrega,
      status: estado,
      porConfirmar: porConfirmar,
      createdAt: DateTime(2026, 10, 10, 9, 5),
    );

Map<String, dynamic> _respuestaDetalle(String estado) => {
      'success': true,
      'pedido': {'id': 7, 'numero': 'PIER-261010-0007', 'estado': estado},
      'items': [
        {'nombre_producto': 'Chocoflan', 'cantidad': 2, 'subtotal': 300},
      ],
    };

(OrderDetailViewModel, FakeApiClient) _armar({
  Order? pedido,
  Map<String, dynamic>? respuestas,
  ValueChanged<Order>? alCambiarEstado,
}) {
  final api = FakeApiClient(respuestas: respuestas);
  final vm = OrderDetailViewModel(
    repo: PedidosRepositoryRemote(api: api),
    pedido: pedido ?? _pedido(),
    alCambiarEstado: alCambiarEstado,
  );
  return (vm, api);
}

void main() {
  group('OrderDetailViewModel: actualizar', () {
    test('trae el pedido fresco con sus productos', () async {
      final (vm, _) = _armar(respuestas: {_detalle: _respuestaDetalle('asignado')});
      expect(vm.pedido.items, isEmpty);

      await vm.actualizar();

      expect(vm.actualizando, isFalse);
      expect(vm.pedido.status, OrderStatus.assigned);
      expect(vm.pedido.items.single.nombre, 'Chocoflan');
    });

    test('si falla se queda el pedido que tenía', () async {
      final (vm, _) = _armar(respuestas: {
        _detalle: {'success': false, 'message': 'Sin conexión'},
      });

      await vm.actualizar();

      expect(vm.pedido.status, OrderStatus.ready);
      expect(vm.actualizando, isFalse);
    });

    test('no lanza otra lectura mientras una sigue en curso', () async {
      final (vm, api) = _armar(respuestas: {_detalle: _respuestaDetalle('listo')});
      api.demorar(_detalle, const Duration(milliseconds: 20));

      final primera = vm.actualizar();
      expect(vm.actualizando, isTrue);
      await vm.actualizar();
      await primera;

      expect(api.llamadas.where((l) => l.endpoint == _detalle), hasLength(1));
    });

    test('cerrada a media lectura no cambia, pero avisa a quien la abrió',
        () async {
      final avisos = <Order>[];
      final (vm, api) = _armar(
        respuestas: {_detalle: _respuestaDetalle('asignado')},
        alCambiarEstado: avisos.add,
      );
      api.demorar(_detalle, const Duration(milliseconds: 20));

      final lectura = vm.actualizar();
      vm.dispose();
      await lectura;

      expect(vm.pedido.status, OrderStatus.ready);
      expect(avisos.single.status, OrderStatus.assigned);
    });

    test('solo avisa a quien lo abrió si el estado cambió', () async {
      final avisos = <Order>[];
      final (vm, api) = _armar(
        respuestas: {_detalle: _respuestaDetalle('listo')},
        alCambiarEstado: avisos.add,
      );

      await vm.actualizar(); // sigue «listo»
      expect(avisos, isEmpty);

      api.responder(_detalle, _respuestaDetalle('cancelado'));
      await vm.actualizar();
      expect(avisos.single.status, OrderStatus.cancelled);
    });
  });

  group('OrderDetailViewModel: cancelar', () {
    test('cancelado con éxito: mensaje del backend y estado fresco', () async {
      final (vm, api) = _armar(respuestas: {
        _cancelar: {'success': true, 'message': 'Pedido cancelado'},
        _detalle: _respuestaDetalle('cancelado'),
      });

      final resultado = await vm.cancelar();

      expect(resultado.cancelado, isTrue);
      expect(resultado.mensaje, 'Pedido cancelado');
      expect(vm.pedido.status, OrderStatus.cancelled);
      expect(vm.cancelando, isFalse);
      expect(api.llamo(_cancelar, metodo: 'PUT-Auth'), isTrue);
    });

    test('rechazado: devuelve el motivo y el pedido sigue igual', () async {
      final (vm, _) = _armar(respuestas: {
        _cancelar: {
          'success': false,
          'message': 'Un repartidor ya tomó tu pedido; ya no es posible cancelarlo',
        },
        _detalle: _respuestaDetalle('asignado'),
      });

      final resultado = await vm.cancelar();

      expect(resultado.cancelado, isFalse);
      expect(resultado.mensaje, contains('Un repartidor ya tomó tu pedido'));
      expect(vm.pedido.status, OrderStatus.assigned);
    });

    test('si el backend falla tras cancelar, lo da por cancelado', () async {
      final (vm, _) = _armar(respuestas: {
        _cancelar: {'success': false, 'message': 'Error al cancelar el pedido'},
        _detalle: _respuestaDetalle('cancelado'),
      });

      final resultado = await vm.cancelar();

      expect(resultado.cancelado, isTrue);
      expect(resultado.mensaje, OrderDetailViewModel.mensajeCancelado);
    });
  });

  group('OrderDetailViewModel: línea de tiempo y textos', () {
    test('pickup: Recibido, Listo y Entregado; va en Listo', () {
      final (vm, _) = _armar();

      expect(vm.pasos.map((p) => p.etiqueta),
          ['Recibido', 'Listo', 'Entregado']);
      expect(vm.pasoActual, 1);
      expect(vm.mensajeEstado, 'Tu pedido está listo. Pasa a recogerlo');
      expect(vm.vaEnCamino, isFalse);
    });

    test('pickup por confirmar: el primer paso lo dice', () {
      final (vm, _) = _armar(
          pedido: _pedido(estado: OrderStatus.pending, porConfirmar: true));

      expect(vm.pasos.first.etiqueta, 'Por confirmar');
      expect(vm.pasoActual, 0);
      expect(vm.mensajeEstado, contains('estamos confirmando'));
    });

    test('domicilio en camino: cuatro pasos y la animación', () {
      final (vm, _) = _armar(
          pedido: _pedido(
              estado: OrderStatus.onTheWay, tipoEntrega: 'domicilio'));

      expect(vm.pasos.map((p) => p.etiqueta),
          ['Listo', 'Asignado', 'En camino', 'Entregado']);
      expect(vm.pasoActual, 2);
      expect(vm.vaEnCamino, isTrue);
    });

    test('un pedido viejo «en preparación» se ubica tras Recibido', () {
      final (vm, _) =
          _armar(pedido: _pedido(estado: OrderStatus.preparing));

      expect(vm.pasoActual, 0);
      expect(vm.mensajeEstado, contains('preparando'));
    });

    test('cancelado o con entrega fallida termina mal', () {
      for (final estado in [
        OrderStatus.cancelled,
        OrderStatus.deliveryFailed,
      ]) {
        final (vm, _) = _armar(pedido: _pedido(estado: estado));
        expect(vm.terminoMal, isTrue, reason: estado.name);
      }
      expect(_armar().$1.terminoMal, isFalse);
    });

    test('cada estado tiene su mensaje', () {
      final mensajes = {
        for (final estado in OrderStatus.values)
          estado: _armar(pedido: _pedido(estado: estado)).$1.mensajeEstado,
      };

      expect(mensajes.values.every((m) => m.isNotEmpty), isTrue);
      expect(mensajes[OrderStatus.completed], mensajes[OrderStatus.delivered]);
      expect(mensajes[OrderStatus.cancelled], 'Este pedido fue cancelado');
      expect(mensajes[OrderStatus.assigned], contains('repartidor'));
      expect(mensajes[OrderStatus.onTheWay], contains('en camino'));
      expect(mensajes[OrderStatus.deliveryFailed], contains('No pudimos'));
      expect(
        _armar(pedido: _pedido(tipoEntrega: 'domicilio')).$1.mensajeEstado,
        contains('repartidor'),
      );
      expect(
        _armar(pedido: _pedido(estado: OrderStatus.pending)).$1.mensajeEstado,
        'Tu pedido fue recibido y está en cola',
      );
    });
  });
}
