// test/unitarias/actividad/actividad_equipo_view_model_test.dart — la
// pestaña «Equipo» de Actividad del equipo (#139) sin red y con el reloj
// fijo (CI corre en UTC): cargar, el error de carga y reintentar, refrescar
// sin perder lo cargado, el último acceso como lo dice la web, lo que ha
// registrado cada persona (entregas o movimientos) y la barra de cada zona.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository_remote.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';
import 'package:pier_reposteria/ui/actividad/view_model/actividad_equipo_view_model.dart';

import '../../fakes/actividad_json.dart';
import '../../fakes/fake_api_client.dart';

(ActividadEquipoViewModel, FakeApiClient) _armar() {
  final api = backendActividad();
  return (
    ActividadEquipoViewModel(
      repo: ActividadRepositoryRemote(api: api),
      ahora: ahoraActividad,
    ),
    api,
  );
}

/// El instante de hace [cuanto] con el reloj fijo.
DateTime _hace(Duration cuanto) => ahoraActividad().subtract(cuanto);

void main() {
  group('ActividadEquipoViewModel: carga', () {
    test('carga la actividad del equipo', () async {
      final (vm, api) = _armar();
      expect(vm.cargando, isFalse);

      final carga = vm.cargar();
      expect(vm.cargando, isTrue);
      await carga;

      expect(vm.cargando, isFalse);
      expect(vm.error, isNull);
      expect(vm.actividad!.equipo, hasLength(4));
      expect(consultasDe(api, ApiConstants.actividadEquipo), 1);
    });

    test('si no carga expone el motivo y al reintentar se recupera',
        () async {
      final (vm, api) = _armar();
      api.fallar(
        ApiConstants.actividadEquipo,
        'Error al obtener la actividad del equipo',
      );
      await vm.cargar();
      expect(vm.error, 'Error al obtener la actividad del equipo');
      expect(vm.actividad, isNull);

      api.responder(ApiConstants.actividadEquipo, actividadJson);
      await vm.cargar();
      expect(vm.error, isNull);
      expect(vm.actividad, isNotNull);
    });

    test('al refrescar sin respuesta conserva lo cargado y da el motivo',
        () async {
      final (vm, api) = _armar();
      await vm.cargar();
      api.fallar(ApiConstants.actividadEquipo, 'Sin conexión');

      expect(await vm.refrescar(), 'Sin conexión');
      expect(vm.actividad!.zonas, hasLength(3));
      expect(vm.error, isNull);
    });

    test('si la pantalla se cierra a media carga no avisa a nadie', () async {
      final (vm, api) = _armar();
      api.demorar(
        ApiConstants.actividadEquipo,
        const Duration(milliseconds: 5),
      );
      var avisos = 0;
      vm.addListener(() => avisos++);

      final carga = vm.cargar();
      vm.dispose();
      await carga;

      expect(vm.actividad, isNull);
      // Solo el de «cargando», antes de cerrarse.
      expect(avisos, 1);
    });
  });

  group('ActividadEquipoViewModel: textos', () {
    late ActividadEquipoViewModel vm;

    setUp(() {
      vm = _armar().$1;
    });

    test('último acceso: nunca, ahora mismo, minutos, horas y días', () {
      expect(vm.haceCuanto(null), 'Nunca');
      expect(vm.haceCuanto(_hace(const Duration(seconds: 59))), 'Ahora mismo');
      // Un reloj adelantado no da tiempos negativos.
      expect(vm.haceCuanto(_hace(const Duration(minutes: -3))), 'Ahora mismo');
      expect(vm.haceCuanto(_hace(const Duration(minutes: 1))), 'Hace 1 min');
      expect(vm.haceCuanto(_hace(const Duration(minutes: 59))), 'Hace 59 min');
      expect(vm.haceCuanto(_hace(const Duration(hours: 1))), 'Hace 1 h');
      expect(
        vm.haceCuanto(_hace(const Duration(hours: 23, minutes: 59))),
        'Hace 23 h',
      );
      expect(vm.haceCuanto(_hace(const Duration(hours: 24))), 'Hace 1 día');
      expect(
        vm.haceCuanto(_hace(const Duration(days: 6, hours: 5))),
        'Hace 6 días',
      );
    });

    test('el equipo del backend con el reloj fijo', () async {
      await vm.cargar();
      final equipo = vm.actividad!.equipo;

      expect(
        equipo.map((m) => vm.haceCuanto(m.ultimoAcceso)),
        ['Hace 5 min', 'Hace 3 h', 'Hace 2 días', 'Nunca'],
      );
      expect(equipo.map(vm.actividadDe), [
        '12 movimientos',
        '8 entregas · 2 en curso',
        '1 movimiento',
        '0 movimientos',
      ]);
    });

    test('entregas en singular, con miles y sin las que van en curso', () {
      const una = MiembroEquipo(
        id: 1,
        nombre: 'Luis Pérez',
        rol: 'repartidor',
        entregadas: 1,
      );
      const muchas = MiembroEquipo(
        id: 2,
        nombre: 'Juan Gil',
        rol: 'repartidor',
        entregadas: 1500,
        entregasActivas: 1,
      );
      const ana = MiembroEquipo(
        id: 3,
        nombre: 'Ana Ruiz',
        rol: 'gerencia',
        acciones: 2048,
      );

      expect(vm.actividadDe(una), '1 entrega');
      expect(vm.actividadDe(muchas), '1,500 entregas · 1 en curso');
      expect(vm.actividadDe(ana), '2,048 movimientos');
    });

    test('las cifras llevan separador de miles, como la web', () {
      expect(ActividadEquipoViewModel.cifra(0), '0');
      expect(ActividadEquipoViewModel.cifra(1234567), '1,234,567');
    });

    test('la barra de cada zona, frente a la de más pedidos', () async {
      const zona = ZonaEntregas(colonia: 'Centro', pedidos: 3);
      // Sin actividad todavía no hay con qué compararla.
      expect(vm.proporcion(zona), 0);

      await vm.cargar();

      expect(vm.actividad!.zonas.map(vm.proporcion), [1, 0.5, 0.25]);
    });
  });
}
