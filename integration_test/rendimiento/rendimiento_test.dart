// integration_test/rendimiento/rendimiento_test.dart — #61: línea base de
// fluidez de la app real con el servidor real, en el Samsung SM-N975U.
//
// Flutter solo mide bien en modo profile, y el modo profile no corre en
// emuladores: se corre con flutter drive en el celular (ver rendimiento.yml)
// y test_driver/perf_driver.dart guarda cada medición en
// build/<medición>.timeline_summary.json.
//
// Tres mediciones con traceAction, como las vive el cliente:
//   · arranque:  la app se abre con la sesión guardada, pasa el splash y
//                arma el Inicio con sus animaciones de entrada.
//   · catalogo:  el catálogo se desplaza hasta abajo y de regreso.
//   · checkout:  del carrito con un producto a «Finalizar Pedido».
// El cuadro debe construirse en 16 ms o menos para verse a 60 por segundo.
//
// Usa la cuenta de prueba (USUARIO_PRUEBA y CLAVE_PRUEBA con --dart-define);
// sin ella se omite. El carrito se vacía al terminar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pier_reposteria/data/repositories/carrito_repository_remote.dart';
import 'package:pier_reposteria/routing/app_routes.dart';

import '../ayudas/servidor_real.dart';

/// Lo que se deja correr la pantalla después de aparecer, para que la
/// medición incluya sus animaciones de entrada y la carga de imágenes.
const _ventana = Duration(seconds: 3);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  toquesPerdidosFallan();

  /// Mide [accion] con los cuadros que pide el motor como en la app real
  /// (vsync), no la prueba: ahí tester.pump solo espera. Fuera de la medición
  /// (iniciar sesión, preparar el carrito) la prueba corre como las de flujos.
  Future<void> medir(String medicion, Future<void> Function() accion) async {
    final antes = binding.framePolicy;
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
    try {
      await binding.traceAction(accion, reportKey: medicion);
    } finally {
      binding.framePolicy = antes;
    }
  }

  group('#61 Línea base de rendimiento', () {
    testWidgets('arranque con la sesión guardada', (tester) async {
      if (faltanCredenciales()) return;
      await abrirLaApp(tester);
      await iniciarSesion(tester);

      // Otra app desde cero: el splash encuentra la sesión y va al Inicio.
      await medir('arranque', () async {
        await abrirLaApp(tester, initialLocation: AppRoutes.splash);
        await esperar(
          tester,
          find.byType(BottomNavigationBar),
          limite: esperaDelServidor,
        );
        await tester.pump(_ventana);
      });
    });

    testWidgets('desplazar el catálogo', (tester) async {
      if (faltanCredenciales()) return;
      await abrirLaApp(tester);
      await iniciarSesion(tester);
      await tester.tap(pestana('Catálogo'));
      final lista = listaDelCatalogo();
      await esperar(tester, lista, limite: esperaDelServidor);
      await tester.pump(_ventana);

      await medir('catalogo', () async {
        for (final sentido in [-1.0, 1.0]) {
          for (var vez = 0; vez < 5; vez++) {
            await tester.fling(lista.first, Offset(0, 800 * sentido), 3000);
            await tester.pump(const Duration(seconds: 1));
          }
        }
      });
    });

    testWidgets('abrir el checkout', (tester) async {
      if (faltanCredenciales()) return;
      final api = await abrirLaApp(tester);
      addTearDown(() => CarritoRepositoryRemote(api: api).vaciar());
      await iniciarSesion(tester);
      final producto = await productoConExistencias(api);
      await agregarAlCarrito(tester, producto);

      await medir('checkout', () async {
        await abrirElCheckout(tester, producto);
        await tester.pump(_ventana);
      });
    });
  });
}
