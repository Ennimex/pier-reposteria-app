// test/widget/checkout/checkout_screen_test.dart — el checkout pinta lo que
// expone su ViewModel (MVVM, Fase 4) y reacciona al Command del pago, sin
// red ni Stripe.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/direcciones_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/pagos_repository_remote.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/ui/checkout/view_model/checkout_view_model.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/checkout_screen.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/direccion_form_sheet.dart';
import 'package:pier_pasteleria/ui/checkout/widgets/order_success_screen.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:provider/provider.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

class _PasarelaFalsa implements PasarelaPago {
  Exception? falla;

  @override
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  }) async {
    final f = falla;
    if (f != null) throw f;
  }
}

FakeApiClient _backend() => FakeApiClient(respuestas: {
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
            'referencias': 'Portón verde',
          },
          {'id': 3, 'alias': 'Rancho', 'calle_numero': 'Km 5', 'colonia': 'Lejos'},
        ],
        'direccion': {'id': 4, 'alias': 'Nueva', 'colonia': 'Centro', 'tarifa': 40},
      },
      ApiConstants.zonasColonias: {
        'success': true,
        'colonias': [
          {'colonia': 'Centro', 'tarifa': '40.00'},
        ],
      },
      ApiConstants.direccionById('3'): {'success': true},
      ApiConstants.crearPaymentIntent: {
        'success': true,
        'clientSecret': 'pi_1_secret_x',
        'publishableKey': 'pk',
        'total': 340,
      },
      ApiConstants.confirmarPago: {
        'success': true,
        'pedido': {'numero': 'P-90'},
      },
    });

/// La animación Lottie de la sucursal se repite sin fin (pumpAndSettle no
/// terminaría): se avanza un tiempo fijo, suficiente para hojas y diálogos.
Future<void> _asentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<(FakeApiClient, _PasarelaFalsa, CheckoutViewModel)> _montar(
    WidgetTester tester,
    {bool abierto = true}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _backend();
  final pasarela = _PasarelaFalsa();
  final vm = CheckoutViewModel(
    configRepo: ConfiguracionRepositoryRemote(api: api),
    direccionesRepo: DireccionesRepositoryRemote(api: api),
    pagosRepo: PagosRepositoryRemote(api: api),
    pasarela: pasarela,
    totalCarrito: () => 300,
    confirmarPorConfirmar: (_) async => true,
    estaAbierto: () => abierto,
    esperar: (_) async {},
  );
  await tester.pumpApp(CheckoutScreen(viewModel: vm), api: api);
  await _asentar(tester);
  return (api, pasarela, vm);
}

void main() {
  group('CheckoutScreen', () {
    testWidgets('recoger: muestra la sucursal, el total y paga', (tester) async {
      final (_, _, vm) = await _montar(tester);

      expect(find.text('Finalizar Pedido'), findsOneWidget);
      expect(find.text('Av. Revolución 100'), findsOneWidget);
      expect(find.text(r'Pagar  $300 MXN'), findsOneWidget);
      expect(find.textContaining('Presenta tu número de pedido', findRichText: true), findsOneWidget);

      // Sin fecha: avisa y no paga.
      await tester.tap(find.text(r'Pagar  $300 MXN'));
      await _asentar(tester);
      expect(find.text('Selecciona fecha y hora de recolección'), findsOneWidget);

      vm
        ..elegirFecha(DateTime(2026, 10, 13))
        ..elegirHora('11:00 - 12:00');
      await _asentar(tester);
      expect(find.text('13/10/2026'), findsOneWidget);

      await tester.tap(find.text(r'Pagar  $300 MXN'));
      await _asentar(tester);

      expect(find.byType(OrderSuccessScreen), findsOneWidget);
    });

    testWidgets('domicilio: direcciones, envío y borrar una', (tester) async {
      final (api, _, _) = await _montar(tester);

      await tester.tap(find.text('Domicilio'));
      await _asentar(tester);

      expect(find.text('Trabajo'), findsOneWidget);
      expect(find.text(r'$40 envío'), findsOneWidget);
      expect(find.text('Sin cobertura'), findsOneWidget);
      expect(find.text('Ref: Portón verde'), findsOneWidget);
      expect(find.text(r'Pagar  $340 MXN'), findsOneWidget);
      expect(find.textContaining('Ten a la mano', findRichText: true), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.trash2).last);
      await _asentar(tester);
      await tester.tap(find.text('Eliminar'));
      await _asentar(tester);
      expect(api.llamo(ApiConstants.direccionById('3'), metodo: 'DELETE-Auth'),
          isTrue);
    });

    testWidgets('agregar dirección abre el formulario y la guarda',
        (tester) async {
      await _montar(tester);
      await tester.tap(find.text('Domicilio'));
      await _asentar(tester);

      await tester.tap(find.text('Agregar dirección'));
      await _asentar(tester);
      expect(find.byType(DireccionFormSheet), findsOneWidget);
      expect(find.text('Nueva dirección'), findsOneWidget);

      // Sin datos avisa.
      await tester.tap(find.text('Guardar dirección'));
      await _asentar(tester);
      expect(find.text('Completa alias, calle y número, y colonia'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Nueva');
      await tester.enterText(find.byType(TextField).at(1), 'Morelos 3');
      await tester.ensureVisible(find.byType(DropdownButton<String>).last);
      await tester.tap(find.byType(DropdownButton<String>).last);
      await _asentar(tester);
      await tester.tap(find.textContaining('Centro  ·').last);
      await _asentar(tester);
      expect(find.text(r'Envío: $40 MXN'), findsOneWidget);

      await tester.tap(find.text('Guardar dirección'));
      await _asentar(tester);
      expect(find.byType(DireccionFormSheet), findsNothing);
    });

    testWidgets('si el backend rechaza el pago muestra el error', (tester) async {
      final (api, _, vm) = await _montar(tester);
      api.fallar(ApiConstants.crearPaymentIntent, 'Carrito vacío');
      vm
        ..elegirFecha(DateTime(2026, 10, 13))
        ..elegirHora('11:00 - 12:00');
      await _asentar(tester);

      await tester.tap(find.text(r'Pagar  $300 MXN'));
      await _asentar(tester);

      expect(find.text('Carrito vacío'), findsNWidgets(2)); // aviso + recuadro
    });

    testWidgets('un error inesperado se avisa', (tester) async {
      final (_, pasarela, vm) = await _montar(tester);
      pasarela.falla = Exception('plugin');
      vm
        ..elegirFecha(DateTime(2026, 10, 13))
        ..elegirHora('11:00 - 12:00');
      await _asentar(tester);

      await tester.tap(find.text(r'Pagar  $300 MXN'));
      await _asentar(tester);

      expect(find.textContaining('Error inesperado'), findsOneWidget);
    });

    testWidgets('el resumen lista el carrito con tamaño y descuentos',
        (tester) async {
      final (api, _, _) = await _montar(tester);
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

      expect(find.text('Chocoflan (Grande)'), findsOneWidget);
      expect(find.text('2x'), findsOneWidget);
      expect(find.text(r'$270 c/u'), findsOneWidget);
      expect(find.text('Rosca'), findsOneWidget);
      expect(find.text('Descuentos aplicados'), findsOneWidget);
      expect(find.text(r'-$60'), findsOneWidget);
    });

    testWidgets('fuera de horario avisa y desactiva el botón', (tester) async {
      await _montar(tester, abierto: false);

      expect(find.text('Fuera de servicio'), findsNWidgets(2));
      final boton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Fuera de servicio'));
      expect(boton.onPressed, isNull);
    });
  });
}
