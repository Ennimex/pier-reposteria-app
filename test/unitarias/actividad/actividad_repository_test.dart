// test/unitarias/actividad/actividad_repository_test.dart — «Actividad del
// equipo» (#139) sin red: los modelos leen el contrato de la web (los
// textos escapados por el backend vuelven a ser los escritos y los
// renglones inválidos se descartan) y el repositorio arma la consulta de la
// bitácora con cada filtro (fechas AAAA-MM-DD) y con la página siguiente.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository_remote.dart';
import 'package:pier_reposteria/domain/models/actividad_equipo.dart';

import '../../fakes/actividad_json.dart';
import '../../fakes/fake_api_client.dart';

/// Espera que [llamada] lance ApiException con [mensaje].
Future<void> _fallaCon(Future<Object?> llamada, String mensaje) =>
    expectLater(
      llamada,
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', mensaje),
      ),
    );

void main() {
  group('ActividadEquipo', () {
    test('lee el equipo, los movimientos, las zonas y las cifras', () {
      final a = ActividadEquipo.fromJson(actividadJson);

      expect(
        a.equipo.map((m) => m.nombre),
        ['Ana Ruiz', 'Luis Pérez', 'Rosa Díaz', 'Pedro Sol'],
      );
      final luis = a.equipo[1];
      expect(luis.id, 3);
      expect(luis.rol, 'repartidor');
      expect(luis.esRepartidor, isTrue);
      expect(luis.activo, isTrue);
      expect(luis.ultimoAcceso, DateTime.utc(2026, 10, 31, 15));
      expect((luis.entregadas, luis.entregasActivas), (8, 2));
      final pedro = a.equipo.last;
      expect(pedro.activo, isFalse);
      expect(pedro.ultimoAcceso, isNull);
      expect(pedro.esRepartidor, isFalse);
      expect(a.equipo.first.acciones, 12);

      expect(a.movimientos, hasLength(2));
      final aprobo = a.movimientos.first;
      expect(aprobo.id, isNull);
      expect(aprobo.persona, 'Ana Ruiz');
      expect(aprobo.accion, 'Aprobó reembolso');
      expect((aprobo.entidad, aprobo.entidadId), ('reembolso', 7));
      expect(aprobo.detalles, 'Pedido PIER-41 & cliente avisado');
      expect(aprobo.rol, 'gerencia');
      expect(aprobo.ip, isNull);
      expect(aprobo.fecha, DateTime.utc(2026, 10, 31, 17, 30));
      final sistema = a.movimientos.last;
      expect(sistema.persona, 'Sistema');
      expect(sistema.rol, isNull);
      expect(sistema.detalles, isNull);

      expect(a.zonas.map((z) => (z.colonia, z.zona, z.pedidos)), [
        ('Centro', 'Centro', 12),
        ('San Juan & Anexas', 'Norte', 6),
        ('Sin colonia', null, 3),
      ]);
      final k = a.kpis!;
      expect(
        (
          k.clientesAtendidos,
          k.pedidosCerrados,
          k.productosMovidos,
          k.promocionesCreadas,
          k.avisosDemora,
        ),
        (1234, 56, 9, 2, 4),
      );
    });

    test('sin listas ni cifras queda vacía', () {
      final a = ActividadEquipo.fromJson({'success': true, 'equipo': 'x'});

      expect(a.equipo, isEmpty);
      expect(a.movimientos, isEmpty);
      expect(a.zonas, isEmpty);
      expect(a.kpis, isNull);
    });

    test('tolera faltantes y números que llegan como texto', () {
      final m = MiembroEquipo.fromJson({
        'id': '7',
        'nombre': 'Ian',
        'apellido': 'O&#x27;Brien',
        'acciones': '3',
        'entregadas': 2.9,
        'ultimo_acceso': 'ayer',
      })!;
      expect(m.id, 7);
      expect(m.nombre, "Ian O'Brien");
      expect(m.rol, isEmpty);
      expect(m.activo, isTrue);
      expect(m.acciones, 3);
      expect(m.entregadas, 2);
      expect(m.entregasActivas, 0);
      expect(m.ultimoAcceso, isNull);
      expect(MiembroEquipo.fromJson({'nombre': 'Sin id'}), isNull);
      expect(MiembroEquipo.fromJson('basura'), isNull);

      final z = ZonaEntregas.fromJson({'pedidos': 'muchos'})!;
      expect((z.colonia, z.zona, z.pedidos), ('Sin colonia', null, 0));
      expect(ZonaEntregas.fromJson(null), isNull);
      expect(KpisActividad.fromJson(<String, Object?>{})!.avisosDemora, 0);
      expect(KpisActividad.fromJson([1]), isNull);

      final sinNada = MovimientoEquipo.deActividad({'detalles': '  '})!;
      expect(sinNada.accion, 'Movimiento');
      expect(sinNada.persona, 'Sistema');
      expect(sinNada.detalles, isNull);
      expect(sinNada.fecha, isNull);
      expect(MovimientoEquipo.deActividad(4), isNull);
    });
  });

  group('PaginaBitacora', () {
    test('movimientos, página siguiente, entidades y personas', () {
      final p = PaginaBitacora.fromJson(primeraPaginaJson);

      expect(p.movimientos.map((m) => m.id), [32, 31, 30]);
      expect(p.hayMas, isTrue);
      expect(p.siguienteAntesDeId, 30);
      expect(
        p.entidades,
        ['comanda', 'pedido', 'producto', 'zona_envio', 'otra_cosa'],
      );
      expect(p.personas.map((x) => (x.id, x.nombre, x.rol)), [
        (2, 'Ana Ruiz', 'gerencia'),
        (3, 'Luis Pérez', 'repartidor'),
      ]);

      final cambio = p.movimientos.first;
      expect(cambio.accion, 'Cambió el estado del pedido');
      expect((cambio.entidad, cambio.entidadId), ('pedido', 42));
      expect(cambio.detalles, 'De "listo" a "entregado"');
      expect(cambio.persona, 'Ana Ruiz');
      expect(cambio.rol, 'gerencia');
      expect(cambio.ip, '10.0.0.7');
      expect(cambio.fecha, DateTime.utc(2026, 10, 31, 17, 5));
      final sistema = p.movimientos[1];
      expect(sistema.persona, 'Sistema');
      expect(sistema.rol, isNull);
      expect(sistema.ip, isNull);
      expect(sistema.detalles, isNull);
      expect(p.movimientos.last.detalles, detallesLargos);
    });

    test('la última página no tiene siguiente', () {
      final p = PaginaBitacora.fromJson(segundaPaginaJson);

      expect(p.movimientos.single.accion, 'Creó promoción');
      expect(p.hayMas, isFalse);
      expect(p.siguienteAntesDeId, isNull);
    });

    test('detalles de un objeto como JSON; lo inválido se descarta', () {
      final p = PaginaBitacora.fromJson({
        'success': true,
        'auditoria': [
          registroJson(id: 5, detalles: {'tabla': 'tblusuarios', 'filas': 3}),
          {'accion': 'Sin id'},
          'basura',
        ],
        'hay_mas': true,
        'entidades': ['pedido', ' ', null, 7],
        'personas': [
          {'nombre': 'Sin id'},
        ],
      });

      expect(
        p.movimientos.single.detalles,
        '{"tabla":"tblusuarios","filas":3}',
      );
      // Dice que hay más, pero no con qué pedirlos: no hay más.
      expect(p.hayMas, isFalse);
      expect(p.entidades, ['pedido']);
      expect(p.personas, isEmpty);
    });

    test('sin nada elegido los filtros están vacíos', () {
      expect(const FiltrosBitacora().vacios, isTrue);
      expect(const FiltrosBitacora(entidad: 'pedido').vacios, isFalse);
      expect(const FiltrosBitacora(usuarioId: 2).vacios, isFalse);
      expect(FiltrosBitacora(desde: DateTime(2026)).vacios, isFalse);
      expect(FiltrosBitacora(hasta: DateTime(2026)).vacios, isFalse);
    });
  });

  group('ActividadRepositoryRemote', () {
    late FakeApiClient api;
    late ActividadRepositoryRemote repo;

    setUp(() {
      api = backendActividad();
      repo = ActividadRepositoryRemote(api: api);
    });

    test('pide la actividad del equipo con la sesión', () async {
      final a = await repo.actividadEquipo();

      expect(a.equipo, hasLength(4));
      expect(
        api.llamo(ApiConstants.actividadEquipo, metodo: 'GET-Auth'),
        isTrue,
      );
    });

    test('si no carga lanza el mensaje del backend o uno propio', () async {
      api.fallar(
        ApiConstants.actividadEquipo,
        'No tienes permisos para acceder a este recurso',
      );
      await _fallaCon(
        repo.actividadEquipo(),
        'No tienes permisos para acceder a este recurso',
      );

      api
        ..responder(ApiConstants.actividadEquipo, {'success': false})
        ..responder(ApiConstants.auditoria, {'success': false});
      await _fallaCon(
        repo.actividadEquipo(),
        'No se pudo cargar la actividad del equipo. Intenta de nuevo.',
      );
      await _fallaCon(
        repo.bitacora(const FiltrosBitacora()),
        'No se pudo cargar la bitácora. Intenta de nuevo.',
      );
    });

    test('la primera página sin filtros, de 50 en 50', () async {
      final p = await repo.bitacora(const FiltrosBitacora());

      expect(p.movimientos, hasLength(3));
      expect(
        api.llamo('/reportes/auditoria?limite=50', metodo: 'GET-Auth'),
        isTrue,
      );
    });

    test('cada filtro va en la consulta; las fechas, AAAA-MM-DD', () async {
      await repo.bitacora(const FiltrosBitacora(entidad: 'zona_envio'));
      await repo.bitacora(const FiltrosBitacora(usuarioId: 3));
      await repo.bitacora(FiltrosBitacora(desde: DateTime(2026, 3, 5)));
      await repo.bitacora(FiltrosBitacora(hasta: DateTime(2026, 10, 31)));
      await repo.bitacora(
        FiltrosBitacora(
          entidad: 'pedido',
          usuarioId: 2,
          desde: DateTime(2026, 10),
          hasta: DateTime(2026, 10, 15),
        ),
      );

      expect(api.llamadas.map((l) => l.endpoint), [
        consultaBitacora('&entidad=zona_envio'),
        consultaBitacora('&usuario_id=3'),
        consultaBitacora('&desde=2026-03-05'),
        consultaBitacora('&hasta=2026-10-31'),
        consultaBitacora(
          '&entidad=pedido&usuario_id=2&desde=2026-10-01&hasta=2026-10-15',
        ),
      ]);
    });

    test('una entidad con caracteres especiales va codificada', () async {
      await repo.bitacora(const FiltrosBitacora(entidad: 'a&b c'));

      expect(api.llamo(consultaBitacora('&entidad=a%26b+c')), isTrue);
    });

    test('la página siguiente lleva antes_de_id y los mismos filtros',
        () async {
      final p = await repo.bitacora(const FiltrosBitacora(), antesDeId: 30);
      expect(p.movimientos.single.id, 29);
      expect(p.hayMas, isFalse);

      await repo.bitacora(
        const FiltrosBitacora(entidad: 'pedido'),
        antesDeId: 12,
      );
      expect(
        api.llamo(consultaBitacora('&entidad=pedido&antes_de_id=12')),
        isTrue,
      );
    });

    test('si la bitácora no carga lanza el mensaje del backend', () async {
      api.fallar(
        ApiConstants.auditoria,
        'Fecha "desde" inválida: usa el formato AAAA-MM-DD',
      );

      await _fallaCon(
        repo.bitacora(FiltrosBitacora(desde: DateTime(2026))),
        'Fecha "desde" inválida: usa el formato AAAA-MM-DD',
      );
    });
  });
}
