// test/unitarias/resenas/product_reviews_view_model_test.dart — «Opiniones» de un
// producto (MVVM, Fase 3) sin red: el repositorio tipa la lista y «útil», y
// el ViewModel lleva resumen, filtro, orden y «útil» (toggle del backend).
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/api_exception.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/ui/reviews/view_model/product_reviews_view_model.dart';

import '../../fakes/fake_api_client.dart';

final String _lista = ApiConstants.resenasPorProducto('36');
final String _like1 = ApiConstants.likeResena('1');

Map<String, dynamic> _conDatos() => {
      _lista: {
        'success': true,
        'resenas': [
          {
            'id': 1,
            'rating': '5',
            'titulo': 'Delicioso',
            'comentario': 'El mejor',
            'util_count': 3,
            'verificada': true,
            'autor_nombre': 'Ana',
            'autor_apellido': 'García',
            'created_at': '2026-10-01T12:00:00Z',
          },
          {'id': 2, 'rating': 3.4, 'autor_nombre': 'Luis', 'util_count': '0'},
          {'id': 3, 'rating': 4, 'autor_nombre': 'Eva', 'autor_apellido': ''},
          'basura',
        ],
      },
      _like1: {'success': true, 'liked': true},
    };

ProductReviewsViewModel _vm(FakeApiClient api) => ProductReviewsViewModel(
      repo: ResenasRepositoryRemote(api: api),
      productoId: '36',
    );

void main() {
  group('ResenaProducto y repositorio', () {
    test('listarDeProducto tipa, tolera faltantes e ignora basura', () async {
      final api = FakeApiClient(respuestas: _conDatos());

      final lista = await ResenasRepositoryRemote(api: api).listarDeProducto('36');

      expect(lista, hasLength(3));
      final r = lista.first;
      expect(r.rating, 5);
      expect(r.utilCount, 3);
      expect(r.verificada, isTrue);
      expect(r.autor, 'Ana G.');
      expect(r.creadaEn, isNotNull);
      expect(lista[1].autor, 'Luis');
      expect(lista[1].estrellas, 3);
      expect(lista[1].verificada, isFalse);
      expect(api.llamo(_lista, metodo: 'GET'), isTrue);
    });

    test('listarDeProducto lanza ApiException si falla', () async {
      final api = FakeApiClient()..fallar(_lista, 'Caído');

      expect(() => ResenasRepositoryRemote(api: api).listarDeProducto('36'),
          throwsA(isA<ApiException>()));
    });

    test('alternarUtil devuelve cómo quedó según el backend', () async {
      final api = FakeApiClient(respuestas: {
        _like1: {'success': true, 'liked': false},
      });

      expect(await ResenasRepositoryRemote(api: api).alternarUtil('1'), isFalse);
      expect(api.llamo(_like1, metodo: 'POST-Auth'), isTrue);
    });
  });

  group('ProductReviewsViewModel', () {
    test('carga y calcula promedio y distribución', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos()));
      expect(vm.cargando, isTrue);

      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.promedio, closeTo(4.13, 0.01));
      expect(vm.distribucion, {5: 1, 4: 1, 3: 1, 2: 0, 1: 0});
    });

    test('filtra por estrellas y ordena', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos()));
      await vm.cargar();

      expect(vm.filtradas.map((r) => r.id), ['1', '2', '3']); // backend

      vm.filtrar(4);
      expect(vm.filtradas.map((r) => r.id), ['3']);

      vm
        ..filtrar(0)
        ..ordenar(OrdenResenas.peor);
      expect(vm.filtradas.map((r) => r.id), ['2', '3', '1']);

      vm.ordenar(OrdenResenas.mejor);
      expect(vm.filtradas.map((r) => r.id), ['1', '3', '2']);
    });

    test('útil suma al instante y queda marcada si el backend confirma',
        () async {
      final api = FakeApiClient(respuestas: _conDatos());
      final vm = _vm(api);
      await vm.cargar();

      await vm.alternarUtil('1');

      expect(vm.esUtil('1'), isTrue);
      expect(vm.resenas.first.utilCount, 4);
    });

    test('si ya estaba marcada de otra visita, se ajusta a lo que responde',
        () async {
      final api = FakeApiClient(respuestas: _conDatos())
        ..responder(_like1, {'success': true, 'liked': false});
      final vm = _vm(api);
      await vm.cargar();

      await vm.alternarUtil('1');

      // El backend la quitó: 3 incluía la marca del cliente.
      expect(vm.esUtil('1'), isFalse);
      expect(vm.resenas.first.utilCount, 2);
    });

    test('si el backend falla se revierte', () async {
      final api = FakeApiClient(respuestas: _conDatos())
        ..fallar(_like1, 'Error');
      final vm = _vm(api);
      await vm.cargar();

      await vm.alternarUtil('1');

      expect(vm.esUtil('1'), isFalse);
      expect(vm.resenas.first.utilCount, 3);
    });

    test('si falla la recarga se queda la lista anterior', () async {
      final api = FakeApiClient(respuestas: _conDatos());
      final vm = _vm(api);
      await vm.cargar();

      api.fallar(_lista, 'Caído');
      await vm.cargar();

      expect(vm.resenas, hasLength(3));
      expect(vm.cargando, isFalse);
    });
  });

  group('votos «útil» que se conservan (#42)', () {
    final misUtiles = ApiConstants.misUtiles('36');

    test('con sesión marca las que el cliente ya votó', () async {
      final api = FakeApiClient(respuestas: {
        ..._conDatos(),
        misUtiles: {
          'success': true,
          'ids': [1, 3],
        },
      });
      final vm = _vm(api);

      await vm.cargar(conSesion: true);

      expect(vm.esUtil('1'), isTrue);
      expect(vm.esUtil('2'), isFalse);
      expect(vm.esUtil('3'), isTrue);
      expect(api.llamo(misUtiles, metodo: 'GET-Auth'), isTrue);
    });

    test('sin sesión no los pide', () async {
      final api = FakeApiClient(respuestas: _conDatos());

      await _vm(api).cargar();

      expect(api.llamo(misUtiles), isFalse);
    });

    test('si fallan los votos, las reseñas se muestran igual', () async {
      final api = FakeApiClient(respuestas: _conDatos())
        ..fallar(misUtiles, 'Caído');
      final vm = _vm(api);

      await vm.cargar(conSesion: true);

      expect(vm.resenas, hasLength(3));
      expect(vm.esUtil('1'), isFalse);
      expect(vm.cargando, isFalse);
    });

    test('votar la propia opinión devuelve el motivo y se revierte', () async {
      final api = FakeApiClient(respuestas: _conDatos())
        ..fallar(_like1, 'No puedes marcar como útil tu propia opinión');
      final vm = _vm(api);
      await vm.cargar();

      final error = await vm.alternarUtil('1');

      expect(error, 'No puedes marcar como útil tu propia opinión');
      expect(vm.esUtil('1'), isFalse);
    });

    test('un voto que pasa no devuelve error', () async {
      final api = FakeApiClient(respuestas: _conDatos());
      final vm = _vm(api);
      await vm.cargar();

      expect(await vm.alternarUtil('1'), isNull);
      expect(await vm.alternarUtil('no-existe'), isNull);
    });

    test('misUtiles lanza ApiException si la respuesta no trae ids', () async {
      final api = FakeApiClient(respuestas: {
        misUtiles: {'success': true},
      });

      await expectLater(
        ResenasRepositoryRemote(api: api).misUtiles('36'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
