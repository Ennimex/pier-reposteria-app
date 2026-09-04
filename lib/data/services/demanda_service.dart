// lib/data/services/demanda_service.dart
//
// Registro silencioso de "demanda no atendida": qué busca la gente en el
// catálogo y qué intenta comprar cuando está agotado. Espejo de
// src/utils/demandaNoAtendida.ts de la web. Nunca bloquea ni interrumpe al
// cliente: si el registro falla, la navegación sigue igual.
//
// A diferencia de la web, NO se manda `usuario_id`: hoy el backend lo toma
// del body sin verificarlo (anotado a Pedro en NOTA_PARA_PEDRO #13). Cuando
// lo lea del JWT bastará con cambiar `post` por `postAuth` aquí.

import 'dart:async';

import 'package:pier_pasteleria/config/api_constants.dart';
import 'package:pier_pasteleria/utils/logger.dart';
import 'package:pier_pasteleria/data/services/api_service.dart';

class DemandaService {
  DemandaService._();
  static final ApiService _api = ApiService();

  /// Registra un término buscado y cuántos resultados dio (0 = oro puro).
  static void registrarBusqueda(String texto, int numResultados) {
    final limpio = texto.trim();
    if (limpio.length < 2) return;
    unawaited(_enviar(ApiConstants.busquedas, {
      'texto': limpio.length > 120 ? limpio.substring(0, 120) : limpio,
      'num_resultados': numResultados,
    }));
  }

  /// Registra el interés en un producto agotado (botón "Avísame").
  static void registrarClicAgotado(String productoId) {
    final id = int.tryParse(productoId);
    if (id == null) return;
    unawaited(_enviar(ApiConstants.clicsAgotados, {'producto_id': id}));
  }

  static Future<void> _enviar(String endpoint, Map<String, dynamic> body) async {
    try {
      final r = await _api.post(endpoint, body);
      PierLog.debug(
          'Demanda no atendida $endpoint → ${r['registrado'] ?? r['success']}');
    } catch (e) {
      PierLog.debug('Demanda no atendida $endpoint no registrada: $e');
    }
  }
}
