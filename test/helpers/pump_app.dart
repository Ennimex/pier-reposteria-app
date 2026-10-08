// test/helpers/pump_app.dart — helper para pruebas de widget (#15).
//
// Monta widgets con los 8 providers globales que registra main.dart, todos
// sobre un FakeApiClient (sin red), y simula SharedPreferences vacío (sin
// sesión guardada).
//
//   await tester.pumpApp(const LoginScreen());          // pantalla suelta
//   await tester.pumpApp(const LoginScreen(), api: api); // con respuestas
//   await tester.pumpMyApp(initialLocation: AppRoutes.login); // app completa
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_pasteleria/app.dart';
import 'package:pier_pasteleria/data/repositories/auth_repository.dart';
import 'package:pier_pasteleria/data/repositories/carrito_repository.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/repositories/entregas_repository.dart';
import 'package:pier_pasteleria/data/repositories/notificaciones_repository.dart';
import 'package:pier_pasteleria/data/repositories/pedidos_repository.dart';
import 'package:pier_pasteleria/data/repositories/productos_repository.dart';
import 'package:pier_pasteleria/routing/app_routes.dart';
import 'package:pier_pasteleria/ui/core/state/auth_provider.dart';
import 'package:pier_pasteleria/ui/core/state/cart_provider.dart';
import 'package:pier_pasteleria/ui/core/state/entregas_provider.dart';
import 'package:pier_pasteleria/ui/core/state/navigation_provider.dart';
import 'package:pier_pasteleria/ui/core/state/notification_provider.dart';
import 'package:pier_pasteleria/ui/core/state/order_provider.dart';
import 'package:pier_pasteleria/ui/core/state/product_provider.dart';
import 'package:pier_pasteleria/ui/core/state/tema_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api_client.dart';

/// Los mismos 8 providers de main.dart, cada uno con su repositorio sobre [api].
List<SingleChildWidget> providersDePrueba(FakeApiClient api) => [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(auth: AuthRepository(api: api)),
      ),
      ChangeNotifierProvider(
        create: (_) => CartProvider(repo: CarritoRepository(api: api)),
      ),
      ChangeNotifierProvider(
        create: (_) => OrderProvider(repo: PedidosRepository(api: api)),
      ),
      ChangeNotifierProvider(
        create: (_) => ProductProvider(repo: ProductosRepository(api: api)),
      ),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(
        create: (_) =>
            NotificationProvider(repo: NotificacionesRepository(api: api)),
      ),
      ChangeNotifierProvider(
        create: (_) => EntregasProvider(repo: EntregasRepository(api: api)),
      ),
      ChangeNotifierProvider(
        create: (_) => TemaProvider(repo: ConfiguracionRepository(api: api)),
      ),
    ];

extension PumpApp on WidgetTester {
  /// Monta [widget] dentro de un MaterialApp con los providers globales.
  Future<void> pumpApp(Widget widget, {FakeApiClient? api}) async {
    SharedPreferences.setMockInitialValues({});
    await pumpWidget(
      MultiProvider(
        providers: providersDePrueba(api ?? FakeApiClient()),
        child: MaterialApp(home: widget),
      ),
    );
  }

  /// Monta la app completa (MyApp con su router) en [initialLocation].
  Future<void> pumpMyApp({
    FakeApiClient? api,
    String initialLocation = AppRoutes.splash,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await pumpWidget(
      MultiProvider(
        providers: providersDePrueba(api ?? FakeApiClient()),
        child: MyApp(initialLocation: initialLocation),
      ),
    );
  }
}
