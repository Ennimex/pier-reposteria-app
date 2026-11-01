// test/widget/products/products_screen_test.dart — el catálogo pinta lo que
// expone su ViewModel (MVVM, Fase 4), que le pide los productos a un servidor
// falso que filtra y ordena como el real (#37), sin red: tarjetas en
// cuadrícula y lista, badges de promoción, categorías, hojas de filtros y
// orden, estado vacío y acciones sin sesión.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/auth/widgets/login_screen.dart';
import 'package:pier_reposteria/ui/core/state/navigation_provider.dart';
import 'package:pier_reposteria/ui/core/ui/skeletons.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';

import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pantalla_apretada.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _p(
  int id,
  String nombre, {
  num precio = 100,
  String categoria = 'Pasteles',
  String? sabor,
  bool popular = false,
  bool agotado = false,
}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Rico $nombre',
      'precio_chico': precio,
      'categoria': categoria,
      'imagen_url': '',
      'sabor': sabor,
      'popular': popular,
      'stock_online': agotado ? 0 : null,
      'activo': true,
      'rating': 4.5,
    };

final List<Map<String, dynamic>> _productos = [
  _p(1, 'Chocoflan', precio: 300, sabor: 'Chocolate', popular: true),
  _p(2, 'Cheesecake', precio: 450, categoria: 'Pays', sabor: 'Fresa'),
  _p(3, 'Pay de limón', precio: 200, categoria: 'Pays', agotado: true),
  _p(4, 'Rosca', precio: 380, popular: true),
  _p(5, 'Tres leches', precio: 320),
  _p(6, 'Flan napolitano', precio: 150),
];

/// GET /productos como el servidor: filtra por categoría, sabor y búsqueda
/// (en nombre o descripción) y ordena por precio. El catálogo es chico: la
/// primera página ya es la última.
Map<String, dynamic> _catalogo(LlamadaApi llamada) {
  final q = Uri.parse(llamada.endpoint).queryParameters;
  final busqueda = q['busqueda']?.toLowerCase();
  final productos = [
    for (final p in _productos)
      if ((q['categoria'] == null || p['categoria'] == q['categoria']) &&
          (q['sabor'] == null || p['sabor'] == q['sabor']) &&
          (busqueda == null ||
              '${p['nombre']} ${p['descripcion']}'
                  .toLowerCase()
                  .contains(busqueda)))
        p,
  ];
  if (q['ordenar'] == 'precio-desc') {
    productos.sort((a, b) =>
        (b['precio_chico'] as num).compareTo(a['precio_chico'] as num));
  } else if (q['ordenar'] == 'precio-asc') {
    productos.sort((a, b) =>
        (a['precio_chico'] as num).compareTo(b['precio_chico'] as num));
  }
  return {'success': true, 'productos': productos};
}

/// Lo que la búsqueda espera a que se deje de teclear antes de preguntar.
const _esperaBusqueda = Duration(milliseconds: 400);

FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.productos: _catalogo,
      ApiConstants.promocionesActivas: {
        'success': true,
        'promociones': [
          {'producto_id': 4, 'tipo': 'relampago', 'descuento_porcentaje': 10},
          {'producto_id': 5, 'tipo': 'temporada', 'descuento_porcentaje': 15},
          {
            'producto_id': 6,
            'tipo': 'destacado',
            'descuento_porcentaje': 5,
            'badge_destacado': 'Favorito',
          },
          {'producto_id': 2, 'tipo': 'nuevo', 'descuento_porcentaje': 20},
        ],
      },
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
          'sabores': ['Todos', 'Chocolate', 'Fresa'],
          'tamanos': ['Chico', 'Grande'],
          'tipos': ['Horneado'],
        },
      },
      ApiConstants.categoriaOpciones('2'): {
        'success': true,
        'sabores': ['Fresa'],
        'tipos': <String>[],
      },
      ApiConstants.clicsAgotados: {'success': true},
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
      },
      ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
      ApiConstants.carrito: {'success': true},
    });

Future<FakeApiClient> _montar(WidgetTester tester, {FakeApiClient? api}) async {
  // Pantalla alta para que el grid construya todas las tarjetas.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = api ?? _backend();
  await tester.pumpApp(const ProductsScreen(), api: backend);
  await tester.pumpAndSettle();
  return backend;
}

/// El texto que ApiService devuelve cuando no hay red (#112).
const _sinRed =
    'No pudimos conectar con Pier. Revisa tu internet e intenta de nuevo.';

void main() {
  group('ProductsScreen', () {
    testWidgets('pinta el catálogo con badges, precios con descuento y '
        'lo agotado al final', (tester) async {
      await _montar(tester);

      expect(find.text('Nuestro Menú'), findsOneWidget);
      for (final nombre in ['Chocoflan', 'Cheesecake', 'Rosca', 'Pay de limón']) {
        expect(find.text(nombre), findsOneWidget);
      }
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget); // Rosca tiene promo
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Temporada'), findsOneWidget);
      expect(find.text('Favorito'), findsOneWidget);
      expect(find.text('Nuevo'), findsOneWidget);
      expect(find.text('-10%'), findsOneWidget);
      expect(find.text(r'$342'), findsOneWidget); // 380 - 10 %
      expect(find.text(r'$380'), findsOneWidget); // tachado

      final y = tester.getTopLeft(find.text('Pay de limón')).dy;
      expect(y, greaterThan(tester.getTopLeft(find.text('Chocoflan')).dy));
    });

    // #271: al jalar para recargar, las promociones se vaciaban antes de
    // pedirlas otra vez y, mientras llegaban, las tarjetas salían sin
    // descuento.
    group('al jalar para recargar (#271)', () {
      /// Jala para recargar y deja que la recarga empiece (sin terminar).
      Future<void> jalar(WidgetTester tester) async {
        unawaited(tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show());
        // El indicador baja (150 ms) y entonces empieza la recarga.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
      }

      int pedidasDePromociones(FakeApiClient api) => api.llamadas
          .where((l) => l.endpoint == ApiConstants.promocionesActivas)
          .length;

      testWidgets('mientras llegan las promociones, la tarjeta sigue con su '
          'precio con descuento', (tester) async {
        final api = await _montar(tester);
        api.demorar(
            ApiConstants.promocionesActivas, const Duration(seconds: 1));

        await jalar(tester);

        expect(pedidasDePromociones(api), 2, reason: 'ya se recargan');
        expect(find.text(r'$342'), findsOneWidget); // 380 - 10 %
        expect(find.text('-10%'), findsOneWidget);
        expect(find.text('Flash'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(r'$342'), findsOneWidget);
      });

      testWidgets('si las promociones no llegan, se quedan las de antes',
          (tester) async {
        final api = await _montar(tester);
        api.fallar(ApiConstants.promocionesActivas, _sinRed);

        await jalar(tester);
        await tester.pumpAndSettle();

        expect(pedidasDePromociones(api), 2);
        expect(find.text(r'$342'), findsOneWidget);
        expect(find.text('-10%'), findsOneWidget);
      });
    });

    testWidgets('cambia a lista y de regreso', (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Cuadrícula'));
      await tester.pumpAndSettle();

      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Avísame'), findsOneWidget);
      expect(find.text('Popular'), findsNWidgets(2)); // en lista sale siempre

      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.text('Cuadrícula'), findsOneWidget);
    });

    testWidgets('el chip de categoría filtra y "Quitar filtros" lo regresa',
        (tester) async {
      await _montar(tester);

      // El chip va arriba; las tarjetas también muestran su categoría.
      await tester.tap(find.text('Pays').first);
      await tester.pumpAndSettle();

      expect(find.text('Chocoflan'), findsNothing);
      expect(find.text('Cheesecake'), findsOneWidget);

      await tester.tap(find.text('Quitar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets('mientras llega otra categoría se ven esqueletos y no lo de '
        'antes', (tester) async {
      final api = await _montar(tester);
      api.demorar('/productos?categoria=Pays&limite=20&offset=0',
          const Duration(milliseconds: 300));

      await tester.tap(find.text('Pays').first);
      await tester.pump();

      expect(find.byType(ProductSkeletonCard), findsWidgets);
      expect(find.byType(ProductoCatalogoCard), findsNothing);
      expect(find.text('Chocoflan'), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(find.text('Cheesecake'), findsOneWidget);
    });

    testWidgets('la hoja de filtros aplica y limpia el sabor', (tester) async {
      await _montar(tester);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      expect(find.text('Tamaño'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget); // solo el chip de categoría

      await tester.tap(find.text('Fresa'));
      await tester.pumpAndSettle();
      expect(find.text('Limpiar'), findsOneWidget);

      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsNothing);
      expect(find.text('Cheesecake'), findsOneWidget);

      await tester.tap(find.byTooltip('Filtrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    testWidgets('ordena por precio desde la hoja de orden', (tester) async {
      await _montar(tester);

      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio: Mayor a Menor'));
      await tester.pumpAndSettle();

      final cheesecake = tester.getTopLeft(find.text('Cheesecake'));
      final chocoflan = tester.getTopLeft(find.text('Chocoflan'));
      expect(cheesecake.dy <= chocoflan.dy, isTrue);
      expect(find.text('Ordenar por'), findsNothing);
    });

    // #281: el servidor ordena por el precio base, sin las promociones.
    testWidgets('por precio, las tarjetas siguen el precio con descuento',
        (tester) async {
      await _montar(tester);
      List<String> nombres() => [
            for (final tarjeta in tester.widgetList<ProductoCatalogoCard>(
                find.byType(ProductoCatalogoCard)))
              tarjeta.producto.nombre,
          ];

      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio: Menor a Mayor'));
      await tester.pumpAndSettle();

      // Flan $143, Tres leches $272 (base 320), Chocoflan $300, Rosca $342,
      // Cheesecake $360 y, agotado, el pay.
      expect(nombres(), [
        'Flan napolitano',
        'Tres leches',
        'Chocoflan',
        'Rosca',
        'Cheesecake',
        'Pay de limón',
      ]);

      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Precio: Mayor a Menor'));
      await tester.pumpAndSettle();

      expect(nombres(), [
        'Cheesecake',
        'Rosca',
        'Chocoflan',
        'Tres leches',
        'Flan napolitano',
        'Pay de limón',
      ]);
    });

    testWidgets('una búsqueda sin resultados ofrece limpiar los filtros',
        (tester) async {
      await _montar(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(_esperaBusqueda);
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan'), findsOneWidget);
    });

    // Escenario (#160): sin conexión
    //   Dado que no hay internet
    //   Cuando abro el catálogo
    //   Entonces veo que no se pudo cargar, con el motivo y «Reintentar»,
    //     y no «Sin resultados / Limpiar filtros».
    // Regresión de #160 (corregido en #162) y de #112: el motivo es el texto
    // amigable, no el de la excepción.
    testWidgets(
        'sin conexión avisa y ofrece «Reintentar» en vez de «Sin resultados»',
        (tester) async {
      await _montar(
        tester,
        api: _backend()..fallar(ApiConstants.productos, _sinRed),
      );

      expect(find.text('No pudimos cargar el catálogo'), findsOneWidget);
      expect(find.text(_sinRed), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Sin resultados'), findsNothing);
      expect(find.text('Limpiar filtros'), findsNothing);
    }, tags: 'regresion');

    // Regresión de #160 (corregido en #162): «Reintentar» sí recupera.
    testWidgets('«Reintentar» vuelve a cargar el catálogo cuando hay red',
        (tester) async {
      final api = await _montar(
        tester,
        api: _backend()..fallar(ApiConstants.productos, _sinRed),
      );
      api.responder(ApiConstants.productos, {
        'success': true,
        'productos': [_p(1, 'Chocoflan')],
      });

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Chocoflan'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    }, tags: 'regresion');

    testWidgets('el botón de borrar búsqueda vacía el buscador', (tester) async {
      await _montar(tester);

      await tester.enterText(find.byType(TextField), 'choco');
      await tester.pump(_esperaBusqueda);
      await tester.pumpAndSettle();
      expect(find.text('Rosca'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.text('Rosca'), findsOneWidget);
      expect(find.byTooltip('Ordenar'), findsOneWidget);
    });

    testWidgets('Avísame en un agotado registra el interés y lo confirma',
        (tester) async {
      final api = await _montar(tester);

      await tester.tap(find.text('Cuadrícula'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avísame'));
      await tester.pump();

      expect(find.textContaining('Anotamos tu interés'), findsOneWidget);
      // #38: no promete un aviso que no existe.
      expect(find.textContaining('Te avisaremos'), findsNothing);
      expect(api.ultima(ApiConstants.clicsAgotados)!.body, {'producto_id': 3});
    });

    testWidgets('una categoría pedida desde el inicio cierra lo apilado y '
        'filtra', (tester) async {
      await _montar(tester);
      final contexto = tester.element(find.byType(ProductsScreen));
      // Como dejar un detalle abierto en la pestaña del catálogo.
      unawaited(Navigator.of(contexto).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detalle abierto')))));
      await tester.pumpAndSettle();
      expect(find.text('Detalle abierto'), findsOneWidget);

      contexto.read<NavigationProvider>().goCatalogo(categoria: 'Pays');
      await tester.pumpAndSettle();

      expect(find.text('Detalle abierto'), findsNothing);
      expect(find.text('Cheesecake'), findsOneWidget);
      expect(find.text('Chocoflan'), findsNothing);
    });

    // Regresión de #111: el catálogo decía «agregado» aunque el alta fallara.
    testWidgets('con sesión confirma «agregado» solo si el backend acepta',
        (tester) async {
      final api = await _montar(tester);
      await tester.iniciarSesion(find.byType(ProductsScreen));
      await tester.tap(find.text('Cuadrícula'));
      await tester.pumpAndSettle();

      api.fallar(ApiConstants.carrito, 'No hay stock suficiente');
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('agregado'), findsNothing);
      expect(find.text('No hay stock suficiente'), findsOneWidget);

      api.responder(ApiConstants.carrito, {'success': true});
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();
      expect(find.text('Chocoflan agregado'), findsOneWidget);
      final alta = api.llamadas.lastWhere((l) =>
          l.endpoint == ApiConstants.carrito && l.metodo == 'POST-Auth');
      expect(alta.body, {'producto_id': 1, 'cantidad': 1, 'tamano': 'chico'});
    }, tags: 'regresion');

    // #275: sin red, GET /favoritos/ids falla y el detalle de un favorito
    // salía con el corazón vacío.
    testWidgets('sin red, el detalle de un favorito conserva el corazón lleno',
        (tester) async {
      final api = _backend()
        ..responder(ApiConstants.favoritosIds, {
          'success': true,
          'ids': [4],
        });
      await _montar(tester, api: api);
      await tester.iniciarSesion(find.byType(ProductsScreen));
      await tester.pumpAndSettle();
      api.fallar(ApiConstants.favoritosIds, _sinRed);

      await tester.tap(find.text('Rosca'));
      await tester.pumpAndSettle();

      final delDetalle = find.descendant(
        of: find.byType(ProductDetailScreen),
        matching: find.byIcon(Icons.favorite_rounded),
      );
      expect(delDetalle, findsOneWidget);
      expect(api.llamadas.where((l) => l.endpoint == ApiConstants.favoritosIds),
          hasLength(2));
    });

    testWidgets('sin sesión, el corazón manda a iniciar sesión', (tester) async {
      await _montar(tester);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  // Regresión de #285: el estado vacío medía justo lo que quedaba de
  // pantalla; si no cabía se desbordaba y su botón quedaba cortado.
  group('El estado vacío del catálogo cabe en una pantalla apretada (#285)',
      () {
    for (final apreton in Apreton.values) {
      testWidgets(
          'sin conexión, «Reintentar» se alcanza ${apreton.descripcion}',
          (tester) async {
        await _montar(
          tester,
          api: _backend()..fallar(ApiConstants.productos, _sinRed),
        );
        await tester.apretar(apreton);

        await tester.alcanzar(find.text('Reintentar'));
      }, tags: 'regresion');

      testWidgets(
          'sin resultados, «Limpiar filtros» se alcanza '
          '${apreton.descripcion}', (tester) async {
        await _montar(
          tester,
          api: _backend()
            ..responder(ApiConstants.productos,
                {'success': true, 'productos': <Object>[]}),
        );
        await tester.apretar(apreton);

        await tester.alcanzar(find.text('Limpiar filtros'));
      }, tags: 'regresion');
    }
  });
}
