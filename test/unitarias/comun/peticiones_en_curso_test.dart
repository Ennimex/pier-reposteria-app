// test/unitarias/comun/peticiones_en_curso_test.dart — PeticionesEnCurso
// comparte una petición que ya va en camino (#341) y, cuando termina, deja
// que la siguiente pida de nuevo. Con él, al abrir la app las promociones y
// las categorías se piden una vez aunque dos pantallas las pidan en el mismo
// cuadro.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/utils/peticiones_en_curso.dart';

import '../../fakes/fake_api_client.dart';

int _pedidas(FakeApiClient api, String endpoint) =>
    api.llamadas.where((llamada) => llamada.endpoint == endpoint).length;

void main() {
  group('PeticionesEnCurso', () {
    test('quien pide lo mismo mientras va en camino espera la misma respuesta',
        () async {
      final enCurso = PeticionesEnCurso<int>();
      final respuesta = Completer<int>();
      var pedidas = 0;
      Future<int> pedir() {
        pedidas++;
        return respuesta.future;
      }

      final primera = enCurso.compartir('a', pedir);
      final segunda = enCurso.compartir('a', pedir);
      respuesta.complete(7);

      expect(await primera, 7);
      expect(await segunda, 7);
      expect(pedidas, 1);
    });

    test('claves distintas no se comparten', () async {
      final enCurso = PeticionesEnCurso<String>();

      final respuestas = await Future.wait([
        enCurso.compartir('a', () async => 'de a'),
        enCurso.compartir('b', () async => 'de b'),
      ]);

      expect(respuestas, ['de a', 'de b']);
    });

    test('cuando ya terminó, la siguiente pide de nuevo', () async {
      final enCurso = PeticionesEnCurso<int>();
      var pedidas = 0;
      Future<int> pedir() async => ++pedidas;

      expect(await enCurso.compartir('a', pedir), 1);
      expect(await enCurso.compartir('a', pedir), 2);
    });

    test('si falla, todos reciben el error y la siguiente lo intenta otra vez',
        () async {
      final enCurso = PeticionesEnCurso<int>();
      var pedidas = 0;
      Future<int> pedir() async {
        if (++pedidas == 1) throw StateError('sin red');
        return pedidas;
      }

      final primera = enCurso.compartir('a', pedir);
      final segunda = enCurso.compartir('a', pedir);
      await expectLater(primera, throwsStateError);
      await expectLater(segunda, throwsStateError);

      expect(await enCurso.compartir('a', pedir), 2);
    });
  });

  group('ProductosRepositoryRemote', () {
    FakeApiClient backend() => FakeApiClient(respuestas: {
          ApiConstants.promocionesActivas: {
            'success': true,
            'promociones': [
              {
                'producto_id': 1,
                'tipo': 'temporada',
                'descuento_porcentaje': 10,
              },
            ],
          },
          ApiConstants.categorias: {
            'success': true,
            'categorias': [
              {'id': 1, 'nombre': 'Pasteles'},
            ],
          },
        });

    // El ProductProvider (precios de las tarjetas) y el Inicio (sus
    // secciones de ofertas) las piden en el mismo cuadro.
    test('las promociones pedidas dos veces a la vez van en una petición '
        '(#341)', () async {
      final api = backend();
      final repo = ProductosRepositoryRemote(api: api);

      final respuestas = await Future.wait<Object>([
        repo.promocionesActivas(),
        repo.promocionesDelInicio(),
      ]);

      expect(_pedidas(api, ApiConstants.promocionesActivas), 1);
      expect((respuestas[0] as Map)['success'], isTrue);
    }, tags: 'regresion');

    // El Inicio y el Catálogo las piden en el mismo cuadro.
    test('las categorías pedidas dos veces a la vez van en una petición '
        '(#341)', () async {
      final api = backend();
      final repo = ProductosRepositoryRemote(api: api);

      final respuestas = await Future.wait([
        repo.nombresDeCategorias(),
        repo.nombresDeCategorias(),
      ]);

      expect(_pedidas(api, ApiConstants.categorias), 1);
      expect(respuestas, [
        ['Pasteles'],
        ['Pasteles'],
      ]);
    }, tags: 'regresion');

    test('al jalar para recargar, las promociones se piden otra vez',
        () async {
      final api = backend();
      final repo = ProductosRepositoryRemote(api: api);
      await repo.promocionesActivas();

      await repo.promocionesActivas();

      expect(_pedidas(api, ApiConstants.promocionesActivas), 2);
    });
  });
}
