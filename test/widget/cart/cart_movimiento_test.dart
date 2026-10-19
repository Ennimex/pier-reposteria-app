// test/widget/cart/cart_movimiento_test.dart — el movimiento de «Mi
// Carrito»: un solo Scaffold mientras el cuerpo cambia de estado (los avisos
// nunca se duplican), el esqueleto de carga sale del árbol al llegar las
// líneas, las líneas entran una sola vez (y una línea nueva entra sola), la
// cantidad rueda sin dejar copias, un rechazo del backend sacude solo su
// línea y, al deslizar, el bote crece al pasar el umbral.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_reposteria/ui/cart/view_model/cart_view_model.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_linea.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_screen.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/core/ui/movimiento/movimiento.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

final String _linea151 = ApiConstants.carritoItem('151');

Map<String, dynamic> _carrito({bool conRosca = false}) => {
  'success': true,
  'carrito': {
    'items': [
      {
        'producto_id': 36,
        'carrito_item_id': 151,
        'nombre': 'Fresa Matcha Bliss',
        'precio_unitario': '90.00',
        'precio_original': '100.00',
        'cantidad': 2,
        'tiene_descuento': true,
        'promo_nombre': 'Temporada de fresas',
      },
      {
        'producto_id': 12,
        'carrito_item_id': 152,
        'nombre': 'Pay de limón',
        'precio_unitario': '50.00',
        'precio_original': '50.00',
        'cantidad': 1,
        'tamano': 'grande',
      },
      if (conRosca)
        {
          'producto_id': 8,
          'carrito_item_id': 153,
          'nombre': 'Rosca',
          'precio_unitario': '150.00',
          'precio_original': '150.00',
          'cantidad': 1,
        },
    ],
  },
};

/// Monta «Mi Carrito» en un celular (412×869 lógicos; [tamano] es la
/// pantalla en pixeles físicos a 3.5). Con [demora] el carrito tarda en
/// llegar (se ve el estado de carga).
Future<(FakeApiClient, CartProvider)> _montar(
  WidgetTester tester, {
  Duration? demora,
  bool reducido = false,
  Size tamano = const Size(1440, 3040),
}) async {
  tester.view
    ..physicalSize = tamano
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final api = FakeApiClient(
    respuestas: {
      ApiConstants.carrito: _carrito(),
      _linea151: {'success': true},
      ApiConstants.carritoItem('152'): {'success': true},
    },
  );
  if (demora != null) api.demorar(ApiConstants.carrito, demora);
  final carrito = CartProvider(repo: CarritoRepositoryRemote(api: api));
  final pantalla = CartScreen(
    viewModel: CartViewModel(carrito: carrito, sesionIniciada: () => true),
  );
  await tester.pumpApp(
    reducido ? ConMovimientoReducido(child: pantalla) : pantalla,
    api: api,
  );
  return (api, carrito);
}

/// Deja terminar las entradas: el primer cuadro las arma y el siguiente es
/// su cuadro cero.
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(seconds: 1));
}

Finder _linea(String nombre) => find.widgetWithText(CartLinea, nombre);

/// Opacidad de la entrada de la línea de [nombre].
double _opacidad(WidgetTester tester, String nombre) => opacidadEn(
  tester,
  find.ancestor(of: find.text(nombre), matching: find.byType(EntradaSuave)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Movimiento de CartScreen', () {
    testWidgets(
      'mientras carga hay un esqueleto y un solo Scaffold; al llegar las '
      'líneas el esqueleto sale del árbol',
      (tester) async {
        await _montar(tester, demora: const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.byType(Shimmer), findsNWidgets(3));
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.text('Mi Carrito'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Fresa Matcha Bliss'), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(Shimmer), findsNothing);
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'con el celular de lado el esqueleto se recorta en vez de desbordar',
      (tester) async {
        // 869×411 lógicos: el cuerpo mide menos que las tres líneas en
        // blanco (~390 dp).
        await _montar(
          tester,
          demora: const Duration(milliseconds: 300),
          tamano: const Size(3040, 1440),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(Shimmer), findsNWidgets(3));

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(Shimmer), findsNothing);
        expect(find.text('Fresa Matcha Bliss'), findsOneWidget);
      },
    );

    testWidgets('las líneas entran una sola vez: un cambio no las repite', (
      tester,
    ) async {
      await _montar(tester);
      await tester.pump();
      expect(_opacidad(tester, 'Fresa Matcha Bliss'), 0);

      await _asentar(tester);
      expect(_opacidad(tester, 'Fresa Matcha Bliss'), 1);

      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      expect(_opacidad(tester, 'Fresa Matcha Bliss'), 1);
      expect(_opacidad(tester, 'Pay de limón'), 1);
    });

    testWidgets('una línea que llega después entra sola', (tester) async {
      final (api, carrito) = await _montar(tester);
      await tester.pump();
      await _asentar(tester);

      api.responder(ApiConstants.carrito, _carrito(conRosca: true));
      await carrito.cargarDesdeBackend();
      await tester.pump();
      expect(_opacidad(tester, 'Rosca'), 0);
      expect(_opacidad(tester, 'Fresa Matcha Bliss'), 1);
      expect(_opacidad(tester, 'Pay de limón'), 1);

      await _asentar(tester);
      expect(_opacidad(tester, 'Rosca'), 1);
    });

    testWidgets('la cantidad rueda y la cifra anterior sale del árbol', (
      tester,
    ) async {
      await _montar(tester);
      await tester.pump();
      await _asentar(tester);
      final linea = _linea('Fresa Matcha Bliss');

      await tester.tap(
        find.descendant(of: linea, matching: find.byIcon(LucideIcons.plus)),
      );
      await tester.pump();
      expect(
        find.descendant(of: linea, matching: find.text('3')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(of: linea, matching: find.text('2')),
        findsNothing,
      );
      expect(
        find.descendant(of: linea, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('un rechazo del backend sacude solo su línea', (tester) async {
      final (api, _) = await _montar(tester);
      await tester.pump();
      await _asentar(tester);
      final linea = _linea('Fresa Matcha Bliss');
      final otra = _linea('Pay de limón');
      final enReposo = tester.getTopLeft(linea);
      final otraEnReposo = tester.getTopLeft(otra);

      api.fallar(_linea151, 'Solo quedan 2 unidades');
      await tester.tap(
        find.descendant(of: linea, matching: find.byIcon(LucideIcons.plus)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.text('Solo quedan 2 unidades'), findsOneWidget);
      expect(tester.getTopLeft(linea).dx, isNot(closeTo(enReposo.dx, 0.5)));
      expect(tester.getTopLeft(otra), otraEnReposo);

      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(linea), enReposo);
    });

    testWidgets('al deslizar, el bote crece al pasar el umbral y vuelve', (
      tester,
    ) async {
      await _montar(tester);
      await tester.pump();
      await _asentar(tester);

      final gesto = await tester.startGesture(
        tester.getCenter(find.text('Fresa Matcha Bliss')),
      );
      await gesto.moveBy(const Offset(-40, 0));
      await gesto.moveBy(const Offset(-220, 0));
      await tester.pump();
      final bote = find.descendant(
        of: find.byType(Dismissible).first,
        matching: find.byType(AnimatedScale),
      );
      expect(tester.widget<AnimatedScale>(bote).scale, greaterThan(1));

      // De regreso, antes del umbral (sin cruzar el cero: el Dismissible
      // ignora un arrastre que lo pasaría).
      await gesto.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(bote).scale, 1);

      await gesto.up();
      await tester.pumpAndSettle();
      expect(_linea('Fresa Matcha Bliss'), findsOneWidget);
    });

    testWidgets('deslizar la última línea deja el carrito vacío sin errores', (
      tester,
    ) async {
      await _montar(tester);
      await tester.pump();
      await _asentar(tester);
      await tester.tap(
        find.descendant(
          of: _linea('Pay de limón'),
          matching: find.byIcon(LucideIcons.trash2),
        ),
      );
      await _asentar(tester);
      expect(_linea('Pay de limón'), findsNothing);

      // La lista sale con el fundido del cuerpo mientras el Dismissible ya
      // se quitó: nada se reconstruye a medias.
      await tester.drag(find.text('Fresa Matcha Bliss'), const Offset(-500, 0));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CartLinea), findsNothing);
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.text('Proceder al Pago'), findsNothing);
    });

    testWidgets('con movimiento reducido las líneas aparecen ya en su lugar', (
      tester,
    ) async {
      await _montar(tester, reducido: true);
      await tester.pump();

      expect(_opacidad(tester, 'Fresa Matcha Bliss'), 1);
      expect(_opacidad(tester, 'Pay de limón'), 1);
    });
  });
}
