// lib/utils/fotos.dart
//
// La foto de una tarjeta de producto, reducida por Cloudinary (#267). Las
// fotos del catálogo se suben en su tamaño original; Cloudinary entrega una
// más chica con solo insertar una transformación después de /upload/ (no hace
// falta tocar el backend): w_<ancho> baja el ancho, c_limit nunca agranda una
// foto que ya es más chica, q_auto elige la calidad y f_auto el formato más
// ligero que el teléfono entiende.

/// `https://res.cloudinary.com/<nube>/<tipo>/upload/` y, aparte, lo que sigue:
/// la versión (v123/), la carpeta o una transformación. Solo mira la ruta
/// (antes de ? y #).
final RegExp _cloudinary = RegExp(
  r'^(https?://res\.cloudinary\.com/[^?#]*?/upload/)([^?#].*)$',
);

/// Lo que ya viene transformado: uno o varios parámetros (w_300 o
/// c_fill,w_300) y una diagonal. La versión (v123/) y las carpetas no
/// empiezan con una a tres letras seguidas de un guion bajo.
final RegExp _yaTransformada = RegExp('^[a-z]{1,3}_[^/]*/');

/// La dirección de [url] con la foto reducida a [ancho] de ancho como máximo.
///
/// Solo cambian las fotos de `res.cloudinary.com` con `/upload/` que todavía
/// no traen una transformación. Cualquier otra cosa (otra dirección, una foto
/// ya transformada, una cadena vacía, una referencia `local:`) se devuelve
/// tal cual.
String fotoReducida(String url, {int ancho = 600}) {
  final partes = _cloudinary.firstMatch(url);
  if (partes == null) return url;
  final resto = partes[2]!;
  if (_yaTransformada.hasMatch(resto)) return url;
  return '${partes[1]}w_$ancho,c_limit,q_auto,f_auto/$resto';
}
