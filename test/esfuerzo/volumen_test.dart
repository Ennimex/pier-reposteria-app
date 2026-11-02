// test/esfuerzo/volumen_test.dart — volumen de datos (#70): la app con mucho
// más de lo que tiene en el uso normal, sin red. La corre la etapa de
// esfuerzo (esfuerzo.yml, trabajo «Volumen de datos») con la etiqueta
// esfuerzo; las unitarias no. Dos pantallas llenas: el carrito con 100
// artículos y el catálogo con 1,000 productos, que llegan de 20 en 20 al
// bajar (#37). Del catálogo se revisa que bajar hasta el final pide sus 50
// páginas una sola vez cada una y en orden (más una vacía, que dice que ya no
// hay más, y ninguna después), sin repetir productos y con los agotados al
// final; y que buscar entre los 1,000 pregunta una sola vez al dejar de
// teclear, trae solo lo que coincide (en todas sus páginas) y, al borrar la
// búsqueda, vuelve a la página 1 del catálogo completo.
@Tags(['esfuerzo'])
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_linea.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_screen.dart';
import 'package:pier_reposteria/ui/core/ui/foto_producto.dart';
import 'package:pier_reposteria/ui/products/view_model/products_view_model.dart';
import 'package:pier_reposteria/ui/products/widgets/catalogo_secciones.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';

import '../fakes/fake_api_client.dart';
import '../helpers/catalogo.dart';
import '../helpers/pump_app.dart';

// ── Carrito de 100 artículos ───────────────────────────────────────────────

/// Cuántos artículos distintos lleva el carrito.
const _articulos = 100;

/// Precio del artículo [i] (1 a 100): 11, 12, …, 110 pesos.
int _precio(int i) => 10 + i;

/// El backend con el carrito lleno: [_articulos] productos distintos, uno de
/// cada uno, con la forma de GET /carrito.
FakeApiClient _backendDelCarrito() => FakeApiClient(respuestas: {
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
      },
      ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
      ApiConstants.carrito: {
        'success': true,
        'carrito': {
          'items': [
            for (var i = 1; i <= _articulos; i++)
              {
                'producto_id': i,
                'carrito_item_id': 1000 + i,
                'nombre': 'Producto $i',
                'precio_unitario': _precio(i).toStringAsFixed(2),
                'precio_original': _precio(i).toStringAsFixed(2),
                'cantidad': 1,
                'tamano': 'chico',
              },
          ],
        },
      },
    });

/// Página de partida que abre «Mi Carrito», como la pestaña del carrito.
class _Anfitriona extends StatelessWidget {
  const _Anfitriona();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const CartScreen()),
          ),
          child: const Text('Ver carrito'),
        ),
      );
}

// ── Catálogo de 1,000 productos ────────────────────────────────────────────

/// Cuántos productos tiene el catálogo.
const _productos = 1000;

/// Productos por página, como la web.
const _porPagina = 20;

/// Las páginas llenas del catálogo: 50.
const int _paginas = _productos ~/ _porPagina;

/// Los productos sin existencias (por número), repartidos entre los 1,000:
/// uno en la primera página, dos a media lista y el último de la búsqueda.
/// El servidor los manda en su lugar; la app los deja al final.
const _agotados = {3, 250, 640, 999};

/// Lo que se busca. Está en el nombre de cada 27.º producto (el 27, el 54,
/// …, el 999): 37 de los 1,000, en dos páginas.
const _termino = 'nuez';

bool _esDeNuez(int i) => i % 27 == 0;

String _nombre(int i) => _esDeNuez(i) ? 'Pastel de $_termino $i' : 'Pastel $i';

/// El catálogo tal como lo manda GET /productos, en el orden del servidor.
final List<Map<String, dynamic>> _catalogo = [
  for (var i = 1; i <= _productos; i++)
    {
      'id': i,
      'nombre': _nombre(i),
      'descripcion': 'Hecho en casa',
      'precio_chico': 100,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'stock_online': _agotados.contains(i) ? 0 : null,
      'activo': true,
    },
];

/// GET /productos como el servidor: deja los que llevan la búsqueda en el
/// nombre o la descripción y entrega `limite` desde `offset`; sin `limite`,
/// todos (la lista que pide el Inicio).
Map<String, dynamic> _servidorDelCatalogo(LlamadaApi llamada) {
  final q = Uri.parse(llamada.endpoint).queryParameters;
  final busqueda = q['busqueda']?.toLowerCase();
  final coinciden = [
    for (final p in _catalogo)
      if (busqueda == null ||
          '${p['nombre']} ${p['descripcion']}'
              .toLowerCase()
              .contains(busqueda))
        p,
  ];
  final limite = int.tryParse(q['limite'] ?? '');
  final offset = int.tryParse(q['offset'] ?? '') ?? 0;
  return {
    'success': true,
    'productos': limite == null
        ? coinciden
        : coinciden.skip(offset).take(limite).toList(),
  };
}

/// Lo que tarda en llegar cada página después de la primera, como por la red:
/// si llegara entre dos eventos del mismo arrastre, el último vería la lista
/// sin acomodar lo nuevo y pediría una página de más.
const _demora = Duration(milliseconds: 300);

/// Lo que la búsqueda espera a que se deje de teclear antes de preguntar.
const _esperaBusqueda = Duration(milliseconds: 400);

/// Entre una tecla y la siguiente: menos que [_esperaBusqueda].
const _entreTeclas = Duration(milliseconds: 150);

/// Lo que se le pide al servidor para la [pagina] (desde 0) de una
/// [consulta]: 20 desde la fila que toca.
Map<String, String> _pedida(
  int pagina, [
  Map<String, String> consulta = const {},
]) =>
    {...consulta, 'limite': '$_porPagina', 'offset': '${pagina * _porPagina}'};

/// El backend con el catálogo de [_productos]. Las páginas que siguen a la
/// primera, del catálogo completo y de la búsqueda, tardan [_demora]; también
/// la que se pide después de la página 50, que llega vacía.
FakeApiClient _backendDelCatalogo() {
  final api = FakeApiClient(respuestas: {
    ApiConstants.productos: _servidorDelCatalogo,
    ApiConstants.promocionesActivas: {
      'success': true,
      'promociones': <Map<String, dynamic>>[],
    },
    ApiConstants.categorias: {
      'success': true,
      'categorias': [
        {'id': 1, 'nombre': 'Pasteles'},
      ],
    },
    ApiConstants.filtros: {
      'success': true,
      'filtros': {
        'sabores': <String>[],
        'tamanos': <String>[],
        'tipos': <String>[],
      },
    },
  });
  for (final consulta in [
    <String, String>{},
    {'busqueda': _termino},
  ]) {
    for (var pagina = 1; pagina <= _paginas; pagina++) {
      api.demorar(
        ApiConstants.consultaProductos(_pedida(pagina, consulta)),
        _demora,
      );
    }
  }
  return api;
}

/// Una foto que nunca termina de llegar, como con la red lenta. En pruebas
/// las tarjetas piden su foto con NetworkImage, que falla en cada tarjeta
/// nueva, y esas fallas se llevarían la mitad del tiempo de bajar los 1,000;
/// lo que se prueba aquí es la lista, no las fotos.
class _FotoQueNoLlega extends ImageProvider<_FotoQueNoLlega> {
  const _FotoQueNoLlega();

  @override
  Future<_FotoQueNoLlega> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FotoQueNoLlega>(this);

  @override
  ImageStreamCompleter loadImage(
    _FotoQueNoLlega key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

/// Abre el catálogo en un celular alto (540×3000: caben unas 7 filas de
/// tarjetas y al final se ven juntos el último disponible y los agotados), deja
/// que llegue la primera página y devuelve el ViewModel de la pantalla, que
/// tiene la lista completa (también lo que no está construido). Las fotos son
/// [_FotoQueNoLlega] (flutter_test_config.dart vuelve a NetworkImage en la
/// prueba siguiente).
Future<ProductsViewModel> _abrirCatalogo(
  WidgetTester tester,
  FakeApiClient api,
) async {
  proveedorDeFoto = (_) => const _FotoQueNoLlega();
  tester.usarCelular(alto: 3000);
  await tester.pumpApp(const ProductsScreen(), api: api);
  await tester.pumpAndSettle();
  return tester.widget<CatalogoHeader>(find.byType(CatalogoHeader)).viewModel;
}

/// Los productos 1 a [n], en el orden del servidor.
List<int> _hasta(int n) => [for (var i = 1; i <= n; i++) i];

/// Los ids de los disponibles entre [numeros].
List<String> _disponibles(Iterable<int> numeros) => [
      for (final i in numeros)
        if (!_agotados.contains(i)) '$i',
    ];

/// Los ids que la lista debe tener cuando ya llegó todo de [numeros]: los
/// disponibles en el orden del servidor y, al final, los agotados.
List<String> _conAgotadosAlFinal(Iterable<int> numeros) => [
      ..._disponibles(numeros),
      for (final i in numeros)
        if (_agotados.contains(i)) '$i',
    ];

/// Los ids de toda la lista del catálogo, de arriba abajo.
List<String> _ids(ProductsViewModel vm) => [for (final p in vm.productos) p.id];

/// Bajo hasta el final de lo cargado y espero a que llegue la página que eso
/// pida, si pide alguna.
Future<void> _bajar(WidgetTester tester) async {
  await tester.bajarAlFinalDelCatalogo();
  await tester.pump(_demora);
  await tester.pumpAndSettle();
}

/// Estoy al final de la lista de [ids]: las tarjetas construidas son las
/// últimas, la última se ve en pantalla y no queda indicador de carga.
void _alFinal(WidgetTester tester, List<String> ids) {
  final nombres = [for (final id in ids) _nombre(int.parse(id))];
  final tarjetas = tester.nombresEnElCatalogo;
  expect(tarjetas, isNotEmpty);
  expect(tarjetas, nombres.sublist(nombres.length - tarjetas.length));
  expect(find.text(nombres.last).hitTestable(), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

void main() {
  group('Volumen de datos (#70)', () {
    testWidgets('carrito de 100 artículos: total correcto y llega al último',
        (tester) async {
      // Un celular como el Note 10+ (412×869 lógicos).
      tester.view
        ..physicalSize = const Size(1440, 3040)
        ..devicePixelRatio = 3.5;
      addTearDown(tester.view.reset);
      await tester.pumpApp(const _Anfitriona(), api: _backendDelCarrito());
      await tester.iniciarSesion(find.byType(_Anfitriona));
      await tester.pump();

      await tester.tap(find.text('Ver carrito'));
      // El total se anima: se deja correr el tiempo sin esperar a que todo
      // termine.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 11 + 12 + … + 110 = 6,050 pesos.
      final total = [for (var i = 1; i <= _articulos; i++) _precio(i)]
          .reduce((a, b) => a + b);
      expect(total, 6050);
      expect(find.text('\$$total MXN'), findsOneWidget);
      expect(find.text('$_articulos productos'), findsOneWidget);
      expect(find.widgetWithText(CartLinea, 'Producto 1'), findsOneWidget);

      final ultimo = find.widgetWithText(CartLinea, 'Producto $_articulos');
      await tester.scrollUntilVisible(
        ultimo,
        600,
        scrollable: find
            .descendant(
                of: find.byType(CartScreen), matching: find.byType(Scrollable))
            .first,
      );
      expect(ultimo, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'catálogo de 1,000 productos: baja hasta el final página por página',
        (tester) async {
      final api = _backendDelCatalogo();
      final vm = await _abrirCatalogo(tester, api);
      expect(parametrosDelCatalogo(api), [_pedida(0)]);
      // De los 20 de la primera página se ven 19: el 3 está agotado y espera.
      expect(_ids(vm), _disponibles(_hasta(_porPagina)));

      // Cada vez que bajo hasta el final de lo cargado se pide la página que
      // sigue, y solo esa; mientras haya más, los agotados esperan.
      for (var pagina = 1; pagina < _paginas; pagina++) {
        await _bajar(tester);
        expect(parametrosDelCatalogo(api), hasLength(pagina + 1));
        expect(_ids(vm), _disponibles(_hasta((pagina + 1) * _porPagina)));
      }
      // Después de la página 50 se pide desde el 1,000: llega vacía y así sabe
      // la app que ya no hay más. Los agotados se suman abajo de lo que se
      // ve: bajo otra vez para llegar a ellos, y eso ya no pide nada.
      await _bajar(tester);
      expect(vm.fin, isTrue);
      await _bajar(tester);

      // Se pidieron las 50 páginas una vez cada una y en orden (del 0 al
      // 980), más la vacía del final
      expect(parametrosDelCatalogo(api), [
        for (var pagina = 0; pagina <= _paginas; pagina++) _pedida(pagina),
      ]);
      // la lista tiene los 1,000 sin repetidos, con los agotados al final
      final ids = _ids(vm);
      expect(ids, hasLength(_productos));
      expect(ids.toSet(), hasLength(_productos));
      expect(ids, _conAgotadosAlFinal(_hasta(_productos)));
      // y en pantalla está el final: el 1,000 y después los cuatro agotados.
      _alFinal(tester, ids);
      expect(
        tester.nombresEnElCatalogo.reversed.take(_agotados.length + 1),
        ['Pastel de nuez 999', 'Pastel 640', 'Pastel 250', 'Pastel 3',
            'Pastel 1000'],
      );
      expect(find.text('Agotado'), findsNWidgets(_agotados.length));

      // Al bajar otra vez tampoco se pide nada.
      await _bajar(tester);
      expect(parametrosDelCatalogo(api), hasLength(_paginas + 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No se pudieron cargar más'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'catálogo de 1,000 productos: la búsqueda pregunta una vez y trae solo '
        'lo que coincide', (tester) async {
      final api = _backendDelCatalogo();
      final vm = await _abrirCatalogo(tester, api);
      final deNuez = [
        for (var i = 1; i <= _productos; i++)
          if (_esDeNuez(i)) i,
      ];
      expect(deNuez, hasLength(37));
      final buscada = {'busqueda': _termino};

      // Tecleo «nuez» letra por letra, cada una antes de que se cumpla la
      // espera de la búsqueda: mientras tecleo no se le pregunta nada al
      // servidor.
      for (var letras = 1; letras <= _termino.length; letras++) {
        await tester.enterText(
          find.byType(TextField),
          _termino.substring(0, letras),
        );
        await tester.pump(_entreTeclas);
      }
      expect(parametrosDelCatalogo(api), [_pedida(0)]);

      // Al dejar de teclear, una sola petición con todo lo escrito, y su
      // primera página arriba de la lista.
      await tester.pump(_esperaBusqueda);
      await tester.pumpAndSettle();
      expect(parametrosDelCatalogo(api), [_pedida(0), _pedida(0, buscada)]);
      expect(_ids(vm), _disponibles(deNuez.take(_porPagina)));
      expect(tester.bajadoEnElCatalogo, 0);

      // Bajo hasta el final del resultado: llega su segunda página (17, con
      // el agotado) y ya no se pide nada más.
      await _bajar(tester);
      await _bajar(tester);
      expect(parametrosDelCatalogo(api), [
        _pedida(0),
        _pedida(0, buscada),
        _pedida(1, buscada),
      ]);
      expect(vm.fin, isTrue);
      expect(_ids(vm), _conAgotadosAlFinal(deNuez));
      _alFinal(tester, _ids(vm));
      expect(tester.nombresEnElCatalogo, everyElement(contains(_termino)));
      expect(find.text('Agotado'), findsOneWidget);

      // Borro la búsqueda: vuelve la página 1 del catálogo completo, arriba.
      await tester.tap(find.byKey(const ValueKey('borrar')));
      await tester.pumpAndSettle();
      expect(parametrosDelCatalogo(api), hasLength(4));
      expect(parametrosDelCatalogo(api).last, _pedida(0));
      expect(vm.busqueda, isEmpty);
      expect(_ids(vm), _disponibles(_hasta(_porPagina)));
      expect(tester.nombresEnElCatalogo.first, 'Pastel 1');
      expect(tester.bajadoEnElCatalogo, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
