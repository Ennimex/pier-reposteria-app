// lib/data/repositories/configuracion_repository.dart
//
// Única puerta a los datos de la configuración pública del panel (contacto, personalización, inicio, faq, nosotros, legales). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class ConfiguracionRepository {
  final ApiClient _api;
  ConfiguracionRepository({ApiClient? api}) : _api = api ?? ApiService();

  /// GET /configuracion/:seccion -> {success, config: {clave: valor}}.
  /// Solo secciones de la whitelist pública del backend; el resto da 403.
  Future<Map<String, dynamic>> seccion(String nombre) =>
      _api.get(ApiConstants.configuracionSeccion(nombre));
}
