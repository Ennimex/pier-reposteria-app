// test/fakes/fake_api_client.dart
//
// ApiClient de pruebas: no toca la red. Responde con lo que se le configure
// por endpoint y registra cada llamada para poder afirmar qué pidió el
// código probado. Solo existe en test/; la app instalada usa ApiService.
//
//   final api = FakeApiClient(respuestas: {
//     '/resenas/mis-resenas': {'success': true, 'resenas': [...]},
//   });
//   api.fallar('/carrito', 'Token expirado');
//   ...
//   expect(api.llamo('/resenas/mis-resenas', metodo: 'GET-Auth'), true);
import 'package:pier_pasteleria/data/services/api_client.dart';

/// Una llamada registrada por el falso.
class LlamadaApi {
  final String metodo; // GET, GET-Auth, POST, POST-Auth, PUT-Auth, DELETE-Auth, UPLOAD
  final String endpoint;
  final Map<String, dynamic>? body;
  const LlamadaApi(this.metodo, this.endpoint, [this.body]);

  @override
  String toString() => '$metodo $endpoint${body == null ? '' : ' $body'}';
}

/// Respuesta calculada a partir de la llamada (para simular eco del body,
/// contadores, etc.).
typedef RespuestaDinamica = Map<String, dynamic> Function(LlamadaApi llamada);

class FakeApiClient implements ApiClient {
  final Map<String, dynamic> _respuestas;

  /// Todas las llamadas recibidas, en orden.
  final List<LlamadaApi> llamadas = [];

  FakeApiClient({Map<String, dynamic>? respuestas})
      : _respuestas = {...?respuestas};

  /// Configura una respuesta fija para un endpoint.
  void responder(String endpoint, Map<String, dynamic> respuesta) =>
      _respuestas[endpoint] = respuesta;

  /// Atajo: simula que el backend rechazó la llamada con ese mensaje.
  void fallar(String endpoint, String mensaje) =>
      _respuestas[endpoint] = {'success': false, 'message': mensaje};

  /// ¿Se llamó este endpoint? Opcionalmente con un método concreto.
  bool llamo(String endpoint, {String? metodo}) => llamadas.any((l) =>
      l.endpoint == endpoint && (metodo == null || l.metodo == metodo));

  /// Última llamada a un endpoint (para inspeccionar el body enviado).
  LlamadaApi? ultima(String endpoint) {
    for (final l in llamadas.reversed) {
      if (l.endpoint == endpoint) return l;
    }
    return null;
  }

  Future<Map<String, dynamic>> _resolver(String metodo, String endpoint,
      [Map<String, dynamic>? body]) async {
    final llamada = LlamadaApi(metodo, endpoint, body);
    llamadas.add(llamada);
    // Coincidencia exacta; si no, sin query string (cotizar?colonia=X).
    final clave = _respuestas.containsKey(endpoint)
        ? endpoint
        : endpoint.split('?').first;
    final r = _respuestas[clave];
    if (r == null) {
      return {
        'success': false,
        'message': 'Sin respuesta configurada: $endpoint',
      };
    }
    if (r is RespuestaDinamica) return Map<String, dynamic>.from(r(llamada));
    if (r is Map) return Map<String, dynamic>.from(r);
    throw StateError('Respuesta inválida para $endpoint: ${r.runtimeType}');
  }

  @override
  Future<Map<String, dynamic>> get(String endpoint) =>
      _resolver('GET', endpoint);

  @override
  Future<Map<String, dynamic>> getAuth(String endpoint) =>
      _resolver('GET-Auth', endpoint);

  @override
  Future<Map<String, dynamic>> post(
          String endpoint, Map<String, dynamic> body) =>
      _resolver('POST', endpoint, body);

  @override
  Future<Map<String, dynamic>> postAuth(
          String endpoint, Map<String, dynamic> body) =>
      _resolver('POST-Auth', endpoint, body);

  @override
  Future<Map<String, dynamic>> putAuth(
          String endpoint, Map<String, dynamic> body) =>
      _resolver('PUT-Auth', endpoint, body);

  @override
  Future<Map<String, dynamic>> deleteAuth(String endpoint) =>
      _resolver('DELETE-Auth', endpoint);

  @override
  Future<Map<String, dynamic>> uploadImageAuth(
          String endpoint, String filePath, Map<String, String> fields) =>
      _resolver('UPLOAD', endpoint, {'filePath': filePath, ...fields});
}
