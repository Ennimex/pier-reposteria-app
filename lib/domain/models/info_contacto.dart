// lib/domain/models/info_contacto.dart
//
// Datos de contacto que Dirección captura en el panel. Fuente:
// GET /api/configuracion/contacto -> config{telefono, email, whatsapp,
// direccion, horarios[{sucursal, horario, descripcion}]}. El horario vive
// dentro de 'contacto' (no existe una sección 'horarios' pública). Cada campo
// es null si no se capturó; la app conserva entonces el de BusinessInfo.
import 'package:pier_pasteleria/utils/config_format.dart';

class InfoContacto {
  const InfoContacto({
    this.telefono,
    this.email,
    this.whatsapp,
    this.horario,
    this.direccion,
  });

  /// Lee el mapa `config` de la sección. Los valores pueden llegar como texto,
  /// JSON serializado o ya decodificados (ver utils/config_format.dart).
  factory InfoContacto.fromConfig(Map<dynamic, dynamic> cfg) {
    final horario = formatearHorario(cfg['horarios'], fallback: '');
    final direccion = formatearDireccion(cfg['direccion'], fallback: '');
    return InfoContacto(
      telefono: configTexto(cfg['telefono']),
      email: configTexto(cfg['email']),
      whatsapp: configTexto(cfg['whatsapp']),
      horario: horario.isEmpty ? null : horario,
      direccion: direccion.isEmpty ? null : direccion,
    );
  }

  final String? telefono;
  final String? email;
  final String? whatsapp;

  /// Ya formateado para mostrar (una línea por sucursal).
  final String? horario;

  /// Ya formateada para mostrar.
  final String? direccion;
}
