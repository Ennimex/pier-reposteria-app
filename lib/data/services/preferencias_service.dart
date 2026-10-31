// lib/data/services/preferencias_service.dart
//
// Preferencias del cliente que se guardan solo en el teléfono y no son
// secretas (SharedPreferences): cuándo aceptó el aviso de privacidad (#220)
// y a qué tratamiento se opone (#223). Lo sensible (token y datos
// personales) vive en StorageService, cifrado.
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
  static const _diagnosticosKey = 'pierreposteria_enviar_diagnosticos';
  static const _busquedasKey = 'pierreposteria_registrar_busquedas';

  /// ¿Se mandan a Sentry los errores y la medición del rendimiento? Sí, hasta
  /// que el cliente se oponga (#223).
  Future<bool> enviaDiagnosticos() => _leer(_diagnosticosKey);

  Future<void> guardarEnviaDiagnosticos({required bool envia}) =>
      _guardar(_diagnosticosKey, envia);

  /// ¿Se registran las búsquedas y los clics en productos agotados (demanda
  /// no atendida)? Sí, hasta que el cliente se oponga (#223).
  Future<bool> registraBusquedas() => _leer(_busquedasKey);

  Future<void> guardarRegistraBusquedas({required bool registra}) =>
      _guardar(_busquedasKey, registra);

  /// Si no se puede leer, vale lo de omisión (encendido).
  Future<bool> _leer(String llave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(llave) ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> _guardar(String llave, bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(llave, valor);
  }

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
