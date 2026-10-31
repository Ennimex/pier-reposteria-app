// test/aceptacion/catalogo/catalogo_test.dart — escenarios Gherkin del
// catálogo (historia #37: buscar y filtrar los productos por categoría,
// sabor, tamaño y tipo, y verlos de 20 en 20 al bajar), sin red: la pantalla
// real del catálogo, su ViewModel y el repositorio de productos sobre
// FakeApiClient, que responde GET /productos como el backend: deja los
// productos que cumplen la consulta (categoría, búsqueda, sabor, tamaño y
// tipo) y entrega `limite` desde `offset`. Los agotados vienen entre los
// demás: es la app la que los deja al final, cuando ya no quedan páginas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

// Las páginas que siguen a la primera tardan en llegar, como por la red: si
// llegaran entre dos eventos del mismo arrastre, el último vería la lista sin
// acomodar lo nuevo y pediría una página de más.
const _segunda = '/productos?limite=20&offset=20';
const _tercera = '/productos?limite=20&offset=40';
const _segundaDePays = '/productos?categoria=Pays&limite=20&offset=20';

/// Lo que tarda en llegar una página demorada.
const _demora = Duration(milliseconds: 300);

/// Lo que la búsqueda espera a que se deje de teclear antes de preguntar.
const _esperaBusqueda = Duration(milliseconds: 400);

/// Un producto tal como lo manda GET /productos.
Map<String, dynamic> _producto(
  int id,
  String nombre, {
  String categoria = 'Pasteles',
  String? sabor,
  String? tamano,
  String? tipo,
  bool agotado = false,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Rico $nombre',
      'precio_chico': 100,
      'categoria': categoria,
      'sabor': sabor,
      'tamano': tamano,
      'tipo': tipo,
      'imagen_url': '',
      'stock_online': agotado ? 0 : null,
      'activo': true,
    };

/// El menú chico de los primeros escenarios: dos pasteles, una rosca y cuatro
/// pays, cada uno con su sabor, tamaño y tipo.
final List<Map<String, dynamic>> _menu = [
  _producto(1, 'Chocoflan',
      sabor: 'Chocolate', tamano: 'Grande', tipo: 'Horneado'),
  _producto(2, 'Tres leches', sabor: 'Vainilla', tamano: 'Grande', tipo: 'Frío'),
  _producto(3, 'Rosca de reyes',
      categoria: 'Roscas', sabor: 'Naranja', tamano: 'Grande', tipo: 'Horneado'),
  _producto(4, 'Pay de limón',
      categoria: 'Pays', sabor: 'Limón', tamano: 'Grande', tipo: 'Frío'),
  _producto(5, 'Pay de fresa',
      categoria: 'Pays', sabor: 'Fresa', tamano: 'Chico', tipo: 'Frío'),
  _producto(6, 'Pay de queso',
      categoria: 'Pays', sabor: 'Queso', tamano: 'Grande', tipo: 'Horneado'),
  _producto(7, 'Pay de chocolate',
      categoria: 'Pays', sabor: 'Chocolate', tamano: 'Chico', tipo: 'Horneado'),
];

final List<String> _nombresDelMenu = [
  for (final p in _menu) p['nombre'] as String,
];

const List<String> _paysDelMenu = [
  'Pay de limón',
  'Pay de fresa',
  'Pay de queso',
  'Pay de chocolate',
];

/// [cuantos] pasteles «Pastel 1» … «Pastel N», los de [agotados] (por número)
/// sin existencias.
List<Map<String, dynamic>> _pasteles(
  int cuantos, {
  Set<int> agotados = const {},
}) =>
    [
      for (var i = 1; i <= cuantos; i++)
        _producto(i, 'Pastel $i', agotado: agotados.contains(i)),
    ];

/// [cuantos] pays «Pay 1» … «Pay N».
List<Map<String, dynamic>> _pays(int cuantos) => [
      for (var i = 1; i <= cuantos; i++)
        _producto(1000 + i, 'Pay $i', categoria: 'Pays'),
    ];

/// GET /productos como el servidor: deja los que cumplen la categoría, la
/// búsqueda (en el nombre o la descripción), el sabor, el tamaño y el tipo
/// que pida la consulta y entrega `limite` desde `offset`; sin `limite`,
/// todos.
RespuestaDinamica _servidor(List<Map<String, dynamic>> catalogo) =>
    (llamada) {
      final q = Uri.parse(llamada.endpoint).queryParameters;
      final busqueda = q['busqueda']?.toLowerCase();
      final coinciden = [
        for (final p in catalogo)
          if ((q['categoria'] == null || p['categoria'] == q['categoria']) &&
              (q['sabor'] == null || p['sabor'] == q['sabor']) &&
              (q['tamano'] == null || p['tamano'] == q['tamano']) &&
              (q['tipo'] == null || p['tipo'] == q['tipo']) &&
              (busqueda == null ||
                  '${p['nombre']} ${p['descripcion']}'
                      .toLowerCase()
                      .contains(busqueda)))
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
    };

/// El backend con ese [catalogo]; la categoría Pays ofrece sabores y tipos
/// propios y los tamaños son los de siempre.
FakeApiClient _backend(List<Map<String, dynamic>> catalogo) =>
    FakeApiClient(
      respuestas: {
        ApiConstants.productos: _servidor(catalogo),
        ApiConstants.promocionesActivas: {
          'success': true,
          'promociones': <Map<String, dynamic>>[],
        },
        ApiConstants.categorias: {
          'success': true,
          'categorias': [
            {'id': 1, 'nombre': 'Pasteles'},
            {'id': 2, 'nombre': 'Roscas'},
            {'id': 3, 'nombre': 'Pays'},
          ],
        },
        ApiConstants.filtros: {
          'success': true,
          'filtros': {
            'sabores': ['Chocolate', 'Vainilla', 'Naranja', 'Limón'],
            'tamanos': ['Chico', 'Grande'],
            'tipos': ['Horneado', 'Frío'],
          },
        },
        ApiConstants.categoriaOpciones('3'): {
          'success': true,
          'sabores': ['Limón', 'Fresa', 'Queso', 'Chocolate'],
          'tipos': ['Frío', 'Horneado'],
        },
      },
    );

/// Un celular de ancho 540 y [alto] px: uno alto deja ver (y construir) toda
/// la lista sin bajar.
void _celular(WidgetTester tester, {required double alto}) {
  tester.view
    ..physicalSize = Size(540, alto)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Abre el catálogo y deja que llegue lo que se pidió al instante.
Future<void> _abrirCatalogo(
  WidgetTester tester,
  FakeApiClient api, {
  double alto = 3000,
}) async {
  _celular(tester, alto: alto);
  await tester.pumpApp(const ProductsScreen(), api: api);
  await tester.pumpAndSettle();
}

/// Lo que se le pidió al servidor para la [pagina] (desde 0) de una
/// [consulta]: 20 desde la fila que toca.
Map<String, String> _pedida(
  int pagina, [
  Map<String, String> consulta = const {},
]) =>
    {...consulta, 'limite': '20', 'offset': '${pagina * 20}'};

/// Los parámetros de cada petición de productos del catálogo, en orden (la
/// lista completa que pide el Inicio no los lleva).
List<Map<String, String>> _peticiones(FakeApiClient api) => [
      for (final l in api.llamadas)
        if (l.endpoint.startsWith('${ApiConstants.productos}?'))
          Uri.parse(l.endpoint).queryParameters,
    ];

/// Los nombres de las tarjetas que la lista tiene construidas, de arriba
/// abajo: con un celular alto, toda la lista.
List<String> _nombres(WidgetTester tester) => [
      for (final tarjeta in tester.widgetList<ProductoCatalogoCard>(
        find.byType(ProductoCatalogoCard),
      ))
        tarjeta.producto.nombre,
    ];

final Finder _lista = find.byType(CustomScrollView);
final Finder _desplazable =
    find.descendant(of: _lista, matching: find.byType(Scrollable));

/// Cuánto se ha bajado la lista.
double _bajado(WidgetTester tester) =>
    tester.state<ScrollableState>(_desplazable).position.pixels;

/// Bajo hasta el final de lo cargado y espero a que llegue la página que eso
/// pida, si pide alguna.
Future<void> _bajar(WidgetTester tester) async {
  await tester.drag(_lista, const Offset(0, -20000));
  await tester.pump();
  await tester.pump(_demora);
  await tester.pumpAndSettle();
}

/// Toco el chip de [categoria]. Las tarjetas también dicen la suya: el chip
/// va antes.
Future<void> _elegirCategoria(WidgetTester tester, String categoria) async {
  await tester.tap(find.text(categoria).first);
  await tester.pumpAndSettle();
}

/// Escribo [texto] en el buscador y espero a que se deje de teclear.
Future<void> _buscar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump(_esperaBusqueda);
  await tester.pumpAndSettle();
}

/// Abro los filtros, toco la opción [opcion] y los aplico.
Future<void> _filtrarPor(WidgetTester tester, String opcion) async {
  await tester.tap(find.byTooltip('Filtrar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(opcion));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aplicar filtros'));
  await tester.pumpAndSettle();
}

/// Abro los filtros, los limpio y aplico.
Future<void> _quitarFiltros(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtrar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Limpiar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aplicar filtros'));
  await tester.pumpAndSettle();
}

/// Desmonta para cancelar lo que la pantalla deje esperando (el registro de
/// una búsqueda).
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('#37 Catálogo: búsqueda, filtros y páginas', () {
    // Escenario: filtrar por categoría
    //   Dado que estoy en el catálogo
    //   Cuando elijo una categoría
    //   Entonces solo veo los productos de esa categoría
    testWidgets('Escenario: filtrar por categoría', (tester) async {
      // Dado que estoy en el catálogo
      final api = _backend(_menu);
      await _abrirCatalogo(tester, api);
      expect(_nombres(tester), _nombresDelMenu);

      // Cuando elijo una categoría
      await _elegirCategoria(tester, 'Pays');

      // Entonces solo veo los productos de esa categoría
      expect(_nombres(tester), _paysDelMenu);
      expect(_peticiones(api).last, _pedida(0, {'categoria': 'Pays'}));
    });

    // Escenario: buscar por texto
    //   Dado que estoy en el catálogo
    //   Cuando escribo parte del nombre de un producto
    //   Entonces la lista muestra los productos que coinciden
    testWidgets('Escenario: buscar por texto', (tester) async {
      // Dado que estoy en el catálogo
      final api = _backend(_menu);
      await _abrirCatalogo(tester, api);
      expect(_nombres(tester), _nombresDelMenu);

      // Cuando escribo parte del nombre de un producto
      await _buscar(tester, 'choco');

      // Entonces la lista muestra los productos que coinciden
      expect(_nombres(tester), ['Chocoflan', 'Pay de chocolate']);
      expect(_peticiones(api).last, _pedida(0, {'busqueda': 'choco'}));
      await _desmontar(tester);
    });

    // Escenario: filtros de sabor, tamaño y tipo
    //   Dado que elegí una categoría que ofrece filtros
    //   Cuando selecciono un sabor, un tamaño o un tipo
    //   Entonces la lista se reduce a los productos que cumplen el filtro
    testWidgets('Escenario: filtros de sabor, tamaño y tipo', (tester) async {
      // Dado que elegí una categoría que ofrece filtros
      final api = _backend(_menu);
      await _abrirCatalogo(tester, api);
      await _elegirCategoria(tester, 'Pays');
      expect(_nombres(tester), _paysDelMenu);

      for (final (opcion, filtro, cumplen) in [
        ('Fresa', 'sabor', ['Pay de fresa']),
        ('Grande', 'tamano', ['Pay de limón', 'Pay de queso']),
        ('Horneado', 'tipo', ['Pay de queso', 'Pay de chocolate']),
      ]) {
        // Cuando selecciono un sabor, un tamaño o un tipo
        await _filtrarPor(tester, opcion);

        // Entonces la lista se reduce a los productos que cumplen el filtro
        expect(_nombres(tester), cumplen);
        expect(
          _peticiones(api).last,
          _pedida(0, {'categoria': 'Pays', filtro: opcion}),
        );

        await _quitarFiltros(tester);
        expect(_nombres(tester), _paysDelMenu);
      }
    });

    // Escenario: productos agotados
    //   Dado que la lista incluye productos agotados
    //   Cuando veo el catálogo hasta el final
    //   Entonces los agotados aparecen al final de la lista
    testWidgets('Escenario: productos agotados', (tester) async {
      // Dado que la lista incluye productos agotados (el servidor los manda
      // entre los demás: dos en la primera página y uno en la segunda)
      const agotados = {2, 4, 22};
      final disponibles = [
        for (var i = 1; i <= 25; i++)
          if (!agotados.contains(i)) 'Pastel $i',
      ];
      final api = _backend(_pasteles(25, agotados: agotados))
        ..demorar(_segunda, _demora);

      // Cuando veo el catálogo hasta el final: con un celular alto, la
      // primera página no lo llena y la app pide la segunda sola. Mientras
      // llega, los agotados de la primera esperan.
      _celular(tester, alto: 6000);
      await tester.pumpApp(const ProductsScreen(), api: api);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_peticiones(api), [_pedida(0), _pedida(1)]);
      // De los 20 de la primera página se ven 18: el 2 y el 4 esperan.
      expect(_nombres(tester), disponibles.take(18).toList());
      expect(find.text('Agotado'), findsNothing);
      await tester.pump(_demora);
      await tester.pumpAndSettle();

      // Entonces los agotados aparecen al final de la lista
      expect(_nombres(tester), [
        ...disponibles,
        for (final n in agotados) 'Pastel $n',
      ]);
      expect(find.text('Agotado'), findsNWidgets(3));
    });

    // Escenario: cargar más al bajar
    //   Dado que el catálogo tiene más de 20 productos
    //   Cuando bajo hasta el final de la lista
    //   Entonces se cargan los siguientes y los veo
    testWidgets('Escenario: cargar más al bajar', (tester) async {
      // Dado que el catálogo tiene más de 20 productos
      final api = _backend(_pasteles(45))..demorar(_segunda, _demora);
      await _abrirCatalogo(tester, api, alto: 1200);
      expect(_peticiones(api), [_pedida(0)]);

      // Cuando bajo hasta el final de la lista
      await _bajar(tester);

      // Entonces se cargan los siguientes y los veo
      expect(_peticiones(api), [_pedida(0), _pedida(1)]);
      await tester.scrollUntilVisible(
        find.text('Pastel 21'),
        500,
        scrollable: _desplazable,
      );
      expect(find.text('Pastel 21'), findsOneWidget);
    });

    // Escenario: al filtrar se empieza de nuevo
    //   Dado que ya cargué varias páginas
    //   Cuando elijo una categoría
    //   Entonces la lista empieza otra vez desde la primera página de esa
    //   categoría
    testWidgets('Escenario: al filtrar se empieza de nuevo', (tester) async {
      // Dado que ya cargué varias páginas
      final api = _backend([..._pasteles(60), ..._pays(25)])
        ..demorar(_segunda, _demora)
        ..demorar(_tercera, _demora)
        ..demorar(_segundaDePays, _demora);
      await _abrirCatalogo(tester, api, alto: 1200);
      await _bajar(tester);
      await _bajar(tester);
      expect(_peticiones(api), [_pedida(0), _pedida(1), _pedida(2)]);
      await tester.scrollUntilVisible(
        find.text('Pastel 41'),
        500,
        scrollable: _desplazable,
      );
      expect(_bajado(tester), greaterThan(1000));

      // Cuando elijo una categoría
      await _elegirCategoria(tester, 'Pays');

      // Entonces la lista empieza otra vez desde la primera página de esa
      // categoría
      expect(_peticiones(api).last, _pedida(0, {'categoria': 'Pays'}));
      expect(_bajado(tester), 0);
      expect(_nombres(tester).first, 'Pay 1');
      expect(_nombres(tester), everyElement(startsWith('Pay ')));
      // y las páginas que siguen son las de esa categoría, desde la segunda
      await _bajar(tester);
      expect(_peticiones(api), [
        _pedida(0),
        _pedida(1),
        _pedida(2),
        _pedida(0, {'categoria': 'Pays'}),
        _pedida(1, {'categoria': 'Pays'}),
      ]);
    });

    // Escenario: fin de la lista
    //   Dado que llegué a la última página
    //   Cuando bajo otra vez
    //   Entonces no se piden más productos
    testWidgets('Escenario: fin de la lista', (tester) async {
      // Dado que llegué a la última página (la segunda trae 5: menos de 20)
      final api = _backend(_pasteles(25))..demorar(_segunda, _demora);
      await _abrirCatalogo(tester, api, alto: 1200);
      await _bajar(tester);
      await _bajar(tester);
      expect(find.text('Pastel 25'), findsOneWidget);

      // Cuando bajo otra vez
      await _bajar(tester);
      await _bajar(tester);

      // Entonces no se piden más productos
      expect(_peticiones(api), [_pedida(0), _pedida(1)]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No se pudieron cargar más'), findsNothing);
    });
  });
}
