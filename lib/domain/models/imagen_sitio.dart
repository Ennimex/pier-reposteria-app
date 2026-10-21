// lib/domain/models/imagen_sitio.dart
//
// Fotos que guarda el editor del sitio de Dirección (GET /contenido). Un campo
// de imagen trae "local:<archivo>" (una de las fotos que vienen con la web:
// producto1 a producto6, en .jpg, .webp o -tarjeta.webp) o la URL de
// Cloudinary de una foto subida. La web las pinta con urlImagen
// (src/sitio/imagenesLocales.ts); la app trae su copia de cada foto en
// assets/images/sitio/.

final RegExp _local =
    RegExp(r'^local:producto([1-6])(?:\.jpg|\.webp|-tarjeta\.webp)$');

/// Lo que la app pinta para [valor]: la ruta del asset de una foto «local:»,
/// la URL https tal cual, o null si no hay foto que pintar.
String? imagenDelSitio(String? valor) {
  if (valor == null) return null;
  final local = _local.firstMatch(valor);
  if (local != null) return 'assets/images/sitio/producto${local[1]}.webp';
  return valor.startsWith('https://') ? valor : null;
}
