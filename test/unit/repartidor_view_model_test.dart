// test/unit/repartidor_view_model_test.dart — panel del repartidor (MVVM,
// Fase 5) sin red: carga entregas, disponibilidad y pool, separa en curso e
// historial, toma pedidos y cambia la disponibilidad con reversión.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/entrega_model.dart';
import 'package:pier_pasteleria/ui/repartidor/view_model/repartidor_view_model.dart';

import '../fakes/fake_api_client.dart';

Map<String, dynamic> _entrega(String id, String estado, {num total = 100}) => {
      'id': id,
      'estado': estado,
      'numero': 'PIER-$id',
      'total': total,
    };

final _pedido = PedidoDisponible.fromJson(const {
  'pedido_id': 41,
  'numero': 'PIER-41',
});

Map<String, dynamic> _backend() => {
      ApiConstants.misEntregas: {
        'success': true,
        'entregas': [
          _entrega('1', 'asignada'),
          _entrega('2', 'en_camino'),
          _entrega('3', 'entregada', total: 250),
          _entrega('4', 'entregada', total: 100.5),
          _entrega('5', 'fallida'),
        ],
      },
      ApiConstants.disponibilidad: {'success': true, 'disponible': true},
      ApiConstants.entregasDisponibles: {
        'success': true,
        'pedidos': [
          {'pedido_id': 41, 'numero': 'PIER-41'},
        ],
      },
    };

(RepartidorViewModel, FakeApiClient) _armar([Map<String, dynamic>? extra]) {
  final api = FakeApiClient(respuestas: {..._backend(), ...?extra});
  return (RepartidorViewModel(repo: EntregasRepositoryRemote(api: api)), api);
}

void main() {
  group('RepartidorViewModel: cargar', () {
    test('trae todo y separa en curso, historial y métricas', () async {
      final (vm, _) = _armar();
      final estados = <bool>[];
      vm.addListener(() => estados.add(vm.cargando));

      await vm.cargar();

      expect(estados.first, isTrue);
      expect(vm.cargando, isFalse);
      expect(vm.errorCarga, isNull);
      expect(vm.disponible, isTrue);
      expect(vm.disponibles.single.numero, 'PIER-41');
      expect(vm.activas.map((e) => e.id), ['1', '2']);
      expect(vm.historial.map((e) => e.id), ['3', '4', '5']);
      expect(vm.entregadasCount, 2);
      expect(vm.fallidasCount, 1);
      expect(vm.totalDia, 350.5);
    });

    test('si fallan las entregas guarda el motivo y conserva lo que había',
        () async {
      final (vm, api) = _armar();
      await vm.cargar();

      api
        ..fallar(ApiConstants.misEntregas, 'Sin conexión')
        ..fallar(ApiConstants.disponibilidad, 'Sin conexión')
        ..fallar(ApiConstants.entregasDisponibles, 'Sin conexión');
      await vm.recargar();

      expect(vm.errorCarga, 'Sin conexión');
      expect(vm.activas, hasLength(2));
      expect(vm.disponible, isTrue);
      expect(vm.disponibles, hasLength(1));

      api.responder(ApiConstants.misEntregas, _backend()[ApiConstants.misEntregas] as Map<String, dynamic>);
      await vm.recargar();
      expect(vm.errorCarga, isNull);
    });

    test('no avisa a la vista si ya se cerró', () async {
      final (vm, api) = _armar();
      api.demorar(ApiConstants.misEntregas, const Duration(milliseconds: 10));
      final carga = vm.cargar();
      vm.dispose();
      await carga; // no lanza «used after being disposed»
    });
  });

  group('RepartidorViewModel: aceptar', () {
    test('toma el pedido, recarga y devuelve el mensaje', () async {
      final (vm, api) = _armar({
        ApiConstants.entregasAceptar: {
          'success': true,
          'message': 'Tomaste el pedido #PIER-41',
        },
      });
      api.demorar(ApiConstants.entregasAceptar, const Duration(milliseconds: 5));

      final accion = vm.aceptar(_pedido);
      expect(vm.aceptando(_pedido), isTrue);
      final repetida = await vm.aceptar(_pedido);
      final r = await accion;

      expect(repetida.ok, isFalse);
      expect(r, (ok: true, mensaje: 'Tomaste el pedido #PIER-41'));
      expect(vm.aceptando(_pedido), isFalse);
      expect(api.ultima(ApiConstants.entregasAceptar)!.body,
          {'pedido_id': '41'});
      expect(api.llamo(ApiConstants.misEntregas), isTrue);
    });

    test('si otro lo tomó devuelve el motivo y no recarga', () async {
      final (vm, api) = _armar();
      api.fallar(
          ApiConstants.entregasAceptar, 'Otro repartidor ya tomó este pedido');

      final r = await vm.aceptar(_pedido);

      expect(r, (ok: false, mensaje: 'Otro repartidor ya tomó este pedido'));
      expect(vm.aceptando(_pedido), isFalse);
      expect(api.llamo(ApiConstants.misEntregas), isFalse);
    });
  });

  group('RepartidorViewModel: disponibilidad', () {
    test('cambia al instante y queda lo que guardó el backend', () async {
      final (vm, api) = _armar({
        ApiConstants.disponibilidad: {'success': true, 'disponible': true},
      });
      final vistos = <bool>[];
      vm.addListener(() => vistos.add(vm.disponible));

      final ok = await vm.cambiarDisponible(valor: true);

      expect(ok, isTrue);
      expect(vistos, [true, true]);
      expect(api.ultima(ApiConstants.disponibilidad)!.body,
          {'disponible': true});
    });

    test('si el backend lo rechaza vuelve al valor anterior', () async {
      final (vm, api) = _armar();
      api.fallar(ApiConstants.disponibilidad, 'Error al cambiar disponibilidad');
      final vistos = <bool>[];
      vm.addListener(() => vistos.add(vm.disponible));

      final ok = await vm.cambiarDisponible(valor: true);

      expect(ok, isFalse);
      expect(vistos, [true, false]);
      expect(vm.disponible, isFalse);
    });
  });
}
