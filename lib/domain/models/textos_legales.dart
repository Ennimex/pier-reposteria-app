// lib/domain/models/textos_legales.dart
//
// Textos legales que Dirección captura en el panel. Fuente:
// GET /api/configuracion/legales -> config{privacidad, terminos, reembolsos}
// (texto plano, misma fuente que Legales.tsx). Cada campo es null si no se
// capturó; la app muestra entonces sus secciones por defecto.
import 'package:pier_pasteleria/utils/config_format.dart';

class TextosLegales {
  const TextosLegales({this.privacidad, this.terminos, this.reembolsos});

  factory TextosLegales.fromConfig(Map<dynamic, dynamic> cfg) => TextosLegales(
        privacidad: configTexto(cfg['privacidad']),
        terminos: configTexto(cfg['terminos']),
        reembolsos: configTexto(cfg['reembolsos']),
      );

  final String? privacidad;
  final String? terminos;
  final String? reembolsos;
}

/// Una tarjeta de la pantalla legal: título opcional ('' = sin título) y
/// contenido.
class SeccionLegal {
  const SeccionLegal({required this.contenido, this.titulo = ''});

  /// Convierte el texto del panel en tarjetas: bloques separados por línea en
  /// blanco (o una tarjeta por línea si no hay bloques). Si un bloque tiene
  /// varias líneas y la primera es corta y no termina en punto ni es viñeta,
  /// esa línea es el título de la tarjeta (sin los dos puntos finales). Si el
  /// texto viene como un solo párrafo sin saltos (así está capturado hoy en el
  /// panel), se reparte una tarjeta por oración para no pintar un bloque
  /// corrido.
  static List<SeccionLegal> desdeTexto(String texto) {
    final normal = texto.replaceAll('\r\n', '\n').trim();
    if (!normal.contains('\n')) {
      // Corte tras . ! ? seguido de espacio y mayúscula (no parte "C.P. 43000"
      // ni decimales). Probado con los 3 textos reales del panel: 5/7/5 tarjetas.
      return normal
          .split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡])'))
          .map((o) => o.trim())
          .where((o) => o.isNotEmpty)
          .map((o) => SeccionLegal(contenido: o))
          .toList();
    }
    var bloques = normal.split(RegExp(r'\n\s*\n'));
    if (bloques.length == 1) bloques = normal.split('\n');
    final out = <SeccionLegal>[];
    for (final b in bloques) {
      final lineas = b
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lineas.isEmpty) continue;
      final primera = lineas.first;
      final esTitulo = lineas.length > 1 &&
          primera.length <= 60 &&
          !primera.endsWith('.') &&
          !primera.startsWith('-') &&
          !primera.startsWith('•');
      out.add(
        esTitulo
            ? SeccionLegal(
                titulo: primera.replaceFirst(RegExp(r':$'), ''),
                contenido: lineas.sublist(1).join('\n'),
              )
            : SeccionLegal(contenido: lineas.join('\n')),
      );
    }
    return out;
  }

  final String titulo;
  final String contenido;
}
