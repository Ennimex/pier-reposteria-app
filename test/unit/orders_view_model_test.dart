// test/unit/orders_view_model_test.dart — «Mis Pedidos» (MVVM, Fase 3) sin
// red: el repositorio tipa /pedidos/mis-pedidos y el ViewModel separa activos
// de finalizados.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/ui/orders/view_model/orders_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _endpoint = ApiConstants.misPedidos;

FakeApiClient _backendCon(List<Object> pedidos, {String clave = 'pedidos'}) =>
    FakeApiClient(
      respuestas: {
        _endpoint: {'success': true, clave: pedidos},
      },
    );

final List<Object> _tres = [
  {'id': 1, 'numero': 'PIER-1', 'estado': 'pendiente', 'total': '150'},
  {'id': 2, 'numero': 'PIER-2', 'estado': 'entregado', 'total': '90'},
  {'id': 3, 'numero': 'PIER-3', 'estado': 'cancelado', 'total': '40'},
];

OrdersViewModel _vm(FakeApiClient api) =>
    OrdersViewModel(repo: PedidosRepository(api: api));

void main() {
  group('PedidosRepository.listarMisPedidos', () {
    test('tipa los pedidos e ignora lo que no es objeto', () async {
      final api = _backendCon([..._tres, 'basura']);

      final lista = await PedidosRepository(api: api).listarMisPedidos();

      expect(lista.map((o) => o.numero), ['PIER-1', 'PIER-2', 'PIER-3']);
      expect(lista.first.total, 150);
      expect(api.llamo(_endpoint, metodo: 'GET-Auth'), isTrue);
    });

    test('acepta la lista en data', () async {
      final lista = await PedidosRepository(api: _backendCon(_tres, clave: 'data'))
          .listarMisPedidos();
      expect(lista, hasLength(3));
    });

    test('si el backend falla lanza ApiException', () async {
      final api = FakeApiClient()..fallar(_endpoint, 'Token expirado');
      await expectLater(
        PedidosRepository(api: api).listarMisPedidos(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('OrdersViewModel', () {
    test('arranca cargando y sin pedidos', () {
      final vm = _vm(FakeApiClient());
      expect(vm.cargando, isTrue);
      expect(vm.activos, isEmpty);
    });

    test('separa activos de finalizados', () async {
      final vm = _vm(_backendCon(_tres));
      await vm.cargar(conSesion: true);

      expect(vm.cargando, isFalse);
      expect(vm.activos.map((o) => o.numero), ['PIER-1']);
      expect(vm.finalizados.map((o) => o.numero), ['PIER-2', 'PIER-3']);
    });

    test('sin sesión limpia la lista y no llama al backend', () async {
      final api = _backendCon(_tres);
      final vm = _vm(api);
      await vm.cargar(conSesion: true);

      await vm.cargar(conSesion: false);

      expect(vm.activos, isEmpty);
      expect(vm.finalizados, isEmpty);
      expect(vm.cargando, isFalse);
      expect(api.llamadas, hasLength(1));
    });

    test('la recarga silenciosa no pasa por cargando', () async {
      final vm = _vm(_backendCon(_tres));
      await vm.cargar(conSesion: true);
      final estados = <bool>[];
      vm.addListener(() => estados.add(vm.cargando));

      await vm.cargar(conSesion: true, silenciosa: true);

      expect(estados, [false]);
    });

    test('si el backend falla conserva la última lista', () async {
      final api = _backendCon(_tres);
      final vm = _vm(api);
      await vm.cargar(conSesion: true);
      api.fallar(_endpoint, 'Sin conexión');

      await vm.cargar(conSesion: true);

      expect(vm.activos, hasLength(1));
      expect(vm.finalizados, hasLength(2));
      expect(vm.cargando, isFalse);
    });
  });
}
