// test/aceptacion/catalogo/catalogo_guardado_test.dart — escenarios Gherkin
// del catálogo guardado en el teléfono (historia #265: la primera página del
// catálogo sin búsqueda ni filtros se guarda y, al volver a abrirlo, se ve al
// instante mientras llega la nueva; sin internet se queda con un aviso), sin
// red: la pantalla real del catálogo, su ViewModel, el servicio que guarda la
// copia en SharedPreferences (de prueba) y el repositorio de productos sobre
// FakeApiClient, que responde GET /productos como el backend. El catálogo se
// abre y se cierra dentro de la misma app, así que lo que guardó al abrirlo
// sigue en el teléfono la vez siguiente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/ui/core/ui/skeletons.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/catalogo.dart';
import '../../helpers/pump_app.dart';

/// La primera página del catálogo sin búsqueda ni filtros.
const _primera = '/productos?limite=20&offset=0';

/// Lo que tarda el servidor en contestar una página demorada (por ejemplo,
/// mientras despierta).
const _demora = Duration(milliseconds: 300);

/// Lo que la búsqueda espera a que se deje de teclear antes de preguntar.
const _esperaBusqueda = Duration(milliseconds: 400);

/// El texto que ApiService devuelve cuando no hay red (#112).
const _sinRed =
    'No pudimos conectar con Pier. Revisa tu internet e intenta de nuevo.';

/// El aviso de que se ve el catálogo guardado en el teléfono.
const _aviso = 'Sin conexión: es el último catálogo que viste';

/// Un producto tal como lo manda GET /productos.
Map<String, dynamic> _producto(
  int id,
  String nombre, {
  String categoria = 'Pasteles',
}) =>
    {
      'id': id,
      'nombre': nombre,
      'descripcion': 'Rico $nombre',
      'precio_chico': 100,
      'categoria': categoria,
      'imagen_url': '',
      'activo': true,
    };

/// [cuantos] pasteles «[nombre] 1» … «[nombre] N»; sus ids siguen a [desde],
/// para que dos versiones del catálogo no se confundan.
List<Map<String, dynamic>> _pasteles(
  String nombre,
  int cuantos, {
  int desde = 0,
}) =>
    [
      for (var i = 1; i <= cuantos; i++) _producto(desde + i, '$nombre $i'),
    ];

/// Los nombres «[nombre] 1» … «[nombre] N».
List<String> _nombresDe(String nombre, int cuantos) => [
      for (var i = 1; i <= cuantos; i++) '$nombre $i',
    ];

const List<String> _pays = ['Pay de limón', 'Pay de fresa'];

/// GET /productos como el servidor: deja los que cumplen la categoría y la
/// búsqueda (en el nombre o la descripción) y entrega `limite` desde
/// `offset`; sin `limite`, todos. Lee [catalogo] en cada petición: si cambia,
/// contesta la versión nueva.
RespuestaDinamica _servidor(List<Map<String, dynamic>> catalogo) =>
    (llamada) {
      final q = Uri.parse(llamada.endpoint).queryParameters;
      final busqueda = q['busqueda']?.toLowerCase();
      final coinciden = [
        for (final p in catalogo)
          if ((q['categoria'] == null || p['categoria'] == q['categoria']) &&
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

/// El backend con ese [catalogo].
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

/// Enciende la app en un celular de ancho 540 y [alto] px, con el catálogo
/// todavía cerrado. Devuelve el interruptor que lo abre y lo cierra: la app
/// (y lo que guardó en el teléfono) es la misma todo el escenario.
Future<ValueNotifier<bool>> _encenderApp(
  WidgetTester tester,
  FakeApiClient api, {
  double alto = 3000,
}) async {
  tester.usarCelular(alto: alto);
  final catalogo = ValueNotifier(false);
  addTearDown(catalogo.dispose);
  await tester.pumpApp(
    ValueListenableBuilder<bool>(
      valueListenable: catalogo,
      builder: (context, abierto, child) =>
          abierto ? const ProductsScreen() : const SizedBox(),
    ),
    api: api,
  );
  return catalogo;
}

/// Abro el catálogo y dejo que llegue lo que pidió.
Future<void> _abrir(WidgetTester tester, ValueNotifier<bool> catalogo) async {
  catalogo.value = true;
  await tester.pumpAndSettle();
}

/// Cierro el catálogo.
Future<void> _cerrar(WidgetTester tester, ValueNotifier<bool> catalogo) async {
  catalogo.value = false;
  await tester.pumpAndSettle();
}

/// Vuelvo a abrir el catálogo, sin esperar al servidor: solo lo que tarda en
/// leerse lo guardado en el teléfono.
Future<void> _volverAAbrir(
  WidgetTester tester,
  ValueNotifier<bool> catalogo,
) async {
  catalogo.value = true;
  await tester.pump();
  await tester.pump();
}

/// Lo que se le pidió al servidor para la página 1 de una [consulta].
Map<String, String> _primeraDe([Map<String, String> consulta = const {}]) =>
    {...consulta, 'limite': '20', 'offset': '0'};

/// Se ven tarjetas y todas son de esa versión del catálogo.
Matcher _soloDe(String version) =>
    allOf(isNotEmpty, everyElement(startsWith(version)));

void main() {
  group('#265 Catálogo guardado en el teléfono', () {
    // Escenario: se ve al instante
    //   Dado que ya abrí el catálogo antes
    //   Cuando lo vuelvo a abrir
    //   Entonces veo los productos de la última vez mientras llega la versión
    //   nueva
    testWidgets('Escenario: se ve al instante', (tester) async {
      // Dado que ya abrí el catálogo antes
      final menu = _pasteles('Pastel de ayer', 6);
      final api = _backend(menu);
      final catalogo = await _encenderApp(tester, api);
      await _abrir(tester, catalogo);
      expect(tester.nombresEnElCatalogo, _nombresDe('Pastel de ayer', 6));
      await _cerrar(tester, catalogo);

      // Cuando lo vuelvo a abrir (el menú cambió y el servidor tarda en
      // contestar)
      menu
        ..clear()
        ..addAll(_pasteles('Pastel de hoy', 6, desde: 100));
      api.demorar(_primera, _demora);
      await _volverAAbrir(tester, catalogo);

      // Entonces veo los productos de la última vez mientras llega la versión
      // nueva
      expect(tester.nombresEnElCatalogo, _nombresDe('Pastel de ayer', 6));
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(parametrosDelCatalogo(api), [_primeraDe(), _primeraDe()]);
      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(tester.nombresEnElCatalogo, _nombresDe('Pastel de hoy', 6));
    });

    // Escenario: la nueva la reemplaza
    //   Dado que se ve la copia guardada
    //   Cuando llega la primera página del servidor
    //   Entonces la lista se actualiza sin saltos
    testWidgets('Escenario: la nueva la reemplaza', (tester) async {
      // Dado que se ve la copia guardada (con el menú de la vez anterior; el
      // de hoy tarda en llegar), y bajé un poco
      final menu = _pasteles('Pastel de ayer', 20);
      final api = _backend(menu);
      final catalogo = await _encenderApp(tester, api, alto: 1200);
      await _abrir(tester, catalogo);
      await _cerrar(tester, catalogo);
      menu
        ..clear()
        ..addAll(_pasteles('Pastel de hoy', 20, desde: 100));
      api.demorar(_primera, _demora);
      await _volverAAbrir(tester, catalogo);
      await tester.drag(listaDelCatalogo, const Offset(0, -300));
      await tester.pump();
      final bajado = tester.bajadoEnElCatalogo;
      expect(bajado, greaterThan(0));
      expect(tester.nombresEnElCatalogo, _soloDe('Pastel de ayer'));

      // Cuando llega la primera página del servidor
      await tester.pump(_demora);
      await tester.pump();

      // Entonces la lista se actualiza sin saltos: en el mismo lugar, sin
      // pasar por la lista vacía ni por los esqueletos
      expect(tester.nombresEnElCatalogo, _soloDe('Pastel de hoy'));
      expect(find.byType(ProductSkeletonCard), findsNothing);
      expect(tester.bajadoEnElCatalogo, bajado);
      await tester.pumpAndSettle();
      expect(tester.bajadoEnElCatalogo, bajado);
    });

    // Escenario: sin internet
    //   Dado que no hay internet y hay una copia guardada
    //   Cuando abro el catálogo
    //   Entonces veo la copia con el aviso «Sin conexión: es el último
    //   catálogo que viste»
    testWidgets('Escenario: sin internet', (tester) async {
      // Dado que no hay internet y hay una copia guardada
      final api = _backend(_pasteles('Pastel de ayer', 6));
      final catalogo = await _encenderApp(tester, api);
      await _abrir(tester, catalogo);
      expect(find.text(_aviso), findsNothing);
      await _cerrar(tester, catalogo);
      api.fallar(ApiConstants.productos, _sinRed);

      // Cuando abro el catálogo
      await _abrir(tester, catalogo);

      // Entonces veo la copia con el aviso «Sin conexión: es el último
      // catálogo que viste»
      expect(parametrosDelCatalogo(api), [_primeraDe(), _primeraDe()]);
      expect(tester.nombresEnElCatalogo, _nombresDe('Pastel de ayer', 6));
      expect(find.text(_aviso), findsOneWidget);
      expect(find.text('No pudimos cargar el catálogo'), findsNothing);
    });

    // Escenario: con búsqueda o filtros siempre al servidor
    //   Dado que hay una copia guardada
    //   Cuando busco o filtro
    //   Entonces la app le pregunta al servidor y no usa la copia
    testWidgets('Escenario: con búsqueda o filtros siempre al servidor',
        (tester) async {
      // Dado que hay una copia guardada (al abrir el catálogo se guardó su
      // primera página)
      final api = _backend([
        ..._pasteles('Pastel', 3),
        _producto(10, _pays[0], categoria: 'Pays'),
        _producto(11, _pays[1], categoria: 'Pays'),
      ])
        ..demorar('/productos?busqueda=Pay&limite=20&offset=0', _demora)
        ..demorar('/productos?categoria=Pays&limite=20&offset=0', _demora);
      final catalogo = await _encenderApp(tester, api);
      await _abrir(tester, catalogo);
      expect(tester.nombresEnElCatalogo,
          [..._nombresDe('Pastel', 3), ..._pays]);

      // Cuando busco
      await tester.enterText(find.byType(TextField), 'Pay');
      await tester.pump(_esperaBusqueda);

      // Entonces la app le pregunta al servidor y no usa la copia: mientras
      // contesta se ven esqueletos, no lo guardado
      expect(parametrosDelCatalogo(api).last, _primeraDe({'busqueda': 'Pay'}));
      expect(tester.nombresEnElCatalogo, isEmpty);
      expect(find.byType(ProductSkeletonCard), findsWidgets);
      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(tester.nombresEnElCatalogo, _pays);

      // Cuando filtro (ya sin búsqueda: entre tanto vuelve el catálogo de
      // siempre)
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(_esperaBusqueda);
      await tester.pumpAndSettle();
      expect(tester.nombresEnElCatalogo,
          [..._nombresDe('Pastel', 3), ..._pays]);
      await tester.tap(find.text('Pays').first);
      await tester.pump();

      // Entonces la app le pregunta al servidor y no usa la copia
      expect(parametrosDelCatalogo(api).last,
          _primeraDe({'categoria': 'Pays'}));
      expect(tester.nombresEnElCatalogo, isEmpty);
      expect(find.byType(ProductSkeletonCard), findsWidgets);
      await tester.pump(_demora);
      await tester.pumpAndSettle();
      expect(tester.nombresEnElCatalogo, _pays);
      await tester.desmontarCatalogo();
    });
  });
}
