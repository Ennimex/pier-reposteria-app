// test/unit/refunds_view_model_test.dart — «Reembolsos» (MVVM, Fase 3) sin
// red: el repositorio tipa el historial y el envío, y el ViewModel lleva el
// historial, los pedidos reembolsables y el formulario.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/reembolsos_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/reembolso.dart';
import 'package:pier_pasteleria/ui/refunds/view_model/refunds_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _mis = ApiConstants.misReembolsos;
const String _crear = ApiConstants.crearReembolso;
const String _pedidos = ApiConstants.misPedidos;

final Map<String, dynamic> _conDatos = {
  _mis: {
    'success': true,
    'reembolsos': [
      {
        'id': 3,
        'pedido_id': 9,
        'pedido_numero': 'PIER-9',
        'monto': '640.00',
        'motivo': 'Producto dañado',
        'estado': 'en_revision',
        'respuesta_admin': 'Lo estamos revisando',
        'created_at': '2026-10-01T18:00:00Z',
      },
      {'id': 4, 'pedido_id': 12, 'estado': 'raro', 'respuesta_admin': ''},
      'basura',
    ],
  },
  _pedidos: {
    'success': true,
    'pedidos': [
      {'id': 9, 'numero': 'PIER-9', 'estado': 'completado', 'total': '640'},
      {'id': 10, 'numero': 'PIER-10', 'estado': 'entregado', 'total': '300'},
      {'id': 11, 'numero': 'PIER-11', 'estado': 'completado', 'total': '150'},
    ],
  },
  _crear: {'success': true, 'reembolso': {'id': 5}},
};

RefundsViewModel _vm(FakeApiClient api) => RefundsViewModel(
      reembolsosRepo: ReembolsosRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
    );

void main() {
  group('Reembolso y repositorio', () {
    test('listarMisReembolsos tipa, tolera faltantes e ignora basura',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);

      final lista = await ReembolsosRepositoryRemote(api: api).listarMisReembolsos();

      expect(lista, hasLength(2));
      final r = lista.first;
      expect(r.pedidoNumero, 'PIER-9');
      expect(r.monto, 640);
      expect(r.estado, EstadoReembolso.enRevision);
      expect(r.respuestaAdmin, 'Lo estamos revisando');
      expect(r.creadoEn, isNotNull);
      // Sin número usa el id del pedido; estado desconocido = pendiente;
      // respuesta vacía = sin respuesta.
      expect(lista[1].pedidoNumero, '12');
      expect(lista[1].estado, EstadoReembolso.pendiente);
      expect(lista[1].respuestaAdmin, isNull);
      expect(lista[1].motivo, isNull);
      expect(api.llamo(_mis, metodo: 'GET-Auth'), isTrue);
    });

    test('listarMisReembolsos lanza ApiException si falla', () async {
      final api = FakeApiClient()..fallar(_mis, 'Token expirado');

      expect(() => ReembolsosRepositoryRemote(api: api).listarMisReembolsos(),
          throwsA(isA<ApiException>()));
    });

    test('solicitar manda el id numérico y lanza el mensaje del backend',
        () async {
      final api = FakeApiClient()
        ..fallar(_crear, 'Solo se pueden reembolsar pedidos completados');
      final repo = ReembolsosRepositoryRemote(api: api);

      await expectLater(
        repo.solicitar(
          pedidoId: '9',
          monto: 640,
          motivo: 'Otro',
          descripcion: 'Llegó aplastado',
        ),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Solo se pueden reembolsar pedidos completados')),
      );
      expect(api.ultima(_crear)?.body, {
        'pedido_id': 9,
        'monto': 640.0,
        'motivo': 'Otro',
        'descripcion': 'Llegó aplastado',
      });
    });
  });

  group('RefundsViewModel', () {
    test('carga el historial y solo los pedidos completados', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      expect(vm.cargandoReembolsos, isTrue);

      await vm.cargar();

      expect(vm.cargandoReembolsos, isFalse);
      expect(vm.reembolsos, hasLength(2));
      expect(vm.pedidos.map((p) => p.numero), ['PIER-9', 'PIER-11']);
    });

    test('sin elegir, el pedido seleccionado es el primero', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      await vm.cargar();

      expect(vm.pedidoSeleccionado?.numero, 'PIER-9');

      vm.seleccionarPedido(vm.pedidos[1]);
      expect(vm.pedidoSeleccionado?.numero, 'PIER-11');
    });

    test('sin pedidos completados no hay seleccionado y no envía', () async {
      final api = FakeApiClient(respuestas: {
        ..._conDatos,
        _pedidos: {'success': true, 'pedidos': <Object>[]},
      });
      final vm = _vm(api);
      await vm.cargar();
      vm.seleccionarMotivo('Otro');

      expect(vm.pedidoSeleccionado, isNull);
      expect(await vm.enviar(descripcion: 'Llegó aplastado'),
          'Selecciona un pedido');
      expect(api.llamo(_crear), isFalse);
    });

    test('envía por el total del pedido, limpia y recarga el historial',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarPedido(vm.pedidos[1])
        ..seleccionarMotivo('Pedido incompleto');
      final antes = api.llamadas.where((l) => l.endpoint == _mis).length;

      final error = await vm.enviar(descripcion: '  Faltó un pay  ');
      await Future<void>.delayed(Duration.zero);

      expect(error, isNull);
      expect(api.ultima(_crear)?.body, {
        'pedido_id': 11,
        'monto': 150.0,
        'motivo': 'Pedido incompleto',
        'descripcion': 'Faltó un pay',
      });
      expect(vm.enviando, isFalse);
      expect(vm.motivo, isNull);
      expect(vm.pedidoSeleccionado?.numero, 'PIER-9'); // vuelve al primero
      expect(api.llamadas.where((l) => l.endpoint == _mis).length, antes + 1);
    });

    test('si el backend rechaza devuelve su mensaje y conserva el formulario',
        () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_crear, 'Pedido no encontrado');
      final vm = _vm(api);
      await vm.cargar();
      vm.seleccionarMotivo('Otro');

      final error = await vm.enviar(descripcion: 'Llegó aplastado');

      expect(error, 'Pedido no encontrado');
      expect(vm.enviando, isFalse);
      expect(vm.motivo, 'Otro');
    });

    test('si falla la recarga se queda el historial anterior', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();

      api.fallar(_mis, 'Caído');
      await vm.cargarReembolsos();

      expect(vm.reembolsos, hasLength(2));
      expect(vm.cargandoReembolsos, isFalse);
    });
  });
}
