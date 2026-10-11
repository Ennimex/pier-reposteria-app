// test/flutter_test_config.dart — se aplica a todas las pruebas de test/.
//
// StorageService guarda el JWT con flutter_secure_storage (#25), que en
// pruebas no tiene plataforma nativa: cada prueba arranca con un
// almacenamiento seguro simulado y vacío (sin sesión), igual que hacen con
// SharedPreferences.setMockInitialValues({}).
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  await testMain();
}
