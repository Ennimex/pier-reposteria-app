// lib/data/repositories/comandas_repository_remote.dart
//
// Implementación HTTP de ComandasRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/api_exception.dart';
import 'package:pier_pasteleria/data/repositories/comandas_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';

/// Implementación de [ComandasRepository] contra el backend vía [ApiClient].
class ComandasRepositoryRemote implements ComandasRepository {
  ComandasRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<AgendaComandas> agenda({
    VistaAgenda vista = VistaAgenda.proximas,
    String busqueda = '',
  }) async {
    final r = await _exigir(
      _api.getAuth(
          ApiConstants.agendaComandas(vista.name, busqueda: busqueda.trim())),
      'No se pudieron cargar las comandas',
    );
    return AgendaComandas.fromJson(r);
  }

  /// La respuesta si trae success: true; si no, SesionInvalidaException
  /// (cuenta desactivada o cambiada) o ApiException con su mensaje (o
  /// [porDefecto]).
  static Future<Map<String, dynamic>> _exigir(
    Future<Map<String, dynamic>> llamada,
    String porDefecto,
  ) async {
    final r = await llamada;
    if (r['success'] == true) return r;
    final mensaje = r['message']?.toString() ?? porDefecto;
    if (r['codigo'] == 'SESION_INVALIDA') {
      throw SesionInvalidaException(mensaje);
    }
    throw ApiException(mensaje);
  }
}
