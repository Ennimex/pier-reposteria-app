// test/aceptacion/carrito_checkout/carrito_test.dart — escenarios Gherkin del
// carrito: agregar, cambiar cantidad, eliminar, vaciar y el rechazo por stock
// (#57; historia #35), sin red.
//
// Cada prueba recorre la app como el cliente: inicia sesión, abre el detalle
// o «Mi Carrito» desde una página anfitriona y toca los mismos botones. El
// backend es un carrito en memoria sobre FakeApiClient que guarda las líneas,
// asigna su id y valida el stock, para que lo que se ve en pantalla sea lo
// que el «servidor» realmente tiene.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_linea.dart';
import 'package:pier_reposteria/ui/cart/widgets/cart_screen.dart';
import 'package:pier_reposteria/ui/products/widgets/product_detail_screen.dart';

import '../../fakes/fake_api_client.dart';
import '../../helpers/pump_app.dart';

/// Catálogo del backend falso: id → (nombre, precio).
const Map<int, (String, num)> _catalogo = {
  7: ('Chocoflan', 300),
  8: ('Pay de queso', 250),
};

/// Carrito en memoria que responde como el backend real: GET lista las
/// líneas, POST agrega (o suma a la línea del mismo producto y tamaño), PUT
/// cambia la cantidad, DELETE de una línea la quita y DELETE /carrito lo
/// vacía. Rechaza con «Solo quedan N unidades» si se pasa del [stock].
class _BackendCarrito {
  _BackendCarrito({this.stock = const {}}) {
    api = FakeApiClient(respuestas: {
      ApiConstants.login: {
        'success': true,
        'token': 'jwt',
        'user': {'id': 1, 'email': 'ana@pier.mx', 'rol': 'cliente'},
      },
      ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
      ApiConstants.productoById('7'): {
        'success': true,
        'producto': {'imagenes': <String>[], 'reviews': 0},
        'resenas': <Map<String, dynamic>>[],
      },
      ApiConstants.recomendaciones('7'): {
        'success': true,
        'recomendaciones': <Map<String, dynamic>>[],
      },
      ApiConstants.carrito: _carrito,
      // Los ids de línea que puede asignar el backend (151, 152, …).
      for (var id = _primerId; id < _primerId + 10; id++)
        ApiConstants.carritoItem('$id'): _linea,
    });
  }

  static const int _primerId = 151;

  /// Existencias por producto; sin entrada, ilimitadas.
  final Map<int, int> stock;
  late final FakeApiClient api;
  final List<Map<String, dynamic>> lineas = [];
  int _siguienteId = _primerId;

  /// Deja [cantidad] de [productoId] en el carrito antes de la prueba.
  void precargar(int productoId, int cantidad) =>
      lineas.add(_nuevaLinea(productoId, cantidad, 'chico'));

  Map<String, dynamic> _nuevaLinea(int productoId, int cantidad, String tamano) {
    final (nombre, precio) = _catalogo[productoId]!;
    return {
      'producto_id': productoId,
      'carrito_item_id': _siguienteId++,
      'nombre': nombre,
      'precio_unitario': precio.toStringAsFixed(2),
      'precio_original': precio.toStringAsFixed(2),
      'cantidad': cantidad,
      'tamano': tamano,
    };
  }

  /// Motivo del rechazo si [cantidad] supera las existencias.
  Map<String, dynamic>? _sinStock(int productoId, int cantidad) {
    final quedan = stock[productoId];
    if (quedan == null || cantidad <= quedan) return null;
    return {'success': false, 'message': 'Solo quedan $quedan unidades'};
  }

  Map<String, dynamic> _carrito(LlamadaApi llamada) {
    switch (llamada.metodo) {
      case 'POST-Auth':
        final body = llamada.body!;
        final productoId = body['producto_id'] as int;
        final cantidad = body['cantidad'] as int;
        final tamano = body['tamano'] as String;
        final existente = lineas
            .where((l) =>
                l['producto_id'] == productoId && l['tamano'] == tamano)
            .firstOrNull;
        final total = (existente?['cantidad'] as int? ?? 0) + cantidad;
        final rechazo = _sinStock(productoId, total);
        if (rechazo != null) return rechazo;
        if (existente != null) {
          existente['cantidad'] = total;
        } else {
          lineas.add(_nuevaLinea(productoId, cantidad, tamano));
        }
        return {'success': true};
      case 'DELETE-Auth':
        lineas.clear();
        return {'success': true};
      default:
        return {
          'success': true,
          'carrito': {
            'items': [for (final l in lineas) {...l}],
          },
        };
    }
  }

  Map<String, dynamic> _linea(LlamadaApi llamada) {
    final id = int.parse(llamada.endpoint.split('/').last);
    final linea = lineas.where((l) => l['carrito_item_id'] == id).firstOrNull;
    if (linea == null) {
      return {'success': false, 'message': 'Ese producto ya no está'};
    }
    if (llamada.metodo == 'DELETE-Auth') {
      lineas.remove(linea);
      return {'success': true};
    }
    final cantidad = llamada.body!['cantidad'] as int;
    final rechazo = _sinStock(linea['producto_id'] as int, cantidad);
    if (rechazo != null) return rechazo;
    linea['cantidad'] = cantidad;
    return {'success': true};
  }
}

/// El producto que el cliente está viendo.
final Product _chocoflan = Product.fromJson(const {
  'id': 7,
  'nombre': 'Chocoflan',
  'descripcion': 'Flan con pastel de chocolate',
  'precio_chico': 300,
  'categoria': 'Pasteles',
  'imagen_url': '',
  'activo': true,
});

/// Página de partida: abre el detalle del producto o «Mi Carrito», como lo
/// hacen el catálogo y la pestaña del carrito.
class _Tienda extends StatelessWidget {
  const _Tienda();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => ProductDetailScreen(product: _chocoflan)),
              ),
              child: const Text('Ver producto'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const CartScreen()),
              ),
              child: const Text('Ver carrito'),
            ),
          ],
        ),
      );
}

/// Avanza el tiempo sin esperar a que todo termine: el Lottie del carrito
/// vacío se repite sin fin y pumpAndSettle no acabaría.
Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Monta la app en un celular (412×869 lógicos, como el Note 10+) con la
/// sesión de un cliente iniciada. El detalle del producto se prueba a 1080
/// de ancho, igual que en product_detail_screen_test.dart: con la fuente de
/// pruebas (Ahem, más ancha que la real) se desborda a 412.
Future<void> _abrirTienda(WidgetTester tester, _BackendCarrito backend,
    {bool conDetalle = false}) async {
  tester.view
    ..physicalSize =
        conDetalle ? const Size(1080, 4200) : const Size(1440, 3040)
    ..devicePixelRatio = conDetalle ? 1 : 3.5;
  addTearDown(tester.view.reset);
  await tester.pumpApp(const _Tienda(), api: backend.api);
  await tester.iniciarSesion(find.byType(_Tienda));
  await tester.pump();
}

/// Abre «Mi Carrito» (que carga las líneas del backend).
Future<void> _verCarrito(WidgetTester tester) async {
  await tester.tap(find.text('Ver carrito'));
  await _asentar(tester);
}

/// La línea del carrito de [nombre].
Finder _linea(String nombre) => find.widgetWithText(CartLinea, nombre);

/// Un botón (por su icono) dentro de la línea de [nombre].
Finder _boton(String nombre, IconData icono) =>
    find.descendant(of: _linea(nombre), matching: find.byIcon(icono));

/// La cantidad que muestra la línea de [nombre].
Finder _cantidad(String nombre, int cantidad) =>
    find.descendant(of: _linea(nombre), matching: find.text('$cantidad'));

void main() {
  group('#35 Carrito: agregar productos y ajustar cantidades', () {
    // Escenario: agregar un producto
    //   Dado que estoy viendo un producto disponible
    //   Cuando lo agrego al carrito
    //   Entonces aparece en el carrito con su cantidad y su precio
    testWidgets('Escenario: agregar un producto', (tester) async {
      final backend = _BackendCarrito();
      await _abrirTienda(tester, backend, conDetalle: true);

      // Dado que estoy viendo un producto disponible
      await tester.tap(find.text('Ver producto'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.text('Chocoflan'), findsOneWidget);

      // Cuando lo agrego al carrito
      await tester.ensureVisible(find.text('Añadir'));
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
      expect(find.text('1 × Chocoflan agregado'), findsOneWidget);
      expect(backend.api.ultima(ApiConstants.carrito)!.metodo, 'GET-Auth');
      final alta = backend.api.llamadas.lastWhere((l) =>
          l.endpoint == ApiConstants.carrito && l.metodo == 'POST-Auth');
      expect(alta.body, {'producto_id': 7, 'cantidad': 1, 'tamano': 'chico'});

      // Entonces aparece en el carrito con su cantidad y su precio
      // («Mi Carrito» ya en tamaño de celular).
      tester.view
        ..physicalSize = const Size(1440, 3040)
        ..devicePixelRatio = 3.5;
      await tester.pump();
      await _verCarrito(tester);
      expect(_linea('Chocoflan'), findsOneWidget);
      expect(_cantidad('Chocoflan', 1), findsOneWidget);
      expect(
        find.descendant(of: _linea('Chocoflan'), matching: find.text(r'$300 c/u')),
        findsOneWidget,
      );
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text(r'$300 MXN'), findsOneWidget); // total
    });

    // Escenario: cambiar la cantidad
    //   Dado que tengo un producto en el carrito
    //   Cuando aumento o disminuyo su cantidad
    //   Entonces el total del carrito se actualiza
    testWidgets('Escenario: cambiar la cantidad', (tester) async {
      final backend = _BackendCarrito()..precargar(7, 1);
      await _abrirTienda(tester, backend);

      // Dado que tengo un producto en el carrito
      await _verCarrito(tester);
      expect(_cantidad('Chocoflan', 1), findsOneWidget);
      expect(find.text(r'$300 MXN'), findsOneWidget);

      // Cuando aumento su cantidad
      await tester.tap(_boton('Chocoflan', LucideIcons.plus));
      await _asentar(tester);

      // Entonces el total del carrito se actualiza
      expect(_cantidad('Chocoflan', 2), findsOneWidget);
      expect(find.text('2 productos'), findsOneWidget);
      expect(find.text(r'$600 MXN'), findsOneWidget);
      expect(backend.api.ultima(ApiConstants.carritoItem('151'))!.body,
          {'cantidad': 2});
      expect(backend.lineas.single['cantidad'], 2);

      // Cuando disminuyo su cantidad
      await tester.tap(_boton('Chocoflan', LucideIcons.minus));
      await _asentar(tester);

      // Entonces el total del carrito se actualiza
      expect(_cantidad('Chocoflan', 1), findsOneWidget);
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text(r'$300 MXN'), findsOneWidget);
      expect(backend.lineas.single['cantidad'], 1);
    });

    // Escenario: eliminar un producto
    //   Dado que tengo varios productos en el carrito
    //   Cuando elimino uno
    //   Entonces deja de aparecer y el total se recalcula
    testWidgets('Escenario: eliminar un producto', (tester) async {
      final backend = _BackendCarrito()
        ..precargar(7, 1)
        ..precargar(8, 1);
      await _abrirTienda(tester, backend);

      // Dado que tengo varios productos en el carrito
      await _verCarrito(tester);
      expect(_linea('Chocoflan'), findsOneWidget);
      expect(_linea('Pay de queso'), findsOneWidget);
      expect(find.text(r'$550 MXN'), findsOneWidget);

      // Cuando elimino uno (con una sola unidad, «−» es el bote de basura)
      await tester.tap(_boton('Pay de queso', LucideIcons.trash2));
      await _asentar(tester);

      // Entonces deja de aparecer y el total se recalcula
      expect(_linea('Pay de queso'), findsNothing);
      expect(_linea('Chocoflan'), findsOneWidget);
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text(r'$300 MXN'), findsOneWidget);
      expect(
        backend.api.llamo(ApiConstants.carritoItem('152'), metodo: 'DELETE-Auth'),
        isTrue,
      );
      expect(backend.lineas.map((l) => l['nombre']), ['Chocoflan']);
    });

    // Escenario: vaciar el carrito
    //   Dado que tengo productos en el carrito
    //   Cuando lo vacío
    //   Entonces el carrito queda sin productos
    testWidgets('Escenario: vaciar el carrito', (tester) async {
      final backend = _BackendCarrito()
        ..precargar(7, 2)
        ..precargar(8, 1);
      await _abrirTienda(tester, backend);

      // Dado que tengo productos en el carrito
      await _verCarrito(tester);
      expect(find.text('3 productos'), findsOneWidget);

      // Cuando lo vacío (y confirmo)
      await tester.tap(find.text('Vaciar'));
      await _asentar(tester);
      expect(find.text('Vaciar carrito'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Vaciar'));
      await _asentar(tester);

      // Entonces el carrito queda sin productos
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.byType(CartLinea), findsNothing);
      expect(find.text('Proceder al Pago'), findsNothing);
      expect(
        backend.api.llamo(ApiConstants.carrito, metodo: 'DELETE-Auth'),
        isTrue,
      );
      expect(backend.lineas, isEmpty);
    });

    // Escenario: no hay existencias para la cantidad pedida
    //   Dado que tengo un producto en el carrito y solo queda 1 unidad
    //   Cuando aumento su cantidad
    //   Entonces la app avisa el motivo y la cantidad y el total no cambian
    testWidgets('Escenario: el backend rechaza la cantidad por stock',
        (tester) async {
      final backend = _BackendCarrito(stock: {7: 1})..precargar(7, 1);
      await _abrirTienda(tester, backend);

      // Dado que tengo un producto en el carrito y solo queda 1 unidad
      await _verCarrito(tester);
      expect(_cantidad('Chocoflan', 1), findsOneWidget);

      // Cuando aumento su cantidad
      await tester.tap(_boton('Chocoflan', LucideIcons.plus));
      await _asentar(tester);

      // Entonces la app avisa el motivo y la cantidad y el total no cambian
      expect(find.text('Solo quedan 1 unidades'), findsOneWidget);
      expect(_cantidad('Chocoflan', 1), findsOneWidget);
      expect(find.text('1 producto'), findsOneWidget);
      expect(find.text(r'$300 MXN'), findsOneWidget);
      expect(backend.lineas.single['cantidad'], 1);
    });
  });
}
