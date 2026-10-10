// lib/data/repositories/configuracion_repository_remote.dart
//
// Implementación HTTP de ConfiguracionRepository. Recibe el ApiClient por constructor:
// en la app, el ApiService único de lib/config/dependencies.dart; en
// pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/configuracion_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/info_contacto.dart';
import 'package:pier_pasteleria/domain/models/info_nosotros.dart';
import 'package:pier_pasteleria/domain/models/pregunta_frecuente.dart';
import 'package:pier_pasteleria/domain/models/textos_legales.dart';

/// Implementación de [ConfiguracionRepository] contra el backend vía [ApiClient].
class ConfiguracionRepositoryRemote implements ConfiguracionRepository {
  ConfiguracionRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> seccion(String nombre) =>
      _api.get(ApiConstants.configuracionSeccion(nombre));

  @override
  Future<InfoContacto> contacto() async {
    final r = await seccion('contacto');
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar los datos de contacto',
      );
    }
    final cfg = r['config'];
    return cfg is Map ? InfoContacto.fromConfig(cfg) : const InfoContacto();
  }

  @override
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

  @override
  Future<List<PreguntaFrecuente>> faq() async {
    final r = await seccion('faq');
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar las preguntas',
      );
    }
    final cfg = r['config'];
    return cfg is Map ? PreguntaFrecuente.listaDesdeConfig(cfg) : const [];
  }

  @override
  Future<TextosLegales> legales() async {
    final r = await seccion('legales');
    if (r['success'] != true) {
      throw ApiException(
        r['message']?.toString() ?? 'No se pudieron cargar los textos legales',
      );
    }
    final cfg = r['config'];
    return cfg is Map ? TextosLegales.fromConfig(cfg) : const TextosLegales();
  }
}
