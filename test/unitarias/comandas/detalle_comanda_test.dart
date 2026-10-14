// test/unitarias/comandas/detalle_comanda_test.dart — detalle de una comanda y
// «Enterado» de producción (#128): modelo, repositorio y ViewModel contra el
// backend falso.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/ui/comandas/view_model/detalle_comanda_view_model.dart';

import '../../fakes/comandas_json.dart';
import '../../fakes/fake_api_client.dart';

const _detalle = '/comandas/7';
const _confirmar = '/comandas/7/confirmar';

final Map<String, dynamic> _firmaHornosV2 = firmaJson(
  vigente: true,
  version: 2,
  usuario: 'Rosa Pérez',
  fecha: 'f',
);

void main() {
  group('DetalleComanda.fromJson', () {
    test('lee cabecera, renglones, imágenes, firmas y permisos', () {
      final d = DetalleComanda.fromJson(
        detalleJson(
          version: 2,
          imagenes: ['https://res.cloudinary.com/a.webp'],
          decoracion: firmaJson(version: 1, usuario: 'Leo Díaz'),
        ),
      );

      expect(d.id, 7);
      expect(d.folio, 5003);
      expect(d.estado, EstadoComanda.activa);
      expect(d.version, 2);
      expect(d.semaforo, Semaforo.naranja);
      expect(d.clienteNombre, 'María López');
      expect(d.clienteTelefono, '7711234567');
      expect(d.fechaEntrega, '2026-10-14');
      expect(d.horaEntrega, '11:00');
      expect(d.diasRestantes, 2);
      expect(d.notas, 'Entregar en salón Las Palmas');
      expect(d.coloresMesa, {'Capacillos': 'Dorado', 'Betún': 'Blanco'});
      expect(d.tomadoPorNombre, 'Laura Cruz');
      expect(d.imagenes, ['https://res.cloudinary.com/a.webp']);
      expect(d.confirmar, AreaProduccion.hornos);
      expect(d.firma(AreaProduccion.decoracion).estado, EstadoFirma.refirmar);

      final pastel = d.pasteles.single;
      expect(pastel.nombre, 'Pastel de chocolate');
      expect(pastel.sabor, 'Chocolate');
      expect(pastel.tamano, '20 personas');
      expect(pastel.forma, 'Redondo');
      expect(pastel.numPisos, 2);
      expect(pastel.decoracion, 'Flores naturales');
      expect(pastel.leyenda, 'Feliz cumpleaños Ana');
      final producto = d.productos.single;
      expect(producto.nombre, 'Tart Bites 24 piezas');
      expect(producto.cantidad, 2);
      expect(producto.tamanoCatalogo, 'grande');
      expect(producto.indicaciones, 'Sin azúcar glass');
    });

    test('sin permiso de confirmar, cancelada con motivo', () {
      final d = DetalleComanda.fromJson(
        detalleJson(
          estado: 'cancelada',
          semaforo: null,
          confirmar: null,
          motivoCancelacion: 'El cliente ya no lo quiere',
        ),
      );

      expect(d.confirmar, isNull);
      expect(d.estado, EstadoComanda.cancelada);
      expect(d.motivoCancelacion, 'El cliente ya no lo quiere');
    });

    test('cambios pendientes y del historial desde una versión', () {
      final d = DetalleComanda.fromJson(
        detalleJson(
          version: 3,
          cambiosPendientes: [
            cambioJson('Pastel 1 · Sabor', 'Vainilla', 'Chocolate'),
          ],
          historial: [
            eventoJson(
              version: 3,
              cambios: [cambioJson('Notas', null, 'Sin nueces')],
            ),
            eventoJson(
              cambios: [cambioJson('Hora de entrega', '10:00', '11:00')],
            ),
            eventoJson(evento: 'creada', version: 1),
          ],
        ),
      );

      expect(
        d.cambiosPendientes!.single.texto,
        'Pastel 1 · Sabor: Vainilla → Chocolate',
      );
      expect(d.cambiosDesde(1).map((c) => c.texto), [
        'Hora de entrega: 10:00 → 11:00',
        'Notas: — → Sin nueces',
      ]);
      expect(d.cambiosDesde(2).map((c) => c.campo), ['Notas']);
    });

    test('textos de los cambios de renglones', () {
      expect(
        const CambioCampo('Se agregó', null, 'Pastel Fresa · 10').texto,
        'Se agregó: Pastel Fresa · 10',
      );
      expect(
        const CambioCampo('Se quitó', 'Gelatina', null).texto,
        'Se quitó: Gelatina',
      );
    });

    test('sin cambios pendientes queda en null', () {
      final d = DetalleComanda.fromJson(detalleJson());

      expect(d.cambiosPendientes, isNull);
      expect(d.cambiosDesde(1), isEmpty);
    });
  });

  group('ComandasRepositoryRemote: detalle y confirmar', () {
    late FakeApiClient api;
    late ComandasRepositoryRemote repo;

    setUp(() {
      api = FakeApiClient()..responder(_detalle, detalleJson());
      repo = ComandasRepositoryRemote(api: api);
    });

    test('detalle pide la comanda con sesión', () async {
      final d = await repo.detalle(7);

      expect(d.folio, 5003);
      expect(api.llamadas.single.metodo, 'GET-Auth');
    });

    test('detalle no encontrado: ApiException con el mensaje', () async {
      api.fallar(_detalle, 'Comanda no encontrada');

      await expectLater(
        repo.detalle(7),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Comanda no encontrada',
          ),
        ),
      );
    });

    test('confirmar manda la versión leída', () async {
      api.responder(_confirmar, {
        'success': true,
        'confirmacion': {'area': 'hornos', 'version': 2},
        'message': 'Enterado registrado',
      });

      final mensaje = await repo.confirmar(7, version: 2);

      expect(mensaje, 'Enterado registrado');
      final llamada = api.ultima(_confirmar)!;
      expect(llamada.metodo, 'POST-Auth');
      expect(llamada.body, {'version': 2});
    });

    test(
      'la comanda cambió: ConflictoComandaException con la versión actual',
      () async {
        api.responder(_confirmar, {
          'success': false,
          'codigo': 'VERSION_DESACTUALIZADA',
          'version_actual': 3,
          'message':
              'La comanda cambió. Revisa los cambios antes de confirmar.',
        });

        await expectLater(
          repo.confirmar(7, version: 2),
          throwsA(
            isA<ConflictoComandaException>()
                .having((e) => e.cambio, 'cambio', isTrue)
                .having((e) => e.versionActual, 'versionActual', 3),
          ),
        );
      },
    );

    test('ya la confirmó un compañero: ConflictoComandaException', () async {
      api.responder(_confirmar, {
        'success': false,
        'codigo': 'YA_CONFIRMADA',
        'message': 'Esta versión ya la confirmó Rosa Pérez (Hornos).',
      });

      await expectLater(
        repo.confirmar(7, version: 2),
        throwsA(
          isA<ConflictoComandaException>()
              .having((e) => e.cambio, 'cambio', isFalse)
              .having(
                (e) => e.message,
                'message',
                'Esta versión ya la confirmó Rosa Pérez (Hornos).',
              ),
        ),
      );
    });

    test('sesión inválida al confirmar', () async {
      api.responder(_confirmar, {
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu cuenta está desactivada o cambió.',
      });

      await expectLater(
        repo.confirmar(7, version: 2),
        throwsA(isA<SesionInvalidaException>()),
      );
    });
  });

  group('DetalleComandaViewModel', () {
    late FakeApiClient api;
    late DetalleComandaViewModel vm;

    setUp(() {
      api = FakeApiClient()..responder(_detalle, detalleJson(version: 2));
      vm = DetalleComandaViewModel(
        repo: ComandasRepositoryRemote(api: api),
        id: 7,
      );
    });

    test('cargar trae el detalle', () async {
      final carga = vm.cargar();
      expect(vm.cargando, isTrue);
      await carga;

      expect(vm.cargando, isFalse);
      expect(vm.detalle!.folio, 5003);
      expect(vm.error, isNull);
    });

    test('error al cargar', () async {
      api.fallar(_detalle, 'Error al obtener la comanda');
      await vm.cargar();

      expect(vm.detalle, isNull);
      expect(vm.error, 'Error al obtener la comanda');
    });

    test('Enterado: confirma la versión que leí y recarga', () async {
      await vm.cargar();
      api
        ..responder(_confirmar, {
          'success': true,
          'confirmacion': {'area': 'hornos', 'version': 2},
          'message': 'Enterado registrado',
        })
        ..responder(
          _detalle,
          detalleJson(version: 2, confirmar: null, hornos: _firmaHornosV2),
        );

      await vm.enterado.execute();

      expect(api.ultima(_confirmar)!.body, {'version': 2});
      expect(vm.enterado.resultado, 'Enterado registrado');
      expect(vm.detalle!.confirmar, isNull);
      expect(vm.cambio, isNull);
    });

    test(
      'la comanda cambió mientras la leía: recarga y muestra qué cambió',
      () async {
        await vm.cargar();
        api
          ..responder(_confirmar, {
            'success': false,
            'codigo': 'VERSION_DESACTUALIZADA',
            'version_actual': 3,
            'message':
                'La comanda cambió. Revisa los cambios antes de confirmar.',
          })
          ..responder(
            _detalle,
            detalleJson(
              version: 3,
              historial: [
                eventoJson(
                  version: 3,
                  cambios: [
                    cambioJson(
                      'Pastel 1 · Leyenda',
                      'Feliz día',
                      'Feliz cumpleaños Ana',
                    ),
                  ],
                ),
                eventoJson(evento: 'creada', version: 1),
              ],
            ),
          );

        await vm.enterado.execute();

        expect(vm.enterado.error, isA<ConflictoComandaException>());
        expect(vm.detalle!.version, 3);
        expect(vm.cambio!.desde, 2);
        expect(vm.cambio!.hasta, 3);
        expect(
          vm.cambio!.cambios.single.texto,
          'Pastel 1 · Leyenda: Feliz día → Feliz cumpleaños Ana',
        );

        vm.descartarCambio();
        expect(vm.cambio, isNull);
      },
    );

    test('ya la confirmó un compañero: recarga sin caja de cambios', () async {
      await vm.cargar();
      api
        ..responder(_confirmar, {
          'success': false,
          'codigo': 'YA_CONFIRMADA',
          'message': 'Esta versión ya la confirmó Rosa Pérez (Hornos).',
        })
        ..responder(
          _detalle,
          detalleJson(version: 2, confirmar: null, hornos: _firmaHornosV2),
        );

      await vm.enterado.execute();

      expect(
        (vm.enterado.error! as ApiException).message,
        'Esta versión ya la confirmó Rosa Pérez (Hornos).',
      );
      expect(vm.detalle!.confirmar, isNull);
      expect(vm.cambio, isNull);
    });

    test('otro error al confirmar: lo deja en el comando', () async {
      await vm.cargar();
      api.fallar(_confirmar, 'Error al registrar el enterado');

      await vm.enterado.execute();

      expect(
        (vm.enterado.error! as ApiException).message,
        'Error al registrar el enterado',
      );
      expect(vm.detalle!.version, 2);
    });

    test('sesión inválida al cargar o al confirmar', () async {
      api.responder(_detalle, {
        'success': false,
        'codigo': 'SESION_INVALIDA',
        'message': 'Tu cuenta está desactivada o cambió.',
      });
      await vm.cargar();

      expect(vm.sesionInvalida, isTrue);
      expect(vm.error, 'Tu cuenta está desactivada o cambió.');
    });

    test('sin detalle cargado, Enterado no hace nada', () async {
      await vm.enterado.execute();

      expect(api.llamo(_confirmar), isFalse);
    });

    test('tras dispose no avisa', () async {
      api.demorar(_detalle, const Duration(milliseconds: 20));
      final carga = vm.cargar();
      vm.dispose();
      await expectLater(carga, completes);
    });
  });
}
