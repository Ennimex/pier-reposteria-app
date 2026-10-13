// test/unitarias/comandas/agenda_comandas_view_model_test.dart — estado de la
// agenda de comandas de producción (#127): vistas, búsqueda, agrupación por
// día, pendientes del área y sesión inválida.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/ui/comandas/view_model/agenda_comandas_view_model.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

const _proximas = '/comandas?vista=proximas';
const _activas = '/comandas?vista=activas';

final Map<String, dynamic> _firmada = firmaJson(
  vigente: true,
  version: 1,
  usuario: 'Rosa Pérez',
);

AgendaComandasViewModel _vm(
  FakeApiClient api, {
  AreaProduccion? area = AreaProduccion.hornos,
}) => AgendaComandasViewModel(
  repo: ComandasRepositoryRemote(api: api),
  area: area,
);

void main() {
  late FakeApiClient api;

  setUp(() {
    api = FakeApiClient()
      ..responder(
        _proximas,
        agendaJson([
          comandaJson(fecha: '2026-10-12', dias: 0, hora: '16:00'),
          comandaJson(id: 2, fecha: '2026-10-12', dias: 0, hora: '10:00'),
          comandaJson(id: 3, hornos: _firmada),
        ]),
      )
      ..responder(
        _activas,
        agendaJson([
          comandaJson(
            id: 5,
            fecha: '2026-10-10',
            dias: -2,
            semaforo: 'vencida',
          ),
          comandaJson(fecha: '2026-10-12', dias: 0, hora: '16:00'),
          comandaJson(id: 2, fecha: '2026-10-12', dias: 0, hora: '10:00'),
          comandaJson(id: 3, hornos: _firmada),
          comandaJson(id: 4, fecha: '2026-11-20', dias: 39, semaforo: 'verde'),
        ]),
      );
  });

  group('cargar', () {
    test(
      'trae los próximos días y todas las activas para los pendientes',
      () async {
        final vm = _vm(api);
        final cargando = vm.cargar();
        expect(vm.cargando, isTrue);
        await cargando;

        expect(vm.cargando, isFalse);
        expect(vm.error, isNull);
        expect(
          api.llamadas.map((l) => l.endpoint),
          unorderedEquals([_proximas, _activas]),
        );
        expect(vm.hoy, '2026-10-12');
        expect(vm.total, 3);
      },
    );

    test('agrupa por día de entrega con su encabezado', () async {
      final vm = _vm(api);
      await vm.cargar();

      expect(vm.grupos.map((g) => g.titulo), [
        'Hoy · lunes 12 de octubre',
        'Miércoles 14 de octubre',
      ]);
      expect(vm.grupos.first.comandas.map((c) => c.id), [1, 2]);
    });

    test(
      'pendientes: activas sin la firma de mi área, la más urgente primero',
      () async {
        final vm = _vm(api);
        await vm.cargar();

        expect(vm.pendientes!.map((c) => c.id), [5, 2, 1, 4]);
      },
    );

    test(
      'sin área (no es producción) no hay pendientes ni segunda consulta',
      () async {
        final vm = _vm(api, area: null);
        await vm.cargar();

        expect(vm.pendientes, isNull);
        expect(api.llamadas.single.endpoint, _proximas);
      },
    );

    test('error: lo expone y conserva lo que había', () async {
      final vm = _vm(api);
      await vm.cargar();
      api
        ..fallar(_proximas, 'Error al obtener las comandas')
        ..fallar(_activas, 'Error al obtener las comandas');

      await vm.recargar();

      expect(vm.error, 'Error al obtener las comandas');
      expect(vm.total, 3);
    });

    test('sesión inválida: lo marca para cerrar la sesión', () async {
      api.responder(_proximas, {
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu cuenta está desactivada o cambió.',
      });
      final vm = _vm(api);
      var avisos = 0;
      vm.addListener(() => avisos++);

      await vm.cargar();

      expect(vm.sesionInvalida, isTrue);
      expect(avisos, greaterThan(0));
    });
  });

  group('vistas y búsqueda', () {
    test(
      'Todas las activas usa una sola consulta para lista y pendientes',
      () async {
        final vm = _vm(api);
        await vm.cambiarVista(VistaAgenda.activas);

        expect(vm.vista, VistaAgenda.activas);
        expect(api.llamadas.single.endpoint, _activas);
        expect(vm.total, 5);
        expect(vm.pendientes!.length, 4);
        expect(vm.grupos.first.titulo, 'Sábado 10 de octubre');
      },
    );

    test('entregadas: agrupa por el día en que se entregaron', () async {
      api.responder(
        '/comandas?vista=entregadas',
        agendaJson([
          comandaJson(
            id: 8,
            estado: 'entregada',
            semaforo: null,
            fecha: '2026-10-15',
            entregadaAt: '2026-10-12T02:00:00.000Z',
          ),
        ]),
      );
      final vm = _vm(api);
      await vm.cambiarVista(VistaAgenda.entregadas);

      expect(vm.grupos.single.titulo, 'Ayer · domingo 11 de octubre');
    });

    test(
      'canceladas sin fecha de cancelación usa la fecha de entrega',
      () async {
        api.responder(
          '/comandas?vista=canceladas',
          agendaJson([
            comandaJson(id: 9, estado: 'cancelada', semaforo: null),
          ]),
        );
        final vm = _vm(api);
        await vm.cambiarVista(VistaAgenda.canceladas);

        expect(vm.grupos.single.titulo, 'Miércoles 14 de octubre');
      },
    );

    test(
      'buscar quita el # del folio y consulta con la vista actual',
      () async {
        api.responder(
          '/comandas?vista=proximas&busqueda=5003',
          agendaJson([comandaJson(folio: 5003)]),
        );
        final vm = _vm(api);
        await vm.cargar();
        api.llamadas.clear();

        await vm.buscar('  #5003 ');

        expect(vm.busqueda, '5003');
        expect(
          api.llamadas.single.endpoint,
          '/comandas?vista=proximas&busqueda=5003',
        );
        expect(vm.total, 1);
        expect(vm.pendientes!.length, 4, reason: 'los pendientes no cambian');
      },
    );

    test('la misma búsqueda no vuelve a consultar', () async {
      final vm = _vm(api);
      await vm.cargar();
      api.llamadas.clear();

      await vm.buscar('');
      await vm.cambiarVista(VistaAgenda.proximas);

      expect(api.llamadas, isEmpty);
    });

    test('una respuesta vieja no pisa a la más reciente', () async {
      final vm = _vm(api, area: null);
      api.demorar(_proximas, const Duration(milliseconds: 50));
      final lenta = vm.cargar();
      await vm.cambiarVista(VistaAgenda.activas);
      await lenta;

      expect(vm.vista, VistaAgenda.activas);
      expect(vm.total, 5);
    });
  });

  test('tras dispose no avisa', () async {
    final vm = _vm(api);
    api.demorar(_proximas, const Duration(milliseconds: 20));
    final carga = vm.cargar();
    vm.dispose();
    await expectLater(carga, completes);
  });
}
