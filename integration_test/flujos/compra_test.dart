// integration_test/flujos/compra_test.dart — #58: el flujo de compra de punta
// a punta con la app real, en el celular virtual (emulador). Corre en dos
// lugares:
//   · contra el servidor real (flujo-compra.yml y la regresión completa de
//     los martes), con la cuenta de prueba: los dos escenarios;
//   · contra el entorno aislado (integracion.yml, «Flujo de compra en el
//     entorno aislado», dentro de pipeline.yml), con API_BASE_URL apuntando
//     al contenedor y la cuenta ficticia de la semilla: solo el primer
//     escenario. El del pago se excluye por nombre en la línea de comandos
//     (--plain-name) porque la llave de Stripe del contenedor es ficticia.
//
// La prueba inicia sesión con la cuenta que llega en USUARIO_PRUEBA y
// CLAVE_PRUEBA (--dart-define; contra el servidor real, desde los secretos
// del repositorio), añade un producto con existencias, llega al checkout y
// toca «Pagar». La hoja de pago de Stripe es nativa y la prueba no puede llenarla:
// una pasarela espía guarda el intento de pago que creó el servidor y cierra
// la hoja sin pagar. El pedido solo se guarda cuando el pago se completa, así
// que la prueba no deja pedidos; el carrito se vacía al empezar y al terminar.
//
// Sin las credenciales (en local o en un Pull Request sin acceso a los
// secretos) las pruebas se omiten. El botón «Pagar» solo funciona en el
// horario de la tienda (BusinessInfo): fuera de él, el escenario del pago se
// omite y el resumen de la corrida lo dice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_reposteria/config/business_info.dart';
import 'package:pier_reposteria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_reposteria/data/services/pasarela_pago.dart';

import '../ayudas/servidor_real.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('#58 Flujo de compra contra el servidor real', () {
    // Escenario: del inicio de sesión al checkout
    //   Dado que tengo una cuenta de cliente verificada
    //   Cuando inicio sesión, abro un producto con existencias, lo añado
    //     al carrito y toco «Proceder al Pago»
    //   Entonces el carrito muestra el producto y llego a «Finalizar Pedido».
    testWidgets('Escenario: del inicio de sesión al checkout', (tester) async {
      if (faltanCredenciales()) return;
      final api = await abrirLaApp(tester, pasarela: _PasarelaEspia());
      addTearDown(() => CarritoRepositoryRemote(api: api).vaciar());

      await iniciarSesion(tester);
      final producto = await productoConExistencias(api);
      await hastaElCheckout(tester, producto);

      expect(find.text('Finalizar Pedido'), findsOneWidget);
      expect(find.textContaining(producto.nombre), findsWidgets);
    });

    // Escenario: crear el intento de pago
    //   Dado que estoy en el checkout dentro del horario de la tienda
    //   Cuando elijo recoger mañana a la primera hora y toco «Pagar»
    //   Entonces el servidor crea el intento de pago en Stripe (modo prueba)
    //     y la app abre la hoja de pago; al cerrarla sin pagar sigo en el
    //     checkout y no se crea ningún pedido.
    testWidgets('Escenario: crear el intento de pago', (tester) async {
      if (faltanCredenciales()) return;
      if (!BusinessInfo.estaAbierto()) {
        markTestSkipped(
          'fuera del horario de la tienda (${BusinessInfo.horario}): el '
          'botón «Pagar» está desactivado',
        );
        return;
      }
      final pasarela = _PasarelaEspia();
      final api = await abrirLaApp(tester, pasarela: pasarela);
      addTearDown(() => CarritoRepositoryRemote(api: api).vaciar());

      await iniciarSesion(tester);
      final producto = await productoConExistencias(api);
      await hastaElCheckout(tester, producto);
      await _elegirRecogidaManana(tester);

      final pagar = find.byKey(const ValueKey('pagar'));
      await tester.ensureVisible(pagar);
      await tester.tap(pagar);
      // Si algún producto no alcanza para la fecha, la app pide confirmar.
      await esperar(
        tester,
        find.text('Continuar y pagar'),
        limite: const Duration(seconds: 5),
        obligatorio: false,
      );
      if (find.text('Continuar y pagar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continuar y pagar'));
      }
      await esperarQue(
        tester,
        () => pasarela.clientSecret != null,
        motivo: 'el servidor no creó el intento de pago',
      );

      expect(
        pasarela.clientSecret,
        matches(RegExp(r'^pi_\w+_secret_\w+$')),
        reason: 'el servidor debe devolver el secreto de un PaymentIntent',
      );
      expect(
        pasarela.publishableKey,
        startsWith('pk_test_'),
        reason: 'la prueba solo debe correr con Stripe en modo de prueba',
      );
      await esperar(tester, find.text('Finalizar Pedido'));
    });
  });
}

/// Pasarela espía: guarda el intento de pago que creó el servidor y cierra
/// la hoja sin pagar, como si el cliente la hubiera cancelado.
class _PasarelaEspia implements PasarelaPago {
  String? clientSecret;
  String? publishableKey;

  @override
  Future<void> cobrar({
    required String clientSecret,
    required String publishableKey,
  }) async {
    this.clientSecret = clientSecret;
    this.publishableKey = publishableKey;
    throw const PagoCanceladoException();
  }
}

/// Recoger es la opción inicial: falta la fecha (mañana es la primera que
/// ofrece el calendario) y la hora (la primera de la lista).
Future<void> _elegirRecogidaManana(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Fecha'));
  await tester.tap(find.text('Fecha'));
  final aceptar = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.toUpperCase() == 'ACEPTAR',
    ),
  );
  await esperar(tester, aceptar);
  await tester.tap(aceptar);
  await tester.pump(const Duration(milliseconds: 500));

  await tester.ensureVisible(find.text('Hora'));
  await tester.tap(find.text('Hora'));
  final horario = RegExp(r'^\d{2}:\d{2} - \d{2}:\d{2}$');
  final horas = find.byWidgetPredicate(
    (widget) => widget is Text && horario.hasMatch(widget.data ?? ''),
  );
  await esperar(tester, horas);
  final primera = (tester.widget(horas.first) as Text).data!;
  // .last: la opción del menú abierto, no la copia que mide el botón.
  await tester.tap(find.text(primera).last);
  await tester.pump(const Duration(milliseconds: 500));
}
