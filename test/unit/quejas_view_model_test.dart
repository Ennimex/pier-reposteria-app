// test/unit/quejas_view_model_test.dart — «Mis Quejas» (MVVM, Fase 3) sin
// red: el repositorio tipa la lista y el envío, y el ViewModel lleva la
// lista, la tarjeta abierta, los pedidos y el formulario.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/quejas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/queja.dart';
import 'package:pier_pasteleria/ui/more/view_model/quejas_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _mis = ApiConstants.misQuejas;
const String _crear = ApiConstants.crearQueja;
const String _pedidos = ApiConstants.misPedidos;

final Map<String, dynamic> _conDatos = {
  _mis: {
    'success': true,
    'quejas': [
      {
        'id': 7,
        'ticket': 'QJ-0007',
        'pedido_id': 9,
        'tipo': 'sugerencia',
        'categoria': 'servicio',
        'asunto': 'Más horarios',
        'descripcion': 'Abran los domingos',
        'estado': 'en_proceso',
        'respuesta': 'Lo estamos evaluando',
        'created_at': '2026-10-02T15:00:00Z',
      },
      {'id': 8, 'tipo': 'felicitacion', 'categoria': 'otro', 'respuesta': ''},
      'basura',
    ],
  },
  _pedidos: {
    'success': true,
    'pedidos': [
      {'id': 9, 'numero': 'PIER-9', 'estado': 'entregado', 'total': '640'},
    ],
  },
  _crear: {
    'success': true,
    'queja': {'id': 10, 'ticket': 'QJ-0010'},
  },
};

QuejasViewModel _vm(FakeApiClient api) => QuejasViewModel(
      quejasRepo: QuejasRepositoryRemote(api: api),
      pedidosRepo: PedidosRepositoryRemote(api: api),
    );

void main() {
  group('Queja y repositorio', () {
    test('listarMisQuejas tipa, tolera faltantes e ignora basura', () async {
      final api = FakeApiClient(respuestas: _conDatos);

      final lista = await QuejasRepositoryRemote(api: api).listarMisQuejas();

      expect(lista, hasLength(2));
      final q = lista.first;
      expect(q.id, '7');
      expect(q.ticket, 'QJ-0007');
      expect(q.estado, EstadoQueja.enProceso);
      expect(q.tipoTexto, 'Sugerencia');
      expect(q.categoriaTexto, 'Servicio');
      expect(q.pedidoId, '9');
      expect(q.respuesta, 'Lo estamos evaluando');
      expect(q.creadaEn, isNotNull);
      // Tipo desconocido se muestra crudo; sin estado = pendiente; respuesta
      // vacía y sin pedido = null.
      expect(lista[1].tipoTexto, 'felicitacion');
      expect(lista[1].estado, EstadoQueja.pendiente);
      expect(lista[1].respuesta, isNull);
      expect(lista[1].pedidoId, isNull);
      expect(api.llamo(_mis, metodo: 'GET-Auth'), isTrue);
    });

    test('listarMisQuejas lanza ApiException si falla', () async {
      final api = FakeApiClient()..fallar(_mis, 'Token expirado');

      expect(() => QuejasRepositoryRemote(api: api).listarMisQuejas(),
          throwsA(isA<ApiException>()));
    });

    test('crearQueja manda los valores del backend y devuelve el ticket',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);

      final ticket = await QuejasRepositoryRemote(api: api).crearQueja(
        tipo: TipoQueja.comentario,
        categoria: CategoriaQueja.plataforma,
        asunto: 'App',
        descripcion: 'Muy buena',
        pedidoId: '9',
      );

      expect(ticket, 'QJ-0010');
      expect(api.ultima(_crear)?.body, {
        'tipo': 'comentario',
        'categoria': 'plataforma',
        'asunto': 'App',
        'descripcion': 'Muy buena',
        'pedido_id': 9,
      });
    });

    test('crearQueja sin pedido no manda pedido_id', () async {
      final api = FakeApiClient(respuestas: _conDatos);

      await QuejasRepositoryRemote(api: api).crearQueja(
        tipo: TipoQueja.queja,
        categoria: CategoriaQueja.producto,
        asunto: 'A',
        descripcion: 'B',
      );

      expect(api.ultima(_crear)?.body?.containsKey('pedido_id'), isFalse);
    });
  });

  group('QuejasViewModel', () {
    test('carga quejas y pedidos; el pedido se muestra por su número',
        () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      expect(vm.cargando, isTrue);

      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.quejas, hasLength(2));
      expect(vm.numeroDePedido('9'), 'PIER-9');
      expect(vm.numeroDePedido('99'), '99');
    });

    test('alternar abre una tarjeta y la cierra al repetir', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      await vm.cargar();

      vm.alternar('7');
      expect(vm.expandidaId, '7');
      vm.alternar('8');
      expect(vm.expandidaId, '8');
      vm.alternar('8');
      expect(vm.expandidaId, isNull);
    });

    test('nuevaQueja deja el formulario como nuevo', () {
      final vm = _vm(FakeApiClient(respuestas: _conDatos))
        ..seleccionarTipo(TipoQueja.sugerencia)
        ..seleccionarCategoria(CategoriaQueja.otro)
        ..seleccionarPedido('9')
        ..nuevaQueja();

      expect(vm.tipo, TipoQueja.queja);
      expect(vm.categoria, CategoriaQueja.producto);
      expect(vm.pedidoId, isNull);
    });

    test('sin asunto o descripción no envía', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);

      final r = await vm.enviar(asunto: '  ', descripcion: 'Algo');

      expect(r.error, 'Completa todos los campos obligatorios');
      expect(r.ticket, isNull);
      expect(api.llamo(_crear), isFalse);
    });

    test('envía lo elegido, devuelve el ticket y recarga la lista', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();
      vm
        ..seleccionarTipo(TipoQueja.sugerencia)
        ..seleccionarCategoria(CategoriaQueja.servicio)
        ..seleccionarPedido('9');
      final antes = api.llamadas.where((l) => l.endpoint == _mis).length;

      final r = await vm.enviar(asunto: ' Horarios ', descripcion: ' Domingo ');
      await Future<void>.delayed(Duration.zero);

      expect(r.ticket, 'QJ-0010');
      expect(r.error, isNull);
      expect(vm.enviando, isFalse);
      expect(api.ultima(_crear)?.body, {
        'tipo': 'sugerencia',
        'categoria': 'servicio',
        'asunto': 'Horarios',
        'descripcion': 'Domingo',
        'pedido_id': 9,
      });
      expect(api.llamadas.where((l) => l.endpoint == _mis).length, antes + 1);
    });

    test('si el backend rechaza devuelve su mensaje', () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_crear, 'Tipo, categoría, asunto y descripción son requeridos');
      final vm = _vm(api);

      final r = await vm.enviar(asunto: 'A', descripcion: 'B');

      expect(r.error, 'Tipo, categoría, asunto y descripción son requeridos');
      expect(r.ticket, isNull);
      expect(vm.enviando, isFalse);
    });

    test('si falla la recarga se queda la lista anterior', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();

      api.fallar(_mis, 'Caído');
      await vm.cargar();

      expect(vm.quejas, hasLength(2));
      expect(vm.cargando, isFalse);
    });
  });
}
