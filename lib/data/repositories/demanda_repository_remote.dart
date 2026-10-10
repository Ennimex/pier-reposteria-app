// lib/data/repositories/demanda_repository_remote.dart
//
// Implementación HTTP de DemandaRepository. Recibe el ApiClient por
// constructor: en la app, el ApiService único de lib/config/dependencies.dart;
// en pruebas, FakeApiClient (test/fakes/).
//
// A diferencia de la web, NO se manda `usuario_id`: hoy el backend lo toma
// del body sin verificarlo (anotado a Pedro en NOTA_PARA_PEDRO #13). Cuando
// lo lea del JWT bastará con cambiar `post` por `postAuth` aquí.
import 'dart:async';

import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/data/repositories/demanda_repository.dart';
import 'package:pier_pasteleria/data/services/api_client.dart';
import 'package:pier_pasteleria/utils/logger.dart';

/// Implementación de [DemandaRepository] contra el backend vía [ApiClient].
class DemandaRepositoryRemote implements DemandaRepository {
  DemandaRepositoryRemote({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  void registrarBusqueda(String texto, int numResultados) {
    final limpio = texto.trim();
    if (limpio.length < 2) return;
    unawaited(_enviar(ApiConstants.busquedas, {
      'texto': limpio.length > 120 ? limpio.substring(0, 120) : limpio,
      'num_resultados': numResultados,
    }));
  }

  @override
  void registrarClicAgotado(String productoId) {
    final id = int.tryParse(productoId);
    if (id == null) return;
    unawaited(_enviar(ApiConstants.clicsAgotados, {'producto_id': id}));
  }

  Future<void> _enviar(String endpoint, Map<String, dynamic> body) async {
    try {
      final r = await _api.post(endpoint, body);
      PierLog.debug(
          'Demanda no atendida $endpoint → ${r['registrado'] ?? r['success']}');
    } catch (e) {
      PierLog.debug('Demanda no atendida $endpoint no registrada: $e');
    }
  }
}
