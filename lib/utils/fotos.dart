// lib/utils/fotos.dart
//
// La foto de una tarjeta de producto, reducida por Cloudinary (#267). Las
// fotos del catálogo se suben en su tamaño original; Cloudinary entrega una
// más chica con solo insertar una transformación después de /upload/ (no hace
// falta tocar el backend): w_<ancho> baja el ancho, c_limit nunca agranda una
// foto que ya es más chica, q_auto elige la calidad y f_auto el formato más
// ligero que el teléfono entiende.

/// `https://res.cloudinary.com/<nube>/<tipo>/upload/` y, aparte, lo que sigue:
/// la firma, la versión (v123/), la carpeta o una transformación. Solo mira
/// la ruta (antes de ? y #).
final RegExp _cloudinary = RegExp(
  r'^(https?://res\.cloudinary\.com/[^?#]*?/upload/)([^?#].*)$',
);

/// Un parámetro de transformación de Cloudinary: su clave (w, c, q, t, e,
/// dpr…, o una variable propia como $ancho), un guion bajo y su valor (w_300,
/// c_limit, t_tarjeta, e_sepia:50). Una carpeta como img_x o mis_fotos
/// también tiene un guion bajo, pero su nombre no es una clave.
const _parametro =
    '(?:a|ac|af|ar|b|bo|br|c|co|cs|d|dl|dn|dpr|du|e|eo|f|fl|fn|fps|g|h|if|'
    r'ki|l|o|p|pg|q|r|so|sp|t|u|vc|vs|w|x|y|z|\$[a-zA-Z][a-zA-Z0-9]*)'
    '_[^,/?#]+';

/// Lo que ya viene transformado: uno o varios parámetros separados por comas
/// (w_300 o c_fill,w_300) y una diagonal. La versión (v123/) y las carpetas,
/// aunque no traigan versión, no lo son.
final RegExp _yaTransformada = RegExp('^$_parametro(?:,$_parametro)*/');

/// Una dirección firmada (s--XXXXXXXX--/ justo después de /upload/): la
/// firma cubre la transformación y la foto, así que insertar una
/// transformación la rompería y Cloudinary ya no la entregaría.
final RegExp _firmada = RegExp('^s--[A-Za-z0-9_-]+--/');

/// La dirección de [url] con la foto reducida a [ancho] de ancho como máximo.
///
/// Solo cambian las fotos de `res.cloudinary.com` con `/upload/` que todavía
/// no traen una transformación. Cualquier otra cosa (otra dirección, una foto
/// ya transformada, una firmada, una cadena vacía, una referencia `local:`)
/// se devuelve tal cual.
String fotoReducida(String url, {int ancho = 600}) {
  final partes = _cloudinary.firstMatch(url);
  if (partes == null) return url;
  final resto = partes[2]!;
  if (_firmada.hasMatch(resto) || _yaTransformada.hasMatch(resto)) return url;
  return '${partes[1]}w_$ancho,c_limit,q_auto,f_auto/$resto';
}
