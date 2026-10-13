// test/unitarias/comandas/comandas_personal_test.dart — comandas para quien
// cobra (#129): montos y permisos del detalle, entregar con el saldo
// cobrado y cancelar con motivo, en el repositorio y en el ViewModel.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/ui/comandas/view_model/detalle_comanda_view_model.dart';
import 'package:pier_pasteleria/utils/moneda.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

const _detalle = '/comandas/7';
const _entregar = '/comandas/7/entregar';
const _cancelar = '/comandas/7/cancelar';

Map<String, dynamic> _conMontos({
  bool entregar = true,
  bool cancelar = true,
  String estado = 'activa',
}) => detalleJson(
  confirmar: null,
  estado: estado,
  total: '850.00',
  anticipo: '200.00',
  saldo: '650.00',
  entregar: entregar,
  cancelar: cancelar,
  imprimir: true,
);

void main() {
  group('moneda', () {
    test('con separador de miles y dos decimales', () {
      expect(moneda(850), r'$850.00');
      expect(moneda(1250.5), r'$1,250.50');
      expect(moneda(0), r'$0.00');
      expect(moneda(1234567.891), r'$1,234,567.89');
    });
  });

  group('DetalleComanda con montos y permisos', () {
    test('quien cobra recibe montos y permisos', () {
      final d = DetalleComanda.fromJson(_conMontos());

      expect(d.total, 850);
      expect(d.anticipo, 200);
      expect(d.saldo, 650);
      expect(d.descuento, 0);
      expect(d.puedeEntregar, isTrue);
      expect(d.puedeCancelar, isTrue);
      expect(d.puedeImprimir, isTrue);
    });

    test('producción: sin montos ni permisos de captura', () {
      final d = DetalleComanda.fromJson(detalleJson());

      expect(d.total, isNull);
      expect(d.saldo, isNull);
      expect(d.puedeEntregar, isFalse);
      expect(d.puedeCancelar, isFalse);
      expect(d.puedeImprimir, isFalse);
    });

    test('entregada: saldo cobrado y quién la entregó', () {
      final json = detalleJson(
        estado: 'entregada',
        semaforo: null,
        saldoCobrado: '650.00',
      );
      (json['comanda'] as Map)['entregada_por_nombre'] = 'Laura Cruz';
      final d = DetalleComanda.fromJson(json);

      expect(d.saldoCobrado, 650);
      expect(d.entregadaPorNombre, 'Laura Cruz');
    });
  });

  group('ComandasRepositoryRemote: entregar y cancelar', () {
    late FakeApiClient api;
    late ComandasRepositoryRemote repo;

    setUp(() {
      api = FakeApiClient();
      repo = ComandasRepositoryRemote(api: api);
    });

    test(
      'entregar manda el saldo cobrado y devuelve las advertencias',
      () async {
        api.responder(_entregar, {
          'success': true,
          'message': 'Comanda #5003 entregada',
          'advertencias': ['Hornos no confirmó de enterado la versión 1'],
        });

        final r = await repo.entregar(7, saldoCobrado: 600);

        expect(r.mensaje, 'Comanda #5003 entregada');
        expect(r.advertencias, ['Hornos no confirmó de enterado la versión 1']);
        final llamada = api.ultima(_entregar)!;
        expect(llamada.metodo, 'PUT-Auth');
        expect(llamada.body, {'saldo_cobrado': 600.0});
      },
    );

    test('entregar sin advertencias', () async {
      api.responder(_entregar, {'success': true});

      final r = await repo.entregar(7, saldoCobrado: 0);

      expect(r.mensaje, 'Comanda entregada');
      expect(r.advertencias, isEmpty);
    });

    test('cancelar manda el motivo', () async {
      api.responder(_cancelar, {
        'success': true,
        'message': 'Comanda #5003 cancelada',
      });

      final mensaje = await repo.cancelar(7, motivo: 'El cliente ya no vino');

      expect(mensaje, 'Comanda #5003 cancelada');
      expect(api.ultima(_cancelar)!.body, {'motivo': 'El cliente ya no vino'});
      expect(api.ultima(_cancelar)!.metodo, 'PUT-Auth');
    });

    test('sin permiso para cancelar: ApiException con el mensaje', () async {
      api.fallar(
        _cancelar,
        'Solo quien tomó la comanda, gerencia o dirección pueden cancelarla',
      );

      await expectLater(
        repo.cancelar(7, motivo: 'Motivo largo'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Solo quien tomó la comanda'),
          ),
        ),
      );
    });
  });

  group('DetalleComandaViewModel: entregar y cancelar', () {
    late FakeApiClient api;
    late DetalleComandaViewModel vm;

    setUp(() async {
      api = FakeApiClient()..responder(_detalle, _conMontos());
      vm = DetalleComandaViewModel(
        repo: ComandasRepositoryRemote(api: api),
        id: 7,
      );
      await vm.cargar();
    });

    test('entregar: registra el saldo y recarga', () async {
      api
        ..responder(_entregar, {
          'success': true,
          'message': 'Comanda #5003 entregada',
          'advertencias': <String>[],
        })
        ..responder(
          _detalle,
          detalleJson(
            confirmar: null,
            estado: 'entregada',
            semaforo: null,
            saldoCobrado: '650.00',
          ),
        );

      await vm.entregar.execute(650);

      expect(vm.entregar.resultado!.mensaje, 'Comanda #5003 entregada');
      expect(vm.detalle!.estado, EstadoComanda.entregada);
    });

    test('cancelar: registra el motivo y recarga', () async {
      api
        ..responder(_cancelar, {
          'success': true,
          'message': 'Comanda #5003 cancelada',
        })
        ..responder(_detalle, _conMontos(estado: 'cancelada'));

      await vm.cancelar.execute('El cliente ya no vino');

      expect(vm.cancelar.resultado, 'Comanda #5003 cancelada');
      expect(vm.detalle!.estado, EstadoComanda.cancelada);
    });

    test(
      'si falla, el error queda en el comando y la comanda sigue igual',
      () async {
        api.fallar(
          _entregar,
          'Esta comanda ya fue cancelada y no se puede entregar',
        );

        await vm.entregar.execute(650);

        expect(
          (vm.entregar.error! as ApiException).message,
          'Esta comanda ya fue cancelada y no se puede entregar',
        );
        expect(vm.detalle!.estado, EstadoComanda.activa);
      },
    );

    test('un segundo toque mientras corre no manda otra petición', () async {
      api
        ..responder(_cancelar, {'success': true})
        ..demorar(_cancelar, const Duration(milliseconds: 20));

      final primero = vm.cancelar.execute('Motivo uno');
      await vm.cancelar.execute('Motivo dos');
      await primero;

      expect(api.llamadas.where((l) => l.endpoint == _cancelar), hasLength(1));
    });
  });
}
