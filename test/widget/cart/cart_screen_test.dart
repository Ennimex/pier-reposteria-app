// test/widget/cart/cart_screen_test.dart — la vista de «Mi Carrito» pinta lo
// que expone su ViewModel (MVVM, Fase 5) y avisa los rechazos del backend,
// sin red.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_pasteleria/ui/cart/view_model/cart_view_model.dart';
import 'package:pier_pasteleria/ui/cart/widgets/cart_screen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

final String _linea151 = ApiConstants.carritoItem('151');

Map<String, dynamic> get _carrito => {
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
        ],
      },
    };

Future<FakeApiClient> _montar(
  WidgetTester tester, {
  Map<String, dynamic>? respuestas,
}) async {
  // Pantalla de celular (412×869 lógicos, como el Note 10+).
  tester.view
    ..physicalSize = const Size(1440, 3040)
    ..devicePixelRatio = 3.5;
  addTearDown(tester.view.reset);
  final api = FakeApiClient(respuestas: {
    ApiConstants.carrito: _carrito,
    _linea151: {'success': true},
    ...?respuestas,
  });
  await tester.pumpApp(
    CartScreen(
      viewModel: CartViewModel(
        carrito: CartProvider(repo: CarritoRepositoryRemote(api: api)),
        sesionIniciada: () => true,
      ),
    ),
    api: api,
  );
  await tester.pump();
  return api;
}

/// Deja correr la animación del Lottie del estado vacío sin esperar a que
/// termine (se repite sin fin).
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CartScreen', () {
    testWidgets('lista las líneas con descuentos, conteo y total',
        (tester) async {
      await _montar(tester);

      expect(find.text('Fresa Matcha Bliss'), findsOneWidget);
      expect(find.text('Temporada de fresas'), findsOneWidget);
      expect(find.text(r'$90 c/u'), findsOneWidget);
      expect(find.text('Grande'), findsOneWidget);
      expect(find.text('3 productos'), findsOneWidget);
      expect(find.text(r'Ahorras $20'), findsOneWidget);
      expect(find.text(r'$250 MXN'), findsOneWidget); // subtotal tachado
      expect(find.text(r'-$20 MXN'), findsOneWidget);
      expect(find.text(r'$230 MXN'), findsOneWidget);
    });

    testWidgets('sin sesión muestra el carrito vacío', (tester) async {
      await tester.pumpApp(const CartScreen());
      await _asentar(tester);

      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.text('Vaciar'), findsNothing);
    });

    testWidgets('si no carga avisa y deja reintentar', (tester) async {
      final api = await _montar(tester, respuestas: {
        ApiConstants.carrito: {'success': false, 'message': 'Sin conexión'},
      });
      expect(find.text('Sin conexión'), findsOneWidget);

      api.responder(ApiConstants.carrito, _carrito);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(find.text('Fresa Matcha Bliss'), findsOneWidget);
    });

    testWidgets('+ sube la cantidad y un rechazo se avisa', (tester) async {
      final api = await _montar(tester);

      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      expect(find.text('4 productos'), findsOneWidget);

      api.fallar(_linea151, 'Solo quedan 3 unidades');
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();

      expect(find.text('Solo quedan 3 unidades'), findsOneWidget);
      expect(find.text('4 productos'), findsOneWidget);
    });

    testWidgets('− con la última unidad quita la línea', (tester) async {
      final api = await _montar(tester, respuestas: {
        ApiConstants.carritoItem('152'): {'success': true},
      });

      await tester.tap(find.byIcon(LucideIcons.trash2).first);
      await tester.pump();

      expect(find.text('Pay de limón'), findsNothing);
      expect(
        api.llamo(ApiConstants.carritoItem('152'), metodo: 'DELETE-Auth'),
        isTrue,
      );
    });

    testWidgets('deslizar una línea la quita', (tester) async {
      await _montar(tester);

      await tester.drag(find.text('Fresa Matcha Bliss'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Fresa Matcha Bliss'), findsNothing);
      expect(find.text('1 producto'), findsOneWidget);
    });

    testWidgets('vaciar pide confirmación y deja el carrito vacío',
        (tester) async {
      await _montar(tester);

      await tester.tap(find.text('Vaciar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vaciar'));
      await _asentar(tester);

      expect(find.text('Tu carrito está vacío'), findsOneWidget);
    });

    testWidgets('«Proceder al Pago» abre el checkout', (tester) async {
      await _montar(tester);
      // El checkout se prueba a 1080 de ancho (checkout_screen_test.dart).
      tester.view
        ..physicalSize = const Size(1080, 3600)
        ..devicePixelRatio = 1;
      await tester.pump();

      await tester.tap(find.text('Proceder al Pago'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CheckoutScreen), findsOneWidget);
    });
  });
}
