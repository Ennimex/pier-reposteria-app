// test/widget/products/catalogo_paginado_screen_test.dart — el catálogo trae
// sus productos por páginas al bajar (#37): al acercarse al final pide la
// siguiente y la agrega, abajo se ve «cargando» o el aviso para reintentar, una
// primera página que no llena la pantalla pide la siguiente sola (la que llega
// con el catálogo tapado por otra pantalla, sin error ni pedir más), la lista
// vuelve arriba al empezar otra consulta (al recargar la misma se queda donde
// iba), mientras llega la primera página hay esqueletos y la hoja de orden
// ofrece «Mejor calificados». Con la copia de la primera página guardada en el
// teléfono (#265) se ve al instante en lugar de los esqueletos (al bajar a su
// final, el indicador dice que viene más), la página nueva la reemplaza sin
// mover la lista y, sin internet, se queda con su aviso; al volver la conexión,
// «Reintentar» trae la página 1 antes que la 2. Servidor falso que pagina como
// el real; sin red.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/core/ui/skeletons.dart';
import 'package:pier_reposteria/ui/products/widgets/pie_catalogo.dart';
import 'package:pier_reposteria/ui/products/widgets/producto_catalogo_card.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/catalogo.dart';
import '../../helpers/pump_app.dart';

const _primera = '/productos?limite=20&offset=0';
const _segunda = '/productos?limite=20&offset=20';

/// El texto que ApiService devuelve cuando no hay red (#112).
const _sinRed =
    'No pudimos conectar con Pier. Revisa tu internet e intenta de nuevo.';

/// Lo que la búsqueda espera a que se deje de teclear antes de preguntar.
const _esperaBusqueda = Duration(milliseconds: 400);

/// Lo que tarda en llegar una respuesta demorada.
const _demora = Duration(milliseconds: 300);

/// GET /productos como el servidor: los [total] «Producto N» (o 25 «Pay N» en
/// la categoría Pays y en la búsqueda «Pay») de `limite` en `limite` desde
/// `offset`; sin `limite`, todos. [falla] decide si falla la página que
/// empieza en ese `offset`.
RespuestaDinamica _servidor({
  int total = 45,
  bool Function(int offset)? falla,
}) =>
    (llamada) {
      final q = Uri.parse(llamada.endpoint).queryParameters;
      final limite = int.tryParse(q['limite'] ?? '');
      final offset = int.tryParse(q['offset'] ?? '') ?? 0;
      if (falla?.call(offset) ?? false) {
        return {'success': false, 'message': _sinRed};
      }
      final enPays = q['categoria'] == 'Pays' || q['busqueda'] == 'Pay';
      final cuantos = enPays ? 25 : total;
      final todos = [for (var i = 1; i <= cuantos; i++) i];
      final pagina = limite == null ? todos : todos.skip(offset).take(limite);
      return {
        'success': true,
        'productos': [
          for (final i in pagina)
            {
              'id': enPays ? 100 + i : i,
              'nombre': enPays ? 'Pay $i' : 'Producto $i',
              'precio_chico': 100,
              'categoria': enPays ? 'Pays' : 'Pasteles',
              'imagen_url': '',
              'activo': true,
            },
        ],
      };
    };

FakeApiClient _backend({RespuestaDinamica? productos}) => FakeApiClient(
      respuestas: {
        ApiConstants.productos: productos ?? _servidor(),
        ApiConstants.promocionesActivas: {
          'success': true,
          'promociones': <Map<String, dynamic>>[],
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
          'filtros': <String, dynamic>{},
        },
        ApiConstants.categoriaOpciones('2'): {
          'success': true,
          'sabores': <String>[],
          'tipos': <String>[],
        },
      },
    );

/// Abre el catálogo y deja que llegue lo que se pidió al instante.
Future<FakeApiClient> _montar(
  WidgetTester tester, {
  FakeApiClient? api,
  double alto = 1200,
}) async {
  tester.usarCelular(alto: alto);
  final backend = api ?? _backend();
  await tester.pumpApp(const ProductsScreen(), api: backend);
  await tester.pumpAndSettle();
  return backend;
}

/// El aviso de que se ve el catálogo guardado en el teléfono (#265).
const _aviso = 'Sin conexión: es el último catálogo que viste';

/// Lo que hay guardado en el teléfono al abrir el catálogo: una copia de
/// [cuantos] productos, «Copia 1» a «Copia N» (la llave y el formato son los
/// del servicio que la guarda).
Map<String, Object> _conCopia(int cuantos) => {
      'pierreposteria_catalogo_v1': jsonEncode({
        'guardado': '2026-10-30T18:00:00.000Z',
        'productos': [
          for (var i = 1; i <= cuantos; i++)
            Product(
              id: 'c$i',
              nombre: 'Copia $i',
              descripcion: '',
              precio: 90,
              categoria: 'Pasteles',
              imagenUrl: '',
            ).toJson(),
        ],
      }),
    };

/// Abre el catálogo con [cuantos] productos ya guardados en el teléfono, sin
/// esperar a que llegue nada.
Future<void> _abrirConCopia(
  WidgetTester tester,
  FakeApiClient api, {
  int cuantos = 20,
}) async {
  tester.usarCelular();
  await tester.pumpApp(
    const ProductsScreen(),
    api: api,
    preferencias: _conCopia(cuantos),
  );
}

void main() {
  group('Catálogo por páginas en pantalla (#37)', () {
    testWidgets('al bajar al final pide la siguiente página y la muestra',
        (tester) async {
      // La respuesta llega después, como por la red: si llegara entre dos
      // eventos del mismo arrastre, el último vería la lista sin acomodar lo
      // nuevo y pediría también la tercera página.
      final api = _backend()..demorar(_segunda, _demora);
      await _montar(tester, api: api);
      expect(pedidasDelCatalogo(api), [_primera]);
      expect(find.text('Producto 21'), findsNothing);

      await tester.bajarAlFinalDelCatalogo();
      await tester.pump(_demora);
      await tester.pumpAndSettle();

      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
      await tester.scrollUntilVisible(
        find.text('Producto 21'),
        500,
        scrollable: desplazableDelCatalogo,
      );
      expect(find.text('Producto 21'), findsOneWidget);
    });

    testWidgets('mientras carga más se ve el indicador abajo', (tester) async {
      final api = _backend()..demorar(_segunda, _demora);
      await _montar(tester, api: api);
      final indicador = find.descendant(
        of: find.byType(PieCatalogo),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(indicador, findsNothing);

      await tester.bajarAlFinalDelCatalogo();

      expect(indicador, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Abajo de la última tarjeta, no en lugar de ella.
      expect(find.text('Producto 20'), findsOneWidget);
      expect(
        tester.getTopLeft(indicador).dy,
        greaterThan(tester.getTopLeft(find.text('Producto 20')).dy),
      );

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(indicador, findsNothing);
    });

    testWidgets('mientras carga una página no se pide otra', (tester) async {
      final api = _backend()..demorar(_segunda, _demora);
      await _montar(tester, api: api);

      await tester.bajarAlFinalDelCatalogo();
      await tester.bajarAlFinalDelCatalogo();
      await tester.drag(listaDelCatalogo, const Offset(0, 200));
      await tester.drag(listaDelCatalogo, const Offset(0, -200));
      await tester.pump();

      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
    });

    testWidgets(
        'si falla la siguiente página aparece Reintentar y vuelve a pedir',
        (tester) async {
      var falla = true;
      final api = _backend(
        productos: _servidor(falla: (offset) => falla && offset == 20),
      );
      await _montar(tester, api: api);

      await tester.bajarAlFinalDelCatalogo();

      // El aviso es del pie, abajo de lo que ya se veía.
      Finder delPie(Finder finder) =>
          find.descendant(of: find.byType(PieCatalogo), matching: finder);
      expect(delPie(find.text('No se pudieron cargar más')), findsOneWidget);
      expect(delPie(find.text(_sinRed)), findsOneWidget);
      expect(delPie(find.byIcon(LucideIcons.wifiOff)), findsOneWidget);
      expect(delPie(find.text('Reintentar')), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      // Lo que ya se veía se queda.
      expect(find.byType(ProductoCatalogoCard), findsWidgets);
      expect(pedidasDelCatalogo(api), [_primera, _segunda]);

      // Seguir moviendo la lista no insiste: eso es del botón.
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.drag(listaDelCatalogo, const Offset(0, 100));
      await tester.drag(listaDelCatalogo, const Offset(0, -100));
      await tester.pump();
      expect(pedidasDelCatalogo(api), [_primera, _segunda]);

      falla = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(pedidasDelCatalogo(api), [_primera, _segunda, _segunda]);
      expect(find.text('No se pudieron cargar más'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Producto 21'),
        500,
        scrollable: desplazableDelCatalogo,
      );
      expect(find.text('Producto 21'), findsOneWidget);
    });

    testWidgets('mientras llega la primera página se ven esqueletos',
        (tester) async {
      tester.usarCelular(alto: 4000);
      final api = _backend()..demorar(_primera, _demora);
      await tester.pumpApp(const ProductsScreen(), api: api);
      await tester.pump();

      // 6 en cuadrícula y 4 en lista, y ninguna tarjeta de producto.
      expect(find.byType(ProductSkeletonCard), findsNWidgets(6));
      expect(find.byType(ProductoCatalogoCard), findsNothing);
      await tester.tap(find.text('Cuadrícula'));
      await tester.pump();
      expect(find.byType(ProductSkeletonCard), findsNWidgets(4));

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(find.text('Producto 1'), findsOneWidget);
    });

    testWidgets('en el primer cuadro ya hay esqueletos y no una cuadrícula vacía',
        (tester) async {
      tester.usarCelular(alto: 4000);
      final api = _backend()..demorar(_primera, _demora);
      await tester.pumpApp(const ProductsScreen(), api: api);
      // Un solo cuadro: la carga la lanza el callback posterior al cuadro.
      expect(find.byType(ProductSkeletonCard), findsNWidgets(6));
      expect(find.byType(ProductoCatalogoCard), findsNothing);
      expect(find.text('Sin resultados'), findsNothing);

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(find.text('Producto 1'), findsOneWidget);
    });

    testWidgets('los esqueletos se anuncian una vez como «Cargando productos»',
        (tester) async {
      final semantica = tester.ensureSemantics();
      tester.usarCelular(alto: 4000);
      final api = _backend()..demorar(_primera, _demora);
      await tester.pumpApp(const ProductsScreen(), api: api);
      await tester.pump();

      expect(find.bySemanticsLabel('Cargando productos'), findsOneWidget);

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Cargando productos'), findsNothing);
      semantica.dispose();
    });

    testWidgets('el indicador de abajo se anuncia como «Cargando más productos»',
        (tester) async {
      final semantica = tester.ensureSemantics();
      final api = _backend()..demorar(_segunda, _demora);
      await _montar(tester, api: api);

      await tester.bajarAlFinalDelCatalogo();

      expect(find.bySemanticsLabel('Cargando más productos'), findsOneWidget);
      await tester.pump(_demora);
      await tester.pumpAndSettle();
      semantica.dispose();
    });

    testWidgets('«Mejor calificados» lleva la estrella en la hoja de orden',
        (tester) async {
      await _montar(tester);
      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();

      final fila = find.ancestor(
        of: find.text('Mejor calificados'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(
            of: fila.first, matching: find.byIcon(LucideIcons.star)),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.thumbsUp), findsNothing);
    });

    testWidgets('la hoja de orden ofrece Mejor calificados y no Z–A',
        (tester) async {
      final api = await _montar(tester);

      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      expect(find.text('Mejor calificados'), findsOneWidget);
      expect(find.text('Nombre: A–Z'), findsOneWidget);
      expect(find.text('Nombre: Z–A'), findsNothing);

      await tester.tap(find.text('Mejor calificados'));
      await tester.pumpAndSettle();

      expect(find.text('Ordenar por'), findsNothing);
      expect(api.llamo('/productos?ordenar=rating'), isTrue);
    });

    testWidgets('con Mejor calificados baja de 20 en 20 sin pedir más',
        (tester) async {
      final api = await _montar(tester);
      await tester.tap(find.byTooltip('Ordenar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mejor calificados'));
      await tester.pumpAndSettle();
      expect(find.text('Producto 21'), findsNothing);

      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Producto 21'),
        500,
        scrollable: desplazableDelCatalogo,
      );

      expect(find.text('Producto 21'), findsOneWidget);
      // El servidor entregó todo de una vez; lo demás se muestra sin red.
      expect(
        pedidasDelCatalogo(api).where((e) => e.contains('rating')),
        ['/productos?ordenar=rating'],
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('si la página no llena la pantalla, pide la siguiente sola',
        (tester) async {
      // Alta como para ver las 20 primeras tarjetas sin bajar: no hay
      // desplazamiento que avise, lo pide al llegar la página.
      final api = await _montar(tester, alto: 6000);

      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
      expect(find.text('Producto 21'), findsOneWidget);
    });

    // Otra pantalla la tapa desde que se abrió: la lista existe pero aún no
    // se acomoda, así que no sabe cuánto le falta para el final.
    testWidgets('tapada desde que se abre, la página 1 llega sin error ni '
        'pedir más', (tester) async {
      tester.usarCelular();
      final api = _backend()..demorar(_segunda, _demora);
      await tester.pumpApp(
        Navigator(
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(builder: (_) => const ProductsScreen()),
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Encima')),
            ),
          ],
        ),
        api: api,
      );
      await tester.pumpAndSettle();

      // La página 1 llegó sin que la lista se acomodara: ni error ni otra.
      expect(tester.takeException(), isNull);
      expect(pedidasDelCatalogo(api), [_primera]);

      // Al quitar la de encima ya se ve y, al bajar al final, pide la 2.
      Navigator.of(tester.element(find.text('Encima'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Producto 1'), findsOneWidget);
      await tester.bajarAlFinalDelCatalogo();
      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
    });

    testWidgets('al llegar a la última página ya no pide ni muestra nada abajo',
        (tester) async {
      final api = _backend(productos: _servidor(total: 25));
      await _montar(tester, api: api);

      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();
      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();
      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();

      // La segunda trajo 5 (menos de 20): es la última.
      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
      expect(find.text('Producto 25'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No se pudieron cargar más'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      // El pie queda como un espacio de 24.
      expect(tester.getSize(find.byType(PieCatalogo)).height, 24);
    });
  });

  group('Al empezar otra consulta la lista vuelve arriba (#37)', () {
    testWidgets('al cambiar de categoría', (tester) async {
      final api = _backend()
        ..demorar('/productos?categoria=Pays&limite=20&offset=0', _demora);
      await _montar(tester, api: api);
      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();
      expect(tester.bajadoEnElCatalogo, greaterThan(1000));

      await tester.tap(find.text('Pays').first);
      await tester.pump();

      // Los esqueletos ya se ven desde arriba, no desde donde se iba.
      expect(find.byType(ProductSkeletonCard), findsWidgets);
      expect(tester.bajadoEnElCatalogo, 0);

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(tester.bajadoEnElCatalogo, 0);
      expect(find.text('Pay 1'), findsOneWidget);
    });

    testWidgets('al buscar, hasta que se pregunta y no mientras se teclea',
        (tester) async {
      final api = _backend()
        ..demorar('/productos?busqueda=Pay&limite=20&offset=0', _demora);
      await _montar(tester, api: api);
      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();
      final bajado = tester.bajadoEnElCatalogo;
      expect(bajado, greaterThan(1000));

      // Mientras se teclea, la lista sigue donde estaba.
      await tester.enterText(find.byType(TextField), 'Pay');
      await tester.pump();
      expect(tester.bajadoEnElCatalogo, bajado);

      await tester.pump(_esperaBusqueda);
      expect(find.byType(ProductSkeletonCard), findsWidgets);
      expect(tester.bajadoEnElCatalogo, 0);

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(tester.bajadoEnElCatalogo, 0);
      expect(find.text('Pay 1'), findsOneWidget);
      await tester.desmontarCatalogo();
    });

    // Jalar para refrescar empieza con la lista arriba; con la lista abajo,
    // la misma recarga llega desde «Reintentar» del aviso sin conexión, que
    // muestra el indicador como si se hubiera jalado.
    testWidgets('al recargar la misma consulta no: se queda donde iba',
        (tester) async {
      final api = await _montar(tester);
      await tester.drag(listaDelCatalogo, const Offset(0, -300));
      await tester.pumpAndSettle();
      final bajado = tester.bajadoEnElCatalogo;
      expect(bajado, greaterThan(0));
      api.demorar(_primera, _demora);

      unawaited(tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show());
      await tester.pump();
      // El indicador baja y pide la página 1 otra vez.
      await tester.pump(const Duration(milliseconds: 200));

      expect(pedidasDelCatalogo(api), [_primera, _primera]);
      expect(tester.bajadoEnElCatalogo, bajado, reason: 'mientras llega');

      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(tester.bajadoEnElCatalogo, bajado);
      expect(find.byType(ProductSkeletonCard), findsNothing);
    });
  });

  group('Catálogo guardado en el teléfono en pantalla (#265)', () {
    testWidgets('con copia se ve al instante, sin esqueletos, y la reemplaza '
        'la página nueva', (tester) async {
      final api = _backend()..demorar(_primera, _demora);
      await _abrirConCopia(tester, api);
      await tester.pump();

      // La copia ya se ve mientras la página nueva llega: ni un esqueleto.
      expect(find.text('Copia 1'), findsOneWidget);
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(find.text(_aviso), findsNothing);
      expect(pedidasDelCatalogo(api), [_primera]);

      await tester.pump(_demora);
      await tester.pumpAndSettle();

      expect(find.text('Copia 1'), findsNothing);
      expect(find.text('Producto 1'), findsOneWidget);
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(find.text(_aviso), findsNothing);
    });

    testWidgets('al bajar al final de la copia se ve el indicador mientras '
        'llega la página nueva, y después pide la siguiente sola',
        (tester) async {
      // El servidor está despertando: la página 1 tarda.
      final api = _backend()..demorar(_primera, _demora);
      await _abrirConCopia(tester, api);
      await tester.pump();
      final indicador = find.descendant(
        of: find.byType(PieCatalogo),
        matching: find.byType(CircularProgressIndicator),
      );

      await tester.bajarAlFinalDelCatalogo();

      // Abajo de la copia se ve que algo viene; la página 2 no se pide
      // mientras no llegue la 1.
      expect(find.text('Copia 20'), findsOneWidget);
      expect(indicador, findsOneWidget);
      expect(pedidasDelCatalogo(api), [_primera]);

      await tester.pump(_demora);
      await tester.pumpAndSettle();

      // La página nueva tomó el lugar de la copia y, como la lista está al
      // final, la siguiente se pidió sola.
      expect(find.text('Copia 20'), findsNothing);
      expect(find.text('Producto 20'), findsOneWidget);
      expect(pedidasDelCatalogo(api), [_primera, _segunda]);
      expect(indicador, findsNothing);
    });

    testWidgets('la página nueva reemplaza la copia sin mover la lista',
        (tester) async {
      final api = _backend()..demorar(_primera, _demora);
      await _abrirConCopia(tester, api);
      await tester.pump();
      await tester.drag(listaDelCatalogo, const Offset(0, -300));
      await tester.pump();
      final bajado = tester.bajadoEnElCatalogo;
      expect(bajado, greaterThan(0));
      expect(find.textContaining('Copia'), findsWidgets);

      await tester.pump(_demora);
      await tester.pumpAndSettle();

      expect(find.textContaining('Copia'), findsNothing);
      expect(find.textContaining('Producto'), findsWidgets);
      expect(tester.bajadoEnElCatalogo, bajado);
    });

    testWidgets('sin conexión con copia muestra el aviso', (tester) async {
      final api = _backend(productos: _servidor(falla: (_) => true));
      await _abrirConCopia(tester, api);
      await tester.pumpAndSettle();

      expect(find.text(_aviso), findsOneWidget);
      expect(find.byIcon(LucideIcons.wifiOff), findsOneWidget);
      // Se ve lo guardado, no el estado de «no se pudo cargar».
      expect(find.text('Copia 1'), findsOneWidget);
      expect(find.text('No pudimos cargar el catálogo'), findsNothing);
      expect(find.byType(ProductSkeletonCard), findsNothing);
    });

    testWidgets('sin conexión con copia, al bajar al final aparece «No se '
        'pudieron cargar más»', (tester) async {
      final api = _backend(productos: _servidor(falla: (_) => true));
      await _abrirConCopia(tester, api);
      await tester.pumpAndSettle();
      expect(pedidasDelCatalogo(api), [_primera]);

      await tester.bajarAlFinalDelCatalogo();

      // No hay más páginas guardadas y a la copia no se le pega la página 2:
      // se vuelve a pedir la página 1, y no llega.
      Finder delPie(Finder finder) =>
          find.descendant(of: find.byType(PieCatalogo), matching: finder);
      expect(delPie(find.text('No se pudieron cargar más')), findsOneWidget);
      expect(delPie(find.text('Reintentar')), findsOneWidget);
      expect(pedidasDelCatalogo(api), [_primera, _primera]);
      expect(find.text('Copia 20'), findsOneWidget);
      expect(find.text(_aviso), findsOneWidget);
    });

    testWidgets('al volver la conexión, Reintentar pone la página 1 en lugar '
        'de la copia, quita el aviso y sigue con la 2', (tester) async {
      var falla = true;
      final api = _backend(productos: _servidor(falla: (_) => falla));
      await _abrirConCopia(tester, api);
      await tester.pumpAndSettle();
      await tester.bajarAlFinalDelCatalogo();
      await tester.pumpAndSettle();
      expect(find.text(_aviso), findsOneWidget);
      expect(pedidasDelCatalogo(api), [_primera, _primera]);

      // Vuelve la conexión; la página 1 tarda un poco en llegar. «Reintentar»
      // del pie (el aviso de arriba también lo ofrece, #275).
      falla = false;
      api.demorar(_primera, _demora);
      final reintentarDelPie = find.descendant(
        of: find.byType(PieCatalogo),
        matching: find.text('Reintentar'),
      );
      await tester.ensureVisible(reintentarDelPie);
      await tester.pump();
      await tester.tap(reintentarDelPie);
      await tester.pump();

      // Mientras llega, la copia se queda donde estaba.
      expect(pedidasDelCatalogo(api), [_primera, _primera, _primera]);
      expect(find.text('Copia 20'), findsOneWidget);

      await tester.pump(_demora);
      await tester.pump();

      // La página nueva toma el lugar de la copia sin volver arriba.
      expect(find.text('Copia 20'), findsNothing);
      expect(find.text('Producto 20'), findsOneWidget);
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(tester.bajadoEnElCatalogo, greaterThan(1000));

      // El aviso se va y la página 2 se pide sola.
      await tester.pumpAndSettle();
      expect(find.text(_aviso), findsNothing);
      expect(pedidasDelCatalogo(api), [_primera, _primera, _primera, _segunda]);
    });

    testWidgets('el aviso se va cuando llega la página nueva', (tester) async {
      var falla = true;
      final api = _backend(productos: _servidor(falla: (_) => falla));
      await _abrirConCopia(tester, api);
      await tester.pumpAndSettle();
      expect(find.text(_aviso), findsOneWidget);

      // Jalar para recargar, ya con internet.
      falla = false;
      unawaited(tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show());
      await tester.pumpAndSettle();

      expect(find.text(_aviso), findsNothing);
      expect(find.text('Copia 1'), findsNothing);
      expect(find.text('Producto 1'), findsOneWidget);
    });

    testWidgets('sin copia y sin conexión sale el error de siempre, sin aviso',
        (tester) async {
      tester.usarCelular();
      final api = _backend(productos: _servidor(falla: (_) => true));
      await tester.pumpApp(const ProductsScreen(), api: api);
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar el catálogo'), findsOneWidget);
      expect(find.text(_aviso), findsNothing);
    });
  });

  // Antes, con una categoría (o búsqueda, filtros u orden), jalar para
  // refrescar sin internet cambiaba la lista por «No pudimos cargar el
  // catálogo».
  group('Jalar para refrescar sin internet (#275)', () {
    /// El aviso de arriba, con su «Reintentar».
    final reintentarDelAviso = find.descendant(
      of: find.ancestor(of: find.text(_aviso), matching: find.byType(Row)),
      matching: find.text('Reintentar'),
    );

    testWidgets('con una categoría, la lista se queda con el aviso y su '
        '«Reintentar» la trae al volver la conexión', (tester) async {
      var falla = false;
      final api = _backend(productos: _servidor(falla: (_) => falla));
      await _montar(tester, api: api);
      await tester.tap(find.text('Pays').first);
      await tester.pumpAndSettle();
      expect(find.text('Pay 1'), findsOneWidget);

      // Jalar para refrescar, sin internet.
      falla = true;
      await tester.fling(listaDelCatalogo, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Pay 1'), findsOneWidget);
      expect(find.text('No pudimos cargar el catálogo'), findsNothing);
      expect(find.text(_aviso), findsOneWidget);
      expect(reintentarDelAviso, findsOneWidget);
      expect(pedidasDelCatalogo(api).where((e) => e.contains('categoria=Pays')),
          hasLength(2));

      // Vuelve la conexión.
      falla = false;
      await tester.tap(reintentarDelAviso);
      await tester.pumpAndSettle();

      expect(pedidasDelCatalogo(api).where((e) => e.contains('categoria=Pays')),
          hasLength(3));
      expect(find.text(_aviso), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Pay 1'), findsOneWidget);
    });

    testWidgets('si «Reintentar» tampoco llega, la lista y el aviso se quedan',
        (tester) async {
      var falla = false;
      final api = _backend(productos: _servidor(falla: (_) => falla));
      await _montar(tester, api: api);
      await tester.tap(find.text('Pays').first);
      await tester.pumpAndSettle();
      falla = true;
      await tester.fling(listaDelCatalogo, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      await tester.tap(reintentarDelAviso);
      await tester.pumpAndSettle();

      expect(pedidasDelCatalogo(api).where((e) => e.contains('categoria=Pays')),
          hasLength(3));
      expect(find.text('Pay 1'), findsOneWidget);
      expect(find.text(_aviso), findsOneWidget);
      expect(find.text('No pudimos cargar el catálogo'), findsNothing);
    });
  });
}
