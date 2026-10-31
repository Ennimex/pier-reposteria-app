// lib/data/services/api_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pier_reposteria/config/api_constants.dart';
import 'package:pier_reposteria/data/services/api_client.dart';
import 'package:pier_reposteria/data/services/storage_service.dart';
import 'package:pier_reposteria/utils/logger.dart';

// Implementa el contrato ApiClient (data/services/api_client.dart): los
// repositorios dependen de la interfaz, y en pruebas se sustituye por
// FakeApiClient sin tocar la red.
//
// Patrón Singleton: la app usa un solo cliente HTTP, que comparten los 17
// repositorios. El constructor generativo es privado (ApiService._interno),
// la instancia única vive en _instancia y el constructor público es un
// factory que siempre la devuelve: `ApiService()` en cualquier parte de la
// app es el mismo objeto.
class ApiService implements ApiClient {
  /// Devuelve la instancia única de la app.
  factory ApiService() => _instancia;

  ApiService._interno();

  static final ApiService _instancia = ApiService._interno();

  final StorageService _storage = StorageService();

  final StreamController<void> _sesionExpirada =
      StreamController<void>.broadcast();

  @override
  Stream<void> get sesionExpirada => _sesionExpirada.stream;

  /// Cliente para todas las peticiones. En producción, main.dart pone el que
  /// fija el certificado del API (#219, cliente_seguro.dart). Sin uno fijo
  /// (pruebas, entorno aislado por http) cada petición usa un http.Client()
  /// nuevo, como antes.
  http.Client? cliente;

  Future<T> _conCliente<T>(
      Future<T> Function(http.Client cliente) peticion) async {
    final fijo = cliente;
    if (fijo != null) return peticion(fijo);
    final nuevo = http.Client();
    try {
      return await peticion(nuevo);
    } finally {
      nuevo.close();
    }
  }

  /// Lo que ve el cliente cuando la petición no llega al backend (sin red,
  /// DNS, servidor caído). El detalle técnico queda solo en el log de debug.
  static const mensajeSinConexion =
      'No pudimos conectar con Pier. Revisa tu internet e intenta de nuevo.';

  static Map<String, dynamic> get _sinConexion =>
      {'success': false, 'message': mensajeSinConexion};

  // Anuncia una sola vez a qué backend apunta (PierLog solo imprime en debug).
  static bool _ambienteAnunciado = false;

  static String _url(String endpoint) {
    if (!_ambienteAnunciado) {
      _ambienteAnunciado = true;
      PierLog.info(
          'Ambiente ${ApiConstants.ambiente.name} → ${ApiConstants.baseUrl}');
    }
    return '${ApiConstants.baseUrl}$endpoint';
  }

  // Headers base sin auth
  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json',
      };

  // Headers con JWT
  Future<Map<String, String>> get _authHeaders async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET sin autenticación
  @override
  Future<Map<String, dynamic>> get(String endpoint) async {
    PierLog.api('GET $endpoint');
    try {
      final response = await _conCliente((cliente) => cliente.get(
            Uri.parse(_url(endpoint)),
            headers: _baseHeaders,
          ));
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error GET $endpoint: $e');
      return _sinConexion;
    }
  }

  // GET con autenticación
  @override
  Future<Map<String, dynamic>> getAuth(String endpoint) async {
    PierLog.api('GET-Auth $endpoint');
    try {
      final headers = await _authHeaders;
      final response = await _conCliente((cliente) => cliente.get(
            Uri.parse(_url(endpoint)),
            headers: headers,
          ));
      await _revisarSesion(response, endpoint, headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error GET-Auth $endpoint: $e');
      return _sinConexion;
    }
  }

  // POST sin autenticación
  @override
  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    PierLog.api('POST $endpoint');
    try {
      final response = await _conCliente((cliente) => cliente.post(
            Uri.parse(_url(endpoint)),
            headers: _baseHeaders,
            body: jsonEncode(body),
          ));
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error POST $endpoint: $e');
      return _sinConexion;
    }
  }

  // POST con autenticación
  @override
  Future<Map<String, dynamic>> postAuth(
      String endpoint, Map<String, dynamic> body) async {
    PierLog.api('POST-Auth $endpoint');
    try {
      final headers = await _authHeaders;
      final response = await _conCliente((cliente) => cliente.post(
            Uri.parse(_url(endpoint)),
            headers: headers,
            body: jsonEncode(body),
          ));
      await _revisarSesion(response, endpoint, headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error POST-Auth $endpoint: $e');
      return _sinConexion;
    }
  }

  // PUT con autenticación
  @override
  Future<Map<String, dynamic>> putAuth(
      String endpoint, Map<String, dynamic> body) async {
    PierLog.api('PUT-Auth $endpoint');
    try {
      final headers = await _authHeaders;
      final response = await _conCliente((cliente) => cliente.put(
            Uri.parse(_url(endpoint)),
            headers: headers,
            body: jsonEncode(body),
          ));
      await _revisarSesion(response, endpoint, headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error PUT-Auth $endpoint: $e');
      return _sinConexion;
    }
  }

  // DELETE con autenticación
  @override
  Future<Map<String, dynamic>> deleteAuth(String endpoint) async {
    PierLog.api('DELETE-Auth $endpoint');
    try {
      final headers = await _authHeaders;
      final response = await _conCliente((cliente) => cliente.delete(
            Uri.parse(_url(endpoint)),
            headers: headers,
          ));
      await _revisarSesion(response, endpoint, headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error DELETE-Auth $endpoint: $e');
      return _sinConexion;
    }
  }

  /// Un 401 a una petición con token significa que la sesión ya no sirve:
  /// el token venció o se revocó, o la cuenta se desactivó (#218). Se borra
  /// la sesión del teléfono y se avisa por [sesionExpirada]. No cuenta el 401
  /// de /auth/logout (cerrar sesión con un token vencido no la vuelve a
  /// cerrar) ni el de una petición que salió sin token.
  Future<void> _revisarSesion(
    http.Response response,
    String endpoint,
    Map<String, String> headers,
  ) async {
    if (response.statusCode != 401) return;
    if (!headers.containsKey('Authorization')) return;
    if (endpoint == ApiConstants.logout) return;
    PierLog.auth('401 en $endpoint: la sesión expiró');
    await _storage.clearAll();
    _sesionExpirada.add(null);
  }

  // Manejo centralizado de respuestas
  Map<String, dynamic> _handleResponse(http.Response response, String endpoint) {
    try {
      PierLog.api('Respuesta [${response.statusCode}] $endpoint');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      PierLog.error('Fallo en $endpoint: ${data['message']}');
      // Se preserva el resto del cuerpo (p.ej. 'status' en pagos) para que
      // el caller pueda distinguir tipos de fallo.
      return {
        ...data,
        'success': false,
        'message': data['message'] ?? 'Error del servidor',
      };
    } catch (e) {
      PierLog.error('Error parseando respuesta de $endpoint: $e');
      return {
        'success': false,
        'message': 'Error al procesar la respuesta',
      };
    }
  }

  // MULTIPART con autenticación
  @override
  Future<Map<String, dynamic>> uploadImageAuth(String endpoint, String filePath, Map<String, String> fields) async {
    PierLog.api('UPLOAD-Auth $endpoint');
    try {
      final token = await _storage.getToken();
      final uri = Uri.parse(_url(endpoint));
      final request = http.MultipartRequest('POST', uri);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.fields.addAll(fields);
      String ext = filePath.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
        ext = 'jpeg'; // fallback
      }
      
      request.files.add(await http.MultipartFile.fromPath(
        'imagen', 
        filePath,
        contentType: MediaType('image', ext == 'jpg' ? 'jpeg' : ext),
      ));
      
      final response = await _conCliente((cliente) async =>
          http.Response.fromStream(await cliente.send(request)));
      await _revisarSesion(response, endpoint, request.headers);
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error UPLOAD-Auth $endpoint: $e');
      return {
        'success': false,
        'message': 'No se pudo subir la imagen. Intenta de nuevo.',
      };
    }
  }
}
