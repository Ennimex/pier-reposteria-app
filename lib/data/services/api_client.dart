// lib/data/services/api_client.dart
//
// Contrato del cliente HTTP de la app.
//
// `ApiService` es la implementación real (habla con Render). En pruebas se
// usa `FakeApiClient` (test/fakes/fake_api_client.dart), que responde con
// datos fijos sin tocar la red. Los repositorios (Fase 2 de MVVM) reciben un
// ApiClient por constructor y nunca crean un ApiService adentro: así la
// misma lógica corre contra el backend real en la app y contra el falso en
// `flutter test`.
//
// Convención de respuesta (la misma que ya usa ApiService._handleResponse):
// siempre un Map con `success` (bool) y, si falló, `message` (String); el
// resto del cuerpo del backend se conserva tal cual.
abstract class ApiClient {
  /// GET público, sin token.
  Future<Map<String, dynamic>> get(String endpoint);

  /// GET con JWT del usuario en sesión.
  Future<Map<String, dynamic>> getAuth(String endpoint);

  /// POST público, sin token.
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body);

  /// POST con JWT.
  Future<Map<String, dynamic>> postAuth(
      String endpoint, Map<String, dynamic> body);

  /// PUT con JWT.
  Future<Map<String, dynamic>> putAuth(
      String endpoint, Map<String, dynamic> body);

  /// DELETE con JWT.
  Future<Map<String, dynamic>> deleteAuth(String endpoint);

  /// Multipart con JWT (subida de imágenes: perfil, evidencia de entrega).
  Future<Map<String, dynamic>> uploadImageAuth(
      String endpoint, String filePath, Map<String, String> fields);
}
