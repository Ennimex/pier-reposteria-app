// integration_test/flujos/catalogo_resena_test.dart — #65: del catálogo a la
// reseña con la app real, en el celular virtual (emulador), contra el
// entorno aislado (integracion.yml, «Flujos de compra, reseña y entrega en
// el entorno aislado», dentro de pipeline.yml). Junta la búsqueda del
// catálogo (#37), el historial de pedidos (#39) y la reseña de lo comprado
// (#41).
//
// La cuenta ficticia de la semilla (docker/semilla/semilla_pruebas.sql) trae
// un pedido completado. La prueba inicia sesión con ella (USUARIO_PRUEBA y
// CLAVE_PRUEBA por --dart-define, como el flujo de compra), toma ese pedido
// de su historial (GET /pedidos/mis-pedidos) y, con la app: busca su
// producto en el catálogo y lo abre; en «Pedidos» → «Historial» abre el
// pedido, cuyo detalle muestra el producto; vuelve al producto y lo califica
// desde «Escribir» con 5 estrellas y un comentario. Con 5 estrellas el
// backend la publica al momento y, por la compra, la marca «Compra
// verificada», que la prueba busca en «Ver las … opiniones».
//
// Solo corre con la cuenta de la semilla: una reseña no se puede borrar
// desde la app y una cuenta real no tiene por qué traer un pedido
// completado. flujo-compra.yml y la regresión completa corren toda la
// carpeta flujos/ contra el servidor real: ahí se omite, igual que sin
// credenciales. La reseña se queda en la base del contenedor; para repetir
// la prueba hay que bajar y levantar el entorno (tool/entorno_pruebas.sh).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_reposteria/data/repositories/pedidos_repository_remote.dart';
import 'package:pier_reposteria/data/repositories/resenas_repository_remote.dart';
import 'package:pier_reposteria/data/services/api_service.dart';
import 'package:pier_reposteria/domain/models/order_model.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/orders/widgets/order_detail_screen.dart';
import 'package:pier_reposteria/ui/orders/widgets/orders_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/products_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/create_review_screen.dart';
import 'package:pier_reposteria/ui/reviews/widgets/product_reviews_screen.dart';

import '../ayudas/servidor_real.dart';

/// El comentario de la reseña: 10 caracteres o más y sin palabras que el
/// backend mande a revisión, para que con 5 estrellas se publique al momento.
const _comentario = 'Esponjoso, húmedo y con el dulzor justo';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  toquesPerdidosFallan();

  group('#65 Del catálogo a la reseña en el entorno aislado', () {
    // Escenario: calificar un producto de un pedido completado
    //   Dado que tengo un pedido completado
    //   Cuando busco su producto en el catálogo y lo abro, reviso el pedido
    //     en mi historial y califico el producto con 5 estrellas y un
    //     comentario
    //   Entonces la reseña queda publicada como «Compra verificada».
    testWidgets('Escenario: calificar un producto de un pedido completado', (
      tester,
    ) async {
      if (faltanCredenciales() || faltaLaCuentaDeLaSemilla()) return;
      final api = await abrirLaApp(tester);

      // Dado que tengo un pedido completado
      await iniciarSesion(tester);
      final (pedido, renglon) = await _pedidoCompletado(api);
      final producto = await _productoDelCatalogo(api, renglon);
      await _sinResenaPrevia(api, producto);

      // Cuando busco su producto en el catálogo y lo abro, …
      await _buscarYAbrir(tester, api, producto);
      // … reviso el pedido en mi historial …
      await _abrirDelHistorial(tester, pedido, renglon);
      // … y califico el producto con 5 estrellas y un comentario
      await _calificar(tester);

      // Entonces la reseña queda publicada como «Compra verificada»
      await _verLaResenaPublicada(tester);
    });
  });
}

/// El primer pedido completado (recogido o entregado) de la cuenta y su
/// primer renglón con producto: el de la semilla.
Future<(Order, OrderItem)> _pedidoCompletado(ApiService api) async {
  final pedidos = await PedidosRepositoryRemote(api: api).listarMisPedidos();
  for (final pedido in pedidos) {
    if (pedido.status != OrderStatus.completed &&
        pedido.status != OrderStatus.delivered) {
      continue;
    }
    for (final renglon in pedido.items) {
      if (renglon.productoId != null) return (pedido, renglon);
    }
  }
  fail(
    'la cuenta no tiene un pedido completado con productos: revisa '
    'docker/semilla/semilla_pruebas.sql',
  );
}

/// El producto del [renglon] tal como está hoy en el catálogo.
Future<Product> _productoDelCatalogo(ApiService api, OrderItem renglon) async {
  for (final producto in await catalogoDelServidor(api)) {
    if (producto.id == renglon.productoId) return producto;
  }
  fail('«${renglon.nombre}», del pedido completado, no está en el catálogo');
}

/// Una reseña no se puede borrar desde la app y el backend no deja escribir
/// otra del mismo producto: si ya existe (otra corrida en el mismo entorno),
/// lo dice antes de empezar.
Future<void> _sinResenaPrevia(ApiService api, Product producto) async {
  final mias = await ResenasRepositoryRemote(api: api).listarMisResenas();
  if (mias.any((resena) => resena.productoNombre == producto.nombre)) {
    fail(
      'la cuenta ya calificó «${producto.nombre}» en este entorno: bájalo y '
      'levántalo otra vez (bash tool/entorno_pruebas.sh bajar y levantar)',
    );
  }
}

/// Pestaña «Catálogo» → escribe el nombre del producto en el buscador →
/// quedan solo las tarjetas que coinciden → abre la del producto.
Future<void> _buscarYAbrir(
  WidgetTester tester,
  ApiService api,
  Product producto,
) async {
  final termino = producto.nombre.toLowerCase();
  // Lo que la búsqueda debe quitar: los productos cuyo nombre no la tiene.
  final otras = [
    for (final otro in await catalogoDelServidor(api))
      if (!otro.nombre.toLowerCase().contains(termino)) _tarjeta(otro.id),
  ];
  final tarjeta = _tarjeta(producto.id);

  await tester.tap(pestana('Catálogo'));
  final buscador = enPantalla(ProductsScreen, find.byType(TextField));
  await esperar(tester, buscador);
  await escribirYCerrarTeclado(tester, buscador.first, termino);
  await esperarQue(
    tester,
    () =>
        tarjeta.evaluate().isNotEmpty &&
        otras.every((otra) => otra.evaluate().isEmpty),
    limite: esperaDelServidor,
    motivo:
        'al buscar «$termino» el catálogo no quedó solo con lo que '
        'coincide',
  );

  await tester.ensureVisible(tarjeta);
  await esperarQueSeAsiente(tester, tarjeta);
  await tester.tap(
    find.descendant(of: tarjeta, matching: find.text(producto.nombre)),
  );
  await esperar(
    tester,
    enPantalla(ProductDetailScreen, find.text(producto.nombre)),
    limite: esperaDelServidor,
  );
}

/// Pestaña «Pedidos» → «Historial» → la tarjeta del pedido → su detalle:
/// con su estado y el producto comprado.
Future<void> _abrirDelHistorial(
  WidgetTester tester,
  Order pedido,
  OrderItem renglon,
) async {
  await tester.tap(pestana('Pedidos'));
  final historial = enPantalla(OrdersScreen, find.text('Historial'));
  await esperar(tester, historial);
  await tester.tap(historial);

  final tarjeta = enPantalla(OrdersScreen, find.text(pedido.numero));
  await esperar(tester, tarjeta, limite: esperaDelServidor);
  // La página del historial entra deslizándose y, mientras se mueve, la
  // lista no deja tocar sus tarjetas.
  await esperarQueSeAsiente(tester, tarjeta);
  await tester.tap(tarjeta);

  final detalle = find.byType(OrderDetailScreen);
  await esperar(tester, detalle);
  for (final texto in [pedido.numero, pedido.statusText, renglon.nombre]) {
    expect(
      find.descendant(of: detalle, matching: find.text(texto)),
      findsWidgets,
      reason: 'el detalle del pedido debe mostrar «$texto»',
    );
  }
}

/// De vuelta en el producto (pestaña «Catálogo»): «Escribir» → 5 estrellas
/// y el comentario → «Publicar Opinión» → el diálogo de gracias.
Future<void> _calificar(WidgetTester tester) async {
  await tester.tap(pestana('Catálogo'));
  final escribir = enPantalla(ProductDetailScreen, find.text('Escribir'));
  await esperar(tester, escribir);
  await tester.ensureVisible(escribir);
  await esperarQueSeAsiente(tester, escribir);
  await tester.tap(escribir);

  final pantalla = find.byType(CreateReviewScreen);
  final apagadas = find.descendant(
    of: pantalla,
    matching: find.byIcon(Icons.star_border_rounded),
  );
  await esperarQue(
    tester,
    () => apagadas.evaluate().length == 5,
    motivo: 'no se abrió «Escribir Opinión» con sus 5 estrellas',
  );
  final quinta = apagadas.at(4);
  await tester.ensureVisible(quinta);
  await tester.tap(quinta);
  await esperarQue(
    tester,
    () =>
        find
            .descendant(of: pantalla, matching: find.byIcon(Icons.star_rounded))
            .evaluate()
            .length ==
        5,
    motivo: 'no se encendieron las 5 estrellas',
    limite: const Duration(seconds: 10),
  );

  // El comentario va en el último campo (el título, opcional, va antes).
  final comentario = find
      .descendant(of: pantalla, matching: find.byType(TextField))
      .last;
  await tester.ensureVisible(comentario);
  await escribirYCerrarTeclado(tester, comentario, _comentario);

  final publicar = find.text('Publicar Opinión');
  await tester.ensureVisible(publicar);
  await tester.tap(publicar);

  // Contesta con el diálogo de gracias o con un aviso con el motivo.
  final gracias = find.textContaining('¡Gracias por tu');
  final aviso = find.descendant(
    of: find.byType(SnackBar),
    matching: find.byType(Text),
  );
  await esperarQue(
    tester,
    () => gracias.evaluate().isNotEmpty || aviso.evaluate().isNotEmpty,
    limite: esperaDelServidor,
    motivo: 'el servidor no contestó la reseña',
  );
  expect(aviso, findsNothing, reason: 'la app avisó: ${textosDe(aviso)}');
  expect(
    find.textContaining('Tu reseña ha sido publicada'),
    findsOneWidget,
    reason:
        'con 5 estrellas y sin palabras que revisar, el backend la '
        'publica al momento',
  );
}

/// «Entendido» → de vuelta en el producto, su opinión ya aparece → «Ver las
/// … opiniones» → la reseña lleva «Compra verificada».
Future<void> _verLaResenaPublicada(WidgetTester tester) async {
  final entendido = find.widgetWithText(ElevatedButton, 'Entendido');
  await esperarQueSeAsiente(tester, entendido);
  await tester.tap(entendido);
  await esperarQueSeCierre(tester, find.byType(CreateReviewScreen));

  // Al volver, el detalle recarga sus opiniones.
  await esperar(
    tester,
    enPantalla(ProductDetailScreen, find.text(_comentario)),
    limite: esperaDelServidor,
    motivo: 'la opinión no apareció en el detalle del producto',
  );
  final verTodas = enPantalla(
    ProductDetailScreen,
    find.textContaining(RegExp(r'^Ver las \d+ opiniones$')),
  );
  await esperar(tester, verTodas);
  await tester.ensureVisible(verTodas);
  await esperarQueSeAsiente(tester, verTodas);
  await tester.tap(verTodas);

  final opiniones = find.byType(ProductReviewsScreen);
  await esperar(
    tester,
    find.descendant(of: opiniones, matching: find.text(_comentario)),
    limite: esperaDelServidor,
    motivo: 'la opinión no apareció en «Opiniones»',
  );
  expect(
    find.descendant(of: opiniones, matching: find.text('Compra verificada')),
    findsOneWidget,
    reason:
        'la reseña de un producto de un pedido completado es una compra '
        'verificada',
  );
}

/// La tarjeta del producto [id] en la lista del catálogo.
Finder _tarjeta(String id) => find.descendant(
  of: listaDelCatalogo(),
  matching: find.byKey(ValueKey<String>(id)),
);
