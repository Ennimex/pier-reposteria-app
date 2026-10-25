// test/api/entorno_aislado.dart — lo que comparten las pruebas de la API
// contra el entorno aislado (tool/entorno_pruebas.sh): la dirección de la API
// y la cuenta de la semilla.
import 'dart:io';

/// La cuenta de cliente de docker/semilla/semilla_pruebas.sql. Es ficticia y
/// solo existe dentro del contenedor de la base: no es un secreto ni la
/// cuenta de prueba real (USUARIO_PRUEBA).
const correoDeLaSemilla = 'cliente@pier.test';
const claveDeLaSemilla = 'Chocoflan-Prueba-2026';

/// La dirección de la API, sin «/» al final: de --dart-define=API_BASE_URL o,
/// si no vino, de la variable de entorno API_BASE_URL. Sin ninguna de las dos
/// la prueba falla: no hay contra qué probar.
String urlDeLaApi() {
  const porDartDefine = String.fromEnvironment('API_BASE_URL');
  final url = porDartDefine.isNotEmpty
      ? porDartDefine
      : Platform.environment['API_BASE_URL'] ?? '';
  if (url.isEmpty) {
    throw StateError(
      'Falta la dirección de la API: levanta el entorno con '
      '«bash tool/entorno_pruebas.sh levantar» y pasa '
      '--dart-define=API_BASE_URL=http://localhost:3000/api',
    );
  }
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
