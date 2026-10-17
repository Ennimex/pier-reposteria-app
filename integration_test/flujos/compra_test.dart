// integration_test/flujos/compra_test.dart — #58: el flujo de compra de punta
// a punta con la app real y el servidor real, en el celular virtual del
// pipeline (integracion.yml, trabajo «Flujo de compra contra el servidor
// real»).
//
// La prueba inicia sesión con la cuenta de prueba (USUARIO_PRUEBA y
// CLAVE_PRUEBA, que el workflow pasa con --dart-define desde los secretos del
// repositorio), añade un producto con existencias, llega al checkout y toca
// «Pagar». La hoja de pago de Stripe es nativa y la prueba no puede llenarla:
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
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/config/business_info.dart';
import 'package:pier_pasteleria/config/dependencies.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository_remote.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/data/services/pasarela_pago.dart';
import 'package:pier_pasteleria/domain/models/product_model.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

const _usuario = String.fromEnvironment('USUARIO_PRUEBA');
const _clave = String.fromEnvironment('CLAVE_PRUEBA');

/// El servidor gratuito se duerme y tarda en contestar la primera vez.
const _esperaDelServidor = Duration(seconds: 90);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('#58 Flujo de compra contra el servidor real', () {
    // Escenario: del inicio de sesión al checkout
    //   Dado que tengo una cuenta de cliente verificada
    //   Cuando inicio sesión, abro un producto con existencias, lo añado
    //     al carrito y toco «Proceder al Pago»
    //   Entonces el carrito muestra el producto y llego a «Finalizar Pedido».
    testWidgets('Escenario: del inicio de sesión al checkout', (tester) async {
      if (_faltanCredenciales()) return;
      final api = await _abrirLaApp(tester, _PasarelaEspia());
      addTearDown(() => CarritoRepositoryRemote(api: api).vaciar());

      await _iniciarSesion(tester);
      final producto = await _productoConExistencias(api);
      await _hastaElCheckout(tester, producto);

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
      if (_faltanCredenciales()) return;
      if (!BusinessInfo.estaAbierto()) {
        markTestSkipped(
          'fuera del horario de la tienda (${BusinessInfo.horario}): el '
          'botón «Pagar» está desactivado',
        );
        return;
      }
      final pasarela = _PasarelaEspia();
      final api = await _abrirLaApp(tester, pasarela);
      addTearDown(() => CarritoRepositoryRemote(api: api).vaciar());

      await _iniciarSesion(tester);
      final producto = await _productoConExistencias(api);
      await _hastaElCheckout(tester, producto);
      await _elegirRecogidaManana(tester);

      final pagar = find.byKey(const ValueKey('pagar'));
      await tester.ensureVisible(pagar);
      await tester.tap(pagar);
      // Si algún producto no alcanza para la fecha, la app pide confirmar.
      await _esperar(
        tester,
        find.text('Continuar y pagar'),
        limite: const Duration(seconds: 5),
        obligatorio: false,
      );
      if (find.text('Continuar y pagar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continuar y pagar'));
      }
      await _esperarQue(
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
      await _esperar(tester, find.text('Finalizar Pedido'));
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

bool _faltanCredenciales() {
  if (_usuario.isNotEmpty && _clave.isNotEmpty) return false;
  markTestSkipped('faltan USUARIO_PRUEBA y CLAVE_PRUEBA (--dart-define)');
  return true;
}

/// La app real con el servidor real; solo la pasarela de pago es la espía.
Future<ApiService> _abrirLaApp(
  WidgetTester tester,
  PasarelaPago pasarela,
) async {
  final api = ApiService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ...dependencias(api),
        // Va después de las dependencias: sustituye a PasarelaStripe.
        Provider<PasarelaPago>.value(value: pasarela),
      ],
      child: const MyApp(initialLocation: AppRoutes.login),
    ),
  );
  return api;
}

Future<void> _iniciarSesion(WidgetTester tester) async {
  await _esperar(tester, find.text('Iniciar Sesión'));
  await tester.enterText(find.byType(TextFormField).at(0), _usuario);
  await tester.enterText(find.byType(TextFormField).at(1), _clave);
  // En pantallas chicas el teclado tapa el botón (ver app_smoke_test.dart).
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.ensureVisible(find.text('Iniciar Sesión'));
  await tester.tap(find.text('Iniciar Sesión'));
  await _esperar(
    tester,
    find.byType(BottomNavigationBar),
    limite: _esperaDelServidor,
    motivo:
        'no se pudo iniciar sesión: revisa que la cuenta de prueba '
        'exista, sea de cliente y tenga el correo verificado',
  );

  // Un carrito con restos de otra corrida cambiaría el total.
  final carrito = tester.element(find.byType(BottomNavigationBar));
  final error = await carrito.read<CartProvider>().clearCart();
  expect(error, isNull, reason: 'no se pudo vaciar el carrito: $error');
}

/// Toma del catálogo real un producto activo con existencias, para no
/// depender de uno en particular.
Future<Product> _productoConExistencias(ApiService api) async {
  final respuesta = await ProductosRepositoryRemote(api: api).listar();
  final productos = (respuesta['productos'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(Product.fromJson)
      .where((producto) => producto.disponible && !producto.agotado);
  if (productos.isEmpty) {
    fail('el catálogo no tiene productos activos con existencias');
  }
  return productos.first;
}

/// Catálogo → detalle → «Añadir» → carrito → «Proceder al Pago».
Future<void> _hastaElCheckout(WidgetTester tester, Product producto) async {
  await tester.tap(_pestana('Catálogo'));
  final tarjeta = find.byKey(ValueKey<String>(producto.id));
  await _buscarEnElCatalogo(tester, tarjeta);
  await tester.tap(
    find.descendant(of: tarjeta, matching: find.text(producto.nombre)),
  );

  final anadir = find.widgetWithText(ElevatedButton, 'Añadir');
  await _esperar(tester, anadir, limite: _esperaDelServidor);
  await tester.ensureVisible(anadir);
  await tester.tap(anadir);
  await _esperar(
    tester,
    find.textContaining('agregado'),
    limite: _esperaDelServidor,
    motivo: 'el servidor no agregó «${producto.nombre}» al carrito',
  );
  // El aviso «agregado» queda unos segundos encima del botón «Proceder al
  // Pago»; como una persona, la prueba espera a que se quite.
  await _esperarQue(
    tester,
    () => find.byType(SnackBar).evaluate().isEmpty,
    limite: const Duration(seconds: 15),
    motivo: 'el aviso de «agregado» no se quitó',
  );

  await tester.tap(_pestana('Carrito'));
  final pagar = find.text('Proceder al Pago');
  await _esperar(tester, pagar, limite: _esperaDelServidor);
  expect(find.textContaining(producto.nombre), findsWidgets);
  await tester.ensureVisible(pagar);
  await tester.tap(pagar);
  await _esperar(tester, find.text('Finalizar Pedido'));
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
  await _esperar(tester, aceptar);
  await tester.tap(aceptar);
  await tester.pump(const Duration(milliseconds: 500));

  await tester.ensureVisible(find.text('Hora'));
  await tester.tap(find.text('Hora'));
  final horario = RegExp(r'^\d{2}:\d{2} - \d{2}:\d{2}$');
  final horas = find.byWidgetPredicate(
    (widget) => widget is Text && horario.hasMatch(widget.data ?? ''),
  );
  await _esperar(tester, horas);
  final primera = (tester.widget(horas.first) as Text).data!;
  // .last: la opción del menú abierto, no la copia que mide el botón.
  await tester.tap(find.text(primera).last);
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _pestana(String nombre) => find.descendant(
  of: find.byType(BottomNavigationBar),
  matching: find.text(nombre),
);

/// El catálogo arma las tarjetas conforme se desplaza: baja hasta encontrar
/// la del producto.
Future<void> _buscarEnElCatalogo(WidgetTester tester, Finder tarjeta) async {
  final lista = find.descendant(
    of: find.byType(ProductsScreen),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  await _esperar(tester, lista);
  await _esperar(
    tester,
    tarjeta,
    limite: const Duration(seconds: 10),
    obligatorio: false,
  );
  for (var intento = 0; intento < 60 && tarjeta.evaluate().isEmpty; intento++) {
    await tester.drag(lista.first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(tarjeta, findsOneWidget, reason: 'el producto no está en el catálogo');
  await tester.ensureVisible(tarjeta);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Espera a que aparezca [buscado] dando cuadros con tiempo real: con el
/// servidor real no sirve pumpAndSettle (las animaciones de carga no paran).
Future<void> _esperar(
  WidgetTester tester,
  Finder buscado, {
  Duration limite = const Duration(seconds: 30),
  String? motivo,
  bool obligatorio = true,
}) => _esperarQue(
  tester,
  () => buscado.evaluate().isNotEmpty,
  limite: limite,
  motivo: motivo ?? 'no apareció $buscado',
  obligatorio: obligatorio,
);

Future<void> _esperarQue(
  WidgetTester tester,
  bool Function() condicion, {
  required String motivo,
  Duration limite = const Duration(seconds: 60),
  bool obligatorio = true,
}) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condicion()) return;
  }
  if (obligatorio) fail('$motivo (${limite.inSeconds} s)');
}
