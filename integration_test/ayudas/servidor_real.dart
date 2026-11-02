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
// ficticia de la semilla. Del catálogo a la reseña (#65,
// flujos/catalogo_resena_test.dart) y la entrega con su reembolso (#69,
// flujos/entrega_reembolso_test.dart) corren solo ahí; la entrega también
// inicia sesión como el repartidor de la semilla (REPARTIDOR_PRUEBA y
// CLAVE_REPARTIDOR_PRUEBA, también con --dart-define).
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

import 'esperas.dart';

export 'esperas.dart';

const _usuario = String.fromEnvironment('USUARIO_PRUEBA');
const _clave = String.fromEnvironment('CLAVE_PRUEBA');
const _repartidor = String.fromEnvironment('REPARTIDOR_PRUEBA');
const _claveRepartidor = String.fromEnvironment('CLAVE_REPARTIDOR_PRUEBA');

/// El servidor gratuito se duerme y tarda en contestar la primera vez.
const esperaDelServidor = Duration(seconds: 90);

/// Omite la prueba (y lo dice) si no llegaron las credenciales.
bool faltanCredenciales() {
  if (_usuario.isNotEmpty && _clave.isNotEmpty) return false;
  markTestSkipped('faltan USUARIO_PRUEBA y CLAVE_PRUEBA (--dart-define)');
  return true;
}

/// La cuenta ficticia de docker/semilla/semilla_pruebas.sql: solo existe en
/// el contenedor del entorno aislado.
const cuentaDeLaSemilla = 'cliente@pier.test';

/// Omite la prueba (y lo dice) si no inicia sesión con la cuenta de la
/// semilla, es decir, si no corre contra el entorno aislado: para lo que
/// deja datos que no se pueden borrar o necesita los datos de la semilla.
bool faltaLaCuentaDeLaSemilla() {
  if (_usuario == cuentaDeLaSemilla) return false;
  markTestSkipped(
    'solo corre en el entorno aislado, con la cuenta de la semilla '
    '($cuentaDeLaSemilla)',
  );
  return true;
}

/// El repartidor ficticio de docker/semilla/semilla_pruebas.sql: como la
/// cuenta de la semilla, solo existe en el contenedor del entorno aislado.
const repartidorDeLaSemilla = 'repartidor@pier.test';

/// Omite la prueba (y lo dice) si no llegaron las credenciales del
/// repartidor de la semilla.
bool faltaElRepartidorDeLaSemilla() {
  if (_repartidor == repartidorDeLaSemilla && _claveRepartidor.isNotEmpty) {
    return false;
  }
  markTestSkipped(
    'faltan REPARTIDOR_PRUEBA y CLAVE_REPARTIDOR_PRUEBA (--dart-define) con '
    'el repartidor de la semilla ($repartidorDeLaSemilla)',
  );
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

/// Desde «Iniciar Sesión» hasta el Inicio, con el carrito vacío. Sin
/// [usuario] ni [clave] entra con la cuenta de prueba; con [vaciarCarrito]
/// en false no toca el carrito (el repartidor no compra).
Future<void> iniciarSesion(
  WidgetTester tester, {
  String? usuario,
  String? clave,
  bool vaciarCarrito = true,
}) async {
  final correo = usuario ?? _usuario;
  final contrasena = clave ?? _clave;
  await esperar(tester, find.text('Iniciar Sesión'));
  await tester.enterText(find.byType(TextFormField).at(0), correo);
  await tester.enterText(find.byType(TextFormField).at(1), contrasena);
  // En pantallas chicas el teclado tapa el botón (ver app_smoke_test.dart):
  // se cierra y se espera a que se vaya (#215).
  await cerrarTeclado(tester);
  // En un celular real el teclado del sistema borra al cerrarse lo que
  // escribió enterText (en el emulador del CI no): se deja el texto directo
  // en los campos.
  for (final (campo, texto) in [(0, correo), (1, contrasena)]) {
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
        'exista, tenga el rol que la prueba espera (cliente o repartidor) '
        'y el correo verificado',
  );
  if (!vaciarCarrito) return;

  // Un carrito con restos de otra corrida cambiaría el total.
  final carrito = tester.element(find.byType(BottomNavigationBar));
  final error = await carrito.read<CartProvider>().clearCart();
  expect(error, isNull, reason: 'no se pudo vaciar el carrito: $error');
}

/// Desde «Iniciar Sesión» hasta el panel del repartidor de la semilla
/// («Entregas», «Historial» y «Perfil»).
Future<void> iniciarSesionComoRepartidor(WidgetTester tester) => iniciarSesion(
  tester,
  usuario: _repartidor,
  clave: _claveRepartidor,
  vaciarCarrito: false,
);

/// Los productos del catálogo del servidor (GET /productos).
Future<List<Product>> catalogoDelServidor(ApiService api) async {
  final respuesta = await ProductosRepositoryRemote(api: api).listar();
  return (respuesta['productos'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(Product.fromJson)
      .toList();
}

/// Toma del catálogo real un producto activo con existencias, para no
/// depender de uno en particular.
Future<Product> productoConExistencias(ApiService api) async {
  final productos = (await catalogoDelServidor(
    api,
  )).where((producto) => producto.disponible && !producto.agotado);
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

/// [buscado] dentro de la pantalla [pantalla].
Finder enPantalla(Type pantalla, Finder buscado) =>
    find.descendant(of: find.byType(pantalla), matching: buscado);

/// Los textos de los widgets [textos] (de tipo Text), para explicar una
/// falla.
String textosDe(Finder textos) => textos
    .evaluate()
    .map((elemento) => (elemento.widget as Text).data ?? '')
    .join(' · ');

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
