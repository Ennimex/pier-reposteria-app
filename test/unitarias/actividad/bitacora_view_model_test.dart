// test/unitarias/actividad/bitacora_view_model_test.dart — la pestaña
// «Bitácora» de Actividad del equipo (#139) sin red y con el reloj fijo
// (CI corre en UTC): la primera página y su error, cada filtro (entidad,
// persona y fechas, que no se cruzan ni pasan de hoy en México), limpiar,
// «Cargar más» con antes_de_id, refrescar sin perder lo cargado y que gane
// la consulta más reciente.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository_remote.dart';
import 'package:pier_reposteria/ui/actividad/view_model/bitacora_view_model.dart';

import '../../fakes/actividad_json.dart';
import '../../fakes/fake_api_client.dart';

(BitacoraViewModel, FakeApiClient) _armar({
  DateTime Function() ahora = ahoraActividad,
}) {
  final api = backendActividad();
  return (
    BitacoraViewModel(repo: ActividadRepositoryRemote(api: api), ahora: ahora),
    api,
  );
}

void main() {
  group('BitacoraViewModel: primera página', () {
    test('trae los movimientos y llena los filtros', () async {
      final (vm, api) = _armar();
      final carga = vm.cargar();
      expect(vm.cargando, isTrue);
      expect(vm.resumen, 'Cargando movimientos…');
      await carga;

      expect(vm.cargando, isFalse);
      expect(vm.error, isNull);
      expect(vm.movimientos.map((m) => m.id), [32, 31, 30]);
      expect(vm.hayMas, isTrue);
      expect(vm.hayFiltros, isFalse);
      expect(vm.resumen, 'Mostrando 3 movimientos; hay más antiguos');
      expect(api.llamo(consultaBitacora(), metodo: 'GET-Auth'), isTrue);
      // Por su etiqueta; una clave desconocida, legible.
      expect(vm.opcionesEntidad, {
        'comanda': 'Comanda',
        'otra_cosa': 'Otra cosa',
        'pedido': 'Pedido',
        'producto': 'Producto',
        'zona_envio': 'Zona de envío',
      });
      expect(vm.opcionesEntidad.keys.first, 'comanda');
      expect(vm.opcionesEntidad.keys.last, 'zona_envio');
      expect(vm.opcionesPersona, {
        2: 'Ana Ruiz · Gerencia',
        3: 'Luis Pérez · Repartidor',
      });
    });

    test('si no carga expone el motivo y al reintentar se recupera',
        () async {
      final (vm, api) = _armar();
      api.fallar(ApiConstants.auditoria, 'Error al obtener auditoría');
      await vm.cargar();

      expect(vm.error, 'Error al obtener auditoría');
      expect(vm.movimientos, isEmpty);
      expect(vm.hayMas, isFalse);
      expect(vm.resumen, isNull);

      api.responder(ApiConstants.auditoria, primeraPaginaJson);
      await vm.cargar();
      expect(vm.error, isNull);
      expect(vm.movimientos, hasLength(3));
    });

    test('una página de un solo movimiento lo dice en singular', () async {
      final (vm, api) = _armar();
      api.responder(
        ApiConstants.auditoria,
        paginaJson([registroJson(id: 1)]),
      );
      await vm.cargar();

      expect(vm.resumen, 'Mostrando 1 movimiento');
      expect(vm.hayMas, isFalse);
    });

    test('si la pantalla se cierra a media carga no avisa a nadie', () async {
      final (vm, api) = _armar();
      api.demorar(consultaBitacora(), const Duration(milliseconds: 5));
      var avisos = 0;
      vm.addListener(() => avisos++);

      final carga = vm.cargar();
      vm.dispose();
      await carga;

      expect(avisos, 1);
    });
  });

  group('BitacoraViewModel: filtros', () {
    late BitacoraViewModel vm;
    late FakeApiClient api;

    setUp(() async {
      (vm, api) = _armar();
      await vm.cargar();
    });

    test('por entidad y por persona, cada uno en la consulta', () async {
      await vm.elegirEntidad('producto');
      expect(api.llamo(consultaBitacora('&entidad=producto')), isTrue);
      expect(vm.hayFiltros, isTrue);

      await vm.elegirPersona(3);
      expect(
        api.llamo(consultaBitacora('&entidad=producto&usuario_id=3')),
        isTrue,
      );
      expect(vm.filtros.entidad, 'producto');
      expect(vm.filtros.usuarioId, 3);
    });

    test('elegir lo mismo no vuelve a consultar', () async {
      await vm.elegirEntidad(null);
      await vm.elegirPersona(null);
      await vm.elegirDesde(null);
      await vm.elegirHasta(null);
      await vm.limpiarFiltros();

      expect(consultasDe(api, consultaBitacora()), 1);
    });

    test('las fechas van como AAAA-MM-DD y no se cruzan', () async {
      await vm.elegirDesde(DateTime(2026, 10, 5));
      await vm.elegirHasta(DateTime(2026, 10, 20));
      expect(
        api.llamo(consultaBitacora('&desde=2026-10-05&hasta=2026-10-20')),
        isTrue,
      );

      // «Desde» después de «Hasta»: «Hasta» se recorre a ese día.
      await vm.elegirDesde(DateTime(2026, 10, 25));
      expect(vm.filtros.hasta, DateTime(2026, 10, 25));
      // «Hasta» antes de «Desde»: «Desde» se recorre a ese día.
      await vm.elegirHasta(DateTime(2026, 10, 2));
      expect(vm.filtros.desde, DateTime(2026, 10, 2));
      expect(
        api.llamo(consultaBitacora('&desde=2026-10-02&hasta=2026-10-02')),
        isTrue,
      );
    });

    test('limpiar los filtros vuelve a todos los movimientos', () async {
      api.responder(consultaBitacora('&usuario_id=3'), paginaJson([]));
      await vm.elegirPersona(3);
      expect(vm.movimientos, isEmpty);

      await vm.limpiarFiltros();

      expect(vm.hayFiltros, isFalse);
      expect(vm.movimientos, hasLength(3));
      expect(consultasDe(api, consultaBitacora()), 2);
    });

    test('lo elegido se ofrece aunque ya no venga del servidor', () async {
      await vm.elegirEntidad('sorteo');
      await vm.elegirPersona(9);

      expect(vm.opcionesEntidad['sorteo'], 'Sorteo');
      expect(vm.opcionesPersona[9], 'Persona ID 9');
      expect(vm.opcionesPersona[2], 'Ana Ruiz · Gerencia');
    });

    test('un día elegido se muestra como en la web', () {
      expect(BitacoraViewModel.textoDia(DateTime(2026, 3, 5)), '05/03/2026');
      expect(BitacoraViewModel.textoDia(DateTime(2026, 10, 31)), '31/10/2026');
    });
  });

  group('BitacoraViewModel: calendario', () {
    test('hoy es el día de México aunque en UTC ya sea mañana', () {
      // 03:00 UTC del 1 de noviembre son las 21:00 del 31 de octubre.
      final (vm, _) = _armar(ahora: () => DateTime.utc(2026, 11, 1, 3));
      expect(vm.hoy, DateTime(2026, 10, 31));
    });

    test('no deja pasar de hoy ni que «Desde» quede después de «Hasta»',
        () async {
      final (vm, _) = _armar();
      await vm.cargar();

      var c = vm.calendario(desde: true);
      expect(c.primero, BitacoraViewModel.primerDia);
      expect(
        (c.inicial, c.ultimo),
        (DateTime(2026, 10, 31), DateTime(2026, 10, 31)),
      );

      await vm.elegirHasta(DateTime(2026, 10, 20));
      c = vm.calendario(desde: true);
      expect(
        (c.inicial, c.ultimo),
        (DateTime(2026, 10, 20), DateTime(2026, 10, 20)),
      );

      await vm.elegirDesde(DateTime(2026, 10, 5));
      c = vm.calendario(desde: true);
      expect(c.inicial, DateTime(2026, 10, 5));
      c = vm.calendario(desde: false);
      expect(
        (c.primero, c.inicial, c.ultimo),
        (DateTime(2026, 10, 5), DateTime(2026, 10, 20), DateTime(2026, 10, 31)),
      );
    });

    test('lo elegido fuera de lo permitido abre en la orilla', () async {
      final (vm, _) = _armar();
      await vm.elegirDesde(DateTime(1999, 12, 31));
      expect(vm.calendario(desde: true).inicial, BitacoraViewModel.primerDia);

      await vm.elegirHasta(DateTime(2027));
      final c = vm.calendario(desde: false);
      expect(c.inicial, DateTime(2026, 10, 31));
      expect(c.primero, DateTime(1999, 12, 31));
    });
  });

  group('BitacoraViewModel: más páginas', () {
    late BitacoraViewModel vm;
    late FakeApiClient api;

    setUp(() async {
      (vm, api) = _armar();
      await vm.cargar();
    });

    test('Cargar más pide la siguiente con antes_de_id y la agrega',
        () async {
      final mas = vm.cargarMas();
      expect(vm.cargandoMas, isTrue);
      await mas;

      expect(api.llamo(consultaBitacora('&antes_de_id=30')), isTrue);
      expect(vm.movimientos.map((m) => m.id), [32, 31, 30, 29]);
      expect(vm.hayMas, isFalse);
      expect(vm.cargandoMas, isFalse);
      expect(vm.resumen, 'Mostrando 4 movimientos');

      // Ya no hay más: no vuelve a pedir.
      await vm.cargarMas();
      expect(consultasDe(api, consultaBitacora('&antes_de_id=30')), 1);
    });

    test('no repite movimientos que ya estaban', () async {
      api.responder(
        consultaBitacora('&antes_de_id=30'),
        paginaJson([registroJson(id: 30), registroJson(id: 29)]),
      );
      await vm.cargarMas();

      expect(vm.movimientos.map((m) => m.id), [32, 31, 30, 29]);
    });

    test('no pide dos veces la misma página', () async {
      api.demorar(consultaBitacora('&antes_de_id=30'), Duration.zero);
      final primera = vm.cargarMas();
      await vm.cargarMas();
      await primera;

      expect(consultasDe(api, consultaBitacora('&antes_de_id=30')), 1);
    });

    test('si no llega, da el motivo, conserva lo cargado y se reintenta',
        () async {
      api.fallar(consultaBitacora('&antes_de_id=30'), 'Sin conexión');
      await vm.cargarMas();

      expect(vm.errorMas, 'Sin conexión');
      expect(vm.movimientos, hasLength(3));
      expect(vm.hayMas, isTrue);

      api.responder(consultaBitacora('&antes_de_id=30'), segundaPaginaJson);
      await vm.cargarMas();
      expect(vm.errorMas, isNull);
      expect(vm.movimientos, hasLength(4));
    });

    test('la página siguiente de otros filtros se descarta', () async {
      api.demorar(
        consultaBitacora('&antes_de_id=30'),
        const Duration(milliseconds: 20),
      );
      final mas = vm.cargarMas();
      await vm.elegirEntidad('pedido');
      await mas;

      expect(vm.movimientos.map((m) => m.id), [32, 31, 30]);
      expect(vm.cargandoMas, isFalse);
    });
  });

  group('BitacoraViewModel: consultas que se cruzan', () {
    test('si cambian los filtros a media consulta gana la más reciente',
        () async {
      final (vm, api) = _armar();
      api
        ..demorar(consultaBitacora(), const Duration(milliseconds: 20))
        ..responder(
          consultaBitacora('&entidad=producto'),
          paginaJson([productoDelSistemaJson]),
        );

      final primera = vm.cargar();
      await vm.elegirEntidad('producto');
      await primera;

      expect(vm.movimientos.map((m) => m.id), [31]);
      expect(vm.cargando, isFalse);
      expect(vm.actualizando, isFalse);
    });

    test('con filtros nuevos se ve que se actualiza', () async {
      final (vm, api) = _armar();
      await vm.cargar();
      api.demorar(
        consultaBitacora('&entidad=pedido'),
        const Duration(milliseconds: 5),
      );

      final filtro = vm.elegirEntidad('pedido');
      expect(vm.actualizando, isTrue);
      expect(vm.resumen, 'Actualizando…');
      // Mientras tanto no se pide la página siguiente de lo anterior.
      await vm.cargarMas();
      await filtro;

      expect(vm.actualizando, isFalse);
      expect(
        api.llamadas.where((l) => l.endpoint.contains('antes_de_id')),
        isEmpty,
      );
    });
  });

  group('BitacoraViewModel: refrescar', () {
    test('pone al día la primera página; si falla deja lo cargado', () async {
      final (vm, api) = _armar();
      await vm.cargar();
      await vm.cargarMas();
      expect(vm.movimientos, hasLength(4));

      expect(await vm.refrescar(), isNull);
      expect(vm.movimientos, hasLength(3));

      api.fallar(ApiConstants.auditoria, 'Sin conexión');
      expect(await vm.refrescar(), 'Sin conexión');
      expect(vm.movimientos, hasLength(3));
      expect(vm.error, isNull);
    });

    test('a media consulta de filtros nuevos cuenta como esa consulta',
        () async {
      final (vm, api) = _armar();
      api
        ..fallar(ApiConstants.auditoria, 'Sin conexión')
        ..demorar(consultaBitacora(), const Duration(milliseconds: 5));

      final carga = vm.cargar();
      expect(await vm.refrescar(), 'Sin conexión');
      await carga;

      expect(vm.error, 'Sin conexión');
      expect(vm.cargando, isFalse);
    });
  });
}
