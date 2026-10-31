// test/unitarias/catalogo/catalogo_paginado_test.dart — el catálogo por
// páginas (#37): ProductsViewModel pide los productos de 20 en 20 con la
// consulta actual, termina con una página corta o vacía, hace una sola
// petición a la vez, descarta lo que llega tarde de una consulta anterior,
// vacía la lista al cambiar de consulta (al recargar la misma, no), no
// repite productos, deja los agotados para cuando ya no hay más, trae
// completos los órdenes que el servidor no desempata (precio y calificación)
// y espera a que se deje de teclear para buscar. Sin red.
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';

import '../../fakes/fake_api_client.dart';

/// Ids 1 a [total], en el orden del servidor.
List<int> _ids(int total) => [for (var i = 1; i <= total; i++) i];

Map<String, String> _parametros(LlamadaApi llamada) =>
    Uri.parse(llamada.endpoint).queryParameters;

/// GET /productos con lo que toca de [ids] según `limite` y `offset` (sin
/// `limite`, todos), como el servidor.
Map<String, dynamic> _pagina(
  LlamadaApi llamada,
  List<int> ids, {
  Set<int> agotados = const {},
}) {
  final q = _parametros(llamada);
  final limite = int.tryParse(q['limite'] ?? '');
  final offset = int.tryParse(q['offset'] ?? '') ?? 0;
  final pagina = limite == null ? ids : ids.skip(offset).take(limite);
  return {
    'success': true,
    'productos': [
      for (final id in pagina)
        {
          'id': id,
          'nombre': 'Producto $id',
          'precio_chico': 100,
          'categoria': 'Pasteles',
          'stock_online': agotados.contains(id) ? 0 : null,
          'activo': true,
        },
    ],
  };
}

const Map<String, dynamic> _caido = {
  'success': false,
  'message': 'Sin conexión',
};

FakeApiClient _servidor(RespuestaDinamica responder) =>
    FakeApiClient(respuestas: {ApiConstants.productos: responder});

/// Lo que tarda una respuesta que llega tarde; las demás llegan al instante
/// (en microtareas).
const _tarde = Duration(milliseconds: 10);

/// Deja que lleguen también las respuestas que llegan tarde.
Future<void> _esperarLoTardio() => Future<void>.delayed(_tarde * 3);

ProductsViewModel _vm(
  FakeApiClient api, {
  Duration esperaBusqueda = Duration.zero,
}) {
  final vm = ProductsViewModel(
    productosRepo: ProductosRepositoryRemote(api: api),
    favoritosRepo: FavoritosRepositoryRemote(api: api),
    demandaRepo: DemandaRepositoryRemote(api: api),
    esperaBusqueda: esperaBusqueda,
  );
  addTearDown(vm.dispose);
  return vm;
}

/// Las peticiones de productos, en orden.
List<String> _pedidas(FakeApiClient api) => [
      for (final l in api.llamadas)
        if (l.endpoint.startsWith(ApiConstants.productos)) l.endpoint,
    ];

List<String> _idsDe(ProductsViewModel vm) => [
      for (final p in vm.productos) p.id,
    ];

/// Deja llegar las respuestas (el servidor falso contesta en microtareas).
Future<void> _esperar() => Future<void>.delayed(Duration.zero);

void main() {
  group('Catálogo por páginas', () {
    test('pide la primera página con 20', () async {
      final api = _servidor((l) => _pagina(l, _ids(45)));
      final vm = _vm(api);

      final carga = vm.cargarProductos();
      expect(vm.cargando, isTrue);
      await carga;

      expect(_pedidas(api), ['/productos?limite=20&offset=0']);
      expect(vm.productos, hasLength(20));
      expect(vm.fin, isFalse);
      expect(vm.cargando, isFalse);
      expect(vm.error, isNull);
    });

    test('cargarMas pide la siguiente y agrega', () async {
      final api = _servidor((l) => _pagina(l, _ids(35)));
      final vm = _vm(api);
      await vm.cargarProductos();

      await vm.cargarMas();

      expect(_pedidas(api), [
        '/productos?limite=20&offset=0',
        '/productos?limite=20&offset=20',
      ]);
      expect(vm.productos, hasLength(35));
      expect(_idsDe(vm).last, '35');
      expect(vm.fin, isTrue);
    });

    test('una página exacta de 20 seguida de una vacía termina sin error',
        () async {
      final api = _servidor((l) => _pagina(l, _ids(20)));
      final vm = _vm(api);
      await vm.cargarProductos();
      expect(vm.fin, isFalse);

      await vm.cargarMas();

      expect(vm.fin, isTrue);
      expect(vm.errorMas, isNull);
      expect(vm.cargandoMas, isFalse);
      expect(vm.productos, hasLength(20));
      // Al terminar ya no pide más.
      await vm.cargarMas();
      expect(_pedidas(api), hasLength(2));
    });

    test('dos cargarMas seguidos hacen una sola petición', () async {
      final api = _servidor((l) => _pagina(l, _ids(45)));
      final vm = _vm(api);
      await vm.cargarProductos();

      final primera = vm.cargarMas();
      expect(vm.cargandoMas, isTrue);
      await vm.cargarMas();
      await primera;

      expect(
        _pedidas(api).where((e) => e.endsWith('offset=20')),
        hasLength(1),
      );
      expect(vm.productos, hasLength(40));
      expect(vm.cargandoMas, isFalse);
    });

    test('cambiar el filtro mientras llega una página la descarta', () async {
      final api = _servidor(
        (l) => _pagina(
          l,
          _parametros(l)['sabor'] == 'Fresa' ? [100] : _ids(45),
        ),
      )..demorar('/productos?limite=20&offset=20', _tarde);
      final vm = _vm(api);
      await vm.cargarProductos();

      // La segunda página de «todo» llega después de la página 1 de Fresa.
      final vieja = vm.cargarMas();
      vm.alternarSabor('Fresa');
      await vieja;

      expect(_idsDe(vm), ['100']);
      expect(vm.fin, isTrue);
      expect(vm.cargandoMas, isFalse);
      expect(_pedidas(api).last, '/productos?sabor=Fresa&limite=20&offset=0');
    });

    test('una primera página que llega tarde no pisa la consulta nueva',
        () async {
      final api = _servidor(
        (l) => _pagina(
          l,
          _parametros(l)['sabor'] == 'Fresa' ? [100] : _ids(45),
        ),
      )..demorar('/productos?limite=20&offset=0', _tarde);
      final vm = _vm(api);

      // La página 1 de «todo» llega después de la de Fresa.
      final vieja = vm.cargarProductos();
      vm.alternarSabor('Fresa');
      await vieja;

      expect(_idsDe(vm), ['100']);
      expect(vm.cargando, isFalse);
    });

    test('un error que llega tarde de la consulta anterior no la borra',
        () async {
      final api = _servidor(
        (l) => _parametros(l)['sabor'] == 'Fresa' ? _pagina(l, [100]) : _caido,
      )..demorar('/productos?limite=20&offset=0', _tarde);
      final vm = _vm(api);

      final vieja = vm.cargarProductos();
      vm.alternarSabor('Fresa');
      await vieja;

      expect(_idsDe(vm), ['100']);
      expect(vm.error, isNull);
    });

    test('un error de la página siguiente que llega tarde no se muestra',
        () async {
      final api = _servidor((l) {
        final q = _parametros(l);
        if (q['sabor'] == 'Fresa') return _pagina(l, [100]);
        return q['offset'] == '20' ? _caido : _pagina(l, _ids(45));
      })..demorar('/productos?limite=20&offset=20', _tarde);
      final vm = _vm(api);
      await vm.cargarProductos();

      final vieja = vm.cargarMas();
      vm.alternarSabor('Fresa');
      await vieja;

      expect(_idsDe(vm), ['100']);
      expect(vm.errorMas, isNull);
    });

    test('al cambiar la consulta la lista se vacía mientras llega su página 1',
        () async {
      final api = _servidor(
        (l) => _pagina(
          l,
          _parametros(l)['categoria'] == 'Pays' ? [100, 101] : _ids(45),
        ),
      )
        ..demorar('/productos?categoria=Pays&limite=20&offset=0', _tarde)
        ..demorar('/productos?categoria=Pays&ordenar=precio-asc', _tarde);
      final vm = _vm(api);
      await vm.cargarProductos();
      expect(vm.productos, hasLength(20));

      await vm.seleccionarCategoria('Pays');

      expect(vm.productos, isEmpty, reason: 'su página 1 aún no llega');
      expect(vm.cargando, isTrue);
      await _esperarLoTardio();
      expect(_idsDe(vm), ['100', '101']);
      expect(vm.cargando, isFalse);

      // Igual con un orden que se pide completo.
      vm.ordenarPor(SortOption.priceAsc);

      expect(vm.productos, isEmpty);
      expect(vm.cargando, isTrue);
      await _esperarLoTardio();
      expect(_idsDe(vm), ['100', '101']);
    });

    test('recargar la misma consulta deja la lista mientras llega', () async {
      final api = _servidor((l) => _pagina(l, _ids(45)));
      final vm = _vm(api);
      await vm.cargarProductos();
      api.demorar('/productos?limite=20&offset=0', _tarde);

      final recarga = vm.recargar();

      expect(vm.cargando, isTrue);
      expect(vm.productos, hasLength(20));
      await recarga;
      expect(vm.cargando, isFalse);
      expect(vm.productos, hasLength(20));
    });

    test('sin duplicados entre páginas', () async {
      // La segunda página empieza con el último de la primera (el catálogo
      // cambió entre una y otra).
      final api = _servidor((l) => _pagina(l, [..._ids(20), 20, 21, 22]));
      final vm = _vm(api);
      await vm.cargarProductos();

      await vm.cargarMas();

      expect(_idsDe(vm).where((id) => id == '20'), hasLength(1));
      expect(vm.productos, hasLength(22));
    });

    test('los agotados salen al final solo cuando termina', () async {
      final api = _servidor((l) => _pagina(l, _ids(25), agotados: {3}));
      final vm = _vm(api);
      await vm.cargarProductos();

      expect(vm.fin, isFalse);
      expect(_idsDe(vm), isNot(contains('3')));
      expect(vm.productos, hasLength(19));

      await vm.cargarMas();

      expect(vm.fin, isTrue);
      expect(vm.productos, hasLength(25));
      expect(_idsDe(vm).last, '3');
    });

    test('error en la siguiente página deja lo visto y permite reintentar',
        () async {
      var caido = true;
      final api = _servidor(
        (l) => caido && _parametros(l)['offset'] == '20'
            ? _caido
            : _pagina(l, _ids(45)),
      );
      final vm = _vm(api);
      await vm.cargarProductos();

      await vm.cargarMas();

      expect(vm.errorMas, 'Sin conexión');
      expect(vm.cargandoMas, isFalse);
      expect(vm.error, isNull);
      expect(vm.productos, hasLength(20));

      caido = false;
      await vm.cargarMas();

      expect(vm.errorMas, isNull);
      expect(vm.productos, hasLength(40));
    });

    test('error en la primera página', () async {
      var caido = true;
      final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(5)));
      final vm = _vm(api);

      await vm.cargarProductos();

      expect(vm.error, 'Sin conexión');
      expect(vm.productos, isEmpty);
      expect(vm.cargando, isFalse);
      expect(vm.fin, isFalse);
      // Sin primera página no hay «más» que pedir.
      await vm.cargarMas();
      expect(_pedidas(api), hasLength(1));

      // «Reintentar» vuelve a la página 1.
      caido = false;
      await vm.recargar();
      expect(vm.error, isNull);
      expect(vm.productos, hasLength(5));
    });

    test('precio y calificación piden todo una vez y revelan de 20 en 20',
        () async {
      for (final (orden, ordenar) in [
        (SortOption.priceAsc, 'precio-asc'),
        (SortOption.priceDesc, 'precio-desc'),
        (SortOption.rating, 'rating'),
      ]) {
        final api = _servidor((l) => _pagina(l, _ids(45)));
        final vm = _vm(api)..ordenarPor(orden);
        await _esperar();

        expect(vm.productos, hasLength(20), reason: '$orden');
        expect(vm.fin, isFalse);
        await vm.cargarMas();
        expect(vm.productos, hasLength(40));
        expect(vm.fin, isFalse);
        await vm.cargarMas();
        expect(vm.productos, hasLength(45));
        expect(vm.fin, isTrue);

        expect(_pedidas(api), ['/productos?ordenar=$ordenar'],
            reason: 'una sola petición sin limite');
      }
    });

    test('la búsqueda espera a que se deje de teclear', () async {
      final api = _servidor((l) => _pagina(l, _ids(3)));
      final vm = _vm(api, esperaBusqueda: const Duration(milliseconds: 400))
        ..buscar('pa')
        ..buscar('pay');

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(_pedidas(api), isEmpty, reason: 'todavía está tecleando');

      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(_pedidas(api), ['/productos?busqueda=pay&limite=20&offset=0']);
      expect(vm.productos, hasLength(3));
    });
  });
}
