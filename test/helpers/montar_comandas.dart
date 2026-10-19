// test/helpers/montar_comandas.dart — monta una pantalla de comandas (#127,
// #128, #129) con sesión del rol dado, dentro de un router con login (para
// probar el cierre de sesión), sobre el backend falso. La pantalla de
// prueba es muy alta para que la lista quepa completa con la fuente de
// pruebas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pier_reposteria/config/dependencies.dart';
import 'package:pier_reposteria/routing/app_routes.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_api_client.dart';

Future<void> montarComandas(
  WidgetTester tester,
  FakeApiClient api, {
  required Widget pantalla,
  String rol = 'hornos',
}) async {
  tester.view
    ..physicalSize = const Size(1080, 7200)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Sin plugin de Google en pruebas: su signOut (al cerrar sesión) responde
  // al instante.
  const google = MethodChannel('plugins.flutter.io/google_sign_in');
  final mensajero = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(google, (_) async => null);
  addTearDown(() => mensajero.setMockMethodCallHandler(google, null));
  SharedPreferences.setMockInitialValues({});
  api.responder('/auth/logout', {'success': true});
  final router = GoRouter(
    initialLocation: AppRoutes.comandas,
    routes: [
      GoRoute(path: AppRoutes.comandas, builder: (_, _) => pantalla),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN')),
      ),
    ],
  );
  // La sesión se abre fuera del build; luego se monta el router.
  final listo = ValueNotifier(false);
  late BuildContext contexto;
  await tester.pumpWidget(
    MultiProvider(
      providers: dependencias(api),
      child: ValueListenableBuilder<bool>(
        valueListenable: listo,
        builder: (context, montar, _) {
          contexto = context;
          return montar
              ? MaterialApp.router(routerConfig: router)
              : const SizedBox();
        },
      ),
    ),
  );
  contexto.read<AuthProvider>().abrirSesion({
    'id': 1,
    'nombre': 'Rosa',
    'rol': rol,
  });
  listo.value = true;
  await tester.pumpAndSettle();
}

/// Registra las URLs que la app intenta abrir (url_launcher sin plugin).
List<Object?> capturarUrls(WidgetTester tester) {
  const canal = MethodChannel('plugins.flutter.io/url_launcher');
  final abiertas = <Object?>[];
  final mensajero = tester.binding.defaultBinaryMessenger
    ..setMockMethodCallHandler(canal, (llamada) async {
      abiertas.add((llamada.arguments as Map)['url']);
      return true;
    });
  addTearDown(() => mensajero.setMockMethodCallHandler(canal, null));
  return abiertas;
}
