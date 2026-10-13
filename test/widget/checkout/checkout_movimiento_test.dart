// test/widget/checkout/checkout_movimiento_test.dart — el movimiento del
// checkout y del pedido confirmado: recoger ↔ domicilio conviven solo
// durante el cambio, la fila a la que le falta un dato se sacude (el botón
// de pagar no), el recuadro de un error repetido se sacude, el resumen se
// queda con lo pagado mientras la celebración lo tapa, y las chispas salen
// cuando el check se cierra (nunca si el pedido está por confirmar ni con
// movimiento reducido).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_entrega.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_partes.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/ui/movimiento/movimiento.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/movimiento.dart';
import '../../helpers/pump_app.dart';

class _PasarelaFalsa implements PasarelaPago {
  @override
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  }) async {}
}

FakeApiClient _backend() => FakeApiClient(
  respuestas: {
    ApiConstants.configuracionSeccion('contacto'): {
      'success': true,
      'config': {'direccion': 'Av. Revolución 100'},
    },
    ApiConstants.direcciones: {
      'success': true,
      'direcciones': [
        {
          'id': 2,
          'alias': 'Trabajo',
          'calle_numero': 'Juárez 9',
          'colonia': 'Centro',
          'tarifa': 40,
        },
      ],
    },
    ApiConstants.crearPaymentIntent: {
      'success': true,
      'clientSecret': 'pi_1_secret_x',
      'publishableKey': 'pk',
      'total': 690,
    },
    ApiConstants.confirmarPago: {
      'success': true,
      'pedido': {'numero': 'P-90'},
    },
  },
);

/// Un pump para el cuadro y otro de 1 s (el Lottie de la sucursal tarda
/// casi 2 s en una sola pasada; no se espera a que termine).
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Monta el checkout a 1080 de ancho. El total del carrito es el del
/// CartProvider de la app (vacío hasta que la prueba lo cargue).
Future<(FakeApiClient, CheckoutViewModel)> _montar(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 3600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend();
  CartProvider? carrito;
  final vm = CheckoutViewModel(
    configRepo: ConfiguracionRepositoryRemote(api: api),
    direccionesRepo: DireccionesRepositoryRemote(api: api),
    pagosRepo: PagosRepositoryRemote(api: api),
    pasarela: _PasarelaFalsa(),
    totalCarrito: () => carrito?.totalAmount ?? 0,
    confirmarPorConfirmar: (_) async => true,
    estaAbierto: () => true,
    esperar: (_) async {},
  );
  await tester.pumpApp(CheckoutScreen(viewModel: vm), api: api);
  carrito = tester.element(find.byType(CheckoutScreen)).read<CartProvider>();
  await _asentar(tester);
  return (api, vm);
}

/// Carga en el CartProvider dos productos (total $690).
Future<void> _cargarCarrito(WidgetTester tester, FakeApiClient api) async {
  api.responder(ApiConstants.carrito, {
    'success': true,
    'carrito': {
      'items': [
        {
          'producto_id': 1,
          'nombre': 'Chocoflan',
          'tamano': 'grande',
          'cantidad': 2,
          'precio_unitario': 270,
          'precio_original': 300,
          'tiene_descuento': true,
        },
        {
          'producto_id': 2,
          'nombre': 'Rosca',
          'cantidad': 1,
          'precio_unitario': 150,
          'precio_original': 150,
        },
      ],
    },
  });
  await tester
      .element(find.byType(CheckoutScreen))
      .read<CartProvider>()
      .cargarDesdeBackend();
  await _asentar(tester);
}

/// La pantalla de éxito a 1080 de ancho, como en checkout_test.dart (con la
/// fuente de pruebas, más ancha, se desborda en la de 800 × 600).
Future<void> _montarExito(WidgetTester tester, Widget pantalla) async {
  tester.view
    ..physicalSize = const Size(1080, 3600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpApp(pantalla);
}

const OrderSuccessScreen _exito = OrderSuccessScreen(
  orderId: 'P-90',
  pickupDate: '13/10/2026',
  pickupTime: '11:00 - 12:00',
  total: 690,
);

void main() {
  group('Movimiento del checkout', () {
    testWidgets('recoger y domicilio conviven solo durante el cambio', (
      tester,
    ) async {
      await _montar(tester);

      await tester.tap(find.text('Domicilio'));
      await tester.pump();
      expect(find.byType(CheckoutRecoger), findsOneWidget);
      expect(find.byType(CheckoutDomicilio), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(CheckoutRecoger), findsNothing);
      expect(find.byType(CheckoutDomicilio), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('si falta la fecha, su fila se sacude y el botón no', (
      tester,
    ) async {
      final (api, _) = await _montar(tester);
      await _cargarCarrito(tester, api);
      final fila = find
          .descendant(
            of: find.byType(CheckoutFechaHora),
            matching: find.byType(Row),
          )
          .first;
      final boton = find.byType(ElevatedButton);
      final filaEnReposo = tester.getTopLeft(fila);
      final botonEnReposo = tester.getTopLeft(boton);

      await tester.tap(find.text(r'Pagar  $690 MXN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      expect(
        find.text('Selecciona fecha y hora de recolección'),
        findsOneWidget,
      );
      expect(tester.getTopLeft(fila).dx, isNot(closeTo(filaEnReposo.dx, 0.5)));
      expect(tester.getTopLeft(boton), botonEnReposo);

      await tester.pump(const Duration(seconds: 1));
      expect(tester.getTopLeft(fila), filaEnReposo);
    });

    testWidgets('si el mismo error del pago se repite, su recuadro se sacude', (
      tester,
    ) async {
      final (api, vm) = await _montar(tester);
      await _cargarCarrito(tester, api);
      api.fallar(ApiConstants.crearPaymentIntent, 'Carrito vacío');
      vm
        ..elegirFecha(DateTime(2026, 10, 13))
        ..elegirHora('11:00 - 12:00');
      await _asentar(tester);

      await tester.tap(find.text(r'Pagar  $690 MXN'));
      await _asentar(tester);
      final recuadro = find.byType(AvisoErrorPago);
      expect(recuadro, findsOneWidget);
      final enReposo = tester.getTopLeft(recuadro);

      await tester.tap(find.text(r'Pagar  $690 MXN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getTopLeft(recuadro).dx, isNot(closeTo(enReposo.dx, 0.5)));

      await _asentar(tester);
      expect(find.byType(AvisoErrorPago), findsOneWidget);
      expect(tester.getTopLeft(recuadro), enReposo);
    });

    testWidgets('con la red de por medio, el mismo error vuelve sacudiendo su '
        'recuadro', (tester) async {
      // Como en el celular: el backend tarda en contestar, así que se pinta
      // al menos un cuadro entre el reintento y el error.
      final (api, vm) = await _montar(tester);
      await _cargarCarrito(tester, api);
      api
        ..fallar(ApiConstants.crearPaymentIntent, 'Carrito vacío')
        ..demorar(
          ApiConstants.crearPaymentIntent,
          const Duration(milliseconds: 300),
        );
      vm
        ..elegirFecha(DateTime(2026, 10, 13))
        ..elegirHora('11:00 - 12:00');
      await _asentar(tester);

      await tester.tap(find.text(r'Pagar  $690 MXN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _asentar(tester);
      final recuadro = find.byType(AvisoErrorPago);
      expect(recuadro, findsOneWidget);
      final enReposo = tester.getTopLeft(recuadro);

      // Al reintentar, el recuadro se cierra mientras el backend contesta…
      await tester.tap(find.text(r'Pagar  $690 MXN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(recuadro, findsNothing);

      // …y el mismo error lo trae de vuelta sacudiéndose.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 40));
      expect(recuadro, findsOneWidget);
      expect(tester.getTopLeft(recuadro).dx, isNot(closeTo(enReposo.dx, 0.5)));

      await _asentar(tester);
      expect(tester.getTopLeft(recuadro), enReposo);
    });

    testWidgets('tras pagar, el resumen se queda con lo pagado mientras la '
        'celebración lo tapa', (tester) async {
      final (api, vm) = await _montar(tester);
      await _cargarCarrito(tester, api);
      vm
        ..elegirFecha(DateTime(2026, 10, 13))
        ..elegirHora('11:00 - 12:00');
      await _asentar(tester);
      expect(find.text('Chocoflan (Grande)'), findsOneWidget);

      await tester.tap(find.text(r'Pagar  $690 MXN'));
      await tester.pump();

      // El carrito ya se vació, pero el checkout que se va no lo muestra.
      expect(
        tester
            .element(find.byType(CheckoutScreen))
            .read<CartProvider>()
            .itemCount,
        0,
      );
      expect(find.text('Chocoflan (Grande)'), findsOneWidget);
      expect(find.text(r'Pagar  $690 MXN'), findsOneWidget);

      await _asentar(tester);
      expect(find.byType(CheckoutScreen), findsNothing);
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });
  });

  group('Movimiento del pedido confirmado', () {
    testWidgets('las chispas salen cuando el check se cierra', (tester) async {
      await _montarExito(tester, _exito);
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Chispas), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Chispas), findsOneWidget);
      expect(find.text('¡Pedido Confirmado!'), findsOneWidget);
      expect(find.text(r'$690 MXN'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('si el pedido está por confirmar no hay chispas', (
      tester,
    ) async {
      await _montarExito(
        tester,
        const OrderSuccessScreen(
          orderId: 'P-91',
          pickupDate: '20/10/2026',
          pickupTime: '11:00 - 12:00',
          total: 690,
          porConfirmar: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));

      expect(find.byType(Chispas), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('con movimiento reducido: sin chispas y el check ya cerrado', (
      tester,
    ) async {
      await _montarExito(tester, const ConMovimientoReducido(child: _exito));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Chispas), findsNothing);
      final check = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
      expect(check.controller?.value, 1);
    });
  });
}
