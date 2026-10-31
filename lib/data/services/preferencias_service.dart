// lib/data/services/preferencias_service.dart
//
// Preferencias del cliente que se guardan solo en el teléfono y no son
// secretas (SharedPreferences): por ahora, cuándo aceptó el aviso de
// privacidad (#220). Lo sensible (token y datos personales) vive en
// StorageService, cifrado.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cuándo y cómo se aceptó el aviso de privacidad. [versionApp] es la versión
/// de la app con la que se aceptó: el backend todavía no guarda la versión
/// del aviso (NOTA del backend), así que es la mejor referencia disponible.
class AceptacionPrivacidad {
  const AceptacionPrivacidad({
    required this.fecha,
    required this.versionApp,
    required this.via,
  });

  factory AceptacionPrivacidad.fromJson(Map<String, dynamic> json) =>
      AceptacionPrivacidad(
        fecha: DateTime.parse(json['fecha'] as String),
        versionApp: json['version_app'] as String,
        via: json['via'] as String,
      );

  final DateTime fecha;
  final String versionApp;

  /// «correo» (registro) o «google».
  final String via;

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toUtc().toIso8601String(),
        'version_app': versionApp,
        'via': via,
      };
}

class PreferenciasService {
  static const _aceptacionKey = 'pierreposteria_privacidad_aceptada';

  Future<void> guardarAceptacionPrivacidad(
      AceptacionPrivacidad aceptacion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aceptacionKey, jsonEncode(aceptacion.toJson()));
  }

  /// La última aceptación guardada, o null si nunca se aceptó o el valor no
  /// se puede leer.
  Future<AceptacionPrivacidad?> aceptacionPrivacidad() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getString(_aceptacionKey);
    if (guardada == null) return null;
    try {
      return AceptacionPrivacidad.fromJson(
          jsonDecode(guardada) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }
}
