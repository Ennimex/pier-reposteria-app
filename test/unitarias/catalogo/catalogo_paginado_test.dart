// test/unitarias/catalogo/catalogo_paginado_test.dart — el catálogo por
// páginas (#37): ProductsViewModel pide los productos de 20 en 20 con la
// consulta actual, termina con una página corta, vacía o con más de lo
// pedido (#272), hace una sola petición a la vez, descarta lo que llega tarde
// de una consulta anterior, vacía la lista al cambiar de consulta (al
// recargar la misma, no), no
// repite productos, deja los agotados para cuando ya no hay más, trae
// completos los órdenes que el servidor no desempata (precio y calificación)
// y espera a que se deje de teclear para buscar. Con la copia de la primera
// página guardada en el teléfono (#265), la consulta por omisión la muestra al
// instante mientras pide la nueva, la reemplaza al llegar y, sin internet, la
// conserva; al volver la conexión, la página 1 nueva toma su lugar antes de
// seguir con la 2 y llegan las categorías y los filtros que fallaron. Sin red.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/demanda_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/favoritos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/data/services/catalogo_guardado_service.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

/// Ids 1 a [total], en el orden del servidor.
List<int> _ids(int total) => [for (var i = 1; i <= total; i++) i];

Map<String, String> _parametros(LlamadaApi llamada) =>
    Uri.parse(llamada.endpoint).queryParameters;

/// GET /productos con lo que toca de [ids] según `limite` y `offset` (sin
/// `limite`, todos), como el servidor. Cada uno cuesta 100 salvo que
/// [precios] diga otra cosa.
Map<String, dynamic> _pagina(
  LlamadaApi llamada,
  List<int> ids, {
  Set<int> agotados = const {},
  Map<int, num> precios = const {},
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
          'precio_chico': precios[id] ?? 100,
          'categoria': 'Pasteles',
          'stock_online': agotados.contains(id) ? 0 : null,
          'activo': true,
        },
    ],
  };
}

/// GET /productos en un orden por precio, como el servidor: todos, por el
/// precio base (`precio_chico`, sin promociones) y, en los empates, por id.
Map<String, dynamic> _porPrecioBase(
  LlamadaApi llamada,
  Map<int, num> precios, {
  Set<int> agotados = const {},
}) {
  final signo = _parametros(llamada)['ordenar'] == 'precio-desc' ? -1 : 1;
  final ids = precios.keys.toList()
    ..sort((a, b) {
      final porPrecio = signo * precios[a]!.compareTo(precios[b]!);
      return porPrecio != 0 ? porPrecio : a.compareTo(b);
    });
  return _pagina(llamada, ids, agotados: agotados, precios: precios);
}

const Map<String, dynamic> _caido = {
  'success': false,
  'message': 'Sin conexión',
};

FakeApiClient _servidor(RespuestaDinamica responder) =>
    FakeApiClient(respuestas: {ApiConstants.productos: responder});

/// Productos (45), categorías y filtros; cada uno contesta [_caido] mientras
/// [caido] (o [productosCaidos], solo para los productos) dé true.
FakeApiClient _servidorCompleto(
  bool Function() caido, {
  bool Function()? productosCaidos,
}) {
  final productosFallan = productosCaidos ?? caido;
  Map<String, dynamic> categorias(LlamadaApi _) => caido()
      ? _caido
      : {
          'success': true,
          'categorias': [
            {'id': 1, 'nombre': 'Pasteles'},
            {'id': 2, 'nombre': 'Pays'},
          ],
        };
  Map<String, dynamic> filtros(LlamadaApi _) => caido()
      ? _caido
      : {
          'success': true,
          'filtros': {
            'sabores': ['Chocolate', 'Fresa'],
            'tamanos': ['Chico'],
            'tipos': ['Frío'],
          },
        };
  return FakeApiClient(respuestas: {
    ApiConstants.productos: (LlamadaApi l) =>
        productosFallan() ? _caido : _pagina(l, _ids(45)),
    ApiConstants.categorias: categorias,
    ApiConstants.filtros: filtros,
  });
}

/// Lo que tarda una respuesta que llega tarde; las demás llegan al instante
/// (en microtareas).
const _tarde = Duration(milliseconds: 10);

/// Deja que lleguen también las respuestas que llegan tarde.
Future<void> _esperarLoTardio() => Future<void>.delayed(_tarde * 3);

ProductsViewModel _vm(
  FakeApiClient api, {
  Duration esperaBusqueda = Duration.zero,
  CatalogoGuardadoService? guardado,
  double Function(Product)? precioFinal,
}) {
  final vm = ProductsViewModel(
    productosRepo: ProductosRepositoryRemote(api: api),
    favoritosRepo: FavoritosRepositoryRemote(api: api),
    demandaRepo: DemandaRepositoryRemote(api: api),
    catalogoGuardado: guardado,
    esperaBusqueda: esperaBusqueda,
    precioFinal: precioFinal,
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

/// Un producto de la copia guardada: «Copia N», con id cN para no confundirlo
/// con los que manda el servidor (1, 2, 3…).
Product _copia(int numero, {bool agotado = false}) => Product(
      id: 'c$numero',
      nombre: 'Copia $numero',
      descripcion: '',
      precio: 90,
      categoria: 'Pasteles',
      imagenUrl: '',
      stockOnline: agotado ? 0 : null,
    );

/// Deja en el teléfono una copia de [cuantos] productos: c1 a c[cuantos].
Future<void> _guardarCopia(int cuantos) => CatalogoGuardadoService().guardar([
      for (var i = 1; i <= cuantos; i++) _copia(i),
    ]);

/// Los ids de la copia que deja [_guardarCopia].
List<String> _idsCopia(int cuantos) =>
    [for (var i = 1; i <= cuantos; i++) 'c$i'];

/// Los ids que manda el servidor falso en su primera página (1 a [cuantos]).
List<String> _idsServidor(int cuantos) =>
    [for (var i = 1; i <= cuantos; i++) '$i'];

/// Lo que hay guardado en el teléfono ahora.
Future<List<String>> _guardada() async => [
      for (final p in await CatalogoGuardadoService().leer() ?? <Product>[])
        p.id,
    ];

/// Un teléfono ocupado: la copia que había al pedirla llega más tarde que una
/// respuesta del servidor falso (aunque entre tanto se guarde otra).
class _ServicioLento extends CatalogoGuardadoService {
  @override
  Future<List<Product>?> leer() async {
    final copia = await super.leer();
    await Future<void>.delayed(_tarde);
    return copia;
  }
}

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

    // #272: si el servidor ignorara `limite` y mandara todo, cada «cargar
    // más» traería los mismos (sin repetirse en pantalla) y, con la persona
    // al final, se seguiría preguntando sin fin.
    test('una página con más de 20 es la última: no se pide otra', () async {
      // El servidor manda los 25 aunque se le pidan 20: contesta como a una
      // petición sin `limite`.
      const sinLimite = LlamadaApi('GET', ApiConstants.productos);
      final api = _servidor((_) => _pagina(sinLimite, _ids(25)));
      final vm = _vm(api);
      await vm.cargarProductos();

      expect(vm.fin, isTrue);
      expect(vm.productos, hasLength(25));

      await vm.cargarMas();
      await vm.cargarMas();

      expect(_pedidas(api), ['/productos?limite=20&offset=0']);
      expect(vm.cargandoMas, isFalse);
      expect(vm.errorMas, isNull);
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

  group('Catálogo guardado en el teléfono (#265)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('con copia la muestra al instante y la reemplaza al llegar', () async {
      await _guardarCopia(20);
      final api = _servidor((l) => _pagina(l, _ids(45)))
        ..demorar('/productos?limite=20&offset=0', _tarde);
      final vm = _vm(api, guardado: CatalogoGuardadoService());

      final carga = vm.cargarProductos();
      await _esperar();

      // La copia ya se ve (sin esqueletos) mientras llega la página nueva,
      // que se pidió al mismo tiempo.
      expect(_idsDe(vm), _idsCopia(20));
      expect(vm.cargando, isTrue);
      expect(vm.sinConexion, isFalse);
      expect(vm.error, isNull);
      expect(_pedidas(api), ['/productos?limite=20&offset=0']);

      await carga;

      expect(_idsDe(vm), _idsServidor(20));
      expect(vm.cargando, isFalse);
      expect(vm.sinConexion, isFalse);
      expect(vm.error, isNull);
    });

    test('pide la página 1 sin esperar a que se lea la copia', () async {
      await _guardarCopia(20);
      final api = _servidor((l) => _pagina(l, _ids(45)));
      final vm = _vm(api, guardado: _ServicioLento());

      final carga = vm.cargarProductos();

      // La petición ya salió, antes de que la copia termine de leerse.
      expect(_pedidas(api), ['/productos?limite=20&offset=0']);
      await carga;
      expect(_idsDe(vm), _idsServidor(20));
    });

    test('una copia que se lee después de la página nueva no la pisa',
        () async {
      await _guardarCopia(20);
      final api = _servidor((l) => _pagina(l, _ids(45)));
      final vm = _vm(api, guardado: _ServicioLento());

      await vm.cargarProductos();
      expect(_idsDe(vm), _idsServidor(20));

      // Termina de leerse la copia, ya sin lugar en pantalla.
      await _esperarLoTardio();
      expect(_idsDe(vm), _idsServidor(20));
    });

    test('si se filtra mientras se lee la copia, la copia no se muestra',
        () async {
      await _guardarCopia(20);
      final api = _servidor(
        (l) => _pagina(
          l,
          _parametros(l)['sabor'] == 'Fresa' ? [100] : _ids(45),
        ),
      )..demorar('/productos?sabor=Fresa&limite=20&offset=0', _tarde * 3);
      final vm = _vm(api, guardado: _ServicioLento());
      final vistos = <String>{};
      vm.addListener(() => vistos.addAll(_idsDe(vm)));

      // La copia de la consulta por omisión llega cuando ya se pidió otra
      // y su página aún no llega.
      unawaited(vm.cargarProductos());
      vm.alternarSabor('Fresa');
      await Future<void>.delayed(_tarde * 5);

      expect(_idsDe(vm), ['100']);
      expect(vistos, isNot(contains('c1')));
    });

    test('la página 1 por omisión se guarda', () async {
      final api = _servidor((l) => _pagina(l, _ids(45), agotados: {3}));
      final vm = _vm(api, guardado: CatalogoGuardadoService());

      await vm.cargarProductos();

      // Al terminar la carga ya está guardada, tal como llegó: también con el
      // agotado que la lista deja para el final.
      expect(await _guardada(), _idsServidor(20));
      expect(_idsDe(vm), isNot(contains('3')));

      // Las páginas siguientes no se guardan.
      await vm.cargarMas();
      await _esperar();
      expect(await _guardada(), _idsServidor(20));
    });

    test('con filtros no usa la copia ni la guarda', () async {
      final cambios = <String, void Function(ProductsViewModel)>{
        'sabor': (vm) => vm.alternarSabor('Fresa'),
        'tamaño': (vm) => vm.alternarTamano('Grande'),
        'tipo': (vm) => vm.alternarTipo('Frío'),
        'orden del servidor': (vm) => vm.ordenarPor(SortOption.nameAsc),
        'orden completo': (vm) => vm.ordenarPor(SortOption.priceAsc),
        'búsqueda': (vm) => vm.buscar('pay'),
        'categoría': (vm) => unawaited(vm.seleccionarCategoria('Pays')),
      };
      for (final MapEntry(key: nombre, value: cambiar) in cambios.entries) {
        await _guardarCopia(20);
        final vm = _vm(
          _servidor((l) => _pagina(l, [100, 101])),
          guardado: CatalogoGuardadoService(),
        );
        // Los ids que se vieron en algún momento.
        final vistos = <String>{};
        vm.addListener(() => vistos.addAll(_idsDe(vm)));

        cambiar(vm);
        await _esperar();

        expect(_idsDe(vm), ['100', '101'], reason: nombre);
        expect(vistos, isNot(contains('c1')), reason: nombre);
        // La copia sigue como estaba.
        expect(await _guardada(), _idsCopia(20), reason: nombre);
      }
    });

    test('al quitar los filtros vuelve a verse la copia mientras llega',
        () async {
      await _guardarCopia(20);
      final api = _servidor(
        (l) => _pagina(
          l,
          _parametros(l)['sabor'] == 'Fresa' ? [100] : _ids(45),
        ),
      );
      final vm = _vm(api, guardado: CatalogoGuardadoService())
        ..alternarSabor('Fresa');
      await _esperar();
      expect(_idsDe(vm), ['100']);
      api.demorar('/productos?limite=20&offset=0', _tarde);

      vm.alternarSabor('Fresa');
      await _esperar();

      expect(_idsDe(vm), _idsCopia(20));
      await _esperarLoTardio();
      expect(_idsDe(vm), _idsServidor(20));
    });

    test('sin internet se queda la copia y sinConexion es true', () async {
      await _guardarCopia(20);
      final vm = _vm(
        _servidor((_) => _caido),
        guardado: CatalogoGuardadoService(),
      );

      await vm.cargarProductos();

      expect(_idsDe(vm), _idsCopia(20));
      expect(vm.sinConexion, isTrue);
      expect(vm.error, isNull);
      expect(vm.cargando, isFalse);
    });

    test('la copia se ve antes de saber que no hay internet', () async {
      await _guardarCopia(20);
      final api = _servidor((_) => _caido)
        ..demorar('/productos?limite=20&offset=0', _tarde);
      final vm = _vm(api, guardado: CatalogoGuardadoService());

      final carga = vm.cargarProductos();
      await _esperar();

      expect(_idsDe(vm), _idsCopia(20));
      expect(vm.sinConexion, isFalse, reason: 'todavía no responde');

      await carga;
      expect(_idsDe(vm), _idsCopia(20));
      expect(vm.sinConexion, isTrue);
    });

    test('si el error llega antes de leer la copia, igual se queda la copia',
        () async {
      await _guardarCopia(20);
      final vm = _vm(_servidor((_) => _caido), guardado: _ServicioLento());

      await vm.cargarProductos();

      expect(_idsDe(vm), _idsCopia(20));
      expect(vm.sinConexion, isTrue);
      expect(vm.error, isNull);
    });

    test('sin internet, bajar al final da errorMas', () async {
      await _guardarCopia(20);
      final api = _servidor((_) => _caido);
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      await vm.cargarProductos();

      await vm.cargarMas();

      // La copia son 20: puede haber más. No se le pega la página 2 (la copia
      // puede ser de hace días): se vuelve a pedir la página 1, y falla.
      expect(vm.errorMas, 'Sin conexión');
      expect(vm.cargandoMas, isFalse);
      expect(_idsDe(vm), _idsCopia(20));
      expect(vm.sinConexion, isTrue);
      expect(_pedidas(api), [
        '/productos?limite=20&offset=0',
        '/productos?limite=20&offset=0',
      ]);
    });

    test('al volver la conexión, Reintentar trae la página 1 y quita el aviso',
        () async {
      await _guardarCopia(20);
      var caido = true;
      final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(45)));
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      await vm.cargarProductos();
      await vm.cargarMas();
      expect(vm.errorMas, 'Sin conexión');
      expect(vm.sinConexion, isTrue);
      final cuantosSeVen = <int>[];
      vm.addListener(() => cuantosSeVen.add(vm.productos.length));

      // «Reintentar» del pie, ya con internet.
      caido = false;
      await vm.cargarMas();

      // La página 1 nueva toma el lugar de la copia (sin pasar por la lista
      // vacía), se guarda y el aviso se va.
      expect(_pedidas(api).last, '/productos?limite=20&offset=0');
      expect(_idsDe(vm), _idsServidor(20));
      expect(cuantosSeVen, everyElement(20));
      expect(vm.sinConexion, isFalse);
      expect(vm.errorMas, isNull);
      expect(vm.cargandoMas, isFalse);
      expect(vm.cargando, isFalse);
      expect(await _guardada(), _idsServidor(20));

      // Después sí sigue la página 2.
      await vm.cargarMas();
      expect(_pedidas(api).last, '/productos?limite=20&offset=20');
      expect(_idsDe(vm), _idsServidor(40));
    });

    test('al volver la conexión, Reintentar también trae las categorías y los '
        'filtros que fallaron', () async {
      await _guardarCopia(20);
      var caido = true;
      final api = _servidorCompleto(() => caido);
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      // Se abre la app sin internet: la copia, chips de respaldo, sin filtros.
      await vm.cargar(autenticado: false);
      await vm.cargarMas();
      expect(vm.nombresCategorias, ProductsViewModel.categoriasDeRespaldo);
      expect(vm.filtrosCargados, isFalse);

      // «Reintentar» del pie, ya con internet.
      caido = false;
      await vm.cargarMas();

      expect(vm.sinConexion, isFalse);
      expect(vm.nombresCategorias, ['Todos', 'Pasteles', 'Pays']);
      expect(vm.filtrosCargados, isTrue);
      expect(vm.sabores, ['Chocolate', 'Fresa']);
    });

    test('si las categorías y los filtros ya llegaron, Reintentar no los '
        'vuelve a pedir', () async {
      await _guardarCopia(20);
      var caido = true;
      // Solo fallan los productos.
      final api = _servidorCompleto(() => false, productosCaidos: () => caido);
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      await vm.cargar(autenticado: false);
      await vm.cargarMas();
      expect(vm.sinConexion, isTrue);

      caido = false;
      await vm.cargarMas();

      expect(vm.sinConexion, isFalse);
      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.categorias),
          hasLength(1));
      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.filtros),
          hasLength(1));
    });

    test('una página 1 que Reintentar pidió y llega tarde no pisa la consulta '
        'nueva', () async {
      await _guardarCopia(20);
      var caido = true;
      final api = _servidor((l) {
        if (_parametros(l)['sabor'] == 'Fresa') return _pagina(l, [100]);
        return caido ? _caido : _pagina(l, _ids(45));
      });
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      await vm.cargarProductos();
      expect(vm.sinConexion, isTrue);
      caido = false;
      api.demorar('/productos?limite=20&offset=0', _tarde);

      // La página 1 del catálogo por omisión llega después de la de Fresa.
      final vieja = vm.cargarMas();
      vm.alternarSabor('Fresa');
      await vieja;
      await _esperarLoTardio();

      expect(_idsDe(vm), ['100']);
      expect(vm.cargandoMas, isFalse);
      expect(await _guardada(), _idsCopia(20));
    });

    test('con varias páginas en pantalla, al volver la conexión sigue con la '
        'siguiente y quita el aviso', () async {
      var caido = false;
      final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(65)));
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      await vm.cargarProductos();
      await vm.cargarMas();
      // Jalar para refrescar sin internet: las 40 se quedan, con el aviso.
      caido = true;
      await vm.cargarProductos();
      expect(vm.productos, hasLength(40));
      expect(vm.sinConexion, isTrue);

      // Vuelve la conexión y se baja al final.
      caido = false;
      await vm.cargarMas();

      // Cambiar las 40 por la página 1 movería a la persona de donde iba.
      expect(_pedidas(api).last, '/productos?limite=20&offset=40');
      expect(_idsDe(vm), _idsServidor(60));
      expect(vm.sinConexion, isFalse);
    });

    test('recargar sin internet deja la lista con el aviso', () async {
      var caido = false;
      final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(45)));
      final vm = _vm(api, guardado: CatalogoGuardadoService());
      await vm.cargarProductos();
      caido = true;

      await vm.cargarProductos();

      // Antes se vaciaba y salía el error; ahora se queda lo que se veía.
      expect(_idsDe(vm), _idsServidor(20));
      expect(vm.sinConexion, isTrue);
      expect(vm.error, isNull);

      // Al volver el internet la página nueva quita el aviso.
      caido = false;
      await vm.cargarProductos();
      expect(_idsDe(vm), _idsServidor(20));
      expect(vm.sinConexion, isFalse);
    });

    test('sin copia y sin internet sale el error de siempre', () async {
      final vm = _vm(
        _servidor((_) => _caido),
        guardado: CatalogoGuardadoService(),
      );

      await vm.cargarProductos();

      expect(vm.error, 'Sin conexión');
      expect(vm.productos, isEmpty);
      expect(vm.sinConexion, isFalse);
    });

    test('la copia sigue las reglas de la página 1: agotados al final y sin '
        'repetidos', () async {
      await CatalogoGuardadoService().guardar([
        _copia(1),
        _copia(2, agotado: true),
        _copia(3),
        _copia(3),
        _copia(4),
      ]);
      final vm = _vm(
        _servidor((_) => _caido),
        guardado: CatalogoGuardadoService(),
      );

      await vm.cargarProductos();

      expect(_idsDe(vm), ['c1', 'c3', 'c4', 'c2']);
      expect(vm.fin, isTrue, reason: 'menos de 20: no hay más páginas');
    });
  });

  // Antes, con búsqueda, filtros, categoría u orden, jalar para refrescar sin
  // internet vaciaba la lista y salía «No pudimos cargar el catálogo»; solo
  // la consulta por omisión se quedaba con lo que se veía.
  group('Jalar para refrescar sin internet (#275)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    /// Lo que cambia la consulta que se ve, como lo hace la persona.
    final consultas = <String, void Function(ProductsViewModel)>{
      'sabor': (vm) => vm.alternarSabor('Fresa'),
      'búsqueda': (vm) => vm.buscar('pay'),
      'categoría': (vm) => unawaited(vm.seleccionarCategoria('Pays')),
      'orden del servidor': (vm) => vm.ordenarPor(SortOption.nameAsc),
    };

    test('con búsqueda, filtros o categoría, un refresco que falla deja la '
        'lista y pone el aviso', () async {
      for (final MapEntry(key: nombre, value: cambiar) in consultas.entries) {
        var caido = false;
        final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(45)));
        final vm = _vm(api, guardado: CatalogoGuardadoService());
        cambiar(vm);
        await _esperar();
        expect(_idsDe(vm), _idsServidor(20), reason: nombre);

        caido = true;
        await vm.recargar();

        expect(_idsDe(vm), _idsServidor(20), reason: nombre);
        expect(vm.sinConexion, isTrue, reason: nombre);
        expect(vm.error, isNull, reason: nombre);
        expect(vm.cargando, isFalse, reason: nombre);

        // Al volver el internet, la página nueva quita el aviso.
        caido = false;
        await vm.recargar();

        expect(_idsDe(vm), _idsServidor(20), reason: nombre);
        expect(vm.sinConexion, isFalse, reason: nombre);
      }
    });

    test('en un orden que se pide completo, lo que se veía se queda y lo que '
        'falta se sigue mostrando sin red', () async {
      for (final orden in [
        SortOption.priceAsc,
        SortOption.priceDesc,
        SortOption.rating,
      ]) {
        var caido = false;
        final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(45)));
        final vm = _vm(api, guardado: CatalogoGuardadoService())
          ..ordenarPor(orden);
        await _esperar();
        await vm.cargarMas();
        expect(vm.productos, hasLength(40), reason: '$orden');

        caido = true;
        await vm.recargar();

        expect(vm.productos, hasLength(40), reason: '$orden');
        expect(vm.sinConexion, isTrue, reason: '$orden');
        expect(vm.error, isNull, reason: '$orden');

        // El resto ya está en el teléfono.
        await vm.cargarMas();

        expect(vm.productos, hasLength(45), reason: '$orden');
        expect(vm.fin, isTrue, reason: '$orden');
        expect(vm.errorMas, isNull, reason: '$orden');
        expect(_pedidas(api), hasLength(2), reason: '$orden');
      }
    });

    test('con filtros, al volver la conexión bajar al final pone la página 1 '
        'nueva y no la guarda como copia', () async {
      await _guardarCopia(20);
      var caido = false;
      final api = _servidor((l) => caido ? _caido : _pagina(l, _ids(45)));
      final vm = _vm(api, guardado: CatalogoGuardadoService())
        ..alternarSabor('Fresa');
      await _esperar();
      caido = true;
      await vm.recargar();
      expect(vm.sinConexion, isTrue);

      caido = false;
      await vm.cargarMas();

      expect(_pedidas(api).last, '/productos?sabor=Fresa&limite=20&offset=0');
      expect(_idsDe(vm), _idsServidor(20));
      expect(vm.sinConexion, isFalse);
      await _esperar();
      expect(await _guardada(), _idsCopia(20));
    });

    test('con filtros y nada en pantalla sale el error de siempre', () async {
      final vm = _vm(
        _servidor((_) => _caido),
        guardado: CatalogoGuardadoService(),
      )..alternarSabor('Fresa');

      await _esperar();

      expect(vm.error, 'Sin conexión');
      expect(vm.productos, isEmpty);
      expect(vm.sinConexion, isFalse);
    });
  });

  // El servidor ordena por el precio base: un producto con promoción quedaba
  // en el lugar de su precio sin descuento (en el Samsung, uno de $430 con
  // -10 % salió entre los de $430 y no junto a los de $387).
  group('Orden por precio con las promociones (#281)', () {
    // Precios base; el 6 está agotado y el 3 y el 7 empatan.
    const precios = <int, num>{1: 380, 2: 430, 3: 400, 4: 430, 5: 450, 6: 100,
        7: 400};
    const agotados = {6};
    // El 2 tiene -10 %: se ve en $387.
    double conPromocion(Product p) => p.id == '2' ? 387 : p.precio;

    FakeApiClient servidor() => _servidor(
        (l) => _porPrecioBase(l, precios, agotados: agotados));

    test('cada producto queda en el lugar del precio que se ve, con los '
        'empates en el orden del servidor y los agotados al final', () async {
      for (final (orden, esperados) in [
        (SortOption.priceAsc, ['1', '2', '3', '7', '4', '5', '6']),
        (SortOption.priceDesc, ['5', '4', '3', '7', '2', '1', '6']),
      ]) {
        final vm = _vm(servidor(), precioFinal: conPromocion)
          ..ordenarPor(orden);
        await _esperar();

        expect(_idsDe(vm), esperados, reason: '$orden');
        expect(vm.fin, isTrue);
      }
    });

    test('sin promociones se respeta el orden del servidor', () async {
      for (final (orden, esperados) in [
        (SortOption.priceAsc, ['1', '3', '7', '2', '4', '5', '6']),
        (SortOption.priceDesc, ['5', '2', '4', '3', '7', '1', '6']),
      ]) {
        // Sin decir cómo se calcula el precio final: el base.
        final vm = _vm(servidor())..ordenarPor(orden);
        await _esperar();

        expect(_idsDe(vm), esperados, reason: '$orden');
      }
    });

    test('los otros órdenes no se tocan', () async {
      // El servidor manda «Mejor calificados» en su orden.
      final api = _servidor(
          (l) => _pagina(l, [5, 2, 1], precios: {1: 380, 2: 430, 5: 450}));
      final vm = _vm(api, precioFinal: (p) => p.id == '5' ? 1 : p.precio)
        ..ordenarPor(SortOption.rating);
      await _esperar();

      expect(_idsDe(vm), ['5', '2', '1']);
    });

    test('si las promociones llegan después, lo que ya se ve se queda y lo '
        'que falta sale en el orden del precio final', () async {
      // 45 productos de $10 a $450, en orden.
      final api = _servidor((l) => _porPrecioBase(l, {
            for (final id in _ids(45)) id: id * 10,
          }));
      final promociones = <String, double>{};
      final vm = _vm(
        api,
        precioFinal: (p) => promociones[p.id] ?? p.precio,
      )..ordenarPor(SortOption.priceAsc);
      await _esperar();
      expect(_idsDe(vm), _idsServidor(20));
      var avisos = 0;
      vm.addListener(() => avisos++);

      // Llegan: el 40 queda en $105 y el 30 en $215.
      promociones.addAll({'40': 105, '30': 215});
      vm.reordenarPorPromociones();

      // Lo que se ve no se mueve.
      expect(_idsDe(vm), _idsServidor(20));
      expect(avisos, 0);

      await vm.cargarMas();

      expect(_idsDe(vm).take(20), _idsServidor(20));
      expect(_idsDe(vm).sublist(20, 24), ['40', '21', '30', '22']);
      expect(vm.productos, hasLength(40));
      await vm.cargarMas();
      expect(vm.productos, hasLength(45));
      expect(vm.productos.map((p) => p.id).toSet(), hasLength(45));
      expect(_pedidas(api), ['/productos?ordenar=precio-asc']);

      // Con todo a la vista ya no hay nada que reordenar.
      final todos = _idsDe(vm);
      promociones['1'] = 999;
      vm.reordenarPorPromociones();
      expect(_idsDe(vm), todos);
    });

    test('reordenar sin un orden por precio o sin nada pendiente no hace nada',
        () async {
      final api = _servidor((l) => _pagina(l, _ids(45)));
      final vm = _vm(api, precioFinal: (p) => -double.parse(p.id))
        ..reordenarPorPromociones();
      expect(vm.productos, isEmpty, reason: 'aún no hay lista');

      await vm.cargarProductos();
      vm.reordenarPorPromociones();
      await vm.cargarMas();
      expect(_idsDe(vm), _idsServidor(40), reason: 'por páginas del servidor');

      vm.ordenarPor(SortOption.rating);
      await _esperar();
      vm.reordenarPorPromociones();
      await vm.cargarMas();
      expect(_idsDe(vm), _idsServidor(40), reason: 'por calificación');
    });
  });
}
