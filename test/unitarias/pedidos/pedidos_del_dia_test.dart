// test/unitarias/pedidos/pedidos_del_dia_test.dart — «Pedidos del día»
// (#137) sin red y con reloj fijo: el modelo, las secciones, la vista de hoy
// en la hora de México, las acciones de cada estado y lo que se manda al
// backend.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/gestion_pedidos_repository_remote.dart';
import 'package:pier_reposteria/domain/models/pedido_del_dia.dart';
import 'package:pier_reposteria/ui/pedidos_personal/view_model/pedidos_del_dia_view_model.dart';

import '../../fakes/fake_api_client.dart';
import '../../fakes/pedidos_del_dia_json.dart';

(PedidosDelDiaViewModel, FakeApiClient) _armar() {
  final api = FakeApiClient()
    ..responder(pedidosAbiertos, abiertosJson)
    ..responder(ApiConstants.repartidores, repartidoresJson);
  return (
    PedidosDelDiaViewModel(
      repo: GestionPedidosRepositoryRemote(api: api),
      ahora: ahoraPedidos,
    ),
    api,
  );
}

PedidoDelDia _pedido(Map<String, dynamic> json) =>
    PedidoDelDia.fromJson(json)!;

void main() {
  group('PedidoDelDia', () {
    test('lee cliente, productos, dirección y repartidor', () {
      final p = _pedido(pedidoJson(
          id: 5, estado: 'asignado', domicilio: true, entregaId: 9,
          repartidor: 'Luis'));
      expect(p.numero, 'PIER-5');
      expect(p.cliente, 'Ana Ruiz');
      expect(p.telefono, '7711234567');
      expect(p.total, 350);
      expect(p.productos, ['1 × Pastel de chocolate (grande)']);
      expect(p.direccion, 'Juárez 10, Centro');
      expect(p.repartidor, 'Luis P.');
      expect(p.entregaId, '9');
      expect(PedidoDelDia.fromJson({'numero': 'sin id'}), isNull);
      expect(PedidoDelDia.fromJson('basura'), isNull);
    });

    test('cada estado va a su sección', () {
      GrupoPedido grupo(Map<String, dynamic> j) => _pedido(j).grupo;
      expect(grupo(pedidoJson(id: 1, porConfirmar: true)),
          GrupoPedido.porConfirmar);
      expect(grupo(pedidoJson(id: 1)), GrupoPedido.pendientes);
      expect(grupo(pedidoJson(id: 1, estado: 'en_preparacion')),
          GrupoPedido.pendientes);
      expect(grupo(pedidoJson(id: 1, estado: 'listo')),
          GrupoPedido.listosRecoger);
      expect(grupo(pedidoJson(id: 1, estado: 'listo', domicilio: true)),
          GrupoPedido.listosEnvio);
      expect(grupo(pedidoJson(id: 1, estado: 'en_camino', domicilio: true)),
          GrupoPedido.enReparto);
      expect(grupo(pedidoJson(id: 1, estado: 'entrega_fallida')),
          GrupoPedido.fallidos);
    });

    test('el día comprometido es el de México', () {
      // 03:00 UTC del 13 = 21:00 del 12 en México.
      final p = _pedido(
          pedidoJson(id: 1, compromiso: '2026-10-13T03:00:00.000Z'));
      expect(p.diaComprometido, DateTime.utc(2026, 10, 12));
      expect(_pedido(pedidoJson(id: 1, compromiso: null)).diaComprometido,
          isNull);
    });

    test('repartidores: nombre, disponibilidad y entregas activas', () {
      final r = RepartidorDisponible.fromJson(
          (repartidoresJson['repartidores'] as List).first)!;
      expect(r.id, 21);
      expect(r.nombre, 'Luis Pérez');
      expect(r.disponible, isTrue);
      expect(r.entregasActivas, 2);
      expect(RepartidorDisponible.fromJson({'nombre': 'x'}), isNull);
    });
  });

  group('PedidosDelDiaViewModel: lista', () {
    test('agrupa los de hoy y los vencidos, en el orden de la web',
        () async {
      final (vm, _) = _armar();
      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect([
        for (final (g, ps) in vm.grupos) (g, ps.map((p) => p.id).toList()),
      ], [
        (GrupoPedido.porConfirmar, ['2']),
        (GrupoPedido.pendientes, ['1', '8']),
        (GrupoPedido.listosRecoger, ['3']),
        (GrupoPedido.listosEnvio, ['4']),
        (GrupoPedido.enReparto, ['5']),
        (GrupoPedido.fallidos, ['6']),
      ]);
      expect(vm.deOtrosDias, 1);

      vm.verSoloHoy(valor: false);
      expect(vm.grupos[1].$2.map((p) => p.id), ['1', '7', '8']);
      expect(vm.deOtrosDias, 0);
    });

    test('dice cuándo: hoy, vencido u otro día', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      String? cuando(String id) => vm.cuando(
          vm.grupos.expand((g) => g.$2).firstWhere((p) => p.id == id));

      expect(cuando('1'), 'Hoy 14:00');
      expect(cuando('2'), 'Vencido · hoy 10:00');
      expect(cuando('3'), 'Vencido · 11 Oct 16:00');
      expect(cuando('8'), isNull);
      vm.verSoloHoy(valor: false);
      expect(cuando('7'), '14 Oct 12:00');
    });

    test('si no carga expone el motivo y al reintentar se recupera',
        () async {
      final (vm, api) = _armar();
      api.fallar(pedidosAbiertos, 'Sin conexión');
      await vm.cargar();
      expect(vm.error, 'Sin conexión');
      expect(vm.grupos, isEmpty);

      api.responder(pedidosAbiertos, abiertosJson);
      await vm.cargar();
      expect(vm.error, isNull);
      expect(vm.grupos, isNotEmpty);
    });

    test('las acciones de cada estado, como la web', () async {
      final (vm, _) = _armar();
      await vm.cargar();
      List<AccionPedido> de(String id) => vm.acciones(
          vm.grupos.expand((g) => g.$2).firstWhere((p) => p.id == id));

      expect(de('2'), [AccionPedido.aprobar, AccionPedido.rechazar]);
      expect(de('1'), [AccionPedido.marcarListo, AccionPedido.cancelar]);
      expect(de('3'), [AccionPedido.entregar, AccionPedido.cancelar]);
      expect(de('4'), [
        AccionPedido.asignar,
        AccionPedido.avisarDemora,
        AccionPedido.cancelar,
      ]);
      expect(de('5'), [AccionPedido.cancelar]);
      expect(de('6'), [AccionPedido.volverAEnviar, AccionPedido.cancelar]);
    });
  });

  group('PedidosDelDiaViewModel: acciones', () {
    late PedidosDelDiaViewModel vm;
    late FakeApiClient api;
    PedidoDelDia pedido(String id) =>
        vm.grupos.expand((g) => g.$2).firstWhere((p) => p.id == id);

    setUp(() async {
      (vm, api) = _armar();
      await vm.cargar();
    });

    int cargas() =>
        api.llamadas.where((l) => l.endpoint == pedidosAbiertos).length;

    test('marcar listo, entregar y volver a enviar cambian el estado',
        () async {
      api
        ..responder(ApiConstants.pedidoEstado('1'), {
          'success': true,
          'message': 'Estado actualizado',
        })
        ..responder(ApiConstants.pedidoEstado('3'), {'success': true})
        ..responder(ApiConstants.pedidoEstado('6'), {'success': true});
      final antes = cargas();

      final r = await vm.marcarListo(pedido('1'));
      expect(r, (mensaje: 'Estado actualizado', ok: true));
      expect(api.ultima(ApiConstants.pedidoEstado('1'))!.body,
          {'estado': 'listo'});
      expect(cargas(), antes + 1);

      expect((await vm.entregar(pedido('3'))).mensaje, 'Pedido actualizado');
      expect(api.ultima(ApiConstants.pedidoEstado('3'))!.body,
          {'estado': 'completado'});
      await vm.volverAEnviar(pedido('6'));
      expect(api.ultima(ApiConstants.pedidoEstado('6'))!.body,
          {'estado': 'listo'});
    });

    test('cancelar manda el motivo; aprobar y rechazar', () async {
      api
        ..responder(ApiConstants.pedidoEstado('1'), {'success': true})
        ..responder(ApiConstants.pedidoAprobar('2'), {
          'success': true,
          'message': 'Pedido PIER-2 aprobado; el cliente ya fue notificado',
        })
        ..responder(ApiConstants.pedidoRechazar('2'), {'success': true});

      await vm.cancelar(pedido('1'), '  Cliente no vino  ');
      expect(api.ultima(ApiConstants.pedidoEstado('1'))!.body, {
        'estado': 'cancelado',
        'nota_cancelacion': 'Cliente no vino',
      });
      expect((await vm.aprobar(pedido('2'))).mensaje,
          'Pedido PIER-2 aprobado; el cliente ya fue notificado');
      await vm.rechazar(pedido('2'), 'Sin harina hoy');
      expect(api.ultima(ApiConstants.pedidoRechazar('2'))!.body,
          {'motivo': 'Sin harina hoy'});
    });

    test('asignar repartidor y avisar demora (sin recargar)', () async {
      api
        ..responder(ApiConstants.asignarEntrega, {
          'success': true,
          'message': 'Pedido #4 asignado a Luis Pérez',
        })
        ..responder(ApiConstants.avisarDemora, {'success': true});

      final repartidores = await vm.repartidores();
      expect(repartidores.map((r) => r.id), [21, 22]);
      expect((await vm.asignar(pedido('4'), 21)).mensaje,
          'Pedido #4 asignado a Luis Pérez');
      expect(api.ultima(ApiConstants.asignarEntrega)!.body,
          {'pedido_id': 4, 'repartidor_id': 21});

      final antes = cargas();
      expect((await vm.avisarDemora(pedido('4'))).mensaje,
          'Aviso de demora enviado');
      expect(api.ultima(ApiConstants.avisarDemora)!.body, {'pedido_id': 4});
      expect(cargas(), antes);
    });

    test('si el backend lo rechaza devuelve su motivo y recarga', () async {
      api.fallar(ApiConstants.pedidoEstado('3'),
          'Este pedido ya se entregó y no se puede cancelar');
      final antes = cargas();

      final r = await vm.cancelar(pedido('3'), 'Ya no lo quiere');

      expect(r, (
        mensaje: 'Este pedido ya se entregó y no se puede cancelar',
        ok: false,
      ));
      expect(cargas(), antes + 1);
      expect(vm.ocupado(pedido('3')), isFalse);
    });

    test('no corre dos acciones a la vez sobre el mismo pedido', () async {
      api
        ..responder(ApiConstants.avisarDemora, {'success': true})
        ..demorar(ApiConstants.avisarDemora, const Duration(milliseconds: 5));
      final primera = vm.avisarDemora(pedido('4'));
      expect(vm.ocupado(pedido('4')), isTrue);

      final segunda = await vm.avisarDemora(pedido('4'));
      expect(segunda.ok, isFalse);
      await primera;
      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.avisarDemora),
          hasLength(1));
    });

    test('el motivo va de 5 a 300 caracteres', () {
      expect(PedidosDelDiaViewModel.validarMotivo(' abc '),
          'Escribe el motivo (mínimo 5 caracteres).');
      expect(PedidosDelDiaViewModel.validarMotivo('x' * 301),
          'Máximo 300 caracteres (llevas 301).');
      expect(PedidosDelDiaViewModel.validarMotivo('No vino'), isNull);
    });
  });
}
