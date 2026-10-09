// lib/data/repositories/configuracion_repository.dart
//
// Única puerta a los datos de la configuración pública del panel (contacto, personalización, inicio, faq, nosotros, legales). En esta fase (2 de MVVM) cada
// método devuelve la respuesta cruda del backend ({success, ...}) tal como la
// consumen hoy las pantallas; el tipado a modelos llega con cada ViewModel.
// Recibe un ApiClient por constructor: en la app es ApiService, en pruebas
// FakeApiClient (test/fakes/).
//
// Fase 3: las secciones que ya tienen ViewModel tienen su método tipado
// (nosotros) y lanzan ApiException si el backend falla.
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';
import 'package:pier_pasteleria/domain/models/info_nosotros.dart';

class ConfiguracionRepository {
  ConfiguracionRepository({ApiClient? api}) : _api = api ?? ApiService();

  final ApiClient _api;

  /// GET /configuracion/:seccion -> {success, config: {clave: valor}}.
  /// Solo secciones de la whitelist pública del backend; el resto da 403.
  Future<Map<String, dynamic>> seccion(String nombre) =>
      _api.get(ApiConstants.configuracionSeccion(nombre));

  /// GET /configuracion/nosotros. Sin `config` devuelve todo vacío.
  Future<InfoNosotros> nosotros() async {
    final r = await seccion('nosotros');
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudo cargar «Nosotros»',
      );
    }
    final cfg = r['config'];
    return cfg is Map ? InfoNosotros.fromConfig(cfg) : const InfoNosotros();
  }
}
