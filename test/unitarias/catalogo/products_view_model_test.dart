// test/unitarias/catalogo/products_view_model_test.dart — ViewModel del catálogo (MVVM,
// Fase 4) sin red: la consulta que se le manda al servidor (categoría,
// búsqueda, filtros y orden), categorías, opciones por categoría, favoritos
// optimistas y registro de demanda no atendida. Las páginas, en
// catalogo_paginado_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';

import '../../fakes/fake_api_client.dart';

Map<String, dynamic> _producto(
  int id,
  String nombre, {
  String categoria = 'Pasteles',
  bool agotado = false,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'precio_chico': 100,
      'categoria': categoria,
      'stock_online': agotado ? 0 : null,
      'activo': true,
    };

final List<Map<String, dynamic>> _catalogo = [
  _producto(1, 'Chocoflan'),
  _producto(2, 'Cheesecake fresa', categoria: 'Cheesecakes'),
  _producto(3, 'Pay de limón', categoria: 'Pays', agotado: true),
  _producto(4, 'Arcoíris'),
];

/// GET /productos como el servidor: los del catálogo cuyo nombre tiene la
/// `busqueda` (sin ella, todos).
Map<String, dynamic> _productosQueCoinciden(LlamadaApi llamada) {
  final busqueda =
      Uri.parse(llamada.endpoint).queryParameters['busqueda'] ?? '';
  return {
    'success': true,
    'productos': [
      for (final p in _catalogo)
        if ((p['nombre'] as String)
            .toLowerCase()
            .contains(busqueda.toLowerCase()))
          p,
    ],
  };
}

ProductsViewModel _vm(
  FakeApiClient api, {
  String categoriaInicial = ProductsViewModel.todas,
}) =>
    ProductsViewModel(
      productosRepo: ProductosRepositoryRemote(api: api),
      favoritosRepo: FavoritosRepositoryRemote(api: api),
      demandaRepo: DemandaRepositoryRemote(api: api),
      categoriaInicial: categoriaInicial,
      esperaBusqueda: Duration.zero,
      esperaRegistroBusqueda: Duration.zero,
    );

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.productos: _productosQueCoinciden,
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

/// Las peticiones de productos, en orden.
List<String> _pedidas(FakeApiClient api) => [
      for (final l in api.llamadas)
        if (l.endpoint.startsWith(ApiConstants.productos)) l.endpoint,
    ];

/// Deja correr los timers en cero y los envíos sin await de la demanda.
Future<void> _esperar() => Future<void>.delayed(Duration.zero);

void main() {
  group('parámetros de la consulta', () {
    test('por omisión no filtra ni ordena', () {
      final consulta = _vm(FakeApiClient()).consulta;

      expect(consulta.parametros, isEmpty);
      expect(consulta.orden, SortOption.popular);
    });

    test('por categoría y por búsqueda, recortada', () {
      final vm = _vm(FakeApiClient(), categoriaInicial: 'Pasteles');
      expect(vm.consulta.parametros, {'categoria': 'Pasteles'});

      vm
        ..limpiarTodo()
        ..buscar('  COLORES ');
      expect(vm.consulta.parametros, {'busqueda': 'COLORES'});
      expect(vm.busqueda, '  COLORES ', reason: 'el buscador no cambia');
    });

    test('sabor, tamaño y tipo se alternan y se combinan', () {
      final vm = _vm(FakeApiClient())..alternarSabor('Fresa');
      expect(vm.consulta.parametros, {'sabor': 'Fresa'});
      expect(vm.hayFiltrosDeOpciones, isTrue);

      vm
        ..alternarTamano('Chico')
        ..alternarTipo('Frío');
      expect(vm.consulta.parametros,
          {'sabor': 'Fresa', 'tamano': 'Chico', 'tipo': 'Frío'});

      vm
        ..alternarTamano('Chico')
        ..alternarSabor('Fresa');
      expect(vm.consulta.parametros, {'tipo': 'Frío'});

      vm.limpiarFiltrosDeOpciones();
      expect(vm.hayFiltrosDeOpciones, isFalse);
      expect(vm.consulta.parametros, isEmpty);
    });

    test('ordena por precio, por nombre y por calificación', () {
      final vm = _vm(FakeApiClient())..ordenarPor(SortOption.priceAsc);
      expect(vm.consulta.parametros, {'ordenar': 'precio-asc'});
      vm.ordenarPor(SortOption.priceDesc);
      expect(vm.consulta.parametros, {'ordenar': 'precio-desc'});
      vm.ordenarPor(SortOption.nameAsc);
      expect(vm.consulta.parametros, {'ordenar': 'nombre'});
      vm.ordenarPor(SortOption.rating);
      expect(vm.consulta.parametros, {'ordenar': 'rating'});
    });

    test('limpiarTodo regresa búsqueda, categoría, orden y filtros', () {
      final vm = _vm(FakeApiClient(), categoriaInicial: 'Pays')
        ..buscar('x')
        ..ordenarPor(SortOption.rating)
        ..alternarSabor('Fresa');
      expect(vm.hayFiltros, isTrue);

      vm.limpiarTodo();

      expect(vm.hayFiltros, isFalse);
      expect(vm.categoria, ProductsViewModel.todas);
      expect(vm.orden, SortOption.popular);
      expect(vm.busqueda, isEmpty);
      expect(vm.consulta.parametros, isEmpty);
    });

    test('cada cambio vuelve a pedir la página 1 con su consulta', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargarProductos();

      vm.alternarSabor('Fresa');
      await _esperar();
      expect(_pedidas(api).last, '/productos?sabor=Fresa&limite=20&offset=0');

      await vm.seleccionarCategoria('Pasteles');
      await _esperar();
      expect(_pedidas(api).last,
          '/productos?categoria=Pasteles&sabor=Fresa&limite=20&offset=0');

      vm.limpiarFiltrosDeOpciones();
      await _esperar();
      expect(_pedidas(api).last,
          '/productos?categoria=Pasteles&limite=20&offset=0');

      vm.buscar('fresa');
      await _esperar();
      expect(_pedidas(api).last,
          '/productos?categoria=Pasteles&busqueda=fresa&limite=20&offset=0');

      vm.limpiarBusqueda();
      await _esperar();
      expect(_pedidas(api).last,
          '/productos?categoria=Pasteles&limite=20&offset=0');

      vm.limpiarTodo();
      await _esperar();
      expect(_pedidas(api).last, '/productos?limite=20&offset=0');
    });

    test('lo que no cambia la consulta no vuelve a preguntar', () async {
      final api = _backend();
      final vm = _vm(api)..buscar('fresa');
      await _esperar();

      vm
        ..buscar('fresa  ')
        ..limpiarFiltrosDeOpciones();
      await _esperar();

      expect(_pedidas(api), ['/productos?busqueda=fresa&limite=20&offset=0']);
    });
  });

  group('carga', () {
    test('sin categorías del backend usa las de respaldo', () {
      expect(_vm(FakeApiClient()).nombresCategorias,
          ProductsViewModel.categoriasDeRespaldo);
    });

    test('carga la primera página, categorías, filtros globales y favoritos',
        () async {
      final vm = _vm(_backend());

      await vm.cargar(autenticado: true);

      expect(vm.productos.map((p) => p.nombre),
          ['Chocoflan', 'Cheesecake fresa', 'Arcoíris', 'Pay de limón']);
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

    test('recargar pide de nuevo la página 1, categorías y filtros', () async {
      final api = _backend();
      final vm = _vm(api);
      await vm.cargar(autenticado: false);
      api.llamadas.clear();

      await vm.recargar();

      expect(api.llamadas.map((l) => l.endpoint), unorderedEquals([
        '/productos?limite=20&offset=0',
        ApiConstants.categorias,
        ApiConstants.filtros,
      ]));
      expect(vm.productos, hasLength(4));
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
      final api = _backend();
      final vm = _vm(api);
      await vm.cargar(autenticado: false);
      vm.alternarSabor('Fresa');

      await vm.seleccionarCategoria('Pays');
      await _esperar();

      expect(vm.sabores, ['Limón', 'Maracuyá']);
      // Sin tipos propios se quedan los globales.
      expect(vm.tipos, ['Frío', 'Horneado']);
      expect(vm.filtroSabor, isNull);
      // Y la página 1 se vuelve a pedir sin el sabor que se quitó.
      expect(_pedidas(api).last, '/productos?categoria=Pays&limite=20&offset=0');
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
    test('la búsqueda se registra con cuántos trajo su primera página',
        () async {
      final api = _backend();
      _vm(api).buscar('fresa');

      await _esperar();
      await _esperar();

      final registro = api.ultima(ApiConstants.busquedas)!;
      expect(registro.body, {'texto': 'fresa', 'num_resultados': 1});
    });

    test('si la primera página tarda, la búsqueda se registra al llegar',
        () async {
      final api = _backend()
        ..demorar('/productos?busqueda=fresa&limite=20&offset=0',
            const Duration(milliseconds: 20));
      _vm(api).buscar('fresa');

      await _esperar();
      await _esperar();
      expect(api.llamo(ApiConstants.busquedas), isFalse,
          reason: 'su primera página no ha llegado');

      await Future<void>.delayed(const Duration(milliseconds: 40));
      await _esperar();

      final registro = api.ultima(ApiConstants.busquedas)!;
      expect(registro.body, {'texto': 'fresa', 'num_resultados': 1});
    });

    test('una búsqueda cuya página no llegó no se registra', () async {
      final api = _backend()..fallar(ApiConstants.productos, 'Sin conexión');
      _vm(api).buscar('fresa');

      await _esperar();
      await _esperar();

      expect(api.llamo(ApiConstants.busquedas), isFalse);
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
      _vm(api).avisarme(Product.fromJson(_catalogo[2]));

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
