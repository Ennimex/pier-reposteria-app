// lib/data/services/contacto_guardado_service.dart
//
// La última configuración de contacto que llegó del servidor (teléfono,
// WhatsApp, correo, dirección y horarios), guardada en el teléfono (#312,
// SharedPreferences, no secreta). Sin internet, «Encuéntranos» muestra lo
// último que se supo en lugar de los datos de respaldo de BusinessInfo.
import 'dart:convert';

import 'package:pier_reposteria/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactoGuardadoService {
  /// [preferencias]: dónde se guarda (en pruebas, un teléfono que no acepta
  /// la escritura).
  ContactoGuardadoService({
    Future<SharedPreferences> Function() preferencias =
        SharedPreferences.getInstance,
  }) : _preferencias = preferencias;

  /// La versión va en la llave: si cambia el formato, la copia vieja se deja
  /// de leer sin romper nada.
  static const _llave = 'pierreposteria_contacto_v1';

  final Future<SharedPreferences> Function() _preferencias;

  /// El `config` guardado, o null si no hay o no se puede leer.
  Future<Map<String, dynamic>?> leer() async {
    try {
      final prefs = await _preferencias();
      final guardado = prefs.getString(_llave);
      if (guardado == null) return null;
      return jsonDecode(guardado) as Map<String, dynamic>;
    } on Object catch (e) {
      PierLog.error('No se pudo leer el contacto guardado: $e');
      return null;
    }
  }

  /// Guarda [config] tal como llegó; reemplaza la copia anterior. Nunca
  /// lanza: sin copia se usa BusinessInfo; si no se pudo guardar, lo
  /// registra.
  Future<void> guardar(Map<String, dynamic> config) async {
    try {
      final prefs = await _preferencias();
      if (!await prefs.setString(_llave, jsonEncode(config))) {
        PierLog.error('No se pudo guardar el contacto: el teléfono no aceptó '
            'la copia');
      }
    } on Object catch (e) {
      PierLog.error('No se pudo guardar el contacto: $e');
    }
  }
}
