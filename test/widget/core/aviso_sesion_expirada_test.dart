// test/widget/core/aviso_sesion_expirada_test.dart — #218: cuando el servidor
// rechaza el token, la app cierra la sesión y avisa una vez en la pantalla
// donde esté el cliente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/repositories/auth_repository_remote.dart';
import 'package:pier_reposteria/ui/core/state/auth_provider.dart';
import 'package:pier_reposteria/ui/core/ui/aviso_sesion_expirada.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_api_client.dart';

Future<AuthProvider> _montar(WidgetTester tester, FakeApiClient api) async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthProvider(auth: AuthRepositoryRemote(api: api))
    ..abrirSesion({'id': 1, 'nombre': 'Ana', 'rol': 'cliente'});
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: auth,
    child: MaterialApp(
      builder: (context, child) => AvisoSesionExpirada(child: child!),
      home: const Scaffold(body: Text('Inicio')),
    ),
  ));
  return auth;
}

Future<void> _avanzar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  testWidgets('#218: al expirar la sesión avisa en la pantalla actual',
      (tester) async {
    final api = FakeApiClient();
    final auth = await _montar(tester, api);

    api.expirarSesion();
    await _avanzar(tester);

    expect(find.text(AvisoSesionExpirada.mensaje), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.sesionExpiro, isFalse, reason: 'el aviso ya se mostró');
  });

  testWidgets('#218: varios 401 a la vez muestran un solo aviso',
      (tester) async {
    final api = FakeApiClient();
    await _montar(tester, api);

    api
      ..expirarSesion()
      ..expirarSesion();
    await _avanzar(tester);

    expect(find.text(AvisoSesionExpirada.mensaje), findsOneWidget);
  });

  testWidgets('sin expiración no hay aviso, aunque la sesión cambie',
      (tester) async {
    final api = FakeApiClient();
    final auth = await _montar(tester, api);

    auth.abrirSesion({'id': 2, 'rol': 'repartidor'});
    await _avanzar(tester);

    expect(find.text(AvisoSesionExpirada.mensaje), findsNothing);
  });

  testWidgets('desmontado deja de escuchar al AuthProvider', (tester) async {
    final api = FakeApiClient();
    final auth = await _montar(tester, api);

    await tester.pumpWidget(const SizedBox());
    api.expirarSesion();
    await tester.pump();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.sesionExpiro, isTrue, reason: 'nadie mostró el aviso');
    expect(tester.takeException(), isNull);
  });
}
