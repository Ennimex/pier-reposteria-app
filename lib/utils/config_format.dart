// lib/utils/config_format.dart
//
// Helpers para mostrar valores de `configuracion/*` del backend. El backend
// guarda cada valor como JSON (JSON.stringify), por lo que un campo puede
// llegar como texto plano, como JSON serializado (string que empieza con
// '{' o '['), o ya como Map/List. Estos helpers lo normalizan a texto legible.

import 'dart:convert';

/// Horario de negocio. El backend lo guarda como la clave `horarios` DENTRO de
/// la seccion `contacto` (NO existe una seccion `horarios`): un array de
/// {sucursal, horario, descripcion}. Acepta ese array (o su JSON serializado),
/// texto plano, o un mapa dia->rango (compat). Devuelve texto legible.
String formatearHorario(
  dynamic raw, {
  String fallback = 'Lun–Sáb  9:00 AM – 9:00 PM',
}) {
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
  if (raw is List) {
    // Formato del panel web: [{sucursal, horario, descripcion}, ...]
    final lineas = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final h = item['horario']?.toString().trim() ?? '';
        if (h.isEmpty) continue;
        final s = item['sucursal']?.toString().trim() ?? '';
        lineas.add(s.isNotEmpty ? '$s: $h' : h);
      } else {
        final s = item.toString().trim();
        if (s.isNotEmpty) lineas.add(s);
      }
    }
    return lineas.join('\n');
  }
  if (raw is Map) {
    // Compat: {horario: '...'} o mapa dia -> rango.
    final directo = raw['horario']?.toString().trim();
    if (directo != null && directo.isNotEmpty) return directo;
    final partes = <String>[];
    raw.forEach((k, v) {
      final valor = v?.toString().trim() ?? '';
      if (valor.isNotEmpty) partes.add('${_prettyClave(k.toString())}: $valor');
    });
    return partes.join('\n');
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

/// Normaliza un valor crudo de `configuracion/*`: si llega como JSON
/// serializado (string que empieza con '{' o '[') lo decodifica; si ya es
/// Map/List/num/bool lo devuelve tal cual. Un string que no es JSON se
/// devuelve recortado. Nunca lanza.
dynamic parseConfigValor(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('{') || t.startsWith('[') || t.startsWith('"')) {
      try {
        return jsonDecode(t);
      } catch (_) {
        return t;
      }
    }
    return t;
  }
  return raw;
}

/// Texto NO vacío de un valor de configuración, o null si no hay texto.
/// Útil para "valor del panel ?? texto por defecto de la app".
String? configTexto(dynamic raw) {
  final v = parseConfigValor(raw);
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}
