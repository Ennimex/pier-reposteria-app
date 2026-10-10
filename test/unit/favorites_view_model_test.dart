// test/unit/favorites_view_model_test.dart — «Mis Favoritos» (MVVM, Fase 3)
// sin red: los repositorios tipan quitar y las categorías, y el ViewModel
// lleva la lista, la búsqueda, quitar (optimista) y «Avísame».
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/ui/favorites/view_model/favorites_view_model.dart';

import '../fakes/fake_api_client.dart';

const String _favoritos = ApiConstants.favoritos;
const String _categorias = ApiConstants.categorias;
final String _quitar36 = ApiConstants.favoritoById('36');

final Map<String, dynamic> _conDatos = {
  _favoritos: {
    'success': true,
    'favoritos': [
      {'id': 36, 'nombre': 'Fresa Matcha Bliss', 'categoria': 'Pasteles'},
      {'id': 40, 'nombre': 'Pay de queso', 'categoria': 'Pays'},
      {'id': 41, 'nombre': 'Latte', 'categoria': 'Cafetería'},
    ],
  },
  _categorias: {
    'success': true,
    'categorias': [
      {'id': 1, 'nombre': 'Pasteles'},
      {'id': 2, 'name': 'Roscas'},
      {'id': 3, 'nombre': ''},
      'basura',
      {'id': 4, 'nombre': 'Pays'},
      {'id': 5, 'nombre': 'Postres'},
      {'id': 6, 'nombre': 'Bebidas'},
    ],
  },
  _quitar36: {'success': true},
};

FavoritesViewModel _vm(FakeApiClient api, {List<String>? avisos}) =>
    FavoritesViewModel(
      favoritosRepo: FavoritosRepository(api: api),
      productosRepo: ProductosRepository(api: api),
      registrarInteres: avisos?.add ?? (_) {},
    );

void main() {
  group('Repositorios', () {
    test('quitarFavorito llama DELETE autenticado', () async {
      final api = FakeApiClient(respuestas: _conDatos);

      await FavoritosRepository(api: api).quitarFavorito('36');

      expect(api.llamo(_quitar36, metodo: 'DELETE-Auth'), isTrue);
    });

    test('quitarFavorito lanza ApiException con el mensaje del backend',
        () async {
      final api = FakeApiClient()..fallar(_quitar36, 'No autorizado');

      expect(
        () => FavoritosRepository(api: api).quitarFavorito('36'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'No autorizado')),
      );
    });

    test('nombresDeCategorias acepta nombre o name e ignora vacíos y basura',
        () async {
      final api = FakeApiClient(respuestas: _conDatos);

      final nombres = await ProductosRepository(api: api).nombresDeCategorias();

      expect(nombres, ['Pasteles', 'Roscas', 'Pays', 'Postres', 'Bebidas']);
    });

    test('nombresDeCategorias lee la lista en data', () async {
      final api = FakeApiClient(respuestas: {
        _categorias: {
          'success': true,
          'data': [
            {'nombre': 'Panes'},
          ],
        },
      });

      expect(await ProductosRepository(api: api).nombresDeCategorias(),
          ['Panes']);
    });

    test('nombresDeCategorias lanza ApiException si falla', () async {
      final api = FakeApiClient()..fallar(_categorias, 'Caído');

      expect(() => ProductosRepository(api: api).nombresDeCategorias(),
          throwsA(isA<ApiException>()));
    });
  });

  group('FavoritesViewModel', () {
    test('arranca cargando y termina con la lista y las categorías', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      expect(vm.cargando, isTrue);

      await vm.cargar();

      expect(vm.cargando, isFalse);
      expect(vm.favoritos.map((p) => p.id), ['36', '40', '41']);
      expect(vm.categoriasSugeridas, ['Pasteles', 'Roscas', 'Pays', 'Postres']);
    });

    test('si fallan las categorías usa las de respaldo', () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_categorias, 'Caído');
      final vm = _vm(api);

      await vm.cargar();

      expect(vm.categoriasSugeridas, FavoritesViewModel.categoriasDeRespaldo);
    });

    test('si falla la recarga se queda la lista anterior', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();

      api.fallar(_favoritos, 'Token expirado');
      await vm.cargarFavoritos();

      expect(vm.favoritos, hasLength(3));
      expect(vm.cargando, isFalse);
    });

    test('busca por nombre o categoría sin distinguir mayúsculas', () async {
      final vm = _vm(FakeApiClient(respuestas: _conDatos));
      await vm.cargar();

      vm.buscar('PAY');
      expect(vm.filtrados.map((p) => p.id), ['40']);

      vm.buscar('cafeter');
      expect(vm.filtrados.map((p) => p.id), ['41']);

      vm.buscar('');
      expect(vm.filtrados, hasLength(3));
    });

    test('quitar lo saca de la lista y avisa al backend', () async {
      final api = FakeApiClient(respuestas: _conDatos);
      final vm = _vm(api);
      await vm.cargar();

      final ok = await vm.quitar(vm.favoritos.first);

      expect(ok, isTrue);
      expect(vm.favoritos.map((p) => p.id), ['40', '41']);
      expect(api.llamo(_quitar36, metodo: 'DELETE-Auth'), isTrue);
    });

    test('si quitar falla lo regresa a su mismo lugar', () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..fallar(_quitar36, 'Error');
      final vm = _vm(api);
      await vm.cargar();
      final fresa = vm.favoritos.first;

      final futuro = vm.quitar(fresa);
      expect(vm.favoritos, isNot(contains(fresa))); // optimista
      final ok = await futuro;

      expect(ok, isFalse);
      expect(vm.favoritos.map((p) => p.id), ['36', '40', '41']);
    });

    test('avisarme registra el interés con el id del producto', () async {
      final avisos = <String>[];
      final vm = _vm(FakeApiClient(respuestas: _conDatos), avisos: avisos);
      await vm.cargar();

      vm.avisarme(vm.favoritos[1]);

      expect(avisos, ['40']);
    });

    test('no notifica después de dispose', () async {
      final api = FakeApiClient(respuestas: _conDatos)
        ..demorar(_favoritos, const Duration(milliseconds: 20));
      final vm = _vm(api);
      final carga = vm.cargar();

      vm.dispose();

      await expectLater(carga, completes);
    });
  });
}
