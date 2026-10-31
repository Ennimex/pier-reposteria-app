// lib/utils/texto_sanitizado.dart
//
// El sanitizador global del backend (validator.escape) guarda escapado lo
// que escribe el personal: 'Pan & café "Rosa"' llega como
// 'Pan &amp; café &quot;Rosa&quot;'. Aquí se deshacen SOLO las entidades que
// él mete (más &#39;, el apóstrofo en decimal) y en una sola pasada:
// '&amp;lt;' vuelve a ser '&lt;', que es lo que se escribió. Es la
// decodificarSanitizado de la web (src/utils/etiquetasAuditoria.ts); la usan
// «Atención a clientes» y lo que el cliente lee de Pier (#138).

const Map<String, String> _entidades = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#x27;': "'",
  '&#39;': "'",
  '&#x2F;': '/',
  '&#x5C;': r'\',
  '&#96;': '`',
};

final RegExp _patron = RegExp('&(?:amp|lt|gt|quot|#x27|#39|#x2F|#x5C|#96);');

/// [texto] tal como se escribió, sin el escapado del sanitizador.
String decodificarSanitizado(String texto) => texto.replaceAllMapped(
      _patron,
      (m) => _entidades[m[0]] ?? m[0]!,
    );
