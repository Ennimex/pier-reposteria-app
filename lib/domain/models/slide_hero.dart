// lib/domain/models/slide_hero.dart
//
// Un slide del carrusel del inicio: los de respaldo de la app, los del editor
// del sitio de Dirección (GET /contenido → inicio.carrusel, #168) o los que se
// administraban en Dirección → Personalización (como en la web).

/// A dónde lleva el botón del slide.
enum RutaSlide { catalogo, contacto, nosotros, faq, legales }

/// La pantalla de la app para un enlace del editor del sitio (una ruta de la
/// web, p. ej. "/contacto"). Lo que no tiene pantalla en la app (iniciar
/// sesión, crear cuenta, el inicio) abre el catálogo.
RutaSlide rutaDeEnlace(String enlace) =>
    switch (enlace.split('?').first) {
      '/contacto' => RutaSlide.contacto,
      '/nosotros' || '/conocenos' => RutaSlide.nosotros,
      '/preguntas-frecuentes' => RutaSlide.faq,
      '/legales' => RutaSlide.legales,
      _ => RutaSlide.catalogo,
    };

class SlideHero {
  const SlideHero({
    required this.titulo,
    required this.subtitulo,
    required this.cta,
    required this.imagen,
    this.etiqueta = '',
    this.ruta = RutaSlide.catalogo,
  });

  /// Píldora de arriba ("ARTESANAL"); vacía en los del panel.
  final String etiqueta;
  final String titulo;
  final String subtitulo;

  /// Texto del botón.
  final String cta;
  final RutaSlide ruta;

  /// URL de la foto o ruta de un asset de la app (assets/…).
  final String imagen;

  /// La foto viene con la app (no se descarga).
  bool get imagenEsAsset => imagen.startsWith('assets/');

  SlideHero copyWith({String? titulo, String? subtitulo}) => SlideHero(
        etiqueta: etiqueta,
        titulo: titulo ?? this.titulo,
        subtitulo: subtitulo ?? this.subtitulo,
        cta: cta,
        ruta: ruta,
        imagen: imagen,
      );
}
