// lib/data/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/data/services/storage_service.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';

// Implementa el contrato ApiClient (data/services/api_client.dart): los
// repositorios dependen de la interfaz, y en pruebas se sustituye por
// FakeApiClient sin tocar la red.
class ApiService implements ApiClient {
  final StorageService _storage = StorageService();

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
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _baseHeaders,
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error GET $endpoint: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // GET con autenticación
  @override
  Future<Map<String, dynamic>> getAuth(String endpoint) async {
    PierLog.api('GET-Auth $endpoint');
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: await _authHeaders,
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error GET-Auth $endpoint: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // POST sin autenticación
  @override
  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    PierLog.api('POST $endpoint');
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _baseHeaders,
        body: jsonEncode(body),
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error POST $endpoint: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // POST con autenticación
  @override
  Future<Map<String, dynamic>> postAuth(
      String endpoint, Map<String, dynamic> body) async {
    PierLog.api('POST-Auth $endpoint');
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: await _authHeaders,
        body: jsonEncode(body),
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error POST-Auth $endpoint: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // PUT con autenticación
  @override
  Future<Map<String, dynamic>> putAuth(
      String endpoint, Map<String, dynamic> body) async {
    PierLog.api('PUT-Auth $endpoint');
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: await _authHeaders,
        body: jsonEncode(body),
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error PUT-Auth $endpoint: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // DELETE con autenticación
  @override
  Future<Map<String, dynamic>> deleteAuth(String endpoint) async {
    PierLog.api('DELETE-Auth $endpoint');
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: await _authHeaders,
      );
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error DELETE-Auth $endpoint: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
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
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
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
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response, endpoint);
    } catch (e) {
      PierLog.error('Error UPLOAD-Auth $endpoint: $e');
      return {'success': false, 'message': 'Error al subir la imagen: $e'};
    }
  }
}