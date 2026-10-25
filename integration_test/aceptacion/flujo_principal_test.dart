// integration_test/aceptacion/flujo_principal_test.dart — aceptación del flujo
// principal en el celular virtual: inicio de sesión (#34) → carrito (#35) →
// checkout (#36), con la app completa instalada y el servidor de mentira
// (FakeApiClient), sin red.
//
// Los escenarios Gherkin de cada historia viven en test/aceptacion/ y corren
// sin emulador; aquí se comprueba que, ya en un Android, las tres historias
// se encadenan. Lo corre aceptacion.yml (trabajo «Flujo principal en el
// emulador») con flutter drive y test_driver/aceptacion_driver.dart, que
// guarda una captura de pantalla por paso y el reporte en build/resultados/.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_reposteria/app.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/domain/models/product_model.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:provider/provider.dart';

import '../../test/fakes/fake_api_client.dart';
import '../ayudas/servidor_real.dart';

void main() {
  // La app dibuja todos sus cuadros, como en un celular de verdad, para que
  // cada captura muestre la pantalla de ese momento. Con la política por
  // omisión (fadePointers) el cuadro que pide la captura se salta y salía la
  // pantalla de un paso anterior (corrida 40174857476).
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Flujo principal #34 → #35 → #36', () {
    // Escenario: del inicio de sesión al checkout
    //   Dado que tengo una cuenta de cliente verificada y el catálogo tiene
    //     productos con existencias
    //   Cuando inicio sesión (#34), abro un producto, lo añado al carrito
    //     (#35) y toco «Proceder al Pago»
    //   Entonces el carrito muestra el producto y llego a «Finalizar Pedido»
    //     (#36).
    testWidgets('Escenario: del inicio de sesión al checkout', (tester) async {
      final backend = _BackendDelFlujo();
      final evidencia = _Evidencia(binding, tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: dependencias(backend.api),
          child: const MyApp(initialLocation: AppRoutes.login),
        ),
      );
      // Android solo deja capturar la pantalla si la app se dibuja en una
      // imagen (integration_test); se revierte sola al terminar la prueba.
      await binding.convertFlutterSurfaceToImage();

      // #34: inicio de sesión con la cuenta del servidor de mentira.
      await esperar(tester, find.text('Iniciar Sesión'));
      await evidencia.paso('01_inicio_de_sesion');
      await _iniciarSesion(tester);
      expect(backend.api.llamo(ApiConstants.login, metodo: 'POST'), isTrue);
      await evidencia.paso('02_inicio');

      // #35: catálogo → detalle → «Añadir».
      await agregarAlCarrito(tester, backend.producto);
      expect(backend.lineasDelCarrito, hasLength(1));
      await evidencia.paso('03_producto_agregado');

      await tester.tap(pestana('Carrito'));
      final procederAlPago = find.text('Proceder al Pago');
      await esperar(tester, procederAlPago);
      expect(find.textContaining(backend.producto.nombre), findsWidgets);
      await evidencia.paso('04_carrito');

      // #36: «Proceder al Pago» abre el checkout.
      await tester.ensureVisible(procederAlPago);
      await tester.tap(procederAlPago);
      await esperar(tester, find.text('Finalizar Pedido'));
      expect(find.textContaining(backend.producto.nombre), findsWidgets);
      await evidencia.paso('05_checkout');
    });
  });
}

/// Correo y contraseña de la cuenta de mentira: solo existen en esta prueba.
const _correo = 'cliente@pier.test';
const _clave = 'pastel-de-prueba';

/// Escribe las credenciales y toca «Iniciar Sesión» hasta llegar al Inicio.
Future<void> _iniciarSesion(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), _correo);
  await tester.enterText(find.byType(TextFormField).at(1), _clave);
  // En pantallas chicas el teclado tapa el botón (ver app_smoke_test.dart).
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.ensureVisible(find.text('Iniciar Sesión'));
  await tester.tap(find.text('Iniciar Sesión'));
  await esperar(tester, find.byType(BottomNavigationBar));
}

/// Lo que deja cada paso para el reporte: su nombre, los segundos desde el
/// inicio de la prueba y una captura de pantalla con el mismo nombre.
class _Evidencia {
  _Evidencia(this._binding, this._tester);

  final IntegrationTestWidgetsFlutterBinding _binding;
  final WidgetTester _tester;
  final Stopwatch _reloj = Stopwatch()..start();

  Future<void> paso(String nombre) async {
    final pasos = (_binding.reportData ??= <String, dynamic>{})
        .putIfAbsent('pasos', () => <Map<String, dynamic>>[]);
    (pasos as List<Map<String, dynamic>>).add({
      'paso': nombre,
      'segundos': _reloj.elapsedMilliseconds / 1000,
    });
    // Medio segundo antes de capturar: termina de dibujarse la pantalla y se
    // borra la marca de los toques que pinta el binding de pruebas.
    await _tester.pump(const Duration(milliseconds: 500));
    await _binding.takeScreenshot(nombre);
  }
}

/// El servidor de mentira del flujo: una cuenta de cliente, un catálogo con
/// existencias y un carrito en memoria que guarda lo que se agrega. Responde
/// también lo que piden el Inicio y el checkout, para que ninguna pantalla
/// muestre errores que no son del flujo.
class _BackendDelFlujo {
  _BackendDelFlujo() {
    api = FakeApiClient(
      respuestas: {
        ApiConstants.login: {
          'success': true,
          'token': 'jwt-de-prueba',
          'user': {
            'id': 1,
            'nombre': 'Ana',
            'apellido': 'Prueba',
            'email': _correo,
            'rol': 'cliente',
          },
        },
        ApiConstants.productos: {
          'success': true,
          'productos': _catalogo,
          'total': _catalogo.length,
        },
        ApiConstants.productoById('7'): {
          'success': true,
          'producto': {..._catalogo.first, 'imagenes': <String>[]},
          'resenas': <Map<String, dynamic>>[],
        },
        ApiConstants.recomendaciones('7'): {
          'success': true,
          'recomendaciones': <Map<String, dynamic>>[],
        },
        ApiConstants.categorias: {
          'success': true,
          'categorias': [
            {'id': 1, 'nombre': 'Pasteles'},
          ],
        },
        ApiConstants.filtros: {'success': true, 'filtros': <String, dynamic>{}},
        ApiConstants.carrito: _carrito,
        ApiConstants.configuracionSeccion('contacto'): {
          'success': true,
          'config': {'direccion': 'Av. Revolución 100'},
        },
        for (final seccion in ['personalizacion', 'inicio'])
          ApiConstants.configuracionSeccion(seccion): {
            'success': true,
            'config': <String, dynamic>{},
          },
        ApiConstants.contenido: {
          'success': true,
          'contenido': <String, dynamic>{},
        },
        for (final (endpoint, lista) in _listasVacias)
          endpoint: {'success': true, lista: <Map<String, dynamic>>[]},
        ApiConstants.favoritosIds: {'success': true, 'ids': <int>[]},
      },
    );
  }

  late final FakeApiClient api;

  /// Líneas del carrito en memoria, en el formato de GET /carrito.
  final List<Map<String, dynamic>> lineasDelCarrito = [];

  /// El producto que se compra: el primero del catálogo.
  Product get producto => Product.fromJson(_catalogo.first);

  static const List<Map<String, Object>> _catalogo = [
    {
      'id': 7,
      'nombre': 'Chocoflan',
      'precio_chico': '350.00',
      'stock_online': 5,
      'activo': true,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'reviews': 0,
    },
    {
      'id': 8,
      'nombre': 'Pay de queso',
      'precio_chico': '250.00',
      'stock_online': 3,
      'activo': true,
      'categoria': 'Pasteles',
      'imagen_url': '',
      'reviews': 0,
    },
  ];

  /// Endpoints que el Inicio, el catálogo y el checkout piden al entrar y que
  /// en este flujo no traen nada: endpoint → nombre de la lista.
  static final List<(String, String)> _listasVacias = [
    (ApiConstants.notificaciones, 'notificaciones'),
    (ApiConstants.resenasDestacadas, 'resenas'),
    (ApiConstants.misResenas, 'resenas'),
    (ApiConstants.misPedidos, 'pedidos'),
    (ApiConstants.productosComprados, 'productos'),
    (ApiConstants.promocionesActivas, 'promociones'),
    (ApiConstants.publicacionesPromociones, 'promociones'),
    // Sin la consulta (?limite=8): FakeApiClient también responde así.
    (ApiConstants.publicacionesFeed().split('?').first, 'publicaciones'),
    (ApiConstants.direcciones, 'direcciones'),
  ];

  /// POST agrega una línea, DELETE vacía y GET lista lo que hay.
  Map<String, dynamic> _carrito(LlamadaApi llamada) {
    switch (llamada.metodo) {
      case 'POST-Auth':
        final cuerpo = llamada.body!;
        lineasDelCarrito.add({
          'producto_id': cuerpo['producto_id'],
          'carrito_item_id': 150 + lineasDelCarrito.length + 1,
          'nombre': producto.nombre,
          'precio_unitario': '350.00',
          'precio_original': '350.00',
          'cantidad': cuerpo['cantidad'],
          'tamano': cuerpo['tamano'],
        });
        return {'success': true};
      case 'DELETE-Auth':
        lineasDelCarrito.clear();
        return {'success': true};
      default:
        return {
          'success': true,
          'carrito': {
            'items': [for (final linea in lineasDelCarrito) {...linea}],
          },
        };
    }
  }
}
