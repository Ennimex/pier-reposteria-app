// test/unit/products_view_model_test.dart — ViewModel del catálogo (MVVM,
// Fase 4) sin red: filtrado local, orden, categorías, opciones por categoría,
// favoritos optimistas y registro de demanda no atendida.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/ui/products/view_model/products_view_model.dart';

import '../fakes/fake_api_client.dart';

Product _producto(
  String id,
  String nombre, {
  double precio = 100,
  String categoria = 'Pasteles',
  String? sabor,
  String? tamano,
  String? tipo,
  bool popular = false,
  bool agotado = false,
  String descripcion = '',
}) =>
    Product.fromJson({
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio_chico': precio,
      'categoria': categoria,
      'sabor': sabor,
      'tamano': tamano,
      'tipo': tipo,
      'popular': popular,
      'stock_online': agotado ? 0 : null,
      'activo': true,
    });

final List<Product> _catalogo = [
  _producto('1', 'Chocoflan', precio: 300, sabor: 'Chocolate', popular: true),
  _producto('2', 'Cheesecake fresa', precio: 450, categoria: 'Cheesecakes',
      sabor: 'Fresa', tamano: 'Grande'),
  _producto('3', 'Pay de limón', precio: 200, categoria: 'Pays',
      sabor: 'Limón', tipo: 'Frío', agotado: true),
  _producto('4', 'Arcoíris', precio: 350, sabor: 'Vainilla',
      descripcion: 'Capas de colores'),
];

ProductsViewModel _vm(
  FakeApiClient api, {
  String categoriaInicial = ProductsViewModel.todas,
  List<Product>? catalogo,
}) =>
    ProductsViewModel(
      productosRepo: ProductosRepositoryRemote(api: api),
      favoritosRepo: FavoritosRepositoryRemote(api: api),
      demandaRepo: DemandaRepositoryRemote(api: api),
      catalogo: () => catalogo ?? _catalogo,
      categoriaInicial: categoriaInicial,
      esperaRegistroBusqueda: Duration.zero,
    );

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.categorias: {
        'success': true,
        'categorias': [
          {'id': 1, 'nombre': 'Pasteles'},
          {'id': 2, 'nombre': 'Pays'},
        ],
      },
      ApiConstants.filtros: {
        'success': true,
        'filtros': {
          'sabores': ['Chocolate', 'Fresa', 'Limón'],
          'tamanos': ['Chico', 'Grande'],
          'tipos': ['Frío', 'Horneado'],
        },
      },
      ApiConstants.categoriaOpciones('2'): {
        'success': true,
        'sabores': [
          {'nombre': 'Limón'},
          'Maracuyá',
          {'nombre': ''},
        ],
        'tipos': <dynamic>[],
      },
      ApiConstants.favoritosIds: {
        'success': true,
        'ids': [2, '4'],
      },
      ApiConstants.busquedas: {'success': true, 'registrado': true},
      ApiConstants.clicsAgotados: {'success': true},
    });

List<String> _nombres(List<Product> lista) => lista.map((p) => p.nombre).toList();

/// Deja correr los timers en cero y los envíos sin await de la demanda.
Future<void> _esperar() => Future<void>.delayed(Duration.zero);

void main() {
  group('filtrar', () {
    test('popular primero y lo agotado siempre al final', () {
      final vm = _vm(FakeApiClient());
      expect(_nombres(vm.filtrar(_catalogo)),
          ['Chocoflan', 'Cheesecake fresa', 'Arcoíris', 'Pay de limón']);
    });

    test('por categoría y por búsqueda en nombre, descripción o categoría', () {
      final vm = _vm(FakeApiClient(), categoriaInicial: 'Pasteles');
      expect(_nombres(vm.filtrar(_catalogo)), ['Chocoflan', 'Arcoíris']);

      vm
        ..limpiarTodo()
        ..buscar('COLORES');
      expect(_nombres(vm.filtrar(_catalogo)), ['Arcoíris']);

      vm.buscar('cheese');
      expect(_nombres(vm.filtrar(_catalogo)), ['Cheesecake fresa']);
    });

    test('sabor, tamaño y tipo se alternan y se combinan', () {
      final vm = _vm(FakeApiClient())..alternarSabor('Fresa');
      expect(_nombres(vm.filtrar(_catalogo)), ['Cheesecake fresa']);
      expect(vm.hayFiltrosDeOpciones, isTrue);

      vm.alternarTamano('Chico');
      expect(vm.filtrar(_catalogo), isEmpty);

      vm
        ..alternarTamano('Chico')
        ..alternarSabor('Fresa')
        ..alternarTipo('Frío');
      expect(_nombres(vm.filtrar(_catalogo)), ['Pay de limón']);

      vm.limpiarFiltrosDeOpciones();
      expect(vm.hayFiltrosDeOpciones, isFalse);
      expect(vm.filtrar(_catalogo), hasLength(4));
    });

    test('ordena por precio y por nombre', () {
      final vm = _vm(FakeApiClient())..ordenarPor(SortOption.priceAsc);
      expect(_nombres(vm.filtrar(_catalogo)).first, 'Chocoflan');
      vm.ordenarPor(SortOption.priceDesc);
      expect(_nombres(vm.filtrar(_catalogo)).first, 'Cheesecake fresa');
      vm.ordenarPor(SortOption.nameAsc);
      expect(_nombres(vm.filtrar(_catalogo)).first, 'Arcoíris');
      vm.ordenarPor(SortOption.nameDesc);
      expect(_nombres(vm.filtrar(_catalogo)).first, 'Chocoflan');
      // Agotado al final aunque el orden lo pusiera antes.
      expect(_nombres(vm.filtrar(_catalogo)).last, 'Pay de limón');
    });

    test('limpiarTodo regresa búsqueda, categoría, orden y filtros', () {
      final vm = _vm(FakeApiClient(), categoriaInicial: 'Pays')
        ..buscar('x')
        ..ordenarPor(SortOption.nameDesc)
        ..alternarSabor('Fresa');
      expect(vm.hayFiltros, isTrue);

      vm.limpiarTodo();

      expect(vm.hayFiltros, isFalse);
      expect(vm.categoria, ProductsViewModel.todas);
      expect(vm.orden, SortOption.popular);
      expect(vm.busqueda, isEmpty);
    });
  });

  group('carga', () {
    test('sin categorías del backend usa las de respaldo', () {
      expect(_vm(FakeApiClient()).nombresCategorias,
          ProductsViewModel.categoriasDeRespaldo);
    });

    test('carga categorías, filtros globales y favoritos', () async {
      final vm = _vm(_backend());

      await vm.cargar(autenticado: true);

      expect(vm.nombresCategorias, ['Todos', 'Pasteles', 'Pays']);
      expect(vm.filtrosCargados, isTrue);
      expect(vm.sabores, ['Chocolate', 'Fresa', 'Limón']);
      expect(vm.tamanos, ['Chico', 'Grande']);
      expect(vm.tipos, ['Frío', 'Horneado']);
      expect(vm.esFavorito('2'), isTrue);
      expect(vm.esFavorito('4'), isTrue);
      expect(vm.esFavorito('1'), isFalse);
    });

    test('si el backend falla se queda sin filtros ni categorías', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.categorias, 'caído')
        ..fallar(ApiConstants.filtros, 'caído')
        ..fallar(ApiConstants.favoritosIds, 'caído');
      final vm = _vm(api);

      await vm.cargar(autenticado: true);

      expect(vm.filtrosCargados, isFalse);
      expect(vm.nombresCategorias, ProductsViewModel.categoriasDeRespaldo);
      expect(vm.sabores, isEmpty);
    });

    test('sin sesión no pide favoritos y limpia los anteriores', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargarFavoritos(autenticado: true);
      expect(vm.esFavorito('2'), isTrue);

      await vm.cargarFavoritos(autenticado: false);

      expect(vm.esFavorito('2'), isFalse);
      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.favoritosIds),
          hasLength(1));
    });
  });

  group('opciones por categoría', () {
    test('la categoría con opciones propias reemplaza sabores y limpia '
        'los filtros que ya no existen', () async {
      final vm = _vm(_backend());
      await vm.cargar(autenticado: false);
      vm.alternarSabor('Fresa');

      await vm.seleccionarCategoria('Pays');

      expect(vm.sabores, ['Limón', 'Maracuyá']);
      // Sin tipos propios se quedan los globales.
      expect(vm.tipos, ['Frío', 'Horneado']);
      expect(vm.filtroSabor, isNull);
    });

    test('entrar con categoría preseleccionada carga sus opciones', () async {
      final vm = _vm(_backend(), categoriaInicial: 'Pays');
      await vm.cargarCategorias();
      expect(vm.sabores, ['Limón', 'Maracuyá']);
    });

    test('volver a Todos regresa al set global', () async {
      final vm = _vm(_backend());
      await vm.cargar(autenticado: false);
      await vm.seleccionarCategoria('Pays');

      await vm.seleccionarCategoria(ProductsViewModel.todas);

      expect(vm.sabores, ['Chocolate', 'Fresa', 'Limón']);
    });

    test('una categoría sin id conocido no pide opciones', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargar(autenticado: false);

      await vm.seleccionarCategoria('Roscas');

      expect(api.llamadas.any((l) => l.endpoint.startsWith('/categoria-opciones')),
          isFalse);
    });
  });

  group('favoritos', () {
    test('agregar y quitar van al backend al instante', () async {
      final api = _backend()
        ..responder(ApiConstants.favoritoById('1'), {'success': true});
      final vm = _vm(api);

      expect(await vm.alternarFavorito('1'), isNull);
      expect(vm.esFavorito('1'), isTrue);
      expect(api.ultima(ApiConstants.favoritoById('1'))!.metodo, 'POST-Auth');

      expect(await vm.alternarFavorito('1'), isNull);
      expect(vm.esFavorito('1'), isFalse);
      expect(api.llamo(ApiConstants.favoritoById('1'), metodo: 'DELETE-Auth'),
          isTrue);
    });

    test('si el backend falla se revierte y devuelve su mensaje', () async {
      final api = FakeApiClient()
        ..fallar(ApiConstants.favoritoById('9'), 'Sin sesión');
      final vm = _vm(api);
      var avisos = 0;
      vm.addListener(() => avisos++);

      final error = await vm.alternarFavorito('9');

      expect(error, 'Sin sesión');
      expect(vm.esFavorito('9'), isFalse);
      expect(avisos, 2); // marcado optimista + reversión
    });
  });

  group('demanda no atendida', () {
    test('la búsqueda se registra con cuántos resultados dio', () async {
      final api = _backend();
      _vm(api).buscar('fresa');

      await _esperar();
      await _esperar();

      final registro = api.ultima(ApiConstants.busquedas)!;
      expect(registro.body, {'texto': 'fresa', 'num_resultados': 1});
    });

    test('términos de menos de 2 letras o borrados no se registran', () async {
      final api = _backend();
      _vm(api).buscar('f');
      _vm(api)
        ..buscar('fresa')
        ..limpiarBusqueda();

      await _esperar();
      await _esperar();

      expect(api.llamo(ApiConstants.busquedas), isFalse);
    });

    test('Avísame registra el clic en el agotado', () async {
      final api = _backend();
      _vm(api).avisarme(_catalogo[2]);

      await _esperar();

      expect(api.ultima(ApiConstants.clicsAgotados)!.body, {'producto_id': 3});
    });

    test('al cerrar la pantalla ya no se registra la búsqueda pendiente',
        () async {
      final api = _backend();
      _vm(api)
        ..buscar('fresa')
        ..dispose();

      await _esperar();

      expect(api.llamo(ApiConstants.busquedas), isFalse);
    });
  });
}
