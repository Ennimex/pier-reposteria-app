// lib/domain/models/sucursal_atencion.dart
//
// Una sucursal con su horario de atención (#320), como la captura Dirección
// en el panel: GET /configuracion/contacto → `horarios: [{sucursal, horario,
// descripcion, ...}]`, con el horario en texto libre («Lun - Dom: 8:00 AM -
// 9:00 PM»). Al recoger, el cliente elige la sucursal y las horas salen de su
// horario; a domicilio se usan las horas en que abren todas (horarioComun),
// así nunca se ofrece una hora en que alguna esté cerrada.
import 'dart:convert';

import 'package:pier_reposteria/domain/models/horario_atencion.dart';

class SucursalAtencion {
  const SucursalAtencion({
    required this.nombre,
    required this.horarioTexto,
    this.horario,
  });

  /// La sucursal [nombre] con su horario escrito [texto], ya interpretado.
  SucursalAtencion._desdeTexto(String nombre, String texto)
      : nombre = nombre.trim(),
        horarioTexto = texto.trim(),
        horario = HorarioAtencion.desdeTexto(texto);

  /// Como se capturó en el panel («Sucursal Aviacion»); vacío si el horario
  /// llegó como texto suelto, sin sucursal.
  final String nombre;

  /// El horario tal como se ve.
  final String horarioTexto;

  /// El horario interpretado; null si el texto no se entiende.
  final HorarioAtencion? horario;

  /// Lee `horarios` de la configuración de contacto: la lista del panel, esa
  /// misma lista en JSON, un mapa o un texto suelto. Las sucursales sin
  /// horario se omiten.
  static List<SucursalAtencion> listaDesdeConfig(Object? horarios) {
    if (horarios is String) {
      final texto = horarios.trim();
      if (texto.isEmpty) return const [];
      if (texto.startsWith('[') || texto.startsWith('{')) {
        try {
          return listaDesdeConfig(jsonDecode(texto));
        } on FormatException {
          return const [];
        }
      }
      return [SucursalAtencion._desdeTexto('', texto)];
    }
    final entradas = switch (horarios) {
      final List<Object?> lista => lista,
      final Map<Object?, Object?> una => [una],
      _ => const <Object?>[],
    };
    return [for (final entrada in entradas) ?_desdeEntrada(entrada)];
  }

  static SucursalAtencion? _desdeEntrada(Object? entrada) {
    final (nombre, texto) = switch (entrada) {
      final String s => ('', s),
      final Map<Object?, Object?> m => (
          m['sucursal']?.toString() ?? '',
          m['horario']?.toString() ?? '',
        ),
      _ => ('', ''),
    };
    return texto.trim().isEmpty
        ? null
        : SucursalAtencion._desdeTexto(nombre, texto);
  }

  /// Las horas en que abren todas [sucursales]; null si no hay, si alguna no
  /// tiene un horario que se entienda o si no coinciden ningún día.
  static HorarioAtencion? horarioComun(List<SucursalAtencion> sucursales) {
    HorarioAtencion? comun;
    for (final sucursal in sucursales) {
      final horario = sucursal.horario;
      if (horario == null) return null;
      comun = comun == null ? horario : comun.interseccion(horario);
    }
    return (comun != null && comun.abreAlgunDia) ? comun : null;
  }
}
