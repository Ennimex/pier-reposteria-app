// lib/core/utils/config_format.dart
//
// Helpers para mostrar valores de `configuracion/*` del backend. El backend
// guarda cada valor como JSON (JSON.stringify), por lo que un campo puede
// llegar como texto plano, como JSON serializado (string que empieza con
// '{' o '['), o ya como Map/List. Estos helpers lo normalizan a texto legible.

import 'dart:convert';

/// Horario de `configuracion/horarios`. Acepta el mapa completo de la seccion
/// y prioriza las claves conocidas; si el valor es un mapa de dias -> rango lo
/// formatea como lineas "Dia: rango".
String formatearHorario(
  Map<String, dynamic> configHorarios, {
  String fallback = 'Lun–Sáb  9:00 AM – 9:00 PM',
}) {
  dynamic raw = configHorarios['horario'] ??
      configHorarios['lunes_sabado'] ??
      configHorarios['semana'];
  // Si no hay clave conocida pero si hay datos, usar todo el mapa.
  raw ??= configHorarios.isNotEmpty ? configHorarios : null;

  final texto = _horarioToTexto(raw);
  return texto.isNotEmpty ? texto : fallback;
}

String _horarioToTexto(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('{') || t.startsWith('[')) {
      try {
        return _horarioToTexto(jsonDecode(t));
      } catch (_) {
        return t;
      }
    }
    return t;
  }
  if (raw is Map) {
    final partes = <String>[];
    raw.forEach((k, v) {
      final valor = v?.toString().trim() ?? '';
      if (valor.isNotEmpty) partes.add('${_prettyClave(k.toString())}: $valor');
    });
    return partes.join('\n');
  }
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }
  return raw.toString();
}

/// Direccion de `configuracion/contacto`. Acepta texto, JSON serializado o un
/// mapa {calle, colonia, ciudad, estado, cp} y lo une en una sola linea.
String formatearDireccion(
  dynamic raw, {
  String fallback = 'Calle Allende, Col. Tahuizán',
}) {
  final texto = _direccionToTexto(raw);
  return texto.isNotEmpty ? texto : fallback;
}

String _direccionToTexto(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.startsWith('{') || t.startsWith('[')) {
      try {
        return _direccionToTexto(jsonDecode(t));
      } catch (_) {
        return t;
      }
    }
    return t;
  }
  if (raw is Map) {
    final partes = <String>[];
    // Orden preferido de campos conocidos.
    for (final clave in const ['calle', 'colonia', 'ciudad', 'estado', 'cp']) {
      final v = raw[clave]?.toString().trim();
      if (v != null && v.isNotEmpty) partes.add(v);
    }
    // Si no coincidio ninguna clave conocida, usar todos los valores.
    if (partes.isEmpty) {
      raw.forEach((_, v) {
        final s = v?.toString().trim() ?? '';
        if (s.isNotEmpty) partes.add(s);
      });
    }
    return partes.join(', ');
  }
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  return raw.toString();
}

String _prettyClave(String clave) {
  final s = clave.replaceAll('_', ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
