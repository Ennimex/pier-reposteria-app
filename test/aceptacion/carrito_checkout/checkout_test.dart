// test/aceptacion/carrito_checkout/checkout_test.dart — escenarios Gherkin del
// checkout: resumen, entrega a domicilio, recoger en sucursal, pago aprobado
// y pago rechazado por el backend (#57; historia #36), las respuestas del
// backend después de cobrar (historia #171) y el pedido programado con la
// tienda cerrada (historia #188), sin red.
//
// La hoja de pago de Stripe es nativa y flutter_test no la maneja: la prueba
// llega hasta que la app solicita el intento de pago al backend y le pasa el
// client secret a la pasarela (PasarelaPago), y una pasarela falsa simula la
// respuesta de la tarjeta. Todo lo demás es la app real: CheckoutScreen, su
// ViewModel, los repositorios y el CartProvider compartido sobre
// FakeApiClient.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_reposteria/data/services/pasarela_pago.dart';
import 'package:pier_reposteria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_reposteria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_reposteria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Pasarela falsa: registra cada cobro y lo aprueba (tarjeta válida).
class _PasarelaFalsa implements PasarelaPago {
  final List<String> cobros = [];

  @override
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  }) async {
    cobros.add(clientSecret);
  }
}

/// Backend falso: carrito con dos productos (uno con descuento), la
/// dirección de la sucursal, dos direcciones del cliente con cobertura y el
/// pago. El total del intent lo calcula «el backend»: carrito + envío.
FakeApiClient _backend() => FakeApiClient(respuestas: {
      ApiConstants.carrito: {
        'success': true,
        'carrito': {
          'items': [
            {
              'producto_id': 7,
              'carrito_item_id': 151,
              'nombre': 'Chocoflan',
              'cantidad': 2,
              'precio_unitario': '270.00',
              'precio_original': '300.00',
              'tiene_descuento': true,
            },
            {
              'producto_id': 8,
              'carrito_item_id': 152,
              'nombre': 'Rosca',
              'cantidad': 1,
              'precio_unitario': '150.00',
              'precio_original': '150.00',
            },
          ],
        },
      },
      ApiConstants.configuracionSeccion('contacto'): {
        'success': true,
        'config': {'direccion': 'Av. Revolución 100'},
      },
      ApiConstants.direcciones: {
        'success': true,
        'direcciones': [
          {
            'id': 1,
            'alias': 'Casa',
            'calle_numero': 'Hidalgo 12',
            'colonia': 'Centro',
            'tarifa': 40,
          },
          {
            'id': 2,
            'alias': 'Trabajo',
            'calle_numero': 'Juárez 9',
            'colonia': 'Aviación',
            'tarifa': 60,
          },
        ],
      },
      ApiConstants.crearPaymentIntent: (LlamadaApi llamada) {
        final envio = switch (llamada.body?['direccion_id']) {
          1 || '1' => 40,
          2 || '2' => 60,
          _ => 0,
        };
        return <String, dynamic>{
          'success': true,
          'clientSecret': 'pi_1_secret_x',
          'publishableKey': 'pk_test',
          'total': 690 + envio,
        };
      },
      ApiConstants.confirmarPago: {
        'success': true,
        'pedido': {'numero': 'P-90'},
      },
    });

/// Página de partida: «Proceder al Pago» abre el checkout como lo hace el
/// carrito, pero con la pasarela falsa y el horario de servicio fijo en
/// [abierto] (el real depende del reloj).
class _Carrito extends StatelessWidget {
  const _Carrito({required this.pasarela, required this.abierto});

  final PasarelaPago pasarela;
  final bool abierto;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CheckoutScreen(
                  viewModel: CheckoutViewModel(
                    configRepo: ConfiguracionRepositoryRemote(
                        api: context.read<FakeApiClient>()),
                    direccionesRepo: DireccionesRepositoryRemote(
                        api: context.read<FakeApiClient>()),
                    pagosRepo: PagosRepositoryRemote(
                        api: context.read<FakeApiClient>()),
                    pasarela: pasarela,
                    totalCarrito: () => context.read<CartProvider>().totalAmount,
                    confirmarPorConfirmar: (_) async => true,
                    estaAbierto: () => abierto,
                    esperar: (_) async {},
                  ),
                ),
              ),
            ),
            child: const Text('Proceder al Pago'),
          ),
        ),
      );
}

/// La animación Lottie de la sucursal se repite sin fin (pumpAndSettle no
/// terminaría): se avanza un tiempo fijo, suficiente para hojas y avisos.
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Dado que tengo productos en el carrito: carga el carrito del backend y
/// abre el checkout, con la tienda abierta salvo que se diga otra cosa.
/// Devuelve el backend falso, la pasarela y el ViewModel.
Future<(FakeApiClient, _PasarelaFalsa, CheckoutViewModel)> _abrirCheckout(
    WidgetTester tester,
    {bool abierto = true}) async {
  // El checkout se prueba a 1080 de ancho (checkout_screen_test.dart): con
  // la fuente de pruebas (Ahem) se desborda a 412.
  tester.view
    ..physicalSize = const Size(1080, 3600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend();
  final pasarela = _PasarelaFalsa();
  await tester.pumpApp(
    Provider<FakeApiClient>.value(
      value: api,
      child: _Carrito(pasarela: pasarela, abierto: abierto),
    ),
    api: api,
  );
  await tester
      .element(find.byType(_Carrito))
      .read<CartProvider>()
      .cargarDesdeBackend();
  await tester.tap(find.text('Proceder al Pago'));
  await _asentar(tester);
  final vm = tester
      .widget<CheckoutScreen>(find.byType(CheckoutScreen))
      .viewModel!;
  return (api, pasarela, vm);
}

/// Fecha y hora del pedido. La hora se elige en su lista desplegable; la
/// fecha se fija en el ViewModel porque el calendario de Material pide la
/// localización en español, que el MaterialApp de pruebas no trae.
Future<void> _elegirFechaYHora(
    WidgetTester tester, CheckoutViewModel vm) async {
  vm.elegirFecha(DateTime(2026, 10, 13)); // martes
  await _asentar(tester);
  final hora = find.byType(DropdownButton<String>);
  await tester.ensureVisible(hora);
  await tester.tap(hora);
  await _asentar(tester);
  await tester.tap(find.text('11:00 - 12:00').last);
  await _asentar(tester);
}

/// Toca «Pagar  $N MXN».
Future<void> _pagar(WidgetTester tester, int total) async {
  final boton = find.text('Pagar  \$$total MXN');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await _asentar(tester);
}

/// Veces que la app pidió confirmar el pedido al backend.
int _confirmaciones(FakeApiClient api) => api.llamadas
    .where((l) => l.endpoint == ApiConstants.confirmarPago)
    .length;

/// Mensajes reales de POST /pagos/confirmar después del cobro (#171).
const String _cobroSinPedido = 'Tu pago se cobró pero no pudimos registrar '
    'el pedido ni devolverlo automáticamente. Ya avisamos a la sucursal para '
    'devolvértelo. Referencia: pi_1';
const String _cobroDevuelto = 'Solo quedan 0 unidades de Rosca. Te '
    r'devolvimos $690.00 a tu tarjeta; el banco puede tardar de 5 a 10 días '
    'hábiles en mostrarlo.';

void main() {
  group('#36 Checkout: tipo de entrega y pago con tarjeta', () {
    // Escenario: resumen del pedido
    //   Dado que tengo productos en el carrito
    //   Cuando abro el checkout
    //   Entonces el resumen lista cada producto con su cantidad y su precio,
    //   los descuentos y el total a pagar
    testWidgets('Escenario: resumen del pedido', (tester) async {
      // Dado que tengo productos en el carrito / Cuando abro el checkout
      await _abrirCheckout(tester);

      // Entonces el resumen lista cada producto, descuentos y total
      expect(find.text('Finalizar Pedido'), findsOneWidget);
      expect(find.text('Resumen del pedido'), findsOneWidget);
      expect(find.text('Chocoflan'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text(r'$270 c/u'), findsOneWidget);
      expect(find.text('Rosca'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text(r'$540'), findsOneWidget); // 2 × 270
      expect(find.text(r'$150'), findsOneWidget); // 1 × 150
      expect(find.text('Descuentos aplicados'), findsOneWidget);
      expect(find.text(r'-$60'), findsOneWidget);
      expect(find.text('Total a Pagar'), findsOneWidget);
      expect(find.text(r'$690'), findsOneWidget);
      expect(find.text(r'Pagar  $690 MXN'), findsOneWidget);
    });

    // Escenario: entrega a domicilio
    //   Dado que tengo productos en el carrito y una dirección guardada
    //   Cuando elijo entrega a domicilio y selecciono esa dirección
    //   Entonces el pedido se prepara para entregarse en esa dirección
    testWidgets('Escenario: entrega a domicilio', (tester) async {
      // Dado que tengo productos en el carrito y una dirección guardada
      final (api, pasarela, vm) = await _abrirCheckout(tester);

      // Cuando elijo entrega a domicilio y selecciono esa dirección
      await tester.tap(find.text('Domicilio'));
      await _asentar(tester);
      expect(find.text('Dirección de entrega'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Trabajo'), findsOneWidget);
      await tester.tap(find.text('Trabajo'));
      await _asentar(tester);

      // Entonces el pedido se prepara para entregarse en esa dirección:
      // cobra su envío, el intent lleva esa dirección y la confirmación la
      // muestra.
      expect(vm.direccion!.alias, 'Trabajo');
      expect(find.text('Costo de envío'), findsOneWidget);
      expect(find.text(r'Pagar  $750 MXN'), findsOneWidget);

      await _elegirFechaYHora(tester, vm);
      await _pagar(tester, 750);

      expect(api.ultima(ApiConstants.crearPaymentIntent)!.body,
          {'tipo_entrega': 'domicilio', 'direccion_id': '2'});
      expect(pasarela.cobros, ['pi_1_secret_x']);
      expect(api.ultima(ApiConstants.confirmarPago)!.body, {
        'payment_intent_id': 'pi_1',
        'notas': '',
        'horario_entrega': '2026-10-13 11:00',
      });
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
      expect(find.text('Entrega a domicilio'), findsOneWidget);
      expect(find.text('Juárez 9, Aviación'), findsOneWidget);
      expect(find.text(r'$750 MXN'), findsOneWidget);
    });

    // Escenario: recoger en sucursal
    //   Dado que tengo productos en el carrito
    //   Cuando elijo recoger en sucursal
    //   Entonces la app muestra la dirección de la sucursal y no pide
    //   dirección de entrega
    testWidgets('Escenario: recoger en sucursal', (tester) async {
      // Dado que tengo productos en el carrito
      final (api, _, vm) = await _abrirCheckout(tester);
      await tester.tap(find.text('Domicilio'));
      await _asentar(tester);

      // Cuando elijo recoger en sucursal
      await tester.tap(find.text('Recoger'));
      await _asentar(tester);

      // Entonces la app muestra la dirección de la sucursal…
      expect(find.text('¿Dónde recoges?'), findsOneWidget);
      expect(find.text(BusinessInfo.sucursal), findsOneWidget);
      expect(find.text('Av. Revolución 100'), findsOneWidget);
      // …y no pide dirección de entrega (ni cobra envío)
      expect(find.text('Dirección de entrega'), findsNothing);
      expect(find.text('Agregar dirección'), findsNothing);
      expect(find.text('Costo de envío'), findsNothing);
      expect(find.text(r'Pagar  $690 MXN'), findsOneWidget);

      await _elegirFechaYHora(tester, vm);
      await _pagar(tester, 690);
      expect(api.ultima(ApiConstants.crearPaymentIntent)!.body,
          {'horario_recogida': '2026-10-13 11:00'});
      expect(find.text('Sucursal'), findsOneWidget);
      expect(find.text('Fecha de recogida'), findsOneWidget);
    });

    // Escenario: pago aprobado
    //   Dado que confirmé los datos de mi pedido
    //   Cuando pago con una tarjeta válida en la hoja de pago de Stripe
    //   Entonces la app muestra la pantalla de confirmación del pedido
    testWidgets('Escenario: pago aprobado', (tester) async {
      // Dado que confirmé los datos de mi pedido
      final (api, pasarela, vm) = await _abrirCheckout(tester);
      await _elegirFechaYHora(tester, vm);
      expect(find.text('13/10/2026'), findsOneWidget);
      expect(find.text('11:00 - 12:00'), findsOneWidget);

      // Cuando pago con una tarjeta válida: la app solicita el intento de
      // pago y abre la pasarela con su client secret (la falsa lo aprueba).
      await _pagar(tester, 690);
      expect(api.llamo(ApiConstants.crearPaymentIntent, metodo: 'POST-Auth'),
          isTrue);
      expect(pasarela.cobros, ['pi_1_secret_x']);
      expect(api.llamo(ApiConstants.confirmarPago, metodo: 'POST-Auth'),
          isTrue);

      // Entonces la app muestra la pantalla de confirmación del pedido
      expect(find.byType(CheckoutScreen), findsNothing);
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
      expect(find.text('¡Pedido Confirmado!'), findsOneWidget);
      expect(find.textContaining('Tu pedido #P-90 ha sido registrado'),
          findsOneWidget);
      expect(find.text('13/10/2026'), findsOneWidget);
      expect(find.text('11:00 - 12:00'), findsOneWidget);
      expect(find.text(r'$690 MXN'), findsOneWidget);
      // y el carrito queda vacío
      expect(api.llamo(ApiConstants.carrito, metodo: 'DELETE-Auth'), isTrue);
      expect(
        tester
            .element(find.byType(OrderSuccessScreen))
            .read<CartProvider>()
            .itemCount,
        0,
      );
    });

    // Escenario: el backend rechaza el pago
    //   Dado que confirmé los datos de mi pedido
    //   Cuando pago y el backend rechaza el intento de pago
    //   Entonces la app muestra el motivo, no abre la hoja de pago y me deja
    //   en el checkout
    testWidgets('Escenario: el backend rechaza el pago', (tester) async {
      // Dado que confirmé los datos de mi pedido
      final (api, pasarela, vm) = await _abrirCheckout(tester);
      await _elegirFechaYHora(tester, vm);
      api.fallar(ApiConstants.crearPaymentIntent,
          'Solo quedan 1 unidades de Chocoflan');

      // Cuando pago y el backend rechaza el intento de pago
      await _pagar(tester, 690);

      // Entonces la app muestra el motivo (aviso + recuadro), no abre la hoja
      // de pago y me deja en el checkout
      expect(find.text('Solo quedan 1 unidades de Chocoflan'),
          findsNWidgets(2));
      expect(pasarela.cobros, isEmpty);
      expect(api.llamo(ApiConstants.confirmarPago), isFalse);
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.byType(OrderSuccessScreen), findsNothing);
      expect(
        tester
            .element(find.byType(CheckoutScreen))
            .read<CartProvider>()
            .itemCount,
        2,
      );
    });
  });

  group('#171 Pago: respuestas del backend después de cobrar', () {
    // Escenario: cobro sin pedido
    //   Dado que pagué y el backend responde "COBRO_SIN_PEDIDO"
    //   Cuando termina la confirmación
    //   Entonces la app no vuelve a intentar el registro
    //   Y veo el mensaje del backend con la referencia
    //   Y la app no me pide presionar "Pagar" otra vez
    testWidgets('Escenario: cobro sin pedido', (tester) async {
      // Dado que pagué y el backend responde "COBRO_SIN_PEDIDO"
      final (api, pasarela, vm) = await _abrirCheckout(tester);
      await _elegirFechaYHora(tester, vm);
      api.responder(ApiConstants.confirmarPago, {
        'success': false,
        'codigo': 'COBRO_SIN_PEDIDO',
        'message': _cobroSinPedido,
      });

      // Cuando termina la confirmación
      await _pagar(tester, 690);

      // Entonces la app no vuelve a intentar el registro
      expect(pasarela.cobros, ['pi_1_secret_x']);
      expect(_confirmaciones(api), 1);
      // Y veo el mensaje del backend con la referencia (aviso + recuadro)
      expect(find.text(_cobroSinPedido), findsNWidgets(2));
      // Y la app no me pide presionar "Pagar" otra vez
      expect(find.textContaining('presiona "Pagar"'), findsNothing);
      expect(find.byType(CheckoutScreen), findsOneWidget);
    });

    // Escenario: confirmación pendiente
    //   Dado que el backend responde "CONFIRMACION_PENDIENTE"
    //   Cuando termina la confirmación
    //   Entonces la app conserva el pago y reintenta solo el registro, como hoy
    testWidgets('Escenario: confirmación pendiente', (tester) async {
      // Dado que el backend responde "CONFIRMACION_PENDIENTE"
      final (api, pasarela, vm) = await _abrirCheckout(tester);
      await _elegirFechaYHora(tester, vm);
      api.responder(ApiConstants.confirmarPago, {
        'success': false,
        'codigo': 'CONFIRMACION_PENDIENTE',
        'message': 'Tu pago quedó hecho, pero no pudimos registrar tu pedido. '
            'Vuelve a intentarlo en un momento: no se te cobrará otra vez.',
      });

      // Cuando termina la confirmación
      await _pagar(tester, 690);

      // Entonces la app conserva el pago y reintenta solo el registro
      expect(_confirmaciones(api), CheckoutViewModel.intentosConfirmacion);
      api.responder(ApiConstants.confirmarPago, {
        'success': true,
        'pedido': {'numero': 'P-91'},
      });
      await _pagar(tester, 690);
      expect(pasarela.cobros, ['pi_1_secret_x']);
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });

    // Escenario: cobro devuelto
    //   Dado que el backend responde "COBRO_DEVUELTO"
    //   Cuando termina la confirmación
    //   Entonces veo el mensaje del backend
    //   Y el siguiente pago empieza de cero
    testWidgets('Escenario: cobro devuelto', (tester) async {
      // Dado que el backend responde "COBRO_DEVUELTO"
      final (api, pasarela, vm) = await _abrirCheckout(tester);
      await _elegirFechaYHora(tester, vm);
      api.responder(ApiConstants.confirmarPago, {
        'success': false,
        'codigo': 'COBRO_DEVUELTO',
        'status': 'refunded',
        'reembolsado': true,
        'message': _cobroDevuelto,
      });

      // Cuando termina la confirmación
      await _pagar(tester, 690);

      // Entonces veo el mensaje del backend (aviso + recuadro), sin reintentos
      expect(find.text(_cobroDevuelto), findsNWidgets(2));
      expect(_confirmaciones(api), 1);

      // Y el siguiente pago empieza de cero: intento de pago y cobro nuevos
      api.responder(ApiConstants.confirmarPago, {
        'success': true,
        'pedido': {'numero': 'P-92'},
      });
      await _pagar(tester, 690);
      expect(pasarela.cobros, ['pi_1_secret_x', 'pi_1_secret_x']);
      expect(
          api.llamadas
              .where((l) => l.endpoint == ApiConstants.crearPaymentIntent),
          hasLength(2));
    });
  });

  group('#188 Checkout: programar el pedido con la tienda cerrada', () {
    // Escenario: programar con la tienda cerrada
    //   Dado que la tienda está cerrada en este momento
    //   Cuando elijo la fecha y la hora de recolección
    //   Entonces veo el aviso de que estamos cerrados
    //   Y el botón dice "Pagar" con el total
    //   Y puedo pagar el pedido
    testWidgets('Escenario: programar con la tienda cerrada', (tester) async {
      // Dado que la tienda está cerrada en este momento
      final (api, pasarela, vm) = await _abrirCheckout(tester, abierto: false);

      // Cuando elijo la fecha y la hora de recolección
      await _elegirFechaYHora(tester, vm);

      // Entonces veo el aviso de que estamos cerrados
      expect(find.textContaining('En este momento estamos cerrados'),
          findsOneWidget);
      // Y el botón dice "Pagar" con el total
      expect(find.text(r'Pagar  $690 MXN'), findsOneWidget);

      // Y puedo pagar el pedido
      await _pagar(tester, 690);
      expect(pasarela.cobros, ['pi_1_secret_x']);
      expect(api.llamo(ApiConstants.confirmarPago, metodo: 'POST-Auth'),
          isTrue);
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });

    // Escenario: tienda abierta
    //   Dado que la tienda está abierta
    //   Cuando abro el checkout
    //   Entonces no veo el aviso de que estamos cerrados
    //   Y pago como hasta ahora
    testWidgets('Escenario: tienda abierta', (tester) async {
      // Dado que la tienda está abierta / Cuando abro el checkout
      final (_, pasarela, vm) = await _abrirCheckout(tester);

      // Entonces no veo el aviso de que estamos cerrados
      expect(find.textContaining('En este momento estamos cerrados'),
          findsNothing);
      expect(find.text('Fuera de servicio'), findsNothing);

      // Y pago como hasta ahora
      await _elegirFechaYHora(tester, vm);
      await _pagar(tester, 690);
      expect(pasarela.cobros, ['pi_1_secret_x']);
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });

    // Escenario: faltan datos con la tienda cerrada
    //   Dado que la tienda está cerrada y no elegí fecha ni hora
    //   Cuando presiono "Pagar"
    //   Entonces la app me pide la fecha y la hora de recolección
    testWidgets('Escenario: faltan datos con la tienda cerrada',
        (tester) async {
      // Dado que la tienda está cerrada y no elegí fecha ni hora
      final (api, pasarela, _) = await _abrirCheckout(tester, abierto: false);

      // Cuando presiono "Pagar"
      await _pagar(tester, 690);

      // Entonces la app me pide la fecha y la hora de recolección
      expect(find.text('Selecciona fecha y hora de recolección'),
          findsOneWidget);
      expect(pasarela.cobros, isEmpty);
      expect(api.llamo(ApiConstants.crearPaymentIntent, metodo: 'POST-Auth'),
          isFalse);
    });
  });
}
