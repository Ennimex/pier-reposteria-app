// integration_test/ayudas/servidor_real.dart — lo que comparten las pruebas
// que usan la app real con el servidor real: el flujo de compra (#58,
// flujos/compra_test.dart) y la línea base de rendimiento (#61,
// rendimiento/rendimiento_test.dart).
//
// Las dos inician sesión con la cuenta de prueba (USUARIO_PRUEBA y
// CLAVE_PRUEBA, que llegan con --dart-define). Sin las credenciales (en local
// o en un Pull Request sin acceso a los secretos) las pruebas se omiten. El
// flujo de compra también corre contra el entorno aislado (integracion.yml):
// ahí el servidor es el del contenedor (API_BASE_URL) y la cuenta, la
// ficticia de la semilla.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/app.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/data/repositories/productos_repository_remote.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/data/services/pasarela_pago.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/core/state/cart_provider.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';
import 'package:provider/provider.dart';

const _usuario = String.fromEnvironment('USUARIO_PRUEBA');
const _clave = String.fromEnvironment('CLAVE_PRUEBA');

/// El servidor gratuito se duerme y tarda en contestar la primera vez.
const esperaDelServidor = Duration(seconds: 90);

/// Omite la prueba (y lo dice) si no llegaron las credenciales.
bool faltanCredenciales() {
  if (_usuario.isNotEmpty && _clave.isNotEmpty) return false;
  markTestSkipped('faltan USUARIO_PRUEBA y CLAVE_PRUEBA (--dart-define)');
  return true;
}

/// La app real con el servidor real. Con [pasarela], esa sustituye a la de
/// Stripe. Cada llamada monta una app nueva desde cero, aunque ya haya una.
Future<ApiService> abrirLaApp(
  WidgetTester tester, {
  PasarelaPago? pasarela,
  String initialLocation = AppRoutes.login,
}) async {
  final api = ApiService();
  await tester.pumpWidget(
    MultiProvider(
      key: UniqueKey(),
      providers: [
        ...dependencias(api),
        // Va después de las dependencias: sustituye a PasarelaStripe.
        if (pasarela != null) Provider<PasarelaPago>.value(value: pasarela),
      ],
      child: MyApp(initialLocation: initialLocation),
    ),
  );
  return api;
}

/// Desde «Iniciar Sesión» hasta el Inicio, con el carrito vacío.
Future<void> iniciarSesion(WidgetTester tester) async {
  await esperar(tester, find.text('Iniciar Sesión'));
  await tester.enterText(find.byType(TextFormField).at(0), _usuario);
  await tester.enterText(find.byType(TextFormField).at(1), _clave);
  // En pantallas chicas el teclado tapa el botón (ver app_smoke_test.dart).
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  // En un celular real el teclado del sistema borra al cerrarse lo que
  // escribió enterText (en el emulador del CI no): se deja el texto directo
  // en los campos.
  for (final (campo, texto) in [(0, _usuario), (1, _clave)]) {
    final editable = find.byType(EditableText).at(campo);
    tester.widget<EditableText>(editable).controller.text = texto;
  }
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(find.text('Iniciar Sesión'));
  await tester.tap(find.text('Iniciar Sesión'));
  await esperar(
    tester,
    find.byType(BottomNavigationBar),
    limite: esperaDelServidor,
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
Future<Product> productoConExistencias(ApiService api) async {
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
Future<void> hastaElCheckout(WidgetTester tester, Product producto) async {
  await agregarAlCarrito(tester, producto);
  await abrirElCheckout(tester, producto);
}

/// Catálogo → detalle → «Añadir», hasta que se quita el aviso «agregado».
Future<void> agregarAlCarrito(WidgetTester tester, Product producto) async {
  await tester.tap(pestana('Catálogo'));
  final tarjeta = find.byKey(ValueKey<String>(producto.id));
  await _buscarEnElCatalogo(tester, tarjeta);
  await tester.tap(
    find.descendant(of: tarjeta, matching: find.text(producto.nombre)),
  );

  final anadir = find.widgetWithText(ElevatedButton, 'Añadir');
  await esperar(tester, anadir, limite: esperaDelServidor);
  await tester.ensureVisible(anadir);
  await tester.tap(anadir);
  await esperar(
    tester,
    find.textContaining('agregado'),
    limite: esperaDelServidor,
    motivo: 'el servidor no agregó «${producto.nombre}» al carrito',
  );
  // El aviso «agregado» queda unos segundos encima del botón «Proceder al
  // Pago»; como una persona, la prueba espera a que se quite.
  await esperarQue(
    tester,
    () => find.byType(SnackBar).evaluate().isEmpty,
    limite: const Duration(seconds: 15),
    motivo: 'el aviso de «agregado» no se quitó',
  );
}

/// Pestaña «Carrito» → «Proceder al Pago» → «Finalizar Pedido».
Future<void> abrirElCheckout(WidgetTester tester, Product producto) async {
  await tester.tap(pestana('Carrito'));
  final pagar = find.text('Proceder al Pago');
  await esperar(tester, pagar, limite: esperaDelServidor);
  expect(find.textContaining(producto.nombre), findsWidgets);
  await tester.ensureVisible(pagar);
  await tester.tap(pagar);
  await esperar(tester, find.text('Finalizar Pedido'));
}

/// La pestaña [nombre] de la barra de abajo.
Finder pestana(String nombre) => find.descendant(
  of: find.byType(BottomNavigationBar),
  matching: find.text(nombre),
);

/// La lista vertical del catálogo.
Finder listaDelCatalogo() => find.descendant(
  of: find.byType(ProductsScreen),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  ),
);

/// El catálogo arma las tarjetas conforme se desplaza: baja hasta encontrar
/// la del producto.
Future<void> _buscarEnElCatalogo(WidgetTester tester, Finder tarjeta) async {
  final lista = listaDelCatalogo();
  await esperar(tester, lista);
  await esperar(
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
Future<void> esperar(
  WidgetTester tester,
  Finder buscado, {
  Duration limite = const Duration(seconds: 30),
  String? motivo,
  bool obligatorio = true,
}) => esperarQue(
  tester,
  () => buscado.evaluate().isNotEmpty,
  limite: limite,
  motivo: motivo ?? 'no apareció $buscado',
  obligatorio: obligatorio,
);

/// Da cuadros cada 250 ms hasta que se cumpla [condicion] o pase [limite].
Future<void> esperarQue(
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
